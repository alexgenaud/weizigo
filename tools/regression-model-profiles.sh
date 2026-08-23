#!/usr/bin/env bash
# regression-model-profiles.sh — controls for tools/model-profiles.py (T503, extended T524).
#
# T503 built per-model dimension profiles from the ledger (verdict, done
# status, dispatch-verify lines, the wall-kill log census, findings
# conformance) plus a task-type -> data-count map, and an exploration-first
# selection rule: when a model has no data on a task type, that absence is a
# REASON to choose it.  T524 extends the instrument to the operator-approved
# D027 taxonomy: EIGHT dimensions (correctness, completion/close discipline,
# thoroughness, independence, falsifiability discipline, efficiency, citation
# honesty, scope discipline) and EIGHT task types (spec/design,
# implementation-bounded, audit/verification, integration/reframe,
# infra/tooling, research/census, battery-heavy, orchestration-seat), plus
# the role->dimension map.  These controls pin that contract against a
# seeded scratch store — never the live kanban, never
# docs/infra/model-perf.md:
#
#   (a) exploration   a model with 0 tasks of a type is named over one with
#                     data (the operator's exploration-first rule)
#   (b) profile       when every candidate has data on the type, the type's
#                     dominant dimension (spec/design -> correctness) decides
#   (c) no-data       a dimension with zero graded tasks is `—` (null), not 0
#                     (thoroughness and citation-honesty are null by design —
#                     no recorded per-task signal yet; absence of evidence is
#                     not evidence of absence)
#   (d) round-trip    the tool's --json output is byte-identical across two
#                     runs and agrees with hand-computed averages, over the
#                     8-dimension / 8-type schema (D027)
#   (e) committed     a declared deliverable that is not git-committed makes
#                     scope_discipline 0 (a committed one passes)
#   (f) scope-incident a recorded scope incident (e.g. a commit-attribution
#                     incident in the amendments) flips scope_discipline to 0
#                     even when the findings conform
#   (g) falsifiability  the keyword proxy over the recorded close text grades
#                     1 when a refutation/falsification is named, 0 otherwise
#   (h) completion_close  merged per-task dimension: a close event grades
#                     2 (verified pass) / 1 (recoverable) / 0 (unrecoverable);
#                     a graded task with no close event grades 1 (done) / 0
#   (i) roles         the D027 role->dimension map is emitted in --json and
#                     in the --table render (the section the directive said
#                     must carry the taxonomy)
#   (j) --table       every model with data; cells equal the JSON;
#                     deterministic; stamp present
#   (k) --check-doc   FRESH exits 0, STALE exits 1, absent exits 2
#   (l) epochs        models with a recorded epoch boundary (T525: the
#                     2026-08-18 DeepSeek boundary, model-registry.md §Epoch
#                     rules) split into per-epoch profiles — pre-2026-08-18
#                     and 2026-08-18+ are distinct rows; a task's epoch is
#                     its claimed/done/added date, a close event's epoch is
#                     the line's date, a wall-kill's epoch is its task's
#                     date; an undated observation lands in 'epoch-unknown',
#                     present and labeled, never merged into a dated epoch
#   (m) selection     the exploration-first rule is epoch-scoped: a boundary
#                     model's OLD-epoch data counts as zero current data
#                     (old-epoch observations describe the pre-bump model);
#                     with new-epoch data on the type, the profile decides
#   (n) multi-boundary + registry parity: --epochs buckets a model across
#                     several boundaries (pre-d1 / d1..d2 / d2+); the tool's
#                     built-in boundary table mirrors the recorded 2026-08-18
#                     DeepSeek boundary in docs/infra/model-registry.md
#
# All fixtures are synthetic and run in a scratch dir under /tmp/weizigo.
# The tool is invoked with --store/--model-perf/--logs/--c7 pointed at the
# fixture and --no-git (except arm e/f), so the live repo, live kanban and
# live model-perf.md are never read and never written.
#
# Task: T503 (first half) · T524 (8×8 extension) · Role: worker ·
# Model: deepseek-v4-pro (T503) / deepseek-v4-flash (T524) · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TOOL="$ROOT/tools/model-profiles.py"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t524-profiles-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
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

# tasks.json — the store.  Only the fields the tool reads matter.  Slugs
# cover all eight D027 task types:
#   spec/design: T1 T2 T4 T12 · implementation-bounded: T11
#   audit/verification: T6 · integration/reframe: T8 · infra/tooling: T3
#   research/census: T9 · battery-heavy: T5 T7 · orchestration-seat: T10
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
           "done": "2026-08-20T00:14:00Z", "note": None,
           "verdict_note": "baseline hypothesis REFUTED by the control arm"},
    "T6": {"agent": "gamma", "status": "done", "verdict": "pass",
           "bundle": "untracked/T6-verify-audit.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:15:00Z", "note": None, "verdict_note": None},
    # never-claimed row: excluded from grading and type counts entirely
    "T7": {"agent": "alpha", "status": "dispatchable", "verdict": None,
           "bundle": "untracked/T7-battery-vb.md", "claimed": None,
           "done": None, "note": None, "verdict_note": None},
    "T8": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T8-absorb-integration.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:16:00Z", "note": None, "verdict_note": None},
    "T9": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T9-census-inventory.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:17:00Z", "note": None, "verdict_note": None},
    "T10": {"agent": "beta", "status": "done", "verdict": "pass",
            "bundle": "untracked/T10-orcha-triage.md", "claimed": "2026-08-20T00:00:00Z",
            "done": "2026-08-20T00:18:00Z", "note": None, "verdict_note": None},
    "T11": {"agent": "beta", "status": "done", "verdict": "pass",
            "bundle": "untracked/T11-fix-alias.md", "claimed": "2026-08-20T00:00:00Z",
            "done": "2026-08-20T00:19:00Z", "note": None, "verdict_note": None},
    # recorded scope incident in the amendments -> scope_discipline 0 despite
    # a conforming findings file
    "T12": {"agent": "alpha", "status": "done", "verdict": "pass",
            "bundle": "untracked/T12-spec-draft.md", "claimed": "2026-08-20T00:00:00Z",
            "done": "2026-08-20T00:20:00Z", "note": None, "verdict_note": None,
            "amendments": ["2026-08-20T00:21:00Z: COMMIT-ATTRIBUTION INCIDENT (recorded by the worker)"]},
}
with open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w") as f:
    json.dump(tasks, f)

