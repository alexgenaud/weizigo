#!/usr/bin/env bash
# regression-absorption-machinery.sh — T406 controls for the two broken safety
# nets T404 found: `bin/weizigo-absorb` parses the 11-column register as empty
# and emits nothing (silent "nothing to do"), and `managent standing` fires
# STANDING-ABSORB's trigger into a `done` row that can never become
# dispatchable again ("TRIGGERED" + "(already registered, skipping)").
#
# Defect 1 controls (absorb + the shared parser in src/claims_register.zig):
#   seeded 11-col   the REAL register (copied into a scratch repo) must yield
#                   221 rows — a seeded status change must produce an
#                   edit_status directive and a seeded new row must produce an
#                   add_row directive carrying the 11-column shape (tree
#                   column present, C9-gated placeholder)
#   seeded 10-col   the pre-tree 10-column register must FAIL LOUDLY (nonzero
#                   exit, column counts named) — the old "parses as empty,
#                   reports success" failure mode is a hard error now
#   null            a findings file whose proposed status already matches the
#                   register proposes NOTHING (noop directives only) and does
#                   not append to untracked/absorption.md (no counter move)
#   gen-indices     the second vacuous consumer: the generator must index all
#                   221 rows and must fail loudly on a register it cannot
#                   parse (0 claims from a non-empty file)
#
# Defect 2 controls (managent standing — src/managent/main.zig registerStanding):
#   seeded reopen   a `done` standing row re-triggered above threshold must
#                   become dispatchable AGAIN (re-registered, note updated) —
#                   the standing tier is recurring, done must not absorb
#                   future triggers
#   live guard      a dispatchable/in_progress standing row re-triggered must
#                   NOT spawn a second instance, and the refusal must read as
#                   an inaction ("NOT re-registered", never the bare
#                   "(already registered, skipping)" after TRIGGERED)
#   family-wide     the reopen path is shared by all five standing templates —
#                   verified on STANDING-REEVIDENCE too, not just ABSORB
#   null            C7 at/below threshold → no trigger, store untouched
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban, live
# findings/, and live CLAIMS.md are never touched. The real register is
# COPIED in for the 221-row control (absorb only parses; it never edits).
#
# Binary resolution (same convention as regression-managent-standing.sh):
#   $ABSORB_BIN / $MANAGENT_BIN → zig-out/bin/* (built, not deployed) →
#   bin/*. SKIP (loudly) when no binary carries the feature, or when the real
#   repo's bin/weizigo-claimlint is absent (the standing controls run claimlint
#   for real in a scratch repo).
#
# Task: T406 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-07

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# ── binary resolution ─────────────────────────────────────────────────────
ABS="${ABSORB_BIN:-}"
if [ -z "$ABS" ]; then
    if [ -x "$PROJECT/zig-out/bin/weizigo-absorb" ]; then
        ABS="$PROJECT/zig-out/bin/weizigo-absorb"
    elif [ -x "$PROJECT/bin/weizigo-absorb" ]; then
        ABS="$PROJECT/bin/weizigo-absorb"
    fi
fi
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$ABS" ]; then
    echo "SKIP: no weizigo-absorb binary found — build with 'zig build' (zig-out/bin/weizigo-absorb) or deploy"
    exit 0
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent standing"; then
    echo "SKIP: $MG does not carry the standing command — rebuild from src/managent/main.zig"
    exit 0
fi
if [ ! -x "$PROJECT/bin/weizigo-claimlint" ]; then
    echo "SKIP: $PROJECT/bin/weizigo-claimlint not found — build with 'zig build' first (the standing control runs claimlint for real)"
    exit 0
fi

WORK="$(mktemp -d /tmp/weizigo/absorption-machinery-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

echo "=== absorption-machinery regression (T406) ==="

