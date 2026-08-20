#!/usr/bin/env python3
"""Per-model dimension profiles from the ledger (T503).

The operator's directive (2026-08-20): "Grade each model's performance on
various aspect dimensions, then average each dimension to provide a
performance dimension profile per model. If we lack data linking a model to
task type, then that's reason to choose the model (rather than choose models
with abundant data)."

This is a READ-ONLY instrument: it reads the kanban store, the dispatch-verify
ledger, the wall-kill log census and the claimlint C7 findings conformance,
and reports per-model profiles.  It writes nothing — to the ledger or anywhere
else.

Dimensions (each graded per task from an existing recorded signal — no new
subjective scoring):

  correctness               verdict: pass=2, pass-with-findings=1,
                            fail-found=1, blocked=0, abandoned=0
  completion                status reached done=1, else 0 (graded only for
                            tasks that were claimed or closed — a never-claimed
                            dispatchable row has no completion data)
  close_discipline          dispatch-verify line: verified=pass=2;
                            verified=fail with fail in {nonce, deliverables,
                            findings}=1 (recoverable — the work exists, the
                            close protocol broke); fail in {row, exit}=0
                            (unrecoverable — the work is absent or crashed)
  efficiency                wall-kill log census (grep "exit 124" t*.log):
                            clean=2; RSS-cap kill, or a wall-ceiling kill
                            that was emitting progress=1 (wall-kill); a
                            wall-ceiling kill with no progress lines, or a
                            CPU-ceiling kill=0 (stall / over-broad)
  deliverable_conformance   findings file conforms per claimlint C7 AND
                            declared deliverables are git-committed=1, else 0
  independence              audit/verify tasks only: re-derived by a different
                            route=1, re-run=0 (keyword proxy over the recorded
                            note/verdict_note); non-audit tasks have no data

Averaging: per model, per dimension: sum of grades / count of tasks graded on
that dimension.  A dimension with zero graded tasks is `—` (null), never 0 —
absence of evidence is not evidence of absence.

Task types (spec / infra / verification / battery) are classified by a
deterministic keyword rule over the bundle slug + note + verdict_note.  This
map feeds ONLY the exploration-first selection rule, never a graded dimension.

Selection rule (exploration-first): for a task type, prefer the candidate
model with the least data (fewest graded tasks) of that type; if any candidate
has zero, a zero-data candidate is chosen.  Only when every candidate has data
on the type does the profile decide: highest average on the type's dominant
dimension (spec->correctness, infra->deliverable_conformance,
verification->independence, battery->correctness), ties by diversity (more
distinct types with data), then by the least data, then lexicographic label.

Canonical model labels mirror src/managent/main.zig canonical_models[]; the
log-tag canonicalization (strip :cloud, kimi-k2.7-code -> kimi-k2.7) is the
same transform managent applies at registration time.

Task: T503 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20
"""
import argparse
import json
import os
import re
import subprocess
import sys

