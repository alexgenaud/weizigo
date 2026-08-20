#!/usr/bin/env bash
# regression-managent-done-two-phase.sh — T350 controls for cmdDone's two-phase
# lock: the exclusive flock covers the store mutation (phase 1: validate →
# attribute → git deliverable check → write status done + verdict) but never
# the acceptance command's runtime (phase 2, up to 60s — holding the flock
# that long would block every other store operation).  On acceptance failure
# phase 2 re-acquires the flock, re-reads the store and reverts the done write
# to in_progress; dependents left dispatchable only by the reverted completion
# are re-blocked.
#
# Controls (all synthetic, scratch repo under /tmp/weizigo, MANAGENT_STORE
# points at a scratch kanban — the live kanban is never touched):
#   a  acceptance=true  → task stays done, verdict pass
#   b  acceptance=false → task returns to in_progress with ACCEPTANCE FAILED,
#      done/verdict cleared, dependent DEP re-blocked
#   c  acceptance command that itself mutates the store (a nested
#      `managent purge`) → the purge succeeding WHILE the parent runs phase 2
#      proves the flock is not held during acceptance; the task then vanishes
#      and the revert guard fires (WARNING, no clobber, exit non-zero)
#   e  --skip-acceptance <reason> → closes, reason recorded, no phase 2
#   f  --skip-acceptance "" with acceptance declared → REJECTED before the
#      phase-1 write; store unmutated (still in_progress, no done)
#
# Task: T350 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-06

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-done-two-phase-XXXXXX)" || { echo "regression-managent-done-two-phase.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t350@test
git config user.name T350
mkdir -p docs/infra/managent untracked
# T485: the absorption done-gate runs claimlint on every gated close; the
# scratch repo must carry a claimlint binary + a parseable (empty) register.
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
STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Byte-identity guard: the live kanban must not be mutated
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"
LIVE_HASH=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
}

# One in_progress task record (bare "KEY":{...} pair): $1=id  $2=acceptance command
rec() {
    printf '"%s":{"status":"in_progress","agent":"deepseek-v4-pro","model":"deepseek-v4-pro","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":"%s","skip_acceptance_reason":null,"claim_count":1}' "$1" "$1" "$2"
}

# A blocked dependent of $2 (bare "KEY":{...} pair): $1=dep id  $2=parent id
dep_rec() {
    printf '"%s":{"status":"blocked","agent":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":["%s"],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1" "$2"
}

echo "=== managent done two-phase lock regression ==="

# ── control a: acceptance passes → task stays done ─────────────────────────
echo "  a. acceptance=true keeps the task done (verdict pass)"
seed "$(rec TA true)"
OUT=$("$MG" done TA 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'verdict: pass' \
   && "$MG" show TA 2>/dev/null | grep -q '  TA  done' \
   && "$MG" show TA 2>/dev/null | grep -q 'verdict:'; then
    echo "    PASS: TA closed, verdict pass"
else
    echo "    FAIL: acceptance=true did not close the task: $OUT"
    FAIL=1
fi

# ── control b: acceptance fails → revert + re-block dependents ─────────────
echo "  b. acceptance=false reverts to in_progress and re-blocks dependents"
seed "$(rec TB false), $(dep_rec DEP TB)"
OUT=$("$MG" done TB 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'ACCEPTANCE FAILED: TB exited with code 1' \
   && echo "$OUT" | grep -q 'reverted TB to in_progress (acceptance failed)' \
   && echo "$OUT" | grep -q 're-blocked: DEP' \
   && "$MG" show TB 2>/dev/null | grep -q '  TB  in_progress' \
   && ! "$MG" show TB 2>/dev/null | grep -q 'verdict:'; then
    echo "    PASS: TB reverted to in_progress, DEP re-blocked"
else
    echo "    FAIL: acceptance=false did not revert the done write: $OUT"
    FAIL=1
fi

# ── control c: acceptance mutates the store; revert guard on vanished task ──
echo "  c. acceptance runs unlocked (nested purge succeeds); vanish guard fires"
ACC="$(printf '%s purge TC && exit 1' "$MG")"
seed "$(rec TC "$ACC")"
OUT=$("$MG" done TC 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'purged 1 task(s): TC' \
   && echo "$OUT" | grep -q 'ACCEPTANCE FAILED: TC exited with code 1' \
   && echo "$OUT" | grep -q 'WARNING: could not revert TC'; then
    echo "    PASS: lock released during phase 2 (purge succeeded), guard on vanished task"
else
    echo "    FAIL: nested-store-write or vanish guard misbehaved: $OUT"
    FAIL=1
fi

# ── control e: --skip-acceptance closes, reason recorded, no phase 2 ───────
echo "  e. --skip-acceptance closes the task and records the reason"
seed "$(rec TE false)"
OUT=$("$MG" done TE --skip-acceptance "regression control skips" 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'ACCEPTANCE SKIPPED: TE' \
   && echo "$OUT" | grep -q 'verdict: pass' \
   && "$MG" show TE 2>/dev/null | grep -q 'skip_acceptance_reason: regression control skips'; then
    echo "    PASS: TE closed with recorded reason"
else
    echo "    FAIL: --skip-acceptance did not close the task: $OUT"
    FAIL=1
fi

# ── control f: empty --skip-acceptance reason rejected BEFORE the write ────
echo "  f. empty --skip-acceptance reason rejected, store unmutated"
seed "$(rec TF false)"
OUT=$("$MG" done TF --skip-acceptance "" 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'REJECTED: TF --skip-acceptance requires a non-empty reason' \
   && "$MG" show TF 2>/dev/null | grep -q '  TF  in_progress' \
   && ! "$MG" show TF 2>/dev/null | grep -q 'verdict:'; then
    echo "    PASS: TF rejected pre-write, still in_progress"
else
    echo "    FAIL: empty skip reason was not rejected pre-write: $OUT"
    FAIL=1
fi

# ── byte-identity guard ────────────────────────────────────────────────────
echo "  g. live kanban untouched"
LIVE_HASH_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_HASH" = "$LIVE_HASH_AFTER" ]; then
    echo "    PASS: live kanban byte-identical"
else
    echo "    FAIL: live kanban was MUTATED by the regression!"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== managent done two-phase: ALL CONTROLS PASSED ==="
else
    echo "=== managent done two-phase: $FAIL FAILURE(S) ==="
fi
exit "$FAIL"
