#!/usr/bin/env bash
# regression-model-profiles.sh — controls for tools/model-profiles.py (T503).
#
# T503 builds per-model dimension profiles from the ledger (verdict, done
# status, dispatch-verify lines, the wall-kill log census, findings
# conformance) plus a task-type -> data-count map, and an exploration-first
# selection rule: when a model has no data on a task type, that absence is a
# REASON to choose it.  These controls pin the instrument's contract against
# a seeded scratch store — never the live kanban, never docs/infra/model-perf.md:
#
#   (a) exploration   a model with 0 tasks of a type is named over one with
#                     data (the operator's exploration-first rule)
#   (b) profile       when every candidate has data on the type, the type's
#                     dominant dimension (spec -> correctness) decides
#   (c) no-data       a dimension with zero graded tasks is `—` (null), not 0
#   (d) round-trip    the tool's --json output is byte-identical across two
#                     runs and agrees with hand-computed averages
#   (e) committed     a declared deliverable that is not git-committed makes
#                     deliverable_conformance 0 (a committed one passes)
#
# All fixtures are synthetic and run in a scratch dir under /tmp/weizigo.
# The tool is invoked with --store/--model-perf/--logs/--c7 pointed at the
# fixture and --no-git (except arm e), so the live repo, live kanban and
# live model-perf.md are never read and never written.
#
# Task: T503 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TOOL="$ROOT/tools/model-profiles.py"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t503-profiles-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "=== regression-model-profiles: pre-flight ==="
if ! test -f "$TOOL"; then
    echo "FAIL: $TOOL missing — the instrument must exist"
    exit 1
fi

# ── seed the fixture store (synthetic, deterministic) ─────────────────────
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
os.makedirs(os.path.join(work, "docs", "infra", "managent"), exist_ok=True)
os.makedirs(os.path.join(work, "untracked", "log"), exist_ok=True)
os.makedirs(os.path.join(work, "untracked"), exist_ok=True)

# tasks.json — the store.  Only the fields the tool reads matter.
tasks = {
    "T1": {"agent": "alpha", "status": "done", "verdict": "pass-with-findings",
           "bundle": "untracked/T1-spec-design.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:10:00Z", "note": None, "verdict_note": None},
    "T2": {"agent": "alpha", "status": "done", "verdict": "pass-with-findings",
           "bundle": "untracked/T2-spec-strategy.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:11:00Z", "note": None, "verdict_note": None},
    "T3": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T3-infra-tool.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:12:00Z", "note": None, "verdict_note": None},
    "T4": {"agent": "beta", "status": "done", "verdict": "pass",
           "bundle": "untracked/T4-spec-plan.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:13:00Z", "note": None, "verdict_note": None},
    "T5": {"agent": "beta", "status": "done", "verdict": "pass",
           "bundle": "untracked/T5-battery-mutant.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:14:00Z", "note": None, "verdict_note": None},
    "T6": {"agent": "gamma", "status": "done", "verdict": "pass",
           "bundle": "untracked/T6-verify-audit.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:15:00Z", "note": None, "verdict_note": None},
    # never-claimed row: excluded from grading and type counts entirely
    "T7": {"agent": "alpha", "status": "dispatchable", "verdict": None,
           "bundle": "untracked/T7-battery-vb.md", "claimed": None,
           "done": None, "note": None, "verdict_note": None},
}
with open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w") as f:
    json.dump(tasks, f)

# model-perf.md — dispatch-verify lines (close discipline).  alpha: one pass,
# one recoverable nonce fail -> 1.5.  gamma: none -> close discipline is `—`.
with open(os.path.join(work, "model-perf.md"), "w") as f:
    f.write("# fixture\n")
    f.write("dispatch-verify 2026-08-20 T1 alpha report=success verified=pass\n")
    f.write("dispatch-verify 2026-08-20 T2 alpha report=success verified=fail fail=nonce\n")
    f.write("dispatch-verify 2026-08-20 T4 beta report=success verified=pass\n")
    f.write("dispatch-verify 2026-08-20 T5 beta report=success verified=pass\n")