# ── scratch A: absorb against the REAL 11-column register ─────────────────
mkdir -p "$WORK/A/docs/epistemic" "$WORK/A/untracked" "$WORK/A/findings"
cd "$WORK/A"
git init -q
git config user.email t406@test
git config user.name T406
cp "$PROJECT/docs/epistemic/CLAIMS.md" docs/epistemic/CLAIMS.md

# ── A1. seeded 11-col control: 221 rows, edit_status + 11-col add_row ──────
echo "  A1. seeded 11-col register: parser yields 221 rows and emits directives"
cat > findings.json <<'JSONEOF'
{
  "task_id": "T406A1",
  "date": "2026-08-07",
  "model": "deepseek-v4-flash",
  "claims": [
    {
      "id": "GLOBAL.S1",
      "proposed_status": "UNTESTED",
      "rationale": "A1 control: GLOBAL.S1 exists in the 11-column register",
      "evidence_path": "scratch"
    }
  ],
  "new_rows": [
    {
      "id": "GLOBAL.T406A1-NEW",
      "legacy": "—",
      "goban": "all",
      "claim": "A1 control new row",
      "status": "CLAIMED",
      "evidence": "scratch.md:1",
      "depends_on": "d:GLOBAL.S1",
      "narrowed": 0,
      "wrong_answer_pass_rate": "?"
    }
  ]
}
JSONEOF
OUT_A1=$("$ABS" findings.json --dry-run 2>"$WORK/A/stderr-A1")
RC_A1=$?
if [ "$RC_A1" -eq 0 ] && \
   grep -q "parsed 221 rows" "$WORK/A/stderr-A1" && \
   echo "$OUT_A1" | grep -q '"directive":"edit_status","claim_id":"GLOBAL.S1"' && \
   echo "$OUT_A1" | grep -q '"current_status":"PROVEN"' && \
   echo "$OUT_A1" | grep -q '"directive":"add_row","claim_id":"GLOBAL.T406A1-NEW"' && \
   echo "$OUT_A1" | grep -q "| TREE-ASSIGN |" && \
   echo "$OUT_A1" | grep -q '"insert_after":"' && \
   ! echo "$OUT_A1" | grep -q '"insert_after":"GLOBAL.ADR0001-PROJECT"'; then
    echo "    PASS: RC=0, 221 rows parsed, edit_status(GLOBAL.S1 PROVEN→UNTESTED), add_row with 11-column shape, insert_after resolved from the register (not the hard-coded fallback)"
else
    echo "    FAIL: RC=$RC_A1, stderr:"; sed 's/^/      /' "$WORK/A/stderr-A1"
    echo "    stdout:"; echo "$OUT_A1" | sed 's/^/      /'
    FAIL=1
fi