# model-perf.md — dispatch-verify lines (close discipline).  alpha: one pass,
# one recoverable nonce fail.  beta: two passes + one bare dispatch pass.
# gamma: none -> gamma's completion_close comes only from its done status.
with open(os.path.join(work, "model-perf.md"), "w") as f:
    f.write("# fixture\n")
    f.write("dispatch-verify 2026-08-20 T1 alpha report=success verified=pass\n")
    f.write("dispatch-verify 2026-08-20 T2 alpha report=success verified=fail fail=nonce\n")
    f.write("dispatch-verify 2026-08-20 T4 beta report=success verified=pass\n")
    f.write("dispatch-verify 2026-08-20 T5 beta report=success verified=pass\n")
    f.write("dispatch-verify 2026-08-20 - beta report=bare verified=pass\n")

# claimlint c7 --json output (findings conformance -> scope discipline).
# T3 is non-conforming; T12 conforms (its incident is in the amendments).
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
    {"path": "T8-absorb-integration.json", "task_id": "T8", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T9-census-inventory.json", "task_id": "T9", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T10-orcha-triage.json", "task_id": "T10", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T11-fix-alias.json", "task_id": "T11", "conforming": True,
     "conforming_reason": None, "claims_total": 0, "new_rows_total": 0,
     "unabsorbed": [], "dispositioned": []},
    {"path": "T12-spec-draft.json", "task_id": "T12", "conforming": True,
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
      --logs "$LOGS" --c7 "$C7" --select battery-heavy --candidates alpha,beta 2>/dev/null)
if [ "$OUT" = "alpha" ]; then
    echo "    PASS: --select battery-heavy named alpha (no data beats data)"
else
    echo "    FAIL: --select battery-heavy returned '$OUT', expected alpha"
    FAIL=1
