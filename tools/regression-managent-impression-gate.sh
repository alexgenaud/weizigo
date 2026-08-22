#!/usr/bin/env bash
# regression-managent-impression-gate.sh
# T522 regression: `managent done` demands a model impression or an explicit
# waiver at every close (impression-or-waiver, G6 / measurement-methodology §6).
#
# Seeded arms must be RED against a binary that predates the gate (the old
# `managent done` closes the row silently with no impression), then GREEN once
# the gate lands.  Null arms prove the two accepted forms record the field and
# close the row.
#
# Usage:  tools/regression-managent-impression-gate.sh [--build]
#   --build: rebuild managent from source before testing

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# T268: the deployed copy must BE what we built (same stamp discipline as
# regression-managent-integrity.sh).  Binaries older than the gate close rows
# silently — measuring that would be a stale-binary seam, not a gate result.
stamp_of() {
    "$1" --version 2>&1 | grep -oE '[a-z][a-z0-9-]* [0-9a-f]{7}(-dirty)? built' | head -1 | sed 's/ built$//' || true
}
BUILT_STAMP=$(stamp_of "$PROJECT/zig-out/bin/managent")
DEPLOYED_STAMP=$(stamp_of "$MG")
if [ -z "$DEPLOYED_STAMP" ]; then
    echo "    FAIL: bin/managent missing or unstamped — run 'zig build deploy-managent'"
    FAIL=1
elif [ "$BUILT_STAMP" != "$DEPLOYED_STAMP" ]; then
    echo "    FAIL: deployed bin/$DEPLOYED_STAMP != built zig-out/$BUILT_STAMP — bin/ is stale"
    FAIL=1
else
    echo "  T268: deployed $DEPLOYED_STAMP == built $BUILT_STAMP"
fi

# The done path runs the absorption gate (T485), which needs a claimlint
# binary + a parseable register.  Missing binary → SKIP (same convention as
# the absorption-machinery regression), never a live-store write.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build') — the done-gate needs it"
    exit 0
fi

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/impression-gate-XXXXXX)" || { echo "FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

setup() {  # $1 = scratch dir
    local D="$1"
    mkdir -p "$D/docs/infra/managent" "$D/docs/epistemic" "$D/findings" "$D/bin" "$D/untracked"
    cd "$D"
    git init -q
    git config user.email t522@test
    git config user.name T522
    cp "$GATE_CL" bin/
    cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — T522 impression-gate control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
MDEOF
}

seed_task() {  # $1 = store path, $2 = task id
    printf '{"%s":{"status":"in_progress","agent":"deepseek-v4-pro","model":"deepseek-v4-pro","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},"_sys":{"next_id":9700,"directive_next":1}}\n' "$2" "$2" > "$1"
}

store_status() {  # $1 = store path, $2 = task id  → prints the status field
    python3 -c "import json,sys;print(json.load(open('$1'))['$2']['status'])"
}
store_field() {  # $1 = store path, $2 = task id, $3 = field → prints repr
    python3 -c "import json,sys;print(repr(json.load(open('$1'))['$2'].get('$3')))"
}

# ── S1. seeded: no impression and no waiver → refused, store unmutated ─────
echo "  S1. seeded: neither impression nor waiver → refused"
setup "$WORK/S1"
STORE="$WORK/S1/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMPR1
echo "# bundle" > "$WORK/S1/untracked/TIMPR1-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMPR1 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMPR1)
if [ "$RC" -ne 0 ] && \
   echo "$OUT" | grep -q "REJECTED: TIMPR1" && \
   echo "$OUT" | grep -q -- "--impression" && \
   echo "$OUT" | grep -q -- "--impression-waiver" && \
   [ "$STATUS" = "in_progress" ]; then
    echo "    PASS: refused, names both flags, store unmutated"
else
    echo "    FAIL: RC=$RC status=$STATUS, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── S2. seeded: both impression and waiver → refused (ambiguous) ───────────
