#!/usr/bin/env python3
"""tools/attribution-backfill.py — T544: backfill model attribution on the kanban.

The census (2026-08-20) measured 79% of closed rows with a null `model` field,
the field `tools/fleet-keeper.sh`'s least_data_model() counts.  Root cause:
`claim`/`done` wrote `agent` (who did the work) but never `model`; `model` was
only set at add/suggest when --model was passed.  A bulk re-lane additionally
set `model` to a WRONG value on some rows (D049/D050: T519/T532/T534).

This tool is NON-DESTRUCTIVE by default: it prints a census and a per-row diff
and writes nothing.  `--write` applies the backfill under the same
`<store>.lockfile` flock managent uses, atomically.

Resolution policy (sources in priority order, run-record > perf-ledger >
agent > model; `model` is the field under repair):

  * already-attributed (canonical `model` consistent with every present
    source)                                  -> untouched
  * store-wrong (canonical `model` contradicted by a higher-priority
    external source, or by `agent` when no external source exists)
                                             -> correct `model`, record
                                                model_source="conflict:<old>-><new>",
                                                list in the conflict report
  * backfill (`model` null, exactly one canonical candidate among
    run/perf/agent)                          -> set `model`, record
                                                model_source="run-record" /
                                                "perf-ledger" / "agent-field"
  * unattributed (`model` null, no candidate) -> set
                                                model="unattributed-pre-T544",
                                                model_source="unattributed-pre-T544"
                                                (explicit, never a silent null)
  * genuine conflict (`model` null, run and perf disagree, or several
    sources disagree with no external consensus) -> no value chosen: `model`
                                                left null, the row is listed
                                                in the conflict report (the
                                                documented conflict, not a
                                                silent one)

Idempotent: a second run over an already-backfilled store is a no-op (the
diff is empty).  Every backfilled value records its source so it can never be
mistaken for a first-hand observation.

The canonical model list is read from `bin/managent models` (T517's single
source) when available, with a fallback copy for a repo without a built
binary.

Task: T544 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22
"""
import argparse
import fcntl
import json
import os
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_STORE = os.path.join(ROOT, "docs", "infra", "managent", "tasks.json")
DEFAULT_PERF = os.path.join(ROOT, "docs", "infra", "model-perf.md")
DEFAULT_RUNS = os.path.join(ROOT, "untracked", "runs")

UNATTRIBUTED = "unattributed-pre-T544"
# The two explicit unattributed markers — a non-null, non-canonical `model`
# value that says "the data is gone" rather than a silent null.
MARKERS = {UNATTRIBUTED, "unattributed"}


def is_marker(m):
    return m in MARKERS

# Fallback canonical set — only used when `bin/managent models` is unavailable
# (a repo with no built binary).  It must mirror src/managent/main.zig
# canonical_models[]; the live path reads that list from the binary instead of
# keeping a second copy that drifts (T517).
FALLBACK_CANONICAL = [
    "claude-opus-5",
    "claude-sonnet-5",
    "claude-fable-5",
    "claude-haiku-4-5-20251001",
    "deepseek-v4-pro",
    "deepseek-v4-flash",
    "glm-5.2",
    "minimax-m3",
    "kimi-k2.7",
    "qwen3.8:27b-mlx",
]

ALIASES = {"dspro": "deepseek-v4-pro", "dsflash": "deepseek-v4-flash"}


def canonical_models():
    """The canonical set from `managent models` (T517 single source), falling
    back to the in-file copy only when the binary is absent."""
    mg = os.path.join(ROOT, "bin", "managent")
    if os.path.isfile(mg):
        try:
            out = subprocess.run(
                [mg, "models"], capture_output=True, text=True, timeout=10
            ).stdout
            labels = [l.strip() for l in out.splitlines() if l.strip()]
            if labels:
                return labels
        except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
            pass
    return list(FALLBACK_CANONICAL)


def canonicalize(raw):
    """Strip :cloud and the kimi -code variant, map dspro/dsflash — exactly
    like managent's canonicalizeModelTag plus bin/dispatch's aliases."""
    if not raw:
        return None
    s = ALIASES.get(raw, raw)
    if s.endswith(":cloud"):
        s = s[: -len(":cloud")]
    if s == "kimi-k2.7-code":
        return "kimi-k2.7"
    return s