fi
OUT=$("$TOOL" --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" \
      --logs "$LOGS" --c7 "$C7" --select orchestration-seat --candidates alpha,beta 2>/dev/null)
if [ "$OUT" = "alpha" ]; then
    echo "    PASS: --select orchestration-seat named alpha (0 data beats beta's 1)"
else
    echo "    FAIL: --select orchestration-seat returned '$OUT', expected alpha"
    FAIL=1
fi

# ── (b) profile decides when all candidates have data ─────────────────────
echo "  2. profile: both have spec/design data; beta (correctness 2.0) beats alpha (1.67)"
OUT=$("$TOOL" --no-git --root "$WORK" --store "$STORE" --model-perf "$PERF" \
      --logs "$LOGS" --c7 "$C7" --select spec/design --candidates alpha,beta 2>/dev/null)
if [ "$OUT" = "beta" ]; then
    echo "    PASS: --select spec/design named beta (highest dominant-dimension avg)"
else
    echo "    FAIL: --select spec/design returned '$OUT', expected beta"
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
# T525: no boundary recorded for these fixture models -> single 'all' epoch
for m in ("alpha", "beta", "gamma"):
    if set(prof[m].keys()) != {"all"}:
        print(f"    FAIL: {m} epochs = {sorted(prof[m].keys())}, expected ['all'] (no recorded boundary)")
        ok = False
# thoroughness has no recorded per-task signal by design (D027 dim 3)
for m in ("alpha", "beta", "gamma"):
    if prof[m]["all"]["thoroughness"]["avg"] is not None or prof[m]["all"]["thoroughness"]["n"] != 0:
        print(f"    FAIL: {m} thoroughness should be null (no signal), got", prof[m]["all"]["thoroughness"])
        ok = False
    if prof[m]["all"]["citation_honesty"]["avg"] is not None or prof[m]["all"]["citation_honesty"]["n"] != 0:
        print(f"    FAIL: {m} citation_honesty should be null (no incident recorded), got", prof[m]["all"]["citation_honesty"])
        ok = False
# gamma has no log -> efficiency null
if prof["gamma"]["all"]["efficiency"]["avg"] is not None or prof["gamma"]["all"]["efficiency"]["n"] != 0:
    print("    FAIL: gamma efficiency should be null (no log), got", prof["gamma"]["all"]["efficiency"])
    ok = False
# alpha/beta have no audit/verification tasks -> independence null
for m in ("alpha", "beta"):
    if prof[m]["all"]["independence"]["avg"] is not None:
        print(f"    FAIL: {m} independence should be null (no verification tasks), got", prof[m]["all"]["independence"])
        ok = False
if ok:
    print("    PASS: empty dimensions are null (—), not 0; no-boundary models are single-epoch 'all'")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (d) round-trip: deterministic + hand-computed averages over 8 dims ────
echo "  4. round-trip: two runs byte-identical; averages match hand computation (8 dims)"
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

# T525: no boundary recorded -> all observations in a single 'all' epoch
ALL = "all"

def chk(model, dim, expected_avg, expected_n):
    global ok
    a = prof[model][ALL][dim]["avg"]; n = prof[model][ALL][dim]["n"]
    if a is None and expected_avg is None:
        if n != expected_n:
            print(f"    FAIL: {model}.{dim} n={n} expected {expected_n}"); ok = False
        return
    if a is None or abs(a - expected_avg) > 1e-9 or n != expected_n:
        print(f"    FAIL: {model}.{dim} avg={a} n={n}, expected {expected_avg}/{expected_n}")
        ok = False

# alpha: T1 pwf(1) T2 pwf(1) T3 pass(2) T8 pass(2) T9 pass(2) T12 pass(2) = 10/6
chk("alpha", "correctness", round(10/6, 2), 6)
# alpha completion_close: T1 close-pass(2) T2 close-nonce(1) T3 done(1) T8 done(1)
#                        T9 done(1) T12 done(1) = 7/6
chk("alpha", "completion_close", round(7/6, 2), 6)
# alpha scope_discipline: T1(1) T2(1) T3(0 nonconform) T8(1) T9(1) T12(0 incident) = 4/6
chk("alpha", "scope_discipline", round(4/6, 2), 6)
# alpha falsifiability: no refutation named in any recorded close -> 0/6
chk("alpha", "falsifiability", 0.0, 6)
# beta: T4 pass(2) T5 pass(2) T10 pass(2) T11 pass(2) = 8/4
chk("beta", "correctness", 2.0, 4)
# beta completion_close: T4 close-pass(2) T5 close-pass(2) T10 done(1) T11 done(1)
#                        + bare dispatch pass(2) = 8/5
chk("beta", "completion_close", round(8/5, 2), 5)
# beta falsifiability: T5 names a REFUTATION -> 1/4
chk("beta", "falsifiability", 0.25, 4)
# beta efficiency: T5 RSS wall-kill = 1.0 over 1
chk("beta", "efficiency", 1.0, 1)
# beta scope_discipline: T4 T5 T10 T11 all conform -> 1.0/4
chk("beta", "scope_discipline", 1.0, 4)
# gamma: single verify-audit row
chk("gamma", "correctness", 2.0, 1)
chk("gamma", "completion_close", 1.0, 1)
chk("gamma", "independence", 0.0, 1)   # audit row, no re-derivation markers
chk("gamma", "falsifiability", 0.0, 1)
chk("gamma", "scope_discipline", 1.0, 1)

# 8-type data counts (graded rows only; T7 excluded)
TYPES = ["spec/design", "implementation-bounded", "audit/verification",
         "integration/reframe", "infra/tooling", "research/census",
         "battery-heavy", "orchestration-seat"]
def tcd(tc_, model):
    return {t: tc_.get(model, {}).get(ALL, {}).get(t, 0) for t in TYPES}
if tcd(tc, "alpha") != {"spec/design": 3, "implementation-bounded": 0,
                        "audit/verification": 0, "integration/reframe": 1,
                        "infra/tooling": 1, "research/census": 1,
                        "battery-heavy": 0, "orchestration-seat": 0}:
    print("    FAIL: alpha type_counts wrong:", tcd(tc, "alpha")); ok = False
if tcd(tc, "beta") != {"spec/design": 1, "implementation-bounded": 1,
                       "audit/verification": 0, "integration/reframe": 0,
                       "infra/tooling": 0, "research/census": 0,
                       "battery-heavy": 1, "orchestration-seat": 1}:
    print("    FAIL: beta type_counts wrong:", tcd(tc, "beta")); ok = False
if tcd(tc, "gamma") != {"spec/design": 0, "implementation-bounded": 0,
                        "audit/verification": 1, "integration/reframe": 0,
                        "infra/tooling": 0, "research/census": 0,
                        "battery-heavy": 0, "orchestration-seat": 0}:
    print("    FAIL: gamma type_counts wrong:", tcd(tc, "gamma")); ok = False
# T525: the boundary table is emitted with the figure (model-registry.md §
# Epoch rules — the 2026-08-18 DeepSeek boundary)
eb = d.get("epoch_boundaries", {})
if eb.get("deepseek-v4-pro") != ["2026-08-18"] or eb.get("deepseek-v4-flash") != ["2026-08-18"]:
    print("    FAIL: epoch_boundaries =", eb); ok = False

# schema: 8 dimensions in D027 order, 8 task types, role map present
if d["dimensions"] != ["correctness", "completion_close", "thoroughness",
                       "independence", "falsifiability", "efficiency",
                       "citation_honesty", "scope_discipline"]:
    print("    FAIL: dimensions =", d["dimensions"]); ok = False
if d["task_types"] != TYPES:
    print("    FAIL: task_types =", d["task_types"]); ok = False
if not isinstance(d.get("roles"), dict) or "Auditor" not in d["roles"]:
    print("    FAIL: role->dimension map missing from --json"); ok = False
if ok:
    print("    PASS: hand-computed averages, 8-type counts, schema and role map match")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (e) deliverables committed: git-tracked vs not (feeds scope) ──────────
echo "  5. uncommitted deliverable flips scope_discipline"
mkdir -p /tmp/weizigo
GITWORK="$(mktemp -d /tmp/weizigo/t524-git-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK" "$GITWORK"' EXIT
# T626 bakeoff MEDIUM: an un-belted cd leaves the script in the repo root
# if the scratch dir vanished, and `git init -q` below would re-init the
# live repo.  Belt it (the mktemp itself is already belted, T445).
cd "$GITWORK" || { echo "FATAL: could not cd into scratch $GITWORK; refusing to run (T626)" >&2; exit 2; }
git init -q
git config user.email t524@test
git config user.name T524
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
open(os.path.join(w, "docs/T8-out.txt"), "w").write("committed\n")
open(os.path.join(w, "docs/T9-out.txt"), "w").write("uncommitted\n")
print("git fixture seeded")
PYEOF
git add docs/T8-out.txt && git commit -qm "T8 deliverable committed"
# T9-out.txt left untracked

printf '' > "$GITWORK/noperf.md"
GJSON=$("$TOOL" --json --root "$GITWORK" --store "$GITWORK/docs/infra/managent/tasks.json" \
        --model-perf "$GITWORK/noperf.md" --logs "$GITWORK/untracked/log" --c7 "$GITWORK/c7.json" 2>/dev/null)
python3 - "$GJSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]["alpha"]["all"]["scope_discipline"]
# alpha has T8 (committed -> 1) and T9 (uncommitted -> 0): avg 0.5
if prof["n"] != 2 or prof["avg"] is None or abs(prof["avg"] - 0.5) > 1e-9:
    print(f"    FAIL: committed-check scope avg={prof['avg']} n={prof['n']}, expected 0.5/2")
    sys.exit(1)
print("    PASS: uncommitted deliverable flips scope_discipline to 0 (avg 0.5 over T8/T9)")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (f) recorded scope incident flips scope_discipline despite conform ────
echo "  6. scope-incident override: amendments incident -> 0 even when findings conform"
python3 - "$JSON1" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]["alpha"]["all"]["scope_discipline"]
# T12 conforms on c7 but carries a COMMIT-ATTRIBUTION INCIDENT in its
# amendments: expected avg (1+1+0+1+1+0)/6 = 0.67 — the incident pulled it
# below the non-incident 0.8 (T1,T2,T3,T8,T9).
if prof["n"] != 6 or prof["avg"] is None or abs(prof["avg"] - round(4/6, 2)) > 1e-9:
    print(f"    FAIL: incident-override avg={prof['avg']} n={prof['n']}, expected {round(4/6, 2)}/6")
    sys.exit(1)
