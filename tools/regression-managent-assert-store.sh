#!/usr/bin/env bash
# regression-managent-assert-store.sh
# T518 / F9 regression: `managent assert` honors the MANAGENT_STORE override.
#
# The defect (F9): cmdAssert wrote the assertion record to the LIVE ledger
# (repo_root/docs/infra/assertion-ledger/assertions.jsonl) regardless of
# MANAGENT_STORE. Every other mutating verb writes through state_path (the
# store), so a scratch store stayed isolated — but `assert` reached back into
# the real repo's ledger. The fix derives the assertion-ledger path from
# state_path (dirname(state_path)/../assertion-ledger/assertions.jsonl), the
# same sibling layout the default store uses, and the reader
# (readLedgerStatuses) follows the same derivation so a scratch assertion is
# read back from the scratch ledger.
#
# This is the first regression to exercise `managent assert` *writing* at all;
# the T497 ledger-board-seam regression seeds the ledger by hand and only
# reads it. Must be RED against bin/managent before the fix lands.
#
# Arms (all against a scratch store located OUTSIDE the fake repo so the
# store-override path is actually exercised — repo_root != store dir):
#   A. assert writes the record to the SCRATCH ledger, NOT the repo-root one.
#   B. show renders the (asserted) annotation by reading the SCRATCH ledger
#      (the reader honors the store override too).
#   C. the assertion_next counter is persisted to the SCRATCH store
#      (state_path), and the repo-root store is untouched.
#   D. default-store arm (MANAGENT_STORE unset, cwd = fake repo): assert writes
#      to repo_root/docs/infra/assertion-ledger/ — the default layout is
#      preserved (no regression for the common case).
#
# Usage:  tools/regression-managent-assert-store.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# Deploy freshness is a suite preflight, not a per-check assertion: the
# job belongs to tools/smoke.sh (T872 green-up: the four re-implemented
# arms here and in the sibling managent regressions were deleted — a stale
# bin/ must fail the preflight once, not four checks).

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent a suite's arms into the LIVE repo.
mkdir -p /tmp/weizigo
ROOT="$(mktemp -d /tmp/weizigo/managent-assert-store-XXXXXX)" || { echo "regression-managent-assert-store.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

# A fake repo (repo_root) SEPARATE from the scratch store, so MANAGENT_STORE
# pointing outside repo_root is actually exercised.
REPO="$ROOT/repo"
SCRATCH="$ROOT/scratch"
mkdir -p "$REPO" "$SCRATCH/docs/infra/managent" "$SCRATCH/docs/infra/assertion-ledger" "$REPO/docs/infra/assertion-ledger" "$REPO/untracked"
git init -q "$REPO"
git -C "$REPO" config user.email "t518@test"
git -C "$REPO" config user.name "T518"

# Seed a minimal task the assert targets, in the SCRATCH store. assertion_next
# starts at 1 so the first minted id is A0001.
seed_scratch() {  # $1 = task-id
    printf '{"%s":{"status":"in_progress","agent":"glm-5.2","model":"glm-5.2","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9000,"directive_next":1,"assertion_next":1}}' "$1" "$1" > "$SCRATCH/docs/infra/managent/tasks.json"
}
seed_repo() {  # $1 = task-id  (for the default-store arm)
    mkdir -p "$REPO/docs/infra/managent"
    printf '{"%s":{"status":"in_progress","agent":"glm-5.2","model":"glm-5.2","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9000,"directive_next":1,"assertion_next":1}}' "$1" "$1" > "$REPO/docs/infra/managent/tasks.json"
}

SCRATCH_STORE="$SCRATCH/docs/infra/managent/tasks.json"
SCRATCH_LEDGER="$SCRATCH/docs/infra/assertion-ledger/assertions.jsonl"
REPO_LEDGER="$REPO/docs/infra/assertion-ledger/assertions.jsonl"

echo ""
echo "  T518/F9 regression: managent assert honors the store override"

# ── Arm A: assert writes to the SCRATCH ledger, not the repo-root one ──────
echo "    A. assert writes the record to the SCRATCH ledger (store override)"

seed_scratch T518A
: > "$SCRATCH_LEDGER"
: > "$REPO_LEDGER"
export MANAGENT_STORE="$SCRATCH_STORE"
ASSERT_A=$(cd "$REPO" && MANAGENT_TASK_ID=T518A "$MG" assert T518A closed --note "scratch-isolation" 2>&1)
A_ID=$(echo "$ASSERT_A" | grep -oE 'A[0-9]{4}' | head -1)
echo "       assert output: $ASSERT_A"
echo "       minted assertion id: ${A_ID:-<none>}"

if [ ! -s "$SCRATCH_LEDGER" ]; then
    echo "       FAIL: SCRATCH ledger is empty — assert did not honor the store override"
    FAIL=1
else
    echo "       PASS: SCRATCH ledger received the assertion record"
fi
if [ -s "$REPO_LEDGER" ]; then
    echo "       FAIL: REPO-root ledger was written — assert leaked into the live repo layout"
    FAIL=1
else
    echo "       PASS: REPO-root ledger untouched"
fi
if [ -n "$A_ID" ] && grep -q "\"$A_ID\"" "$SCRATCH_LEDGER" 2>/dev/null; then
    echo "       PASS: assertion $A_ID is in the SCRATCH ledger"
elif [ -n "$A_ID" ]; then
    echo "       FAIL: assertion $A_ID not found in SCRATCH ledger"
    FAIL=1
fi
if grep -q '"T518A"' "$SCRATCH_LEDGER" 2>/dev/null && grep -q '"closed"' "$SCRATCH_LEDGER" 2>/dev/null; then
    echo "       PASS: record targets T518A with status closed"
else
    echo "       FAIL: SCRATCH ledger record missing target/status"
    FAIL=1
fi

# ── Arm B: show renders the (asserted) annotation from the SCRATCH ledger ──
echo "    B. show renders the (asserted) annotation from the SCRATCH ledger"

SHOW_B=$(cd "$REPO" && MANAGENT_TASK_ID=T518A "$MG" show T518A 2>/dev/null)
echo "       show output (first lines):"
echo "$SHOW_B" | head -3 | sed 's/^/         /'
if echo "$SHOW_B" | grep -q 'asserted:' || echo "$SHOW_B" | grep -q 'assertion:'; then
    echo "       PASS: show rendered the assertion annotation (read from SCRATCH ledger)"
else
    echo "       FAIL: show did not render the assertion — the reader does not honor the store override"
    FAIL=1
fi
if echo "$SHOW_B" | grep -q "${A_ID:-NOMATCH}"; then
    echo "       PASS: show named the assertion id $A_ID"
else
    echo "       FAIL: show did not name assertion id $A_ID"
    FAIL=1
fi

# ── Arm C: assertion_next counter persisted to SCRATCH store, repo untouched ──
echo "    C. assertion_next counter persisted to the SCRATCH store"

COUNTER=$(python3 -c "import json;print(json.load(open('$SCRATCH_STORE'))['_sys']['assertion_next'])" 2>/dev/null || echo "?")
echo "       SCRATCH _sys.assertion_next after one assert: $COUNTER"
if [ "$COUNTER" = "2" ]; then
    echo "       PASS: counter advanced 1 -> 2 in the SCRATCH store"
else
    echo "       FAIL: counter should be 2 in SCRATCH store, got $COUNTER"
    FAIL=1
fi
# A second assert mints A0002 and advances the counter again.
ASSERT_C=$(cd "$REPO" && MANAGENT_TASK_ID=T518A "$MG" assert T518A in_progress --note "second" 2>&1)
A_ID2=$(echo "$ASSERT_C" | grep -oE 'A[0-9]{4}' | head -1)
COUNTER2=$(python3 -c "import json;print(json.load(open('$SCRATCH_STORE'))['_sys']['assertion_next'])" 2>/dev/null || echo "?")
if [ "$A_ID2" = "A0002" ] && [ "$COUNTER2" = "3" ]; then
    echo "       PASS: second assert minted A0002, counter advanced 2 -> 3"
else
    echo "       FAIL: second assert got id=${A_ID2}, counter=${COUNTER2} (expected A0002 / 3)"
    FAIL=1
fi

# ── Arm D: default store (MANAGENT_STORE unset) writes to repo_root ledger ──
echo "    D. default store (MANAGENT_STORE unset) writes to the repo-root ledger"

unset MANAGENT_STORE
seed_repo T518D
: > "$REPO_LEDGER"
# Default-store path is repo_root/docs/infra/managent/tasks.json; the derived
# ledger is repo_root/docs/infra/assertion-ledger/assertions.jsonl.
ASSERT_D=$(cd "$REPO" && MANAGENT_TASK_ID=T518D "$MG" assert T518D closed --note "default-layout" 2>&1)
echo "       assert output: $ASSERT_D"
if [ -s "$REPO_LEDGER" ] && grep -q '"T518D"' "$REPO_LEDGER"; then
    echo "       PASS: default-store assert wrote to repo-root ledger (default layout preserved)"
else
    echo "       FAIL: default-store assert did not write to repo-root ledger"
    FAIL=1
fi
# And the scratch ledger must NOT have grown from the default-store assert.
D_NEW=$(grep -c '"T518D"' "$SCRATCH_LEDGER" 2>/dev/null || true)
D_NEW=${D_NEW:-0}
if [ "$D_NEW" = "0" ]; then
    echo "       PASS: default-store assert did not touch the scratch ledger"
else
    echo "       FAIL: default-store assert leaked $D_NEW record(s) into the scratch ledger"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T518/F9: ALL CHECKS PASS"
else
    echo "  T518/F9: SOME CHECKS FAILED"
fi
exit "$FAIL"