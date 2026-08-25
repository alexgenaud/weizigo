#!/usr/bin/env python3
"""Retroactively recover token readings the dispatch-time meter missed (T746).

WHY THIS EXISTS.  `tools/runner`'s pi/ollama meter reads a per-lane session
file only when the dispatcher passed `--session <path>` (T662).  When it did
not, the runner writes an explicit MISSING record whose reason says the pi
session file "cannot be attributed to this lane".  **That reason is false.**
`tools/token-capture.py` already implements the cwd-slug scan
(`~/.pi/agent/sessions/<cwd-slug>/`) and attributes those sessions to tasks;
measured 2026-08-23, it recovers 56 lanes the ledger records as UNKNOWN — 53
deepseek and 3 oxalpha — plus 334 tasks the ledger never mentions.  So the
readings were never lost, only un-joined.

The durable fix is the runner falling back to this scan before declaring
UNKNOWN; that is a tooling change and belongs to the refactorization sprint.
This tool is the retroactive half: it recovers what already happened.

DISCIPLINE.  The ledger is append-only, like a findings file — a MISSING
record is a dated assertion and is never edited.  A recovered reading is
APPENDED and carries `supersedes_ts` naming the record it corrects, so the
later assertion supersedes the earlier one and both stay readable.  A lane
that already has a dispatch-time reading is never touched: dispatch-time
truth outranks a retroactive scan.

CONFIDENCE.  A retro reading is marked `source: pi-session-jsonl-retro` and
`trusted: false`.  Per the operator's ruling (2026-08-23): token, cpu and rss
figures are collected but NOT trusted as repeatable, and no qualification
gate or cost ladder may take a decision from them until a repeatability
control exists.  The flag is what keeps a consumer honest.

JOIN KEY.  session.start vs run-record/ledger start, same task, within
--tolerance seconds (default 5).  Measured offset on the oxalpha lanes was
1.0-1.3 s (pi writes its session file just after the runner stamps `start`).
A session that matches no run record is reported, never guessed at.

Usage:
  tools/token-backfill.py                 # dry run: what would be appended
  tools/token-backfill.py --commit        # append the readings
  tools/token-backfill.py --task T735     # one task
  tools/token-backfill.py --control       # run the before/after control only

Task: T746 · Role: console · Model: claude-opus-5 · Date: 2026-08-23
"""
import argparse
import datetime
import importlib.util
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_tc():
    """Import tools/token-capture.py (a hyphenated name is not importable)."""
    path = os.path.join(ROOT, "tools", "token-capture.py")
    spec = importlib.util.spec_from_file_location("token_capture", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _iso_to_dt(s):
    if not s:
        return None
    t = s.strip().replace("Z", "+00:00")
    try:
        return datetime.datetime.fromisoformat(t)
    except ValueError:
        return None


def _is_reading(e):
    return e.get("tokens_in") is not None and e.get("tokens_out") is not None


def load_ledger_raw(path):
    out = []
    if not os.path.exists(path):
        return out
    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                out.append((i, json.loads(line)))
            except ValueError:
                continue
    return out


def load_run_records(root):
    """The runner's own per-attempt records — an INDEPENDENT surface that
    knows (task, start, model).  Used to corroborate the session scan's
    attribution: two surfaces derived from different code paths agreeing is
    the only oracle this recovery has (the ledger cannot serve, because a
    lane either wrote a per-lane session file OR a cwd-slug one, never both).
    """
    d = os.path.join(root, "untracked", "runs")
    out = {}
    if not os.path.isdir(d):
        return out
    for name in os.listdir(d):
        try:
            with open(os.path.join(d, name)) as f:
                r = json.load(f)
        except (OSError, ValueError):
            continue
        if r.get("task"):
            out.setdefault(r["task"], []).append(r)
    return out


def corroborate(tc, entry, runs, tolerance=10.0):
    """How well an independent surface backs this row's attribution.

    'run-record' — a run record for the same task starts within tolerance and
                   its model agrees after canonicalization (strongest).
    'task-only'  — a run record exists for the task but no start matches.
    'none'       — no run record: the lane was dispatched outside the runner.
    'CONFLICT'   — the run record names a different model.  Never appended.
    """
    rs = runs.get(entry["task"])
    if not rs:
        return "none", None
    e_dt = _iso_to_dt(entry["ts"])
    best, gap = None, None
    for r in rs:
        r_dt = _iso_to_dt(r.get("start"))
        if not (e_dt and r_dt):
            continue
        g = abs((e_dt - r_dt).total_seconds())
        if gap is None or g < gap:
            best, gap = r, g
    if best is None or gap > tolerance:
        return "task-only", None
    rm = tc.canon_tag(best.get("model") or "")
    if rm and rm != entry["model"]:
        return "CONFLICT", rm
    return "run-record", gap


def plan(tc, sessions_dir, ledger_path, tolerance, only_task=None):
    """Return (appends, skipped_has_reading, unmatched_sessions)."""
    sessions, _tasks, _models, _unattr, _scanned = tc.scan_sessions(sessions_dir)
    ledger = load_ledger_raw(ledger_path)

    # A task already carrying ANY reading is left alone entirely: a
    # retroactive scan never competes with dispatch-time truth.
    have_reading = {e.get("task") for _n, e in ledger if _is_reading(e)}
    # Retro rows already written — idempotence, so a re-run appends nothing.
    have_retro = {(e.get("task"), e.get("session_id")) for _n, e in ledger
                  if e.get("source") == "pi-session-jsonl-retro"}
    missing_by_task = {}
    for _n, e in ledger:
        if not _is_reading(e):
            missing_by_task.setdefault(e.get("task"), []).append(e)

    appends, skipped, unmatched = [], [], []
    for s in sessions:
        task = s.get("task")
        if not task or (only_task and task != only_task):
            continue
        if task in have_reading:
            skipped.append((task, s["file"]))
            continue
        if (task, s.get("session_id")) in have_retro:
            skipped.append((task, s["file"] + " (retro already present)"))
            continue

        # Which MISSING record does this session correct?  Nearest start
        # within tolerance; None when the ledger never recorded the lane.
        s_dt = _iso_to_dt(s.get("start"))
        best, best_gap = None, None
        for e in missing_by_task.get(task, []):
            e_dt = _iso_to_dt(e.get("ts"))
            if not (s_dt and e_dt):
                continue
            gap = abs((s_dt - e_dt).total_seconds())
            if gap <= tolerance and (best_gap is None or gap < best_gap):
                best, best_gap = e, gap

        tk = s["tokens"]
        entry = {
            "task": task,
            "model": tc.canon_tag(s.get("model") or ""),
            "provider": s.get("provider"),
            "source": "pi-session-jsonl-retro",
            "trusted": False,
            "trusted_reason": ("retroactive session-scan reading; operator ruling "
                               "2026-08-23 — token/cpu/rss figures are collected, "
                               "not trusted as repeatable, and gate no decision "
                               "until a repeatability control exists"),
            "tokens_in": s.get("tokens_in"),
            "tokens_out": s.get("tokens_out"),
            "tokens_fresh": tk.get("input"),
            "tokens_cache_read": tk.get("cache_read"),
            "tokens_cache_write": tk.get("cache_write"),
            "tokens_reasoning": tk.get("reasoning"),
            "turns": s.get("turns"),
            "session_id": s.get("session_id"),
            "session_path": os.path.join(sessions_dir, s["file"]),
            "missing_reason": None,
            "ts": s.get("start"),
            "recovered_by": "T746 tools/token-backfill.py",
        }
        if best is not None:
            entry["supersedes_ts"] = best.get("ts")
            entry["supersedes_reason"] = (
                "the superseded record's missing_reason asserts the pi session "
                "file cannot be attributed to this lane; it can — matched on "
                "task + start within %.1fs" % best_gap)
        else:
            entry["supersedes_ts"] = None
            entry["supersedes_reason"] = ("no ledger record for this lane at all "
                                          "(never UNKNOWN — simply never written)")
        appends.append(entry)

    # Corroboration grade per row — evidence is never flattened to one class.
    runs = load_run_records(ROOT)
    kept = []
    for e in appends:
        grade, detail = corroborate(tc, e, runs)
        e["corroborated"] = grade
        if grade == "run-record":
            e["corroborated_gap_s"] = round(detail, 1)
        elif grade == "CONFLICT":
            e["corroborated_conflict_model"] = detail
            continue          # a conflicting attribution is never appended
        kept.append(e)
    appends = kept

    for s in sessions:
        if not s.get("task"):
            unmatched.append(s["file"])
    return appends, skipped, unmatched


def control(tc, sessions_dir, ledger_path, task="T735"):
    """The null + seeded-defect pair for this tool, per the standing rule
    that no instrument's first reading counts without controls.

    null control     — a task with a dispatch-time reading must produce NO
                       append (the tool must not overwrite real truth).
    seeded defect    — canon_tag must map the stealth serving tag; if it
                       regresses, the ledger silently grows a T276 defect.
    """
    ok = True
    if tc.canon_tag("stealth/ox-alpha") != "oxalpha":
        print("  FAIL seeded-defect: canon_tag('stealth/ox-alpha') != 'oxalpha'")
        ok = False
    else:
        print("  pass seeded-defect: canon_tag maps the stealth serving tag")

    ledger = load_ledger_raw(ledger_path)
    with_reading = [e.get("task") for _n, e in ledger
                    if _is_reading(e) and e.get("source") != "pi-session-jsonl-retro"]
    if not with_reading:
        print("  SKIP null control: no dispatch-time reading in the ledger to guard")
    else:
        probe = with_reading[0]
        appends, _s, _u = plan(tc, sessions_dir, ledger_path, 5.0, only_task=probe)
        if appends:
            print("  FAIL null control: would append over %s, which already "
                  "has a dispatch-time reading" % probe)
            ok = False
        else:
            print("  pass null control: %s already has a reading, nothing "
                  "appended" % probe)
    return ok


def validate(tc, sessions_dir, ledger_path, tolerance):
    """Agreement against dispatch-time truth — the only independent check.

    For every lane that HAS a dispatch-time reading, the session scan is run
    anyway and the two are compared.  A retro reading is only worth appending
    to the 385 lanes with no record if it reproduces the readings we already
    trust.  Disagreement is reported per lane, never averaged away.
    """
    sessions, _t, _m, _u, _n = tc.scan_sessions(sessions_dir)
    ledger = load_ledger_raw(ledger_path)
    truth = {}
    for _n2, e in ledger:
        if _is_reading(e) and e.get("source") != "pi-session-jsonl-retro":
            truth.setdefault(e.get("task"), []).append(e)

    pairs = []
    for s in sessions:
        task = s.get("task")
        if not task or task not in truth:
            continue
        s_dt = _iso_to_dt(s.get("start"))
        best, best_gap = None, None
        for e in truth[task]:
            e_dt = _iso_to_dt(e.get("ts"))
            if not (s_dt and e_dt):
                continue
            gap = abs((s_dt - e_dt).total_seconds())
            if gap <= tolerance and (best_gap is None or gap < best_gap):
                best, best_gap = e, gap
        if best is not None:
            pairs.append((task, s, best, best_gap))

    if not pairs:
        print("no comparable lane: no session matched a dispatch-time reading "
              "within %.0fs — the method is UNVALIDATED, not validated" % tolerance)
        return False

    exact_out = exact_in = 0
    worst = []
    for task, s, e, gap in pairs:
        d_out = (s.get("tokens_out") or 0) - (e.get("tokens_out") or 0)
        d_in = (s.get("tokens_in") or 0) - (e.get("tokens_in") or 0)
        if d_out == 0:
            exact_out += 1
        if d_in == 0:
            exact_in += 1
        if d_out or d_in:
            worst.append((task, d_in, d_out, e.get("source"), gap))
    print("comparable lanes: %d (matched within %.0fs)" % (len(pairs), tolerance))
    print("  tokens_out reproduces exactly: %d/%d" % (exact_out, len(pairs)))
    print("  tokens_in  reproduces exactly: %d/%d" % (exact_in, len(pairs)))
    if worst:
        print("  disagreements (task, d_in, d_out, dispatch-time source, gap s):")
        for w in sorted(worst, key=lambda x: -abs(x[2]))[:15]:
            print("    %-10s d_in=%+d d_out=%+d  %s  %.1fs" % w)
    else:
        print("  no disagreement on any comparable lane")
    return exact_out == len(pairs)


def main(argv):
    ap = argparse.ArgumentParser(prog="token-backfill.py")
    ap.add_argument("--commit", action="store_true",
                    help="append the recovered readings (default: dry run)")
    ap.add_argument("--task", default=None, help="only this task id")
    ap.add_argument("--tolerance", type=float, default=5.0,
                    help="seconds between session start and ledger ts (default 5)")
    ap.add_argument("--sessions", default=None)
    ap.add_argument("--control", action="store_true",
                    help="run the before/after control and exit")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--validate", action="store_true",
                    help="agreement of the retro method against the lanes that "
                         "already carry a dispatch-time reading (the only "
                         "independent check this recovery has)")
    args = ap.parse_args(argv)

    tc = _load_tc()
    sessions_dir = args.sessions or tc.default_sessions_dir(ROOT)
    ledger_path = tc.ledger_path(ROOT)

    if args.validate:
        return 0 if validate(tc, sessions_dir, ledger_path, args.tolerance) else 1

    if args.control:
        print("controls for tools/token-backfill.py:")
        return 0 if control(tc, sessions_dir, ledger_path) else 1

    appends, skipped, unmatched = plan(tc, sessions_dir, ledger_path,
                                       args.tolerance, only_task=args.task)
    if args.json:
        print(json.dumps({"appends": appends, "skipped": len(skipped),
                          "unmatched_sessions": len(unmatched)}, sort_keys=True))
    else:
        print("sessions dir: %s" % sessions_dir)
        print("ledger:       %s" % ledger_path)
        print("recoverable:  %d lane(s)" % len(appends))
        by_model = {}
        for e in appends:
            by_model.setdefault(e["model"], []).append(e)
        for m in sorted(by_model):
            rows = by_model[m]
            print("  %-28s %3d lane(s)  out=%d" %
                  (m, len(rows), sum(r["tokens_out"] or 0 for r in rows)))
        print("skipped (already has a reading): %d" % len(skipped))
        print("sessions with no task attribution: %d" % len(unmatched))
        sup = sum(1 for e in appends if e["supersedes_ts"])
        print("of the recoverable, %d supersede an explicit UNKNOWN record "
              "and %d were never recorded at all" % (sup, len(appends) - sup))

    if not args.commit:
        if not args.json:
            print("\ndry run — nothing written.  --commit to append.")
        return 0

    n = 0
    for e in appends:
        if tc.append_ledger(ROOT, e):
            n += 1
    print("\nappended %d reading(s) to %s" % (n, ledger_path))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