echo "  S2. seeded: impression AND waiver together → refused"
setup "$WORK/S2"
STORE="$WORK/S2/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMPR2
echo "# bundle" > "$WORK/S2/untracked/TIMPR2-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMPR2 --impression "x" --impression-waiver "y" 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMPR2)
if [ "$RC" -ne 0 ] && \
   echo "$OUT" | grep -q "REJECTED: TIMPR2" && \
   echo "$OUT" | grep -q "not both" && \
   [ "$STATUS" = "in_progress" ]; then
    echo "    PASS: refused, both-present is ambiguous, store unmutated"
else
    echo "    FAIL: RC=$RC status=$STATUS, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── S3. seeded: empty impression is not an impression → refused ────────────
echo "  S3. seeded: empty --impression \"\" → refused (a waiver is the N/A form)"
setup "$WORK/S3"
STORE="$WORK/S3/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMPR3
echo "# bundle" > "$WORK/S3/untracked/TIMPR3-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMPR3 --impression "" 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMPR3)
if [ "$RC" -ne 0 ] && \
   echo "$OUT" | grep -q "REJECTED: TIMPR3" && \
   [ "$STATUS" = "in_progress" ]; then
    echo "    PASS: refused, empty impression is not a record, store unmutated"
else
    echo "    FAIL: RC=$RC status=$STATUS, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── N1. null: --impression closes and records the field ────────────────────
echo "  N1. null: --impression closes, field recorded"
setup "$WORK/N1"
STORE="$WORK/N1/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMP
echo "# bundle" > "$WORK/N1/untracked/TIMP-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMP --impression "clean spec pass, citations verified" 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMP)
IMPR=$(store_field "$STORE" TIMP impression)
WAIV=$(store_field "$STORE" TIMP impression_waiver)
if [ "$RC" -eq 0 ] && [ "$STATUS" = "done" ] && [ "$IMPR" = "'clean spec pass, citations verified'" ] && [ "$WAIV" = "None" ]; then
    echo "    PASS: impression recorded, waiver left null"
else
    echo "    FAIL: RC=$RC status=$STATUS impression=$IMPR waiver=$WAIV, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── N2. null: --impression-waiver closes and records the reason ────────────
echo "  N2. null: --impression-waiver closes, reason recorded"
setup "$WORK/N2"
STORE="$WORK/N2/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMPW
echo "# bundle" > "$WORK/N2/untracked/TIMPW-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMPW --impression-waiver "no model ran — operator close" 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMPW)
IMPR=$(store_field "$STORE" TIMPW impression)
WAIV=$(store_field "$STORE" TIMPW impression_waiver)
if [ "$RC" -eq 0 ] && [ "$STATUS" = "done" ] && [ "$IMPR" = "None" ] && [ "$WAIV" = "'no model ran — operator close'" ]; then
    echo "    PASS: waiver recorded, impression left null"
else
    echo "    FAIL: RC=$RC status=$STATUS impression=$IMPR waiver=$WAIV, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── N3. null: blocked close is gated too (a stall is a model datum) ────────
echo "  N3. null: blocked close with a waiver → passes (the gate is per-close)"
setup "$WORK/N3"
STORE="$WORK/N3/docs/infra/managent/tasks.json"
seed_task "$STORE" TIMPB
echo "# bundle" > "$WORK/N3/untracked/TIMPB-bundle.md"
OUT=$(MANAGENT_STORE="$STORE" "$MG" done TIMPB --status blocked --note "N3 control" --impression-waiver "wall-killed before work landed" 2>&1); RC=$?
STATUS=$(store_status "$STORE" TIMPB)
WAIV=$(store_field "$STORE" TIMPB impression_waiver)
if [ "$RC" -eq 0 ] && [ "$STATUS" = "done" ] && [ "$WAIV" = "'wall-killed before work landed'" ]; then
    echo "    PASS: blocked close records the waiver and closes"
else
    echo "    FAIL: RC=$RC status=$STATUS waiver=$WAIV, output:"; echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-impression-gate: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-impression-gate: FAILURES ==="
    exit 1
fi