print("    PASS: recorded scope incident overrode conformance (avg 0.67/6)")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (g) falsifiability keyword proxy ──────────────────────────────────────
echo "  7. falsifiability: REFUTED in the recorded close names it (beta 1/4)"
python3 - "$JSON1" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
prof = d["profiles"]
beta = prof["beta"]["all"]["falsifiability"]
if beta["n"] != 4 or beta["avg"] is None or abs(beta["avg"] - 0.25) > 1e-9:
    print(f"    FAIL: beta falsifiability avg={beta['avg']} n={beta['n']}, expected 0.25/4")
    sys.exit(1)
print("    PASS: T5's 'hypothesis REFUTED' graded beta falsifiability 1/4")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (h) --table render contract: 8 dims + role map, verbatim, faithful ────
# T523: the dimension-profiles table in docs/infra/model-perf.md must be the
# tool's own --table render, pasted verbatim.  T524: the render carries the
# 8 D027 dimensions, the 8-type data column and the role->dimension map.
echo "  8. --table: 8-dim columns; cells equal the JSON; role map present; deterministic; stamp"
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
# model rows only: 12 split-cells (leading/trailing empty from the outer
# pipes) = model + 8 dims + type-data.  The role-map block that follows is
# also a markdown table but has 4 split-cells per row.
rows = [l for l in tbl.splitlines()
        if l.startswith("|") and not l.startswith("|--")
        and len(l.split("|")) == 12]
models = [r.split("|")[1].strip() for r in rows[1:]]
ok = True
if models != ["alpha", "beta", "gamma"]:
    print("    FAIL: --table model rows =", models); ok = False
cells = {m: r.split("|") for m, r in zip(models, rows[1:])}
def cell(m, col):
    return cells[m][col + 1].strip()
# alpha correctness: 10/6 over 6
if cell("alpha", 1) != "1.67 (n=6)":
    print("    FAIL: alpha correctness cell", repr(cell("alpha", 1))); ok = False
# gamma: thoroughness(3) efficiency(6) citation-honesty(7) are all null
for col, name in ((3, "thoroughness"), (6, "efficiency"), (7, "citation-honesty")):
    if cell("gamma", col) != "—":
        print(f"    FAIL: gamma {name} cell", repr(cell("gamma", col))); ok = False
# gamma independence (audit row, re-ran) is a real 0.00
if cell("gamma", 4) != "0.00 (n=1)":
    print("    FAIL: gamma independence cell", repr(cell("gamma", 4))); ok = False
# beta efficiency: RSS wall-kill = 1.00 over 1
if cell("beta", 6) != "1.00 (n=1)":
    print("    FAIL: beta efficiency cell", repr(cell("beta", 6))); ok = False
# type-data column, D027 order (spec/impl/audit/integr/infra/research/battery/orcha)
if cell("alpha", 9) != "3/0/0/1/1/1/0/0":
    print("    FAIL: alpha type-data cell", repr(cell("alpha", 9))); ok = False
if cell("beta", 9) != "1/1/0/0/0/0/1/1":
    print("    FAIL: beta type-data cell", repr(cell("beta", 9))); ok = False
# role->dimension map is part of the --table render (D027 directive)
if "Role" not in tbl or "Auditor" not in tbl or "calibration" not in tbl:
    print("    FAIL: role->dimension map missing from --table render"); ok = False
if ok:
    print("    PASS: --table cells faithful to the fixture JSON; role map present")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (i) --check-doc contract: FRESH exits 0, STALE exits 1, absent exits 2 ─
