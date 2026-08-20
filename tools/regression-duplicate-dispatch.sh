#!/usr/bin/env bash
# regression-duplicate-dispatch.sh — T390 controls: two consoles sent to one
# row must be refused, and working-without-claiming must be visible.
#
# Background (T390 brief, re-diagnosed 2026-08-06): three duplicates happened
# on 2026-08-05/06 (T376, T389, T350), and in every case the operator noticed,
# not an instrument.  The kanban proves `managent dispatch` is not the
# chokepoint (most rows carry dispatched:null — prompts are pasted directly),
# and a claim-time guard fires too late: consoles do the work first and record
# claim+done together at the end (T388 01:22:10/01:22:10, T380 21:34:36/21:34:36,
# T376 13:28:50/13:28:51).  So the guard surfaces are:
#   • cmdDispatch refuses a second dispatch on one row (names the previous
#     holder + timestamp; --force re-dispatches a dead console loudly);
#   • cmdClaim refuses a second claim on the row itself (names holder +
#     timestamp, no phantom .<attempt> suffix);
#   • cmdDone refuses a close whose claim was recorded within 10s of it — the
#     claim-at-close pattern, proof the row ran with no claim held (--force
#     overrides loudly);
#   • cmdAudit reports a done/dispatchable row whose bundle deliverables= paths
#     are dirty in the tree (the T389 second-console shape / the T367
#     worked-without-claiming shape).
#
# Controls (all synthetic, scratch repo under /tmp/weizigo, MANAGENT_STORE
# points at a scratch kanban — the live kanban is never touched):
#   a  dispatch a fresh row                → succeeds
#   b  dispatch it again                   → refuses, naming the holder
#   c  dispatch it again with --force      → succeeds, loudly
#   d  claim an already-claimed row        → refuses, naming holder + timestamp
#      (and no phantom .<attempt> suffix)
#   e  claim then done immediately         → done refuses claim-at-close
#      done --force                        → closes loudly
#   f  done on a normally-claimed row      → closes without --force
#   g  audit: done row, clean deliverable  → clean
#      audit: same row, deliverable dirtied → reports FIX (exit 1)
#   h  audit: dispatchable row, deliverable not yet created → clean
#      audit: same row, deliverable exists dirty → reports FIX (exit 1)
#   i  live kanban untouched (byte-identity)
#
# Task: T390 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-06

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
WORK="$(mktemp -d /tmp/weizigo/managent-dup-dispatch-XXXXXX)" || { echo "regression-duplicate-dispatch.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t390@test
git config user.name T390
mkdir -p docs/infra/managent untracked src
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

# dispatchable task record (bare "KEY":{...} pair): $1=id
rec_disp() {
    printf '"%s":{"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}

# in_progress task record with an OLD claim (legit claim-before-work): $1=id
rec_oldclaim() {
    printf '"%s":{"status":"in_progress","agent":"deepseek-v4-pro","model":"deepseek-v4-pro","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}

# in_progress task record claimed by another agent (for the claim-refusal
# control): $1=id  $2=claiming agent
rec_claimed() {
    printf '"%s":{"status":"in_progress","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1"
}

# done task record (old claim, old done): $1=id
rec_done() {
    printf '"%s":{"status":"done","agent":"deepseek-v4-pro","model":"deepseek-v4-pro","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:10:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}

# Write a bundle whose deliverables= names $2 and commit $2 (if it exists).
bundle() {  # $1=id  $2=deliverable path
    cat > "untracked/$1-bundle.md" <<EOF
<!--managent set=A deliverables=$2 acceptance=-->
# $1
EOF
}

echo "=== managent duplicate-dispatch regression ==="

# ── control a: dispatch a fresh row succeeds ──────────────────────────────
echo "  a. dispatch on a fresh row succeeds"
seed "$(rec_disp TA)"
OUT=$("$MG" dispatch TA --to deepseek-v4-flash 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'dispatched TA'; then
    echo "    PASS: TA dispatched"
else
    echo "    FAIL: fresh dispatch did not succeed: $OUT"
    FAIL=1
fi

# ── control b: dispatch it again refuses, naming the holder ───────────────
echo "  b. second dispatch refuses, naming the holder"
OUT=$("$MG" dispatch TA --to deepseek-v4-flash 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'REJECTED: TA was already dispatched' \
   && echo "$OUT" | grep -q 'to deepseek-v4-flash'; then
    echo "    PASS: TA second dispatch refused"
else
    echo "    FAIL: second dispatch was not refused: $OUT"
    FAIL=1
fi

# ── control c: --force re-dispatch succeeds, loudly ───────────────────────
echo "  c. --force re-dispatch succeeds loudly"
OUT=$("$MG" dispatch TA --to deepseek-v4-flash --force 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'FORCED: TA was already dispatched'; then
    echo "    PASS: TA forced re-dispatch"
else
    echo "    FAIL: forced re-dispatch did not succeed loudly: $OUT"
    FAIL=1
fi

# ── control d: claim an already-claimed row refuses, naming holder+ts ─────
echo "  d. claim on an already-claimed row refuses (holder + timestamp, no phantom suffix)"
seed "$(rec_claimed TB deepseek-v4-pro)"
OUT=$("$MG" claim TB --agent deepseek-v4-flash 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'ALREADY CLAIMED: TB' \
   && echo "$OUT" | grep -q 'by deepseek-v4-pro/TB' \
   && echo "$OUT" | grep -q 'since 2026-08-01T00:00:01Z' \
   && ! echo "$OUT" | grep -q 'TB\.2'; then
    echo "    PASS: TB claim refused, holder/timestamp named, no phantom suffix"
else
    echo "    FAIL: claim-refusal message wrong: $OUT"
    FAIL=1
fi

# ── control e: claim then done immediately → refused; --force closes ──────
echo "  e. claim-then-done within seconds refuses; --force closes"
seed "$(rec_disp TC)"
bundle TC src/tc_demo.txt
echo "tc demo" > src/tc_demo.txt
git add src/tc_demo.txt untracked/TC-bundle.md
git commit -q -m "seed TC deliverables"
OUT=$("$MG" claim TC --agent deepseek-v4-flash 2>&1); RC=$?
if [ "$RC" -ne 0 ] || ! echo "$OUT" | grep -q 'claimed TC'; then
    echo "    FAIL: TC claim failed: $OUT"
    FAIL=1
fi
OUT=$("$MG" done TC 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'REJECTED: TC was claimed [0-9]\+s before this done'; then
    echo "    PASS: TC done refused for claim-at-close"
else
    echo "    FAIL: claim-at-close done was not refused: $OUT"
    FAIL=1
fi
OUT=$("$MG" done TC --force 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'FORCED: TC was claimed only' \
   && "$MG" show TC 2>/dev/null | grep -q '  TC  done'; then
    echo "    PASS: TC --force closed loudly"
else
    echo "    FAIL: TC --force did not close: $OUT"
    FAIL=1
fi

# ── control f: normally-claimed row closes without --force ────────────────
echo "  f. done on a normally-claimed row closes without --force"
seed "$(rec_oldclaim TD)"
bundle TD src/td_demo.txt
echo "td demo" > src/td_demo.txt
git add src/td_demo.txt untracked/TD-bundle.md
git commit -q -m "seed TD deliverables"
OUT=$("$MG" done TD 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q 'verdict: pass' \
   && ! echo "$OUT" | grep -q 'REJECTED'; then
    echo "    PASS: TD closed normally (old claim)"
else
    echo "    FAIL: normally-claimed done misbehaved: $OUT"
    FAIL=1
fi

# ── control g: audit — done row, clean deliverable silent; dirty → FIX ────
echo "  g. audit: done row with clean deliverable is silent"
seed "$(rec_done TE)"
bundle TE src/te_demo.txt
echo "te demo" > src/te_demo.txt
git add src/te_demo.txt untracked/TE-bundle.md
git commit -q -m "seed TE deliverables"
OUT=$("$MG" audit 2>&1); RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q '\[FIX\]'; then
    echo "    PASS: clean done deliverable → audit has no FIX findings"
else
    echo "    FAIL: audit not clean on clean done row: $OUT"
    FAIL=1
fi
echo "  g2. audit: same row with deliverable dirtied reports FIX"
echo "dirty" >> src/te_demo.txt
OUT=$("$MG" audit 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'FIX' \
   && echo "$OUT" | grep -q "TE: done but deliverable 'src/te_demo.txt' is dirty"; then
    echo "    PASS: dirty done deliverable reported"
else
    echo "    FAIL: dirty done deliverable not reported: $OUT"
    FAIL=1
fi

# ── control h: audit — dispatchable row, not-yet-created deliverable silent
#    (negative control so unstarted rows are not flagged); existing dirty → FIX
echo "  h. audit: dispatchable row with not-yet-created deliverable is silent"
seed "$(rec_disp TF)"
bundle TF src/tf_demo.txt
OUT=$("$MG" audit 2>&1); RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'audit: clean'; then
    echo "    PASS: not-yet-created deliverable not flagged"
else
    echo "    FAIL: unstarted dispatchable row flagged: $OUT"
    FAIL=1
fi
echo "  h2. audit: dispatchable row with existing dirty deliverable reports FIX"
echo "tf work" > src/tf_demo.txt
OUT=$("$MG" audit 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q 'FIX' \
   && echo "$OUT" | grep -q "TF: dispatchable but deliverable 'src/tf_demo.txt' is dirty"; then
    echo "    PASS: dirty dispatchable deliverable reported"
else
    echo "    FAIL: dirty dispatchable deliverable not reported: $OUT"
    FAIL=1
fi

# ── byte-identity guard ────────────────────────────────────────────────────
echo "  i. live kanban untouched"
LIVE_HASH_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_HASH" = "$LIVE_HASH_AFTER" ]; then
    echo "    PASS: live kanban byte-identical"
else
    echo "    FAIL: live kanban was MUTATED by the regression!"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== managent duplicate-dispatch: ALL CONTROLS PASSED ==="
else
    echo "=== managent duplicate-dispatch: $FAIL FAILURE(S) ==="
fi
exit "$FAIL"