# claimlint c7 --json output (deliverable conformance).  T3 is non-conforming.
c7 = [
    {"path": "T1-spec-design.json", "task_id": "T1", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T2-spec-strategy.json", "task_id": "T2", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T3-infra-tool.json", "task_id": "T3", "conforming": False,
     "conforming_reason": "missing task_id", "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T4-spec-plan.json", "task_id": "T4", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T5-battery-mutant.json", "task_id": "T5", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T6-verify-audit.json", "task_id": "T6", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
]
with open(os.path.join(work, "c7.json"), "w") as f:
    json.dump(c7, f)

# wall-kill log census (efficiency).  beta's T5 hit the RSS cap -> wall-kill
# grade 1; no other model has a log -> efficiency `—` elsewhere.
with open(os.path.join(work, "untracked", "log", "t5.log"), "w") as f:
    f.write("[runner] argv = ollama launch pi --model beta:cloud -y -- -p 'fixture'\n")
    f.write("[runner] task identity: T5 (source: MANAGENT_TASK_ID)\n")
    f.write("[runner] exit 124 (RSS cap 4096 MB exceeded) in 350.9 s\n")
print("fixture seeded at", work)
PYEOF

STORE="$WORK/docs/infra/managent/tasks.json"
PERF="$WORK/model-perf.md"
LOGS="$WORK/untracked/log"
C7="$WORK/c7.json"

run_json() {
    "$TOOL" --json --no-git --root "$WORK" --store "$STORE" \
        --model-perf "$PERF" --logs "$LOGS" --c7 "$C7" 2>/dev/null
}

# ── (a) exploration-first: 0-data model is chosen ─────────────────────────
echo ""
echo "  1. exploration: alpha (0 battery tasks) chosen over beta (1 battery task)"
OUT=$("$TOOL" --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" \
      --logs "$LOGS" --c7 "$C7" --select battery --candidates alpha,beta 2>/dev/null)
if [ "$OUT" = "alpha" ]; then
    echo "    PASS: --select battery named alpha (no data beats data)"
else
    echo "    FAIL: --select battery returned '$OUT', expected alpha"
    FAIL=1
fi

# ── (b) profile decides when all candidates have data ─────────────────────
echo "  2. profile: both have spec data; beta (correctness 2.0) beats alpha (1.0)"
OUT=$("$TOOL" --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" \
      --logs "$LOGS" --c7 "$C7" --select spec --candidates alpha,beta 2>/dev/null)
if [ "$OUT" = "beta" ]; then
    echo "    PASS: --select spec named beta (highest dominant-dimension avg)"
else
    echo "    FAIL: --select spec returned '$OUT', expected beta"
    FAIL=1
fi

# ── (c) empty dimension is `—` (null), never 0 ────────────────────────────
echo "  3. no-data dimensions are null, not 0"
JSON=$(run_json)
python3 - "$JSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]
ok = True
# gamma has no dispatch-verify lines -> close_discipline null
if prof["gamma"]["close_discipline"]["avg"] is not None:
    print("    FAIL: gamma close_discipline should be null (no data), got", prof["gamma"]["close_discipline"])
    ok = False
if prof["gamma"]["close_discipline"]["n"] != 0:
    print("    FAIL: gamma close_discipline n should be 0, got", prof["gamma"]["close_discipline"]["n"])
    ok = False
# gamma has no log -> efficiency null
if prof["gamma"]["efficiency"]["avg"] is not None:
    print("    FAIL: gamma efficiency should be null (no log), got", prof["gamma"]["efficiency"])
    ok = False
if ok:
    print("    PASS: empty dimensions are null (—), not 0")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (d) round-trip: deterministic + hand-computed averages ────────────────
echo "  4. round-trip: two runs byte-identical; averages match hand computation"
JSON1=$(run_json)
JSON2=$(run_json)
if [ "$JSON1" = "$JSON2" ]; then
    echo "    PASS: two runs produce byte-identical JSON"
else
    echo "    FAIL: two runs differ (non-deterministic output)"
    FAIL=1
fi
python3 - "$JSON1" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]
tc = d["type_counts"]
ok = True

def chk(model, dim, expected_avg, expected_n):
    global ok
    a = prof[model][dim]["avg"]; n = prof[model][dim]["n"]
    if a is None and expected_avg is None:
        if n != expected_n:
            print(f"    FAIL: {model}.{dim} n={n} expected {expected_n}"); ok = False
        return
    if a is None or abs(a - expected_avg) > 1e-9 or n != expected_n:
        print(f"    FAIL: {model}.{dim} avg={a} n={n}, expected {expected_avg}/{expected_n}")
        ok = False

# alpha correctness: T1 pwf(1) + T2 pwf(1) + T3 pass(2) = 4/3 over 3
chk("alpha", "correctness", round(4/3, 2), 3)
# alpha close discipline: pass(2) + nonce(1) = 1.5 over 2
chk("alpha", "close_discipline", 1.5, 2)
# alpha deliverable: T1(1) T2(1) T3(0) = 2/3
chk("alpha", "deliverable_conformance", round(2/3, 2), 3)
# alpha completion: T1,T2,T3 done = 1.0
chk("alpha", "completion", 1.0, 3)
# alpha type counts: spec=2 infra=1 battery=0 verification=0 (T7 excluded)
if tc["alpha"] != {"spec": 2, "infra": 1, "battery": 0, "verification": 0}:
    print("    FAIL: alpha type_counts wrong:", tc["alpha"]); ok = False
# beta efficiency: T5 RSS wall-kill = 1.0 over 1
chk("beta", "efficiency", 1.0, 1)
if ok:
    print("    PASS: hand-computed averages and type counts match")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (e) deliverables committed: git-tracked vs not ────────────────────────
echo "  5. committed deliverable flips deliverable_conformance"
GITWORK="$(mktemp -d /tmp/weizigo/t503-git-XXXXXX)"
trap 'rm -rf "$WORK" "$GITWORK"' EXIT
cd "$GITWORK"
git init -q
git config user.email t503@test
git config user.name T503
mkdir -p docs/infra/managent untracked/log findings
printf 'untracked/\n' > .gitignore

python3 - "$GITWORK" <<'PYEOF'
import json, os, sys
w = sys.argv[1]
# two tasks, each with a findings file (conforming) and a bundle declaring a
# docs/ deliverable.  T8's deliverable is committed; T9's is NOT.
tasks = {
    "T8": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T8-bundle.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:20:00Z", "note": None, "verdict_note": None},
    "T9": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T9-bundle.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:21:00Z", "note": None, "verdict_note": None},
}
with open(os.path.join(w, "docs/infra/managent/tasks.json"), "w") as f:
    json.dump(tasks, f)
with open(os.path.join(w, "untracked/T8-bundle.md"), "w") as f:
    f.write("<!--managent set=A deliverables=docs/T8-out.txt-->\n# T8\n")
with open(os.path.join(w, "untracked/T9-bundle.md"), "w") as f:
    f.write("<!--managent set=A deliverables=docs/T9-out.txt-->\n# T9\n")
c7 = [
    {"path": "T8.json", "task_id": "T8", "conforming": True, "conforming_reason": None,
     "claims_total": 0, "new_rows_total": 0, "unabsorbed": [], "dispositioned": []},
    {"path": "T9.json", "task_id": "T9", "conforming": True, "conforming_reason": None,
     "claims_total": 0, "new_rows_total": 0, "unabsorbed": [], "dispositioned": []},
]
with open(os.path.join(w, "c7.json"), "w") as f:
    json.dump(c7, f)
# deliverable files on disk (T9's exists but is uncommitted)
open(os.path.join(w, "docs/T8-out.txt"), "w").write("committed\n")
open(os.path.join(w, "docs/T9-out.txt"), "w").write("uncommitted\n")
print("git fixture seeded")
PYEOF
# commit T8's deliverable (and the store/c7/bundle so they are tracked where
# the tool checks them — only docs/T8-out.txt matters for the arm)
git add docs/T8-out.txt && git commit -qm "T8 deliverable committed"
# T9-out.txt left untracked

GJSON=$("$TOOL" --json --root "$GITWORK" --store "$GITWORK/docs/infra/managent/tasks.json" \
        --model-perf "$GITWORK/noperf.md" --logs "$GITWORK/untracked/log" --c7 "$GITWORK/c7.json" 2>/dev/null)
printf '' > "$GITWORK/noperf.md"
GJSON=$("$TOOL" --json --root "$GITWORK" --store "$GITWORK/docs/infra/managent/tasks.json" \
        --model-perf "$GITWORK/noperf.md" --logs "$GITWORK/untracked/log" --c7 "$GITWORK/c7.json" 2>/dev/null)
python3 - "$GJSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]["alpha"]["deliverable_conformance"]
# alpha has T8 (committed -> 1) and T9 (uncommitted -> 0): avg 0.5
if prof["n"] != 2 or prof["avg"] is None or abs(prof["avg"] - 0.5) > 1e-9:
    print(f"    FAIL: committed-check avg={prof['avg']} n={prof['n']}, expected 0.5/2")
    sys.exit(1)
print("    PASS: uncommitted deliverable flips conformance to 0 (avg 0.5 over T8/T9)")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (f) --table render contract: verbatim, deterministic, faithful ───────
# T523: the dimension-profiles table in docs/infra/model-perf.md must be the
# tool's own --table render, pasted verbatim — hand-edited tables are
# C10-class drift.  These controls pin the renderer against the same fixture
# as arms (a)-(e): every cell equals the fixture JSON, `—` for null dims,
# deterministic, stamp present.
echo "  6. --table: every model with data; cells equal the JSON; deterministic; stamp present"
TABLE1=$("$TOOL" --table --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" --logs "$LOGS" --c7 "$C7" 2>/dev/null)
TABLE2=$("$TOOL" --table --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" --logs "$LOGS" --c7 "$C7" 2>/dev/null)
if [ "$TABLE1" = "$TABLE2" ]; then
    echo "    PASS: --table deterministic across two runs"
else
    echo "    FAIL: --table not deterministic"; FAIL=1
fi
if echo "$TABLE1" | grep -q -- '<!-- model-profiles table:'; then
    echo "    PASS: --table emits the stamp comment"
else
    echo "    FAIL: --table missing the '<!-- model-profiles table:' stamp"; FAIL=1
fi
python3 - "$TABLE1" <<'PYEOF'
import sys

tbl = sys.argv[1]
data = [l for l in tbl.splitlines() if l.startswith("|") and not l.startswith("|--")]
models = [r.split("|")[1].strip() for r in data[1:]]
ok = True
if models != ["alpha", "beta", "gamma"]:
    print("    FAIL: --table model rows =", models); ok = False
cells = {m: r.split("|") for m, r in zip(models, data[1:])}
def cell(m, col):
    return cells[m][col + 1].strip()
# alpha correctness: T1 pwf + T2 pwf + T3 pass = 4/3 over 3
if cell("alpha", 1) != "1.33 (n=3)":
    print("    FAIL: alpha correctness cell", repr(cell("alpha", 1))); ok = False
# gamma has no dispatch-verify lines / no log -> both null cells are em-dash
if cell("gamma", 3) != "—" or cell("gamma", 4) != "—":
    print("    FAIL: gamma null cells", repr(cell("gamma", 3)), repr(cell("gamma", 4))); ok = False
# beta efficiency: RSS wall-kill = 1.0 over 1
if cell("beta", 4) != "1.00 (n=1)":
    print("    FAIL: beta efficiency cell", repr(cell("beta", 4))); ok = False
# type-data column, infra/verif/spec/battery: alpha infra=1 verif=0 spec=2 battery=0
if cell("alpha", 7) != "1/0/2/0":
    print("    FAIL: alpha type-data cell", repr(cell("alpha", 7))); ok = False
if ok:
    print("    PASS: --table cells faithful to the fixture JSON")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (g) --check-doc contract: FRESH exits 0, STALE exits 1, absent exits 2 ─
# T523: --check-doc is the standing freshness probe — it extracts the table
# embedded in model-perf.md and compares it cell-by-cell against a fresh
# computation.  Report-only by design (the live table goes stale as the
# ledger moves; the fix is regeneration, not a gate).
echo "  7. --check-doc: fresh=0, perturbed cell=1, missing table=2"
FRESH_DOC="$WORK/fresh.md"
{ cat "$PERF"; echo ""; echo "$TABLE1"; } > "$FRESH_DOC"
if "$TOOL" --check-doc --no-git --root "$WORK" --store "$STORE" --model-perf "$FRESH_DOC" --logs "$LOGS" --c7 "$C7" >/dev/null 2>&1; then
    echo "    PASS: fresh doc reports FRESH (exit 0)"
else
    echo "    FAIL: fresh doc should exit 0"; FAIL=1
fi
STALE_DOC="$WORK/stale.md"
sed 's/1.33 (n=3)/9.99 (n=3)/' "$FRESH_DOC" > "$STALE_DOC"
if "$TOOL" --check-doc --no-git --root "$WORK" --store "$STORE" --model-perf "$STALE_DOC" --logs "$LOGS" --c7 "$C7" >/dev/null 2>&1; then
    echo "    FAIL: perturbed doc should exit non-zero (STALE)"; FAIL=1
else
    echo "    PASS: perturbed doc reports STALE (exit 1)"
fi
NOTBL_DOC="$WORK/notbl.md"
cat "$PERF" > "$NOTBL_DOC"
"$TOOL" --check-doc --no-git --root "$WORK" --store "$STORE" --model-perf "$NOTBL_DOC" --logs "$LOGS" --c7 "$C7" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 2 ]; then
    echo "    PASS: doc without a table exits 2"
else
    echo "    FAIL: no-table doc should exit 2, got $rc"; FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-model-profiles: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-model-profiles: FAILURES ==="
    exit 1
fi