# ── A2. seeded 10-col control: the pre-tree format FAILS LOUDLY ────────────
echo "  A2. seeded 10-col register: hard error naming the column counts"
mkdir -p "$WORK/A10/docs/epistemic" "$WORK/A10/findings" "$WORK/A10/untracked"
cd "$WORK/A10"
git init -q
git config user.email t406@test
git config user.name T406
cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — pre-tree 10-column shape

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.TENCOL1` | T1 | all | ten-column row one | PROVEN | `scratch.md:1` | — | — | 0 | ? |
| `GLOBAL.TENCOL2` | T2 | all | ten-column row two | PROVEN | `scratch.md:2` | — | — | 0 | ? |
MDEOF
echo "scratch evidence" > scratch.md
cp "$WORK/A/findings.json" findings.json
OUT_A2=$("$ABS" findings.json --dry-run 2>"$WORK/A10/stderr-A2")
RC_A2=$?
if [ "$RC_A2" -ne 0 ] && \
   grep -qi "0 rows" "$WORK/A10/stderr-A2" && \
   grep -q "10" "$WORK/A10/stderr-A2" && \
   grep -q "11" "$WORK/A10/stderr-A2"; then
    echo "    PASS: RC=$RC_A2, empty-parse hard error with found (10) and expected (11) counts"
else
    echo "    FAIL: RC=$RC_A2, stderr:"; sed 's/^/      /' "$WORK/A10/stderr-A2"
    FAIL=1
fi

# ── A3. null control (absorb): matching status → nothing proposed, no log ──
echo "  A3. null control: no edit directives and no absorption-log append"
cd "$WORK/A"
cat > findings-null.json <<'JSONEOF'
{
  "task_id": "T406A3",
  "date": "2026-08-07",
  "model": "deepseek-v4-flash",
  "claims": [
    {
      "id": "GLOBAL.S1",
      "proposed_status": "PROVEN",
      "rationale": "A3 control: register already reflects PROVEN",
      "evidence_path": "scratch"
    }
  ]
}
JSONEOF
OUT_A3=$("$ABS" findings-null.json 2>/dev/null)
RC_A3=$?
if [ "$RC_A3" -eq 0 ] && \
   echo "$OUT_A3" | grep -q '"directive":"noop"' && \
   ! echo "$OUT_A3" | grep -q '"directive":"edit_status"' && \
   ! echo "$OUT_A3" | grep -q '"directive":"add_row"' && \
   [ ! -f untracked/absorption.md ]; then
    echo "    PASS: RC=0, noop only, no edit directives, absorption log not appended"
else
    echo "    FAIL: RC=$RC_A3, stdout:"; echo "$OUT_A3" | sed 's/^/      /'
    echo "    absorption.md exists: $([ -f untracked/absorption.md ] && echo yes || echo no)"
    FAIL=1
fi

# ── B. gen-indices — the second vacuous consumer ───────────────────────────
echo "  B1. gen-indices on the 11-col register indexes all 221 claims"
mkdir -p "$WORK/B/tools" "$WORK/B/docs/epistemic"
cp "$PROJECT/tools/gen-indices" "$WORK/B/tools/gen-indices"
cp "$PROJECT/docs/epistemic/CLAIMS.md" "$WORK/B/docs/epistemic/CLAIMS.md"
cd "$WORK/B"
if python3 tools/gen-indices >"$WORK/B/gen-stdout" 2>"$WORK/B/gen-stderr"; then
    ROW_COUNT=$(grep -c '^| `' docs/INDEX-claim-evidence.md)
    if [ "$ROW_COUNT" -eq 221 ]; then
        echo "    PASS: INDEX-claim-evidence.md carries 221 rows"
    else
        echo "    FAIL: indexed $ROW_COUNT rows, expected 221"
        FAIL=1
    fi
else
    echo "    FAIL: gen-indices exited nonzero:"; sed 's/^/      /' "$WORK/B/gen-stderr"
    FAIL=1
fi

echo "  B2. gen-indices on a register it cannot parse fails loudly"
mkdir -p "$WORK/B10/tools" "$WORK/B10/docs/epistemic"
cp "$PROJECT/tools/gen-indices" "$WORK/B10/tools/gen-indices"
cp "$WORK/A10/docs/epistemic/CLAIMS.md" "$WORK/B10/docs/epistemic/CLAIMS.md"
cd "$WORK/B10"
if python3 tools/gen-indices >"$WORK/B10/gen-stdout" 2>"$WORK/B10/gen-stderr"; then
    echo "    FAIL: gen-indices exited 0 on a 0-claim parse (silent empty index)"
    FAIL=1
elif grep -qi "0 claim" "$WORK/B10/gen-stderr"; then
    echo "    PASS: gen-indices refused a 0-claim parse with a diagnostic"
else
    echo "    FAIL: gen-indices exited nonzero but without the empty-parse diagnostic:"; sed 's/^/      /' "$WORK/B10/gen-stderr"
    FAIL=1
fi