def parse_perf_model(perf_text, task_id):
    """Model from a `dispatch-verify <date> <task> <model> ...` line, or None."""
    for line in perf_text.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[0] == "dispatch-verify" and parts[2] == task_id:
            if parts[3] == "-":
                return None
            return canonicalize(parts[3])
    return None


def parse_run_model(runs_dir, task_id):
    """Model from the run record's dispatch command (`--model <label>`), or
    None.  The run record is the literal command the dispatcher launched."""
    path = os.path.join(runs_dir, f"{task_id}.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, encoding="utf-8") as f:
            rec = json.load(f)
    except (OSError, ValueError):
        return None
    cmd = rec.get("command", "") or ""
    m = re.search(r"--model\s+([\w.:-]+)", cmd)
    if m:
        return canonicalize(m.group(1))
    return None


def resolve(model, agent, run, perf):
    """Return (action, new_model, new_source, conflict_detail).

    action in {"untouched", "backfill", "correct", "unattributed",
               "conflict-no-value"}.
    """
    model = canonicalize(model)
    agent = canonicalize(agent)

    sources = {}  # model -> set of source names
    if run:
        sources.setdefault(run, set()).add("run-record")
    if perf:
        sources.setdefault(perf, set()).add("perf-ledger")
    if agent:
        sources.setdefault(agent, set()).add("agent-field")
    if model:
        sources.setdefault(model, set()).add("model-store")

    def describe():
        return " ".join(
            f"{m}=[{','.join(sorted(ss))}]" for m, ss in sorted(sources.items())
        )

    if model is not None:
        # ── already-attributed rows ──────────────────────────────────────
        external = [m for m in (run, perf) if m]
        if len(set(external)) > 1:
            # run and perf disagree about an already-attributed row: no value
            # chosen (the store's model stays; the conflict is documented).
            return ("conflict-no-value", None, None, describe())
        ext_val = external[0] if external else None
        if ext_val is not None and ext_val != model:
            # store-wrong (D049/D050): prefer the external record.
            return ("correct", ext_val, f"conflict:{model}->{ext_val}", describe())
        if ext_val is None and agent is not None and agent != model:
            # store fields disagree, no external record: agent (first-hand
            # claim) outranks the bulk-lane `model`.
            return ("correct", agent, f"conflict:{model}->{agent}", describe())
        return ("untouched", None, None, None)

    # ── model is null ────────────────────────────────────────────────────
    cands = {m: ss for m, ss in sources.items()}
    if not cands:
        return ("unattributed", UNATTRIBUTED, UNATTRIBUTED, None)
    if len(cands) == 1:
        m = next(iter(cands))
        # highest-priority source name for the provenance field
        if run == m:
            src = "run-record"
        elif perf == m:
            src = "perf-ledger"
        else:
            src = "agent-field"
        return ("backfill", m, src, None)

    # multiple distinct candidates: prefer run/perf over the store (folded
    # note), but if the external sources themselves disagree there is no
    # value to choose.
    ext = sorted({m for m in (run, perf) if m})
    if len(ext) == 1:
        m = ext[0]
        src = "run-record" if run == m else "perf-ledger"
        # a backfill that resolves a store/external disagreement: still fill
        # the value (external wins) but record the conflict for the audit.
        return ("backfill", m, src, describe())
    return ("conflict-no-value", None, None, describe())


def load_store(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def tasks(store):
    return {k: v for k, v in store.items()
            if not k.startswith("_") and isinstance(v, dict)}


def closed_rows(store):
    return {k: v for k, v in tasks(store).items() if v.get("status") == "done"}


def plan(store, perf_text, runs_dir):
    """Return (rows_changed, conflicts, census).  rows_changed maps task id to
    (old_model, new_model, new_source); conflicts maps id to detail string.
    census states the denominator: done = attributed + backfilled + corrected
    + unattributed + conflict_no_value."""
    rows_changed = {}
    conflicts = {}
    census = {"done": 0, "attributed": 0, "backfilled": 0, "corrected": 0,
              "unattributed": 0, "conflict_no_value": 0}
    for tid, row in closed_rows(store).items():
        census["done"] += 1
        run = parse_run_model(runs_dir, tid)
        perf = parse_perf_model(perf_text, tid)
        action, new_model, new_source, detail = resolve(
            row.get("model"), row.get("agent"), run, perf)
        old_model = row.get("model")
        if action == "untouched":
            if is_marker(old_model):
                census["unattributed"] += 1
            else:
                census["attributed"] += 1
        elif action == "backfill":
            if detail:
                census["corrected"] += 1
                conflicts[tid] = detail
            else:
                census["backfilled"] += 1
            rows_changed[tid] = (old_model, new_model, new_source)
        elif action == "correct":
            census["corrected"] += 1
            conflicts[tid] = detail
            rows_changed[tid] = (old_model, new_model, new_source)
        elif action == "unattributed":
            census["unattributed"] += 1
            rows_changed[tid] = (old_model, new_model, new_source)
        else:  # conflict-no-value
            census["conflict_no_value"] += 1
            conflicts[tid] = detail
    return rows_changed, conflicts, census


def apply(store, rows_changed):
    for tid, (_, new_model, new_source) in rows_changed.items():
        store[tid]["model"] = new_model
        store[tid]["model_source"] = new_source
        # a backfilled/corrected value is never "unknown"; clear the reason
        # if a previous --model-unknown close had set one.
        if "model_unknown_reason" in store[tid] and new_model != UNATTRIBUTED:
            store[tid]["model_unknown_reason"] = None


def atomic_write(path, obj):
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix="tasks.json.tmp.", dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(obj, f, indent=2, ensure_ascii=False)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def print_diff(rows_changed, conflicts):
    if not rows_changed and not conflicts:
        print("  no changes (store is already consistent)")
        return
    for tid in sorted(rows_changed):
        old, new, src = rows_changed[tid]
        old_s = "null" if old is None else f'"{old}"'
        line = f"  {tid}: model {old_s} -> \"{new}\"  [source: {src}]"
        if tid in conflicts:
            line += f"  CONFLICT: {conflicts[tid]}"
        print(line)
    for tid in sorted(conflicts):
        if tid not in rows_changed:
            print(f"  {tid}: CONFLICT (no value chosen): {conflicts[tid]}")


def main(argv):
    ap = argparse.ArgumentParser(description="T544 attribution backfill")
    ap.add_argument("--store", default=os.environ.get("MANAGENT_STORE") or DEFAULT_STORE)
    ap.add_argument("--perf", default=DEFAULT_PERF)
    ap.add_argument("--runs", default=DEFAULT_RUNS)
    ap.add_argument("--write", action="store_true",
                    help="apply the backfill (default: print diff only)")
    ap.add_argument("--json", action="store_true",
                    help="emit the diff/census as JSON (stdout=data)")
    args = ap.parse_args(argv)

    perf_text = ""
    if os.path.isfile(args.perf):
        with open(args.perf, encoding="utf-8") as f:
            perf_text = f.read()

    if args.write:
        lock_path = args.store + ".lockfile"
        lock_fd = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX)
            store = load_store(args.store)
            rows_changed, conflicts, census = plan(store, perf_text, args.runs)
            if rows_changed:
                apply(store, rows_changed)
                atomic_write(args.store, store)
        finally:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
            os.close(lock_fd)
    else:
        if not os.path.isfile(args.store):
            print(f"backfill: store {args.store} not found", file=sys.stderr)
            return 1
        store = load_store(args.store)
        rows_changed, conflicts, census = plan(store, perf_text, args.runs)

    if args.json:
        print(json.dumps({"census": census, "rows_changed": rows_changed,
                          "conflicts": conflicts}, indent=1))
    else:
        print("census:", json.dumps(census))
        print_diff(rows_changed, conflicts)
        if args.write:
            print(f"  wrote {len(rows_changed)} row(s) to {args.store}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