# T523: --check-doc is the standing freshness probe — it extracts the table
# embedded in model-perf.md and compares it cell-by-cell against a fresh
# computation.  Report-only by design (the live table goes stale as the
# ledger moves; the fix is regeneration, not a gate).
echo "  9. --check-doc: fresh=0, perturbed cell=1, missing table=2"
FRESH_DOC="$WORK/fresh.md"
{ cat "$PERF"; echo ""; echo "$TABLE1"; } > "$FRESH_DOC"
if "$TOOL" --check-doc --no-git --root "$WORK" --store "$STORE" --model-perf "$FRESH_DOC" --logs "$LOGS" --c7 "$C7" >/dev/null 2>&1; then
    echo "    PASS: fresh doc reports FRESH (exit 0)"
else
    echo "    FAIL: fresh doc should exit 0"; FAIL=1
fi
STALE_DOC="$WORK/stale.md"
sed 's/1.67 (n=6)/9.99 (n=6)/' "$FRESH_DOC" > "$STALE_DOC"
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

# ── (m) T629: the census — censored rows are refused, skip counts print ──
# Ruling 32: killed_by = none for every scored row; guard-killed rows are
# present and labeled censored (never dropped, never scored); every scorer
# prints, next to each published number, how many rows it skipped and why —
# censored, unattributed, or both.  Seeded fixture: alpha pass (scored),
# beta guard-killed (censored — must contribute NO grade), gamma genuine
# legacy fail without the field (scored, still a failure), delta unattributed
# (model `-` — skipped and counted).  Red (pre-T629): no census key, and the
# censored row grades beta 0.
echo "  m. T629: censored rows never score; the census prints scored/censored/unattributed"
CWORK="$WORK/t629-census"
mkdir -p "$CWORK/docs/infra/managent" "$CWORK/untracked/log" "$CWORK/untracked"
python3 - "$CWORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
tasks = {
    "T1": {"agent": "alpha", "status": "done", "verdict": "pass",
           "bundle": "untracked/T1-spec.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:10:00Z", "note": None, "verdict_note": None},
    # censored row's task: never-graded in the store, so the ONLY way beta
    # could earn a completion_close grade is the (censored) close event.
    "T2": {"agent": "beta", "status": "in_progress", "verdict": None,
           "bundle": "untracked/T2-audit.md", "claimed": "2026-08-20T00:00:00Z",
           "done": None, "note": None, "verdict_note": None},
    "T4": {"agent": "gamma", "status": "done", "verdict": "fail-found",
           "bundle": "untracked/T4-infra.md", "claimed": "2026-08-20T00:00:00Z",
           "done": "2026-08-20T00:10:00Z", "note": None, "verdict_note": None},
    "T5": {"agent": "delta", "status": "in_progress", "verdict": None,
           "bundle": "untracked/T5-spec.md", "claimed": "2026-08-20T00:00:00Z",
           "done": None, "note": None, "verdict_note": None},
}
json.dump(tasks, open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w"))
perf = [
    "# t629 census fixture\n",
    "dispatch-verify 2026-08-20 T1 alpha report=success verified=pass killed_by=none\n",
    "dispatch-verify 2026-08-20 T2 beta report=incomplete verified=fail fail=row killed_by=provider-limit\n",
    # legacy row, no killed_by field: treated as none — still a genuine fail
    "dispatch-verify 2026-08-20 T4 gamma report=incomplete verified=fail fail=row\n",
    # unattributed: model is `-`, skipped and counted
    "dispatch-verify 2026-08-20 T5 - report=incomplete verified=fail fail=row killed_by=none\n",
]
open(os.path.join(work, "model-perf.md"), "w").writelines(perf)
open(os.path.join(work, "c7.json"), "w").write("[]")
PYEOF
CSTORE="$CWORK/docs/infra/managent/tasks.json"
CPERF="$CWORK/model-perf.md"
CLOGS="$CWORK/untracked/log"
CC7="$CWORK/c7.json"
CJSON=$("$TOOL" --json --no-git --root "$CWORK" --store "$CSTORE" --model-perf "$CPERF" --logs "$CLOGS" --c7 "$CC7" 2>/dev/null)
python3 - "$CJSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
ok = True
c = d.get("census")
if not c:
    print("    FAIL: no census key in --json (Ruling 32: skip counts print with the figure)")
    ok = False
else:
    for k, v in (("scored", 2), ("censored", 1), ("unattributed", 1), ("both", 0)):
        if c.get(k) != v:
            print("    FAIL: census[%s] = %s, expected %s (census %s)" % (k, c.get(k), v, c))
            ok = False
beta = d.get("profiles", {}).get("beta", {}).get("all", {}).get("completion_close", {})
if beta.get("n", 0) != 0:
    print("    FAIL: censored row scored beta completion_close n=%s (must be refused)" % beta.get("n"))
    ok = False
gamma = d.get("profiles", {}).get("gamma", {}).get("all", {}).get("completion_close", {})
if gamma.get("avg") != 0.0 or gamma.get("n") != 1:
    print("    FAIL: gamma completion_close = %s (expected 0.0/1 — legacy fail still scores)" % gamma)
    ok = False
alpha = d.get("profiles", {}).get("alpha", {}).get("all", {}).get("completion_close", {})
if alpha.get("avg") != 2.0 or alpha.get("n") != 1:
    print("    FAIL: alpha completion_close = %s (expected 2.0/1 — the pass still scores)" % alpha)
    ok = False
if ok:
    print("    PASS: census scored=2 censored=1 unattributed=1; censored row refused; pass and legacy-fail still grade")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (l) T525: epochs — recorded boundaries never aggregate across ────────
# The 2026-08-18 DeepSeek boundary (model-registry.md §Epoch rules): every
# deepseek-v4-* observation before 2026-08-18 describes the pre-bump models.
# The profile is per-epoch — pre-2026-08-18 and 2026-08-18+ are distinct
# rows — and an undated observation lands in 'epoch-unknown', present and
# labeled, never merged into a dated epoch.
echo "  l. epochs: deepseek-v4-pro splits at 2026-08-18; per-epoch averages; unknown bucket separate"
EWORK="$WORK/epochs"
mkdir -p "$EWORK/docs/infra/managent" "$EWORK/untracked/log" "$EWORK/untracked"
python3 - "$EWORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
def task(claimed, done, verdict, bundle):
    return {"agent": "deepseek-v4-pro", "status": "done", "verdict": verdict,
            "bundle": bundle, "claimed": claimed, "done": done,
            "note": None, "verdict_note": None}
tasks = {
    # old epoch (claimed before 2026-08-18)
    "T100": task("2026-08-10T00:00:00Z", "2026-08-10T01:00:00Z", "pass",
                 "untracked/T100-spec-design.md"),
    "T101": task("2026-08-10T00:00:00Z", "2026-08-10T01:00:00Z", "pass-with-findings",
                 "untracked/T101-spec-strategy.md"),
    # new epoch (claimed on/after 2026-08-18)
    "T102": task("2026-08-22T00:00:00Z", "2026-08-22T01:00:00Z", "pass",
                 "untracked/T102-spec-design.md"),
    "T103": task("2026-08-22T00:00:00Z", "2026-08-22T01:00:00Z", "fail-found",
                 "untracked/T103-spec-draft.md"),
    # no recorded date at all -> epoch-unknown, never merged into either
    "T104": task(None, None, "pass", "untracked/T104-spec-plan.md"),
}
json.dump(tasks, open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w"))
perf = [
    "# epoch fixture\n",
    "dispatch-verify 2026-08-10 T100 deepseek-v4-pro report=success verified=pass\n",
    "dispatch-verify 2026-08-22 T102 deepseek-v4-pro report=success verified=pass\n",
]
open(os.path.join(work, "model-perf.md"), "w").writelines(perf)
open(os.path.join(work, "c7.json"), "w").write("[]")
# wall-kill log census: T100 is an old-epoch task -> its kill grades the OLD
# epoch's efficiency; the new epoch has no efficiency signal.
open(os.path.join(work, "untracked", "log", "t100.log"), "w").write(
    "[runner] argv = ollama launch pi --model deepseek-v4-pro -y -p 'fixture'\n"
    "[runner] task identity: T100 (source: MANAGENT_TASK_ID)\n"
    "[runner] exit 124 (RSS cap 4096 MB exceeded) in 350.9 s\n")
print("epoch fixture seeded")
PYEOF
ESTORE="$EWORK/docs/infra/managent/tasks.json"
EPERF="$EWORK/model-perf.md"
ELOGS="$EWORK/untracked/log"
EC7="$EWORK/c7.json"
EJSON=$("$TOOL" --json --no-git --root "$EWORK" --store "$ESTORE" --model-perf "$EPERF" --logs "$ELOGS" --c7 "$EC7" 2>/dev/null)
python3 - "$EJSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
ok = True
prof = d["profiles"].get("deepseek-v4-pro", {})
# exactly three buckets: pre-2026-08-18, 2026-08-18+, epoch-unknown
expect = {"pre-2026-08-18", "2026-08-18+", "epoch-unknown"}
if set(prof.keys()) != expect:
    print("    FAIL: deepseek-v4-pro epoch keys =", sorted(prof.keys()), "expected", sorted(expect)); ok = False
def avg(ep, dim):
    return prof[ep][dim]["avg"], prof[ep][dim]["n"]
# correctness: old = T100 pass(2)+T101 pwf(1) = 1.5/2; new = T102 pass(2)+
# T103 fail-found(1) = 1.5/2; unknown = T104 pass(2) = 2.0/1
for ep, exp in (("pre-2026-08-18", (1.5, 2)), ("2026-08-18+", (1.5, 2)),
                ("epoch-unknown", (2.0, 1))):
    a, n = avg(ep, "correctness")
    if a is None or abs(a - exp[0]) > 1e-9 or n != exp[1]:
        print(f"    FAIL: {ep} correctness = {a}/{n}, expected {exp[0]}/{exp[1]}"); ok = False
# completion_close: old = T100 close-pass(2)+T101 done(1) = 1.5/2; new =
# T102 close-pass(2)+T103 done(1) = 1.5/2; unknown = T104 done(1) = 1.0/1
for ep, exp in (("pre-2026-08-18", (1.5, 2)), ("2026-08-18+", (1.5, 2)),
                ("epoch-unknown", (1.0, 1))):
    a, n = avg(ep, "completion_close")
    if a is None or abs(a - exp[0]) > 1e-9 or n != exp[1]:
        print(f"    FAIL: {ep} completion_close = {a}/{n}, expected {exp[0]}/{exp[1]}"); ok = False
# efficiency: only the old epoch has a kill (T100, RSS -> grade 1)
a, n = avg("pre-2026-08-18", "efficiency")
if a != 1.0 or n != 1:
    print(f"    FAIL: pre-2026-08-18 efficiency = {a}/{n}, expected 1.0/1"); ok = False
a, n = avg("2026-08-18+", "efficiency")
if a is not None or n != 0:
    print(f"    FAIL: 2026-08-18+ efficiency = {a}/{n}, expected null/0"); ok = False
# type counts per epoch: 2 spec rows old, 2 new, 1 unknown
tc = d["type_counts"].get("deepseek-v4-pro", {})
for ep, exp in (("pre-2026-08-18", 2), ("2026-08-18+", 2), ("epoch-unknown", 1)):
    got = tc.get(ep, {}).get("spec/design", 0)
    if got != exp:
        print(f"    FAIL: {ep} spec/design count = {got}, expected {exp}"); ok = False
# the boundary table is emitted so the figure carries its epoch source
if d.get("epoch_boundaries", {}).get("deepseek-v4-pro") != ["2026-08-18"]:
    print("    FAIL: epoch_boundaries =", d.get("epoch_boundaries")); ok = False
if set(d["profiles"].keys()) != {"deepseek-v4-pro"}:
    print("    FAIL: unexpected models in epoch fixture:", sorted(d["profiles"].keys())); ok = False
if ok:
    print("    PASS: deepseek-v4-pro split pre-/post-2026-08-18 + unknown; per-epoch averages and counts correct")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (m) T525: selection is epoch-scoped — old-epoch data is NOT data ─────
# A boundary model's OLD-epoch profile describes the pre-bump model; for a
# dispatch decision today it counts as zero current data, so exploration-
# first names it over a model that HAS new-epoch data.  With new-epoch data
# on the type, the profile decides (dominant dimension).
echo "  m. selection: deepseek-v4-pro old-epoch data counts as zero current data"
MWORK="$WORK/select-epochs"
mkdir -p "$MWORK/docs/infra/managent" "$MWORK/untracked/log" "$MWORK/untracked"
python3 - "$MWORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
tasks = {
    # deepseek-v4-pro: spec/design data ONLY in the old epoch
    "T110": {"agent": "deepseek-v4-pro", "status": "done", "verdict": "pass-with-findings",
             "bundle": "untracked/T110-spec-design.md",
             "claimed": "2026-08-10T00:00:00Z", "done": "2026-08-10T01:00:00Z",
             "note": None, "verdict_note": None},
    # alpha: no boundary -> its data is current
    "T111": {"agent": "alpha", "status": "done", "verdict": "pass-with-findings",
             "bundle": "untracked/T111-spec-design.md",
             "claimed": "2026-08-22T00:00:00Z", "done": "2026-08-22T01:00:00Z",
             "note": None, "verdict_note": None},
    # deepseek-v4-pro NEW-epoch spec data (for the profile-decides arm)
    "T112": {"agent": "deepseek-v4-pro", "status": "done", "verdict": "pass",
             "bundle": "untracked/T112-spec-design.md",
             "claimed": "2026-08-22T00:00:00Z", "done": "2026-08-22T01:00:00Z",
             "note": None, "verdict_note": None},
}
json.dump(tasks, open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w"))
open(os.path.join(work, "model-perf.md"), "w").write("# fixture\n")
open(os.path.join(work, "c7.json"), "w").write("[]")
print("select-epochs fixture seeded")
PYEOF
MSTORE="$MWORK/docs/infra/managent/tasks.json"
MPERF="$MWORK/model-perf.md"
MLOGS="$MWORK/untracked/log"
MC7="$MWORK/c7.json"
# arm 1: both candidates have NEW-epoch spec data (deepseek: T112, alpha:
# T111) -> profile decides on the dominant dimension (spec/design ->
# correctness): deepseek's pass (2.0) beats alpha's pwf (1.0).
OUT=$("$TOOL" --no-git --root "$MWORK" --store "$MSTORE" --model-perf "$MPERF" \
      --logs "$MLOGS" --c7 "$MC7" --select spec/design --candidates deepseek-v4-pro,alpha 2>/dev/null)
if [ "$OUT" = "deepseek-v4-pro" ]; then
    echo "    PASS: with new-epoch data on the type, profile decides (correctness 2.0 > 1.0)"
else
    echo "    FAIL: --select spec/design returned '$OUT', expected deepseek-v4-pro (profile decides on newest epoch)"
    FAIL=1
fi
# arm 2: drop the new-epoch task -> deepseek has ZERO current spec data and
# must be named by exploration-first despite its strong old-epoch profile.
python3 - "$MWORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
store = json.load(open(os.path.join(work, "docs", "infra", "managent", "tasks.json")))
del store["T112"]
json.dump(store, open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w"))
print("T112 removed")
PYEOF
OUT=$("$TOOL" --no-git --root "$MWORK" --store "$MSTORE" --model-perf "$MPERF" \
      --logs "$MLOGS" --c7 "$MC7" --select spec/design --candidates deepseek-v4-pro,alpha 2>/dev/null)
if [ "$OUT" = "deepseek-v4-pro" ]; then
    echo "    PASS: exploration-first named deepseek-v4-pro (0 NEW-epoch spec data beats alpha's 1)"
else
    echo "    FAIL: --select spec/design returned '$OUT', expected deepseek-v4-pro (old-epoch data must not count)"
    FAIL=1
fi

# ── (n) T525: multi-boundary bucketing (--epochs) + registry parity ──────
# The built-in boundary table must mirror docs/infra/model-registry.md §
# Epoch rules (the recorded 2026-08-18 DeepSeek boundary).  --epochs lets a
# test exercise the general several-boundaries logic.
echo "  n. multi-boundary bucketing (--epochs) + registry parity"
NWORK="$WORK/epochs-multi"
mkdir -p "$NWORK/docs/infra/managent" "$NWORK/untracked/log" "$NWORK/untracked"
python3 - "$NWORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
def task(claimed, bundle):
    return {"agent": "delta", "status": "done", "verdict": "pass",
            "bundle": bundle, "claimed": claimed, "done": claimed,
            "note": None, "verdict_note": None}
tasks = {
    "T120": task("2026-08-01T00:00:00Z", "untracked/T120-spec-design.md"),
    "T121": task("2026-08-10T00:00:00Z", "untracked/T121-spec-design.md"),
    "T122": task("2026-08-22T00:00:00Z", "untracked/T122-spec-design.md"),
}
json.dump(tasks, open(os.path.join(work, "docs", "infra", "managent", "tasks.json"), "w"))
open(os.path.join(work, "model-perf.md"), "w").write("# fixture\n")
open(os.path.join(work, "c7.json"), "w").write("[]")
# two boundaries: 2026-08-05 (preview bump) and 2026-08-18 (full bump)
json.dump({"delta": ["2026-08-05", "2026-08-18"]},
          open(os.path.join(work, "epochs.json"), "w"))
print("multi-epoch fixture seeded")
PYEOF
NSTORE="$NWORK/docs/infra/managent/tasks.json"
NPERF="$NWORK/model-perf.md"
NLOGS="$NWORK/untracked/log"
NC7="$NWORK/c7.json"
NEPOCHS="$NWORK/epochs.json"
NJSON=$("$TOOL" --json --no-git --root "$NWORK" --store "$NSTORE" --model-perf "$NPERF" \
        --logs "$NLOGS" --c7 "$NC7" --epochs "$NEPOCHS" 2>/dev/null)
python3 - "$NJSON" <<'PYEOF'
import json, sys
d = json.loads(sys.argv[1])
ok = True
prof = d["profiles"].get("delta", {})
expect = {"pre-2026-08-05", "2026-08-05..2026-08-18", "2026-08-18+"}
if set(prof.keys()) != expect:
    print("    FAIL: delta epoch keys =", sorted(prof.keys()), "expected", sorted(expect)); ok = False
for ep in expect:
    n = prof[ep]["correctness"]["n"]
    if n != 1:
        print(f"    FAIL: {ep} correctness n = {n}, expected 1"); ok = False
if d.get("epoch_boundaries", {}).get("delta") != ["2026-08-05", "2026-08-18"]:
    print("    FAIL: epoch_boundaries =", d.get("epoch_boundaries")); ok = False
if ok:
    print("    PASS: delta bucketed into three epochs across two boundaries")
else:
    sys.exit(1)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi
# registry parity: the built-in boundary table carries the recorded
# 2026-08-18 DeepSeek boundary (model-registry.md §Epoch rules).
python3 - "$ROOT" <<'PYEOF'
import importlib.util, os, sys
root = sys.argv[1]
txt = open(os.path.join(root, "docs", "infra", "model-registry.md")).read()
if "every deepseek-v4-* observation before 2026-08-18" not in txt:
    print("    FAIL: model-registry.md no longer records the 2026-08-18 deepseek boundary sentence")
    sys.exit(1)
spec = importlib.util.spec_from_file_location(
    "model_profiles", os.path.join(root, "tools", "model-profiles.py"))
mp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mp)
for m in ("deepseek-v4-pro", "deepseek-v4-flash"):
    if "2026-08-18" not in mp.EPOCH_BOUNDARIES.get(m, []):
        print(f"    FAIL: tool's EPOCH_BOUNDARIES missing 2026-08-18 for {m}: {mp.EPOCH_BOUNDARIES.get(m)}")
        sys.exit(1)
print("    PASS: built-in boundary table matches the recorded 2026-08-18 DeepSeek boundary")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── (o) T800: ONE short-name table — no second copy anywhere ──────────────
# Operator ruling 2026-08-23 (T800): the short-name → canonical mapping lives
# in exactly one table, docs/infra/model-registry.md §"Short names →
# canonical". The model-task-matrix.md §0 copy is deleted; this arm stops a
# second table from recurring. The canonical-label set is DERIVED from the
# registry's own table (second column of its short-name rows), so the arm
# holds no second mapping; a markdown row of the shape
# `| \`short\` | \`canonical\` | …` in any other file under docs/, tools/,
# src/ or findings/ is a second table and fails. Red against the pre-T800
# matrix copy (9 rows); green after. untracked/ is not scanned: it is
# gitignored and transient (dispatch bundles), not a tracked surface.
echo "  o. no second short-name table (docs/, tools/, src/, findings/)"
o_fail=0
short_labels=$(grep -E '^\| `[a-z][a-z0-9]*` \| `[^`]+`' "$ROOT/docs/infra/model-registry.md" \
    | sed -E 's/^\| `[a-z][a-z0-9]*` \| `([^`]+)`.*/\1/')
if [ -z "$short_labels" ]; then
    echo "    FAIL: could not derive canonical labels from model-registry.md"
    o_fail=1
else
    for label in $short_labels; do
        hits=$(grep -rnE "^\| \`[a-z][a-z0-9]*\` \| \`$label\` \|" \
            "$ROOT/docs" "$ROOT/tools" "$ROOT/src" "$ROOT/findings" \
            --include='*.md' --include='*.zig' --include='*.sh' --include='*.py' 2>/dev/null \
            | grep -v "^$ROOT/docs/infra/model-registry.md:" || true)
        if [ -n "$hits" ]; then
            echo "    FAIL: second short-name table row mapping to canonical \`$label\`:"
            printf '%s\n' "$hits" | sed "s|^$ROOT/||" | sed 's/^/      /'
            o_fail=1
        fi
    done
fi
if [ "$o_fail" = "0" ]; then
    echo "    PASS: model-registry.md is the only short-name → canonical table"
else
    FAIL=1
fi


echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-model-profiles: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-model-profiles: FAILURES ==="
    exit 1
fi