# ── C. standing reopen (defect 2) ──────────────────────────────────────────
setup_standing() {
    # $1 = scratch dir; $2 = store path (exported via MANAGENT_STORE by caller)
    local D="$1"
    mkdir -p "$D/docs/infra/managent" "$D/docs/infra/dispatch" "$D/docs/epistemic" \
             "$D/findings" "$D/untracked/msg" "$D/bin"
    cd "$D"
    git init -q
    git config user.email t406@test
    git config user.name T406
    cp "$PROJECT/bin/weizigo-claimlint" bin/
    cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — T406 standing control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.SCRATCH1` | S1 | all | scratch row one | PROVEN | `scratch.md:1` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH2` | S2 | all | scratch row two | PROVEN | `scratch.md:2` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH3` | S3 | all | scratch row three | PROVEN | `scratch.md:3` | — | — | 0 | ? | Z- |
MDEOF
    echo "scratch evidence" > scratch.md
}

seed_c7() {
    # $1 = scratch dir — six unabsorbed claims → claimlint C7 = 6 > threshold 5
    cat > "$1/findings/T406SEED-absorb.json" <<'JSONEOF'
{
  "task_id": "T406SEED",
  "date": "2026-08-07",
  "model": "deepseek-v4-flash",
  "claims": [
    "GLOBAL.SEED-1","GLOBAL.SEED-2","GLOBAL.SEED-3","GLOBAL.SEED-4","GLOBAL.SEED-5","GLOBAL.SEED-6"
  ]
}
JSONEOF
}

# ── C1. seeded reopen: a done standing row re-triggered becomes dispatchable ─
echo "  C1. seeded reopen: done STANDING-ABSORB + C7=6 → dispatchable again"
setup_standing "$WORK/C1"
STORE_C1="$WORK/C1/docs/infra/managent/tasks.json"
cat > "$STORE_C1" <<'JSONEOF'
{"STANDING-ABSORB":{"status":"done","agent":"deepseek-v4-flash","bundle":"docs/infra/dispatch/STANDING-ABSORB.md","set":"H","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":"C7 unabsorbed findings 8 > threshold 5","verdict":"pass","claim_count":1}}
JSONEOF
seed_c7 "$WORK/C1"
OUT_C1=$(MANAGENT_STORE="$STORE_C1" "$MG" standing 2>"$WORK/C1/stderr-C1")
if echo "$OUT_C1" | grep -q "C7 unabsorbed: 6 (threshold 5)" && \
   echo "$OUT_C1" | grep -q "re-registered STANDING-ABSORB"; then
    STATUS_C1=$(python3 -c "import json;print(json.load(open('$STORE_C1'))['STANDING-ABSORB']['status'])")
    NOTE_C1=$(python3 -c "import json;print(json.load(open('$STORE_C1'))['STANDING-ABSORB'].get('note',''))")
    if [ "$STATUS_C1" = "dispatchable" ] && echo "$NOTE_C1" | grep -q "6 > threshold 5"; then
        echo "    PASS: store status done→dispatchable, note updated to the new trigger reason"
    else
        echo "    FAIL: reopened but store says status=$STATUS_C1 note='$NOTE_C1'"
        FAIL=1
    fi
else
    echo "    FAIL: output:"; echo "$OUT_C1" | sed 's/^/      /'
    echo "    stderr:"; sed 's/^/      /' "$WORK/C1/stderr-C1"
    FAIL=1
fi

# ── C2. live-instance guard: no duplicate, and the refusal reads as inaction ─
echo "  C2. live guard: in_progress STANDING-ABSORB re-triggered → NOT re-registered"
python3 - "$STORE_C1" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d['STANDING-ABSORB']['status'] = 'in_progress'
d['STANDING-ABSORB']['agent'] = 'deepseek-v4-flash'
json.dump(d, open(p, 'w'))
PYEOF
OUT_C2=$(MANAGENT_STORE="$STORE_C1" "$MG" standing 2>"$WORK/C1/stderr-C2")
STATUS_C2=$(python3 -c "import json;print(json.load(open('$STORE_C1'))['STANDING-ABSORB']['status'])")
if echo "$OUT_C2" | grep -q "TRIGGERED — absorption backlog above threshold" && \
   [ "$STATUS_C2" = "in_progress" ] && \
   grep -q "NOT re-registered" "$WORK/C1/stderr-C2" && \
   ! grep -q "already registered, skipping" "$WORK/C1/stderr-C2" && \
   [ "$(python3 -c "import json;print(sum(1 for k in json.load(open('$STORE_C1')) if k.startswith('STANDING-')))")" = "1" ]; then
    echo "    PASS: trigger fired, store untouched (still in_progress, one row), refusal names the inaction"
else
    echo "    FAIL: status=$STATUS_C2, output:"; echo "$OUT_C2" | sed 's/^/      /'
    echo "    stderr:"; sed 's/^/      /' "$WORK/C1/stderr-C2"
    FAIL=1
fi

# ── C3. family-wide: the reopen path is shared — STANDING-REEVIDENCE too ───
echo "  C3. family-wide: done STANDING-REEVIDENCE + C3 growth → dispatchable again"
setup_standing "$WORK/C3"
STORE_C3="$WORK/C3/docs/infra/managent/tasks.json"
cat > "$STORE_C3" <<'JSONEOF'
{"STANDING-ABSORB":{"status":"dispatchable","agent":null,"bundle":"docs/infra/dispatch/STANDING-ABSORB.md","set":"H","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":"","claim_count":0},"STANDING-REEVIDENCE":{"status":"done","agent":"deepseek-v4-flash","bundle":"docs/infra/dispatch/STANDING-REEVIDENCE.md","set":"H","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":"C3 debt grew: 2→3","verdict":"pass","claim_count":1}}
JSONEOF
# First run persists C3 prior (3 rows of tierB evidence → C3 = 3, no growth → no trigger)
MANAGENT_STORE="$STORE_C3" "$MG" standing >/dev/null 2>&1
# Then grow the register: C3 3→4 with prior>0 → REEVIDENCE trigger fires
cat >> "$WORK/C3/docs/epistemic/CLAIMS.md" <<'MDEOF'
| `GLOBAL.SCRATCH4` | S4 | all | scratch row four | PROVEN | `scratch.md:4` | — | — | 0 | ? | Z- |
MDEOF
OUT_C3=$(MANAGENT_STORE="$STORE_C3" "$MG" standing 2>"$WORK/C3/stderr-C3")
STATUS_C3=$(python3 -c "import json;print(json.load(open('$STORE_C3'))['STANDING-REEVIDENCE']['status'])")
if echo "$OUT_C3" | grep -q "C3 debt: 4 (was 3)" && \
   echo "$OUT_C3" | grep -q "re-registered STANDING-REEVIDENCE" && \
   [ "$STATUS_C3" = "dispatchable" ]; then
    echo "    PASS: REEVIDENCE done→dispatchable on C3 growth (shared registerStanding path)"
else
    echo "    FAIL: status=$STATUS_C3, output:"; echo "$OUT_C3" | sed 's/^/      /'
    FAIL=1
fi

# ── C4. null control (standing): C7=0 → no trigger, store untouched ────────
echo "  C4. null control: C7=0 → nothing proposed, no counter moves"
setup_standing "$WORK/C4"
STORE_C4="$WORK/C4/docs/infra/managent/tasks.json"
echo '{}' > "$STORE_C4"
OUT_C4=$(MANAGENT_STORE="$STORE_C4" "$MG" standing 2>/dev/null)
if [ $? -eq 0 ] && \
   echo "$OUT_C4" | grep -q "C7 unabsorbed: 0 (threshold 5)" && \
   echo "$OUT_C4" | grep -q "at/below threshold, no trigger" && \
   ! grep -q "STANDING-ABSORB" "$STORE_C4"; then
    echo "    PASS: C7=0, explicit at/below-threshold statement, kanban untouched"
else
    echo "    FAIL: output:"; echo "$OUT_C4" | sed 's/^/      /'
    echo "    store: $(cat "$STORE_C4")"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-absorption-machinery: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-absorption-machinery: FAILURES ==="
    exit 1
fi