CANONICAL_MODELS = [
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

DIMENSIONS = [
    "correctness",
    "completion",
    "close_discipline",
    "efficiency",
    "deliverable_conformance",
    "independence",
]

# Dominant dimension per task type — used only by the selection rule's
# "profile decides" branch.
DOMINANT = {
    "spec": "correctness",
    "infra": "deliverable_conformance",
    "verification": "independence",
    "battery": "correctness",
}

# Verdict -> correctness grade (missing verdict = no data).
CORRECTNESS_GRADE = {
    "pass": 2,
    "pass-with-findings": 1,
    "fail-found": 1,
    "blocked": 0,
    "abandoned": 0,
}

# Close-discipline fail reasons that are recoverable (the work exists; the
# close protocol broke).  Everything else (row, exit) is unrecoverable.
RECOVERABLE_FAIL = {"nonce", "deliverables", "findings"}

# Deliverable paths exempt from the git-committed requirement: these live
# outside git by the project's own no-silent-writes rule.
UNTRACKED_PREFIXES = ("untracked/", "data/", "artifacts/")

# ── task-type classifier: deterministic keyword rule, ordered ─────────────
# battery > verification > spec > infra (specific beats general).  The text
# blob is the lowercased bundle basename + note + verdict_note.
TYPE_KEYWORDS = [
    ("battery", [
        "battery", "mutant", "vb_", "bellman", "scc", "movegen", "closure",
        "smd1", "batt-health", "golden-master", "baseline",
        "-i11", "-i5", "-i8", "-i4", "-i9", "-i10", "-i12",
    ]),
    ("verification", [
        "audit", "verify", "verif", "race", "probe", "falsif", "confirm",
        "grade", "grading", "re-audit", "reaudit", "second-auditor",
        "third-auditor", "cross-check", "independent",
    ]),
    ("spec", [
        "spec", "design", "strategy", "architecture", "plan", "blueprint",
        "proposal", "draft",
    ]),
    ("infra", []),
]

# Independence marker: audit/verify tasks that re-derived by a different route.
INDEPENDENCE_MARKERS = [
    "independent", "re-implement", "reimplement", "re-derive", "rederive",
    "re-write", "rewrite", "different route", "from scratch", "second seat",
    "separate implementation", "by hand", "hand-derived", "re-derived",
]


def canon_tag(tag):
    """The same :cloud strip / -code map managent applies at registration."""
    t = tag.strip()
    if t.endswith(":cloud"):
        t = t[:-len(":cloud")]
    if t == "kimi-k2.7-code":
        t = "kimi-k2.7"
    return t


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def parse_dispatch_verify(text):
    """Yield dicts {date, task, model, report, verified, fail} for each
    `dispatch-verify` line.  A model of `-` (bare dispatch) is kept as-is;
    the task id `-` (bare dispatch) is normalized to None."""
    out = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("dispatch-verify "):
            continue
        parts = line.split()
        # parts[0]=dispatch-verify  [1]=date  [2]=task  [3]=model  then key=val
        if len(parts) < 5:
            continue
        task = parts[2] if parts[2] != "-" else None
        model = parts[3] if parts[3] != "-" else None
        rec = {"date": parts[1], "task": task, "model": model,
               "report": None, "verified": None, "fail": None}
        for kv in parts[4:]:
            if "=" in kv:
                k, v = kv.split("=", 1)
                rec[k] = v
        out.append(rec)
    return out


def scan_logs(logdir):
    """Return {(task, model): [kill_reasons]} from `exit 124` lines in
    untracked/log/t*.log, attributed to the model named in the segment's argv
    and the task named in its `task identity` line.  A model with no log, or a
    log with no `--model`, yields no efficiency data (the suite/bakeoff logs)."""
    kills = {}
    try:
        names = sorted(os.listdir(logdir))
    except OSError:
        return kills
    for name in names:
        if not (name.startswith("t") and name.endswith(".log")):
            continue
        cur_model = None
        cur_task = None
        try:
            fh = open(os.path.join(logdir, name), errors="replace")
        except OSError:
            continue
        with fh:
            for line in fh:
                if line.startswith("[runner] argv"):
                    m = re.search(r"--model\s+([\w.:-]+)", line)
                    cur_model = canon_tag(m.group(1)) if m else None
                    cur_task = None
                m = re.search(r"task identity:\s+(T\d+)", line)
                if m:
                    cur_task = m.group(1)
                m = re.search(r"\[runner\] exit 124 \(([^)]*)\)", line)
                if m and cur_model:
                    kills.setdefault((cur_task, cur_model), []).append(m.group(1))
    return kills


def read_c7(c7_path, claimlint_bin, root):
    """Return {task_id: [(conforming, reason), ...]} — one entry per findings
    file — from a precomputed c7 --json file, or by invoking the claimlint
    binary when no file is given."""
    if c7_path:
        data = read_json(c7_path)
        if isinstance(data, list):
            out = {}
            for e in data:
                tid = e.get("task_id")
                if not tid:
                    continue
                out.setdefault(tid, []).append(
                    (bool(e.get("conforming")), e.get("conforming_reason")))
            return out
        return {}

    if claimlint_bin and os.path.isfile(claimlint_bin):
        r = subprocess.run([claimlint_bin, "c7", "--json"],
                           capture_output=True, text=True, cwd=root)
        if r.returncode in (0, 1):  # 1 = non-conforming present; still JSON
            try:
                data = json.loads(r.stdout)
            except ValueError:
                data = []
            out = {}
            for e in data:
                tid = e.get("task_id")
                if tid:
                    out.setdefault(tid, []).append(
                        (bool(e.get("conforming")), e.get("conforming_reason")))
            return out
    return {}


def parse_deliverables(root, bundle):
    """Parse `deliverables=` from a bundle's managent meta header.  Returns []
    when the bundle is missing or declares nothing."""
    if not bundle:
        return []
    p = bundle if os.path.isabs(bundle) else os.path.join(root, bundle)
    try:
        with open(p) as f:
            for line in f:
                line = line.strip()
                if line.startswith("<!--managent "):
                    m = re.search(r"deliverables=(.*?)(?:\s|-->)", line)
                    if m:
                        return [x.strip() for x in m.group(1).rstrip(",").split(",")
                                if x.strip()]
                    break
    except Exception:
        pass
    return []


def git_tracked(root, path):
    """True iff `path` is tracked in git.  A missing git / non-repo is treated
    as 'unknown' (None) so the caller can skip the check."""
    r = subprocess.run(["git", "-C", root, "ls-files", "--error-unmatch", path],
                       capture_output=True, text=True)
    return r.returncode == 0


def classify_type(task):
    bundle = (task.get("bundle") or "")
    base = os.path.basename(bundle)
    if base.endswith(".md"):
        base = base[:-3]
    blob = " ".join([base, task.get("note") or "", task.get("verdict_note") or ""]).lower()
    for typ, kws in TYPE_KEYWORDS:
        for kw in kws:
            if kw in blob:
                return typ
    return "infra"


def is_audit_verify(typ):
    return typ == "verification"


def grade_independence(task):
    """1 if an audit/verify task re-derived by a different route (recorded in
    note/verdict_note), 0 if it re-ran.  Non-audit tasks -> None (no data)."""
    if not is_audit_verify(classify_type(task)):
        return None
    blob = " ".join([task.get("note") or "", task.get("verdict_note") or ""]).lower()
    return 1 if any(m in blob for m in INDEPENDENCE_MARKERS) else 0


def build_profiles(store, perf_text, logs_dir, c7, root, no_git):
    """Compute per-model dimension profiles and the type-count map.

    Returns (profiles, type_counts, task_type):
      profiles[model][dim] = {"avg": float|None, "n": int, "counts": {...}}
      type_counts[model][type] = int
      task_type[taskid] = type
    """
    # ── grading records keyed by task id ─────────────────────────────────
    tasks = {k: v for k, v in store.items()
             if isinstance(v, dict) and k != "_sys" and not k.startswith("_")}
    dispatch = parse_dispatch_verify(perf_text)
    kills = scan_logs(logs_dir)

    # close discipline: grade every dispatch-verify line (a close event).
    close_events = {}  # model -> list of grades
    for rec in dispatch:
        m = rec["model"]
        if not m:
            continue
        if rec["verified"] == "pass":
            g = 2
        elif rec["verified"] == "fail":
            reason = rec.get("fail") or ""
            g = 1 if reason in RECOVERABLE_FAIL else 0
        else:
            continue
        close_events.setdefault(m, []).append(g)

    # efficiency: grade every (task, model) observed in a log segment.  A
    # segment with several kills takes the worst (minimum) grade.
    eff_events = {}  # model -> list of grades
    for (task, model), reasons in kills.items():
        if not model:
            continue
        eff_events.setdefault(model, []).append(min(_grade_reason(r) for r in reasons))

    # per-model accumulator
    acc = {}  # model -> {dim: [grades]}
    type_counts = {}  # model -> {type: n}
    task_type = {}

    for tid, t in tasks.items():
        model = t.get("agent")
        typ = classify_type(t)
        task_type[tid] = typ
        graded = (t.get("verdict") is not None) or (t.get("claimed") is not None)
        if model:
            acc.setdefault(model, {d: [] for d in DIMENSIONS})
            type_counts.setdefault(model, {x: 0 for x in ("spec", "infra", "verification", "battery")})
            if graded:
                type_counts[model][typ] += 1

            # correctness
            v = t.get("verdict")
            if v in CORRECTNESS_GRADE:
                acc[model]["correctness"].append(CORRECTNESS_GRADE[v])

            # completion
            if graded:
                acc[model]["completion"].append(1 if t.get("status") == "done" else 0)

            # deliverable conformance
            c7_entries = c7.get(tid)
            if c7_entries:
                conform = all(ok for ok, _ in c7_entries)
                if conform and not no_git:
                    for dl in parse_deliverables(root, t.get("bundle")):
                        if dl.startswith(UNTRACKED_PREFIXES):
                            continue
                        if not git_tracked(root, dl):
                            conform = False
                            break
                acc[model]["deliverable_conformance"].append(1 if conform else 0)

            # independence
            ind = grade_independence(t)
            if ind is not None:
                acc[model]["independence"].append(ind)

    # close discipline + efficiency are keyed by model, not task.
    for m, grades in close_events.items():
        acc.setdefault(m, {d: [] for d in DIMENSIONS})["close_discipline"].extend(grades)
    for m, grades in eff_events.items():
        acc.setdefault(m, {d: [] for d in DIMENSIONS})["efficiency"].extend(grades)

    profiles = {}
    for model, dims in acc.items():
        profiles[model] = {}
        for dim, grades in dims.items():
            if not grades:
                profiles[model][dim] = {"avg": None, "n": 0, "counts": {}}
            else:
                profiles[model][dim] = {
                    "avg": round(sum(grades) / len(grades), 2),
                    "n": len(grades),
                    "counts": _counts_for(dim, grades),
                }

    return profiles, type_counts, task_type


def _grade_reason(reason):
    """Map a runner kill reason to an efficiency grade.

    RSS cap  -> 1 (wall-kill: the worker was progressing but blew memory)
    CPU ceiling -> 0 (over-broad acceptance run)
    wall ceiling with no progress lines -> 0 (stall)
    wall ceiling with progress -> 1 (wall-kill: legitimate long work)
    unknown -> 1 (milder grade)
    """
    if "RSS cap" in reason:
        return 1
    if "CPU ceiling" in reason:
        return 0
    if "wall ceiling" in reason:
        if "no [progress] lines" in reason:
            return 0  # stall
        return 1  # wall-kill while progressing
    return 1


def _counts_for(dim, grades):
    if dim == "correctness":
        return {"pass": grades.count(2), "pwf_or_fail_found": grades.count(1),
                "blocked_or_abandoned": grades.count(0)}
    if dim == "completion":
        return {"done": grades.count(1), "not_done": grades.count(0)}
    if dim == "close_discipline":
        return {"pass": grades.count(2), "recoverable": grades.count(1),
                "unrecoverable": grades.count(0)}
    if dim == "efficiency":
        return {"clean": grades.count(2), "wall_kill": grades.count(1),
                "stall_or_broad": grades.count(0)}
    if dim == "deliverable_conformance":
        return {"conform": grades.count(1), "nonconform": grades.count(0)}
    if dim == "independence":
        return {"yes": grades.count(1), "no": grades.count(0)}
    return {}


def default_candidates(profiles, type_counts):
    models = set(profiles.keys()) | set(type_counts.keys())
    return sorted(models)


def select(models, typ, profiles, type_counts):
    """Exploration-first selection.  Returns the chosen model label."""
    models = list(models)
    if not models:
        return None
    counts = {m: type_counts.get(m, {}).get(typ, 0) for m in models}
    min_count = min(counts.values())

    if min_count == 0:
        pool = [m for m in models if counts[m] == 0]
        # tie-break: fewer total tasks (more exploration room), then label.
        total = {m: sum(type_counts.get(m, {}).values()) for m in pool}
        pool.sort(key=lambda m: (total[m], m))
        return pool[0]

    # every candidate has data -> profile decides on the dominant dimension.
    dim = DOMINANT[typ]
    def score(m):
        a = profiles.get(m, {}).get(dim, {}).get("avg")
        # null dominant dimension -> fall back to correctness, then 0.
        if a is None:
            a = profiles.get(m, {}).get("correctness", {}).get("avg")
        return a if a is not None else float("-inf")
    def diversity(m):
        return sum(1 for t, n in type_counts.get(m, {}).items() if n > 0)
    pool = sorted(models, key=lambda m: (-score(m), -diversity(m), counts[m], m))
    return pool[0]


def render_human(profiles, type_counts):
    lines = []
    lines.append("Dimension averages (— = no data):")
    header = "  %-22s %11s %10s %14s %10s %22s %12s" % (
        "model", "correct", "complet", "close_disc", "efficienc",
        "deliv_conf", "independence")
    lines.append(header)
    for m in sorted(profiles):
        p = profiles[m]
        def cell(d):
            a = p[d]["avg"]
            return "—" if a is None else ("%.2f" % a)
        lines.append("  %-22s %11s %10s %14s %10s %22s %12s" % (
            m, cell("correctness"), cell("completion"),
            cell("close_discipline"), cell("efficiency"),
            cell("deliverable_conformance"), cell("independence")))
    lines.append("")
    lines.append("Task-type data counts (graded tasks per model):")
    lines.append("  %-22s %6s %6s %13s %8s" % ("model", "spec", "infra", "verification", "battery"))
    for m in sorted(type_counts):
        tc = type_counts[m]
        lines.append("  %-22s %6d %6d %13d %8d" % (
            m, tc.get("spec", 0), tc.get("infra", 0),
            tc.get("verification", 0), tc.get("battery", 0)))
    return "\n".join(lines)


TABLE_STAMP = ("<!-- model-profiles table: generated by tools/model-profiles.py "
               "--table on {date} — never hand-edit; regenerate and re-paste -->")
TABLE_HEADER = ("| model | correctness | completion | close-disc | efficiency | "
                "deliverable | independence | type data (infra/verif/spec/battery) |")
TABLE_SEP = "|---|---|---|---|---|---|---|---|"


def render_table(profiles, type_counts, date):
    """The canonical markdown table — the ONE render that may be pasted into
    docs/infra/model-perf.md.  Hand-editing it is C10-class drift (T523);
    regenerate with `tools/model-profiles.py --table` instead."""
    lines = [TABLE_STAMP.format(date=date), TABLE_HEADER, TABLE_SEP]
    for m in sorted(profiles):
        p = profiles[m]
        def cell(d):
            a = p[d]["avg"]
            n = p[d]["n"]
            return "—" if a is None else "%.2f (n=%d)" % (a, n)
        tc = type_counts.get(m, {})
        tcell = "%d/%d/%d/%d" % (tc.get("infra", 0), tc.get("verification", 0),
                                 tc.get("spec", 0), tc.get("battery", 0))
        lines.append("| %-26s | %s | %s | %s | %s | %s | %s | %s |" % (
            m, cell("correctness"), cell("completion"), cell("close_discipline"),
            cell("efficiency"), cell("deliverable_conformance"),
            cell("independence"), tcell))
    return "\n".join(lines)


def extract_embedded_table(text):
    """The table block embedded in a model-perf.md (stamp line through the
    first blank line), or None when no table stamp is present."""
    lines = text.splitlines()
    for i, ln in enumerate(lines):
        if ln.startswith("<!-- model-profiles table:"):
            out = []
            for ln2 in lines[i:]:
                out.append(ln2)
                if ln2.strip() == "":
                    break
            return "\n".join(out)
    return None


def table_body(table_text):
    """The comparable part of a table render: everything except the stamp
    comment, whose generation date legitimately differs between runs."""
    return "\n".join(l for l in table_text.splitlines()
                     if not l.startswith("<!-- model-profiles table:")).strip()


def main(argv):
    ap = argparse.ArgumentParser(prog="model-profiles.py", add_help=True)
    ap.add_argument("--json", action="store_true", help="machine-readable JSON to stdout")
    ap.add_argument("--table", action="store_true",
                    help="markdown table render — the ONLY render to paste into model-perf.md")
    ap.add_argument("--check-doc", action="store_true",
                    help="compare the table embedded in the model-perf file against a fresh "
                         "computation; exit 0 FRESH / 1 STALE / 2 no embedded table")
    ap.add_argument("--select", metavar="TYPE",
                    help="apply the exploration-first rule and print the chosen model")
    ap.add_argument("--candidates", metavar="LIST",
                    help="comma-separated candidate models for --select")
    ap.add_argument("--root", default=".",
                    help="repo root (default: .)")
    ap.add_argument("--store", default=None, help="tasks.json path")
    ap.add_argument("--model-perf", default=None, help="model-perf.md path")
    ap.add_argument("--logs", default=None, help="log dir (default <root>/untracked/log)")
    ap.add_argument("--c7", default=None, help="precomputed `claimlint c7 --json` file")
    ap.add_argument("--no-git", action="store_true",
                    help="skip the git-committed deliverable check")
    args = ap.parse_args(argv)

    root = args.root
    store_path = args.store or os.path.join(root, "docs", "infra", "managent", "tasks.json")
    perf_path = args.model_perf or os.path.join(root, "docs", "infra", "model-perf.md")
    logs_dir = args.logs or os.path.join(root, "untracked", "log")

    store = read_json(store_path) or {}
    try:
        with open(perf_path) as f:
            perf_text = f.read()
    except OSError:
        perf_text = ""

    claimlint_bin = None
    if not args.c7:
        for cand in (os.path.join(root, "zig-out", "bin", "weizigo-claimlint"),
                     os.path.join(root, "bin", "weizigo-claimlint")):
            if os.path.isfile(cand):
                claimlint_bin = cand
                break
    c7 = read_c7(args.c7, claimlint_bin, root)

    profiles, type_counts, task_type = build_profiles(
        store, perf_text, logs_dir, c7, root, args.no_git)

    if args.select:
        if args.candidates:
            models = [m for m in args.candidates.split(",") if m.strip()]
        else:
            models = default_candidates(profiles, type_counts)
        chosen = select(models, args.select, profiles, type_counts)
        if args.json:
            print(json.dumps({
                "generated": _today(),
                "selection": {"type": args.select, "chosen": chosen,
                              "candidates": models},
                "type_counts": type_counts,
                "profiles": profiles,
            }, sort_keys=True))
        else:
            print(chosen if chosen is not None else "")
        return 0

    if args.check_doc:
        embedded = extract_embedded_table(perf_text)
        if embedded is None:
            print("NO TABLE FOUND: no '<!-- model-profiles table:' marker in %s" % perf_path)
            return 2
        fresh = render_table(profiles, type_counts, _today())
        if table_body(embedded) == table_body(fresh):
            print("FRESH: the embedded table matches `tools/model-profiles.py --table` output")
            return 0
        print("STALE: the embedded table differs from `tools/model-profiles.py --table` output")
        print("regenerate: `tools/model-profiles.py --table`, paste over the old table (never hand-edit)")
        return 1

    if args.json:
        print(json.dumps({
            "generated": _today(),
            "dimensions": DIMENSIONS,
            "profiles": profiles,
            "type_counts": type_counts,
            "task_type": task_type,
        }, sort_keys=True))
        return 0

    if args.table:
        print(render_table(profiles, type_counts, _today()))
        return 0

    print(render_human(profiles, type_counts))
    return 0


def _today():
    import time
    return time.strftime("%Y-%m-%d")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
