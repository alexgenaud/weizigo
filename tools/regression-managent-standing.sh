#!/usr/bin/env bash
# regression-managent-standing.sh — T294 controls for `managent standing`'s
# STANDING-ABSORB trigger
#
# Before T294 the standing mechanism had NO controls at all: the four
# pre-existing triggers ran in production with nothing proving they fire when
# they should or stay silent when they should. STANDING-ABSORB (the C7
# unabsorbed-findings trigger) ships with the pair the brief demands:
#
#   null control     C7 at/below the threshold (here: empty findings/ → C7=0)
#                    → the trigger does NOT fire, and `managent standing` SAYS
#                    so ("at/below threshold, no trigger") rather than silence
#   seeded control   a synthetic unabsorbed finding pushes C7 over (6 claims
#                    not in the register → C7=6 > threshold 5) → the trigger
#                    FIRES, names the count, and registers STANDING-ABSORB as
#                    a dispatchable kanban task
#
# The count is exercised against claimlint's OWN summary (the same binary and
# the same parse the real command uses) — the control never reimplements the
# count, it asserts the trigger reacts to it.
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban, live
# findings/, and live CLAIMS.md are never touched. MANAGENT_STORE points at a
# scratch kanban and the command is invoked from the scratch repo, so
# findRepoRoot resolves there. bin/weizigo-claimlint is copied in so
# `managent standing`'s internal claimlint run works against the scratch
# findings/ and register.
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent (built, not yet
# deployed — same convention as regression-managent-resume.sh) → bin/managent.
# SKIP (loudly) when no binary carries the standing command, or when the real
# repo's bin/weizigo-claimlint is absent (the control cannot run without it) —
# a fresh clone without a build cannot run the control.
#
# Task: T294 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# ── binary resolution ─────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy (zig build deploy-managent)"
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

WORK="$(mktemp -d /tmp/weizigo/managent-standing-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t294@test
git config user.name T294
mkdir -p docs/infra/managent docs/infra/dispatch docs/epistemic findings untracked/msg bin

# claimlint must run against the scratch repo's own findings/ and register
cp "$PROJECT/bin/weizigo-claimlint" bin/

# Minimal register — 2 rows so claimlint's parse/index paths have content;
# none of the seeded claim IDs below exists in it, so every seeded claim is
# unabsorbed ("NO SUCH ID"). Evidence file present so C2/C3 stay quiet.
cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — T294 standing control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.SCRATCH1` | S1 | all | scratch row one | PROVEN | `scratch.md:1` | — | — | 0 | ? |
| `GLOBAL.SCRATCH2` | S2 | all | scratch row two | PROVEN | `scratch.md:2` | — | — | 0 | ? |
MDEOF
echo "scratch evidence" > scratch.md

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

git add -A
git commit -qm base

echo "=== managent standing regression (STANDING-ABSORB) ==="

# ── null control: C7 at/below threshold → no trigger, and it says so ────────
echo "  1. null control: empty findings/ → C7=0 ≤ threshold 5, no trigger, stated"
OUT=$("$MG" standing 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && \
   echo "$OUT" | grep -q "C7 unabsorbed: 0 (threshold 5)" && \
   echo "$OUT" | grep -q "at/below threshold, no trigger" && \
   ! echo "$OUT" | grep -q "TRIGGERED — absorption backlog" && \
   ! echo "$OUT" | grep -q "registered STANDING-ABSORB"; then
    echo "    PASS: count 0, explicit at/below-threshold statement, no registration, RC=0"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── null control 2: nothing may be registered in the scratch kanban ─────────
echo "  2. null control: STANDING-ABSORB not registered in the kanban"
if [ -f "$STORE" ] && grep -q "STANDING-ABSORB" "$STORE"; then
    echo "    FAIL: null control registered STANDING-ABSORB anyway:"
    grep -o "STANDING-ABSORB[^,}]*" "$STORE" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: kanban untouched by a below-threshold C7"
fi

# ── seeded control: 6 unabsorbed claims → C7=6 > 5, trigger fires, names it ─
echo "  3. seeded control: synthetic unabsorbed finding pushes C7 over the threshold"
cat > findings/T294SEED-absorb.json <<'JSONEOF'
{
  "task_id": "T294SEED",
  "date": "2026-08-03",
  "model": "deepseek-v4-flash",
  "claims": [
    "GLOBAL.SEED-ABSORB-1",
    "GLOBAL.SEED-ABSORB-2",
    "GLOBAL.SEED-ABSORB-3",
    "GLOBAL.SEED-ABSORB-4",
    "GLOBAL.SEED-ABSORB-5",
    "GLOBAL.SEED-ABSORB-6"
  ]
}
JSONEOF
OUT=$("$MG" standing 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && \
   echo "$OUT" | grep -q "C7 unabsorbed: 6 (threshold 5)" && \
   echo "$OUT" | grep -q "TRIGGERED — absorption backlog above threshold" && \
   echo "$OUT" | grep -q "registered STANDING-ABSORB" && \
   echo "$OUT" | grep -q "T294SEED-absorb.json: 6"; then
    echo "    PASS: count named (6), trigger fired, task registered, per-file composition surfaced"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── seeded control 2: the kanban actually carries the dispatchable task ─────
echo "  4. seeded control: STANDING-ABSORB is a registered dispatchable task"
if [ -f "$STORE" ] && grep -q '"STANDING-ABSORB"' "$STORE"; then
    echo "    PASS: STANDING-ABSORB present in the scratch kanban"
else
    echo "    FAIL: trigger said registered but the kanban does not carry it:"
    [ -f "$STORE" ] && sed 's/^/      /' "$STORE" || echo "      (no store file)"
    FAIL=1
fi

# ── seeded control 3: the auto-registered brief exists in the scratch repo ──
echo "  5. seeded control: brief file created next to the other standing briefs"
if [ -f "docs/infra/dispatch/STANDING-ABSORB.md" ]; then
    echo "    PASS: docs/infra/dispatch/STANDING-ABSORB.md created"
else
    echo "    FAIL: brief file missing"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-standing: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-standing: FAILURES ==="
    exit 1
fi
