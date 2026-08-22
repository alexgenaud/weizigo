#!/usr/bin/env bash
# regression-orient.sh — T353 controls for `managent orient`
#
# `managent orient` replaces the ~1,524-line worker reading list with a
# generated, ≤150-line preamble composed at read time (principles → gates →
# kanban → fresh activity → handover head → what it does NOT replace). It
# follows the `resume` pattern: nothing is stored, nothing can rot. Controls:
#
#   null control        empty kanban + clean tree → exit 0, output ≤150 lines,
#                       and the stated line count equals `wc -l` of the output
#   seeded-floor        perturb one floor value → orient shows the NEW number,
#                       not a stored copy (it reads tools/hooks/claimlint-floor.json
#                       live at invocation)
#   seeded-row          register a temp row → it appears under dispatchable;
#                       close it (done) → it leaves the live sections
#   degradation         unbuildable sources (claimlint, hook) degrade to
#                       explicit "unavailable"/"NOT INSTALLED" markers, never
#                       fabricated numbers
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and live
# repo are never touched. MANAGENT_STORE points at a scratch kanban and the
# command is invoked from the scratch repo, so findRepoRoot resolves there.
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent → bin/managent. SKIP
# (loudly) when none carries the orient command — same convention as
# regression-managent-resume.sh.
#
# Task: T353 · Role: worker · Model: glm-5.2 · Date: 2026-08-20

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
if ! "$MG" help 2>&1 | grep -q "managent orient"; then
    echo "SKIP: $MG does not carry the orient command — rebuild from src/managent/main.zig"
    exit 0
fi

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — cd "" succeeds silently and once sent a suite's arms into the LIVE
# repo (2026-08-18 incident). Never rely on an empty scratch var.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-orient-XXXXXX)" || { echo "regression-orient.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t353@test
git config user.name T353
echo base > README.md
mkdir -p docs untracked docs/infra/managent tools/hooks
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Seed an empty kanban store (the binary refuses to read a missing store; an
# empty-but-valid store is the null-control substrate).
cat > "$STORE" <<'JSONEOF'
{
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF

# Seed a synthetic claimlint floor so the seeded-floor control can perturb it.
# orient reads this file live; the numbers below are not the live repo's.
cat > "$WORK/tools/hooks/claimlint-floor.json" <<'JSONEOF'
{
  "version": 1,
  "commit": "scratch",
  "floor": {"C1a": 0, "C1b": 0, "C2": 11, "C6": 0, "C7-nonconforming": 0, "calibration": "PASS", "C9": 0}
}
JSONEOF

echo "=== managent orient regression ==="

# ── null control: empty kanban + clean tree, exit 0, ≤150 lines ──────────
echo "  1. null control: empty kanban + clean tree → exit 0, ≤150 lines"
OUT=$("$MG" orient 2>/dev/null)
RC=$?
LINES=$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')
STATED=$(printf '%s\n' "$OUT" | grep -E '[0-9]+ lines$' | tail -1 | grep -oE '^[0-9]+')
if [ "$RC" -eq 0 ] && [ "$LINES" -le 150 ] && [ "$STATED" = "$LINES" ]; then
    echo "    PASS: RC=0, ${LINES} lines (≤150), stated count matches wc -l"
else
    echo "    FAIL: RC=$RC, lines=$LINES, stated=$STATED"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── degradation: unbuildable sources degrade, not lie ────────────────────
echo "  2. degradation control: unavailable sources are named, not fabricated"
if echo "$OUT" | grep -q "claimlint: unavailable" && \
   echo "$OUT" | grep -q "pre-commit hook: NOT INSTALLED"; then
    echo "    PASS: claimlint/hook degrade to explicit markers"
else
    echo "    FAIL: output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── seeded-floor: perturb one floor value, orient shows the new number ───
echo "  3. seeded-floor control: perturb C2 floor, orient reads it live"
OUT_A=$("$MG" orient 2>/dev/null)
if echo "$OUT_A" | grep -q "floor: C1a=0 C1b=0 C2=11 C6=0"; then
    : # baseline floor present
else
    echo "    FAIL: baseline floor C2=11 not shown:"
    echo "$OUT_A" | grep '^floor:' | sed 's/^/      /'
    FAIL=1
fi
# Perturb: C2 11 -> 7 (a floor that moves moves DOWN; orient must show 7).
cat > "$WORK/tools/hooks/claimlint-floor.json" <<'JSONEOF'
{
  "version": 1,
  "commit": "scratch",
  "floor": {"C1a": 0, "C1b": 0, "C2": 7, "C6": 0, "C7-nonconforming": 0, "calibration": "PASS", "C9": 0}
}
JSONEOF
OUT_B=$("$MG" orient 2>/dev/null)
if echo "$OUT_B" | grep -q "floor: C1a=0 C1b=0 C2=7 C6=0" && \
   ! echo "$OUT_B" | grep -q "floor: C1a=0 C1b=0 C2=11 C6=0"; then
    echo "    PASS: perturbed floor C2=7 shown, old C2=11 gone — reads live state"
else
    echo "    FAIL: perturbed floor not reflected:"
    echo "$OUT_B" | grep '^floor:' | sed 's/^/      /'
    FAIL=1
fi
# Restore the floor for the remaining controls.
cat > "$WORK/tools/hooks/claimlint-floor.json" <<'JSONEOF'
{
  "version": 1,
  "commit": "scratch",
  "floor": {"C1a": 0, "C1b": 0, "C2": 11, "C6": 0, "C7-nonconforming": 0, "calibration": "PASS", "C9": 0}
}
JSONEOF

# ── seeded-row: register a temp row, it appears; close it, it moves ──────
echo "  4. seeded-row control: a temp row appears under dispatchable, then leaves when closed"
# T485: `managent done` below runs the absorption done-gate, which needs a
# claimlint binary + parseable register in the scratch repo. Provision it
# ONLY now — the degradation control (arm 2) asserts claimlint is UNAVAILABLE
# in the scratch repo, so it must stay absent until after that arm has run.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build') — the done-gate needs it"
    exit 0
fi
mkdir -p bin docs/epistemic
cp "$GATE_CL" bin/weizigo-claimlint
cat > docs/epistemic/CLAIMS.md <<'CLAIMS_EOF'
# scratch register — done-gate control (T485)

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF
mkdir -p "$WORK/untracked"
cat > "$WORK/untracked/T353SEED-bundle.md" <<'MDEOF'
<!--managent set=C-->
# T353SEED — synthetic orient control row
MDEOF
"$MG" add T353SEED --bundle untracked/T353SEED-bundle.md >/dev/null 2>&1
OUT_C=$("$MG" orient 2>/dev/null)
if echo "$OUT_C" | grep -q "T353SEED" && echo "$OUT_C" | grep -q "dispatchable (1)"; then
    : # row present under dispatchable
else
    echo "    FAIL: T353SEED not shown under dispatchable (1):"
    echo "$OUT_C" | grep -A2 'dispatchable' | sed 's/^/      /'
    FAIL=1
fi
# Close it: claim then done. done needs the row in_progress; claim moves it.
"$MG" claim T353SEED --agent glm-5.2 >/dev/null 2>&1
"$MG" done T353SEED --agent glm-5.2 --status pass --note "synthetic orient control" --impression "orient control" --force >/dev/null 2>&1
OUT_D=$("$MG" orient 2>/dev/null)
# After done, the row must NOT appear in any live section (in_progress /
# dispatchable / blocked) — done rows are not live.
if echo "$OUT_D" | grep -q "T353SEED"; then
    echo "    FAIL: T353SEED still appears in the live surface after done:"
    echo "$OUT_D" | grep 'T353SEED' | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: T353SEED appeared when dispatchable, left the live surface when done"
fi

# ── structure control: all five sections present, in order ───────────────
echo "  5. structure control: principles → gates → kanban → fresh activity → handover head"
OUT_E=$("$MG" orient 2>/dev/null)
P=$(echo "$OUT_E" | grep -n '^## principles' | head -1 | cut -d: -f1)
G=$(echo "$OUT_E" | grep -n '^## gates' | head -1 | cut -d: -f1)
K=$(echo "$OUT_E" | grep -n '^## kanban' | head -1 | cut -d: -f1)
F=$(echo "$OUT_E" | grep -n '^## fresh activity' | head -1 | cut -d: -f1)
H=$(echo "$OUT_E" | grep -n '^## handover head' | head -1 | cut -d: -f1)
N=$(echo "$OUT_E" | grep -n '^## what this does NOT replace' | head -1 | cut -d: -f1)
if [ -n "$P" ] && [ -n "$G" ] && [ -n "$K" ] && [ -n "$F" ] && [ -n "$H" ] && [ -n "$N" ] && \
   [ "$P" -lt "$G" ] && [ "$G" -lt "$K" ] && [ "$K" -lt "$F" ] && [ "$F" -lt "$H" ] && [ "$H" -lt "$N" ]; then
    echo "    PASS: all six sections present and ordered (principles → gates → kanban → fresh activity → handover head → not-replace)"
else
    echo "    FAIL: section order wrong (principles=$P gates=$G kanban=$K fresh=$F handover=$H not-replace=$N)"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-orient: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-orient: FAILURES ==="
    exit 1
fi