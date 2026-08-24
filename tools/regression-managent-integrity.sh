#!/usr/bin/env bash
# regression-managent-integrity.sh
# T204 regression test: managent suggest collision-safety + audit detection
#
# Seeds a temp store with next_id ≤ an existing T-ID, runs suggest, asserts
# the existing record and bundle survive, and asserts audit flags the collision.
# Must be RED against current bin/managent before the fix lands.
#
# Usage:  tools/regression-managent-integrity.sh [--build]
#   --build: rebuild managent from source before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    # Guarded build (tools/runner) + remove-copy-sign deploy (tools/deploy.sh).
    # A bare `cp` over a live signed binary SIGKILLs it on Apple Silicon (T268).
    # --no-prepend-zig: keep ReleaseSafe (correctness convention); the runner
    # would otherwise auto-add ReleaseFast and duplicate the -Doptimize flag.
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# Deploy freshness is a suite preflight (tools/smoke.sh), not a per-check
# assertion — T872 green-up deleted the re-implemented arm (see the sibling
# managent regressions).

# ── Setup: temp store in /tmp/weizigo (disposable; the `ephemeral`
#    indirection was retired 2026-08-03, T286) ────────────────────────────
# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
TMPDIR="$(mktemp -d /tmp/weizigo/managent-integrity-XXXXXX)" || { echo "regression-managent-integrity.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$TMPDIR"' EXIT

# Create minimal repo structure the binary expects
mkdir -p "$TMPDIR/docs/infra/managent"
mkdir -p "$TMPDIR/untracked"
# T295: a real git repo (git init) not touch .git — gitOk needs a
# valid .git directory. The old binary worked around the missing PATH
# (empty environ) by failing to find git, which treated the repo as
# "unavailable" and skipped the deliveable check. With the environ fix
# git IS on PATH and a file at .git correctly fails the guard.
git init "$TMPDIR" 2>/dev/null
git -C "$TMPDIR" config user.email "test@test" 2>/dev/null
git -C "$TMPDIR" config user.name "test" 2>/dev/null

# T485: the absorption done-gate runs claimlint on every gated close; the
# scratch repo must carry a claimlint binary + a parseable (empty) register.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build') — the done-gate needs it"
    exit 0
fi
mkdir -p "$TMPDIR/bin" "$TMPDIR/docs/epistemic"
cp "$GATE_CL" "$TMPDIR/bin/weizigo-claimlint"
cat > "$TMPDIR/docs/epistemic/CLAIMS.md" <<'CLAIMS_EOF'
# scratch register — done-gate control (T485)

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF

# Seed an existing task T105 with next_id=105 (next_id ≤ max T-ID → collision)
# When suggest runs, it will read next_id=105 and mint T105, clobbering this one.
EXISTING_BUNDLE="untracked/T105-important-experiment.md"
echo "# T105 — important experiment" > "$TMPDIR/$EXISTING_BUNDLE"

# Record the bundle content hash for survival check
BUNDLE_HASH_BEFORE="$(sha256sum "$TMPDIR/$EXISTING_BUNDLE" | cut -d' ' -f1)"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T105": {
    "status": "dispatchable",
    "agent": null,
    "bundle": "untracked/T105-important-experiment.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-01T00:00:00Z",
    "claimed": null,
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "claim_count": 0
  },
  "_sys": {
    "next_id": 105,
    "directive_next": 1
  }
}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write

echo ""
echo "  T204 regression: managent integrity"

# ── Check 1: suggest does not destroy existing task record ───────────────────
echo "        1. suggest preserves existing task record"

ORIG_TASK_COUNT=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
echo "           tasks before suggest: $ORIG_TASK_COUNT"

# Run suggest — note: this will try to read state_path from the repo root,
# but the binary finds repo root from cwd. We run from TMPDIR.
(cd "$TMPDIR" && "$MG" suggest "test-slug" --type infra 2>/dev/null) || true

TASK_COUNT_AFTER=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
echo "           tasks after suggest: $TASK_COUNT_AFTER"

# Check that T105 still exists in the state
T105_EXISTS=$(cd "$TMPDIR" && "$MG" show T105 2>/dev/null)
if echo "$T105_EXISTS" | grep -q "T105"; then
    echo "           PASS: T105 record survives suggest"
else
    echo "           FAIL: T105 record lost after suggest"
    FAIL=1
fi

# ── Check 2: suggest does not destroy existing bundle file ───────────────────
echo "        2. suggest preserves existing bundle file"

BUNDLE_HASH_AFTER="$(sha256sum "$TMPDIR/$EXISTING_BUNDLE" 2>/dev/null | cut -d' ' -f1)"
if [ "$BUNDLE_HASH_BEFORE" = "$BUNDLE_HASH_AFTER" ]; then
    echo "           PASS: bundle file unchanged (hash: ${BUNDLE_HASH_BEFORE:0:16}...)"
else
    echo "           FAIL: bundle file was modified or overwritten"
    echo "           before: ${BUNDLE_HASH_BEFORE:0:16}..."
    echo "           after:  ${BUNDLE_HASH_AFTER:0:16}..."
    FAIL=1
fi

# ── Check 3: auto-correction of next_id on load ──────────────────────────────
echo "        3. parseStateJson auto-corrects next_id ≤ max(T-ID)"

# Seed a fresh state with the collision
# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T105": {
    "status": "dispatchable",
    "agent": null,
    "bundle": "untracked/T105-important-experiment.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-01T00:00:00Z",
    "claimed": null,
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "claim_count": 0
  },
  "_sys": {
    "next_id": 100,
    "directive_next": 1
  }
}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write

# Running suggest should auto-correct and mint T106, not T100 or T105
SUGGEST_OUT=$(cd "$TMPDIR" && "$MG" suggest "auto-correct-test" --type infra 2>/dev/null)
echo "           suggest output: $SUGGEST_OUT"

if echo "$SUGGEST_OUT" | grep -q "T106"; then
    echo "           PASS: suggest auto-corrected next_id and minted T106 (not T100 or T105)"
else
    echo "           FAIL: suggest did not auto-correct; output was: $SUGGEST_OUT"
    FAIL=1
fi

# Verify T105 still exists after auto-correction
T105_AFTER=$(cd "$TMPDIR" && "$MG" show T105 2>/dev/null)
if echo "$T105_AFTER" | grep -q "T105"; then
    echo "           PASS: T105 survives after auto-correction"
else
    echo "           FAIL: T105 lost after auto-correction"
    FAIL=1
fi

# Audit should now be clean (next_id was auto-corrected)
AUDIT_OUT2=$(cd "$TMPDIR" && "$MG" audit 2>/dev/null)
AUDIT_RC2=$?
if [ "$AUDIT_RC2" -eq 0 ]; then
    echo "           PASS: audit clean after auto-correction"
else
    echo "           FAIL: audit non-zero after auto-correction: $AUDIT_OUT2"
    FAIL=1
fi

# ── Check 4: T209 — suggest output is minimal dispatch line ────────────────
echo "        4. T209: suggest prints minimal dispatch line"

SUGGEST_OUT2=$(cd "$TMPDIR" && "$MG" suggest "t209-test" --model DSPro --type infra 2>/dev/null)
echo "           suggest output: $SUGGEST_OUT2"

if echo "$SUGGEST_OUT2" | grep -qE '^Follow untracked/T[0-9]+-t209-test\.md$'; then
    echo "           PASS: suggest prints 'Follow untracked/T<ID>-<slug>.md'"
else
    echo "           FAIL: suggest output did not match expected format"
    FAIL=1
fi

# ── Check 5: T209 — bundle template has deliverables= in meta header ───────
echo "        5. T209: bundle template has deliverables= in meta header"

LATEST_BUNDLE=$(cd "$TMPDIR" && ls untracked/T???-t209-test.md | tail -1)
META_LINE=$(head -1 "$TMPDIR/$LATEST_BUNDLE" 2>/dev/null)
echo "           meta: $META_LINE"

if echo "$META_LINE" | grep -q 'deliverables='; then
    echo "           PASS: bundle meta contains deliverables="
else
    echo "           FAIL: bundle meta missing deliverables=: $META_LINE"
    FAIL=1
fi

# ── Check 6: T213 — done --status pass (default) ──────────────────────────
echo "        6. T213: done --status pass (default verdict)"

# Create a task, claim it, and done it with default verdict
SUGGEST_OUT3=$(cd "$TMPDIR" && "$MG" suggest "t213-pass" --model DSPro --type infra 2>/dev/null)
T213_TID=$(echo "$SUGGEST_OUT3" | sed 's/.*T\([0-9]*\).*/\1/')
# Create deliverable file so done-check passes
BUNDLE_PATH="$TMPDIR/untracked/T${T213_TID}-t213-pass.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH"
echo "# T$T213_TID — t213-pass" >> "$BUNDLE_PATH"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID" 2>/dev/null)
# T390: claim-then-done within seconds is the claim-at-close pattern the
# duplicate-dispatch guard refuses — the done gate needs --force to test the
# verdict plumbing here (the claim was just recorded, no work between).
DONE_OUT=$(cd "$TMPDIR" && "$MG" done "T$T213_TID" --impression "T213 default-verdict control" --force 2>&1)
if echo "$DONE_OUT" | grep -q 'verdict: pass'; then
    echo "           PASS: default verdict is pass"
else
    echo "           FAIL: expected verdict pass, got: $DONE_OUT"
    FAIL=1
fi

# ── Check 7: T213 — done --fail backward compat ────────────────────────────
echo "        7. T213: done --fail backward compat sets verdict=blocked"

SUGGEST_OUT4=$(cd "$TMPDIR" && "$MG" suggest "t213-fail" --model DSPro --type infra 2>/dev/null)
T213_TID2=$(echo "$SUGGEST_OUT4" | sed 's/.*T\([0-9]*\).*/\1/')
BUNDLE_PATH2="$TMPDIR/untracked/T${T213_TID2}-t213-fail.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH2"
echo "# T$T213_TID2 — t213-fail" >> "$BUNDLE_PATH2"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID2" 2>/dev/null)
# T390: --force for the same claim-at-close reason as check 6.
DONE_OUT2=$(cd "$TMPDIR" && "$MG" done "T$T213_TID2" --fail --impression "T213 fail-compat control" --force 2>&1)
if echo "$DONE_OUT2" | grep -q 'verdict: blocked'; then
    echo "           PASS: --fail sets verdict=blocked"
else
    echo "           FAIL: expected verdict blocked, got: $DONE_OUT2"
    FAIL=1
fi

# ── Check 8: T213 — reject non-pass without --note ─────────────────────────
echo "        8. T213: reject non-pass verdict without --note"

SUGGEST_OUT5=$(cd "$TMPDIR" && "$MG" suggest "t213-nonote" --model DSPro --type infra 2>/dev/null)
T213_TID3=$(echo "$SUGGEST_OUT5" | sed 's/.*T\([0-9]*\).*/\1/')
BUNDLE_PATH3="$TMPDIR/untracked/T${T213_TID3}-t213-nonote.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH3"
echo "# T$T213_TID3 — t213-nonote" >> "$BUNDLE_PATH3"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID3" 2>/dev/null)
# T390: --force for the same claim-at-close reason as check 6.
if (cd "$TMPDIR" && "$MG" done "T$T213_TID3" --status pass-with-findings --impression "T213 no-note control" --force 2>&1); then
    echo "           FAIL: pass-with-findings without --note should be rejected"
    FAIL=1
else
    echo "           PASS: pass-with-findings without --note rejected"
fi

# ── Check 9: T213 — verdict command backfill ───────────────────────────────
echo "        9. T213: verdict command backfills verdict on done task"

(cd "$TMPDIR" && "$MG" done "T$T213_TID3" --status pass --note "temp" --impression "T213 backfill control" --force 2>/dev/null)
(cd "$TMPDIR" && "$MG" verdict "T$T213_TID3" pass-with-findings --note "gap X, follow-up T999" 2>/dev/null)
SHOW_OUT=$(cd "$TMPDIR" && "$MG" show "T$T213_TID3" 2>/dev/null)
if echo "$SHOW_OUT" | grep -q 'verdict:  pass-with-findings' && echo "$SHOW_OUT" | grep -q 'follow-up T999'; then
    echo "           PASS: verdict command backfills correctly"
else
    echo "           FAIL: verdict backfill not reflected in show"
    FAIL=1
fi

# ── Check 10: T217 — done with acceptance= (passing command) ──────────────
echo "        10. T217: acceptance=true passes and task closes"

cat > "$TMPDIR/untracked/TA217-pass-test.md" <<'BEOF'
<!--managent set=A acceptance=true-->
# TA217 — acceptance pass test
BEOF
# Seed task directly with acceptance field set
# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA217":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"true","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
DONE_OUT10=$(cd "$TMPDIR" && "$MG" done TA217 --impression "TA217 control" 2>&1)
if echo "$DONE_OUT10" | grep -q 'verdict: pass' && echo "$DONE_OUT10" | grep -q 'acceptance: true OK'; then
    echo "           PASS: acceptance executed and task closed with pass"
else
    echo "           FAIL: acceptance did not run or task did not close: $DONE_OUT10"
    FAIL=1
fi

# ── Check 11: T217 — done with acceptance=false (failing command) ──────────
echo "        11. T217: acceptance=false rejects and task stays in_progress"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA218":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"false","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
if (cd "$TMPDIR" && "$MG" done TA218 --impression "TA218 control" 2>&1); then
    echo "           FAIL: acceptance=false should have REJECTED"
    FAIL=1
else
    echo "           PASS: acceptance=false rejected, task stayed in_progress"
fi

# ── Check 12: T217 — --skip-acceptance bypasses acceptance ────────────────
echo "        12. T217: --skip-acceptance bypasses command and closes task"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA219":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"false","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
DONE_OUT12=$(cd "$TMPDIR" && "$MG" done TA219 --impression "TA219 control" --skip-acceptance "acceptance run takes 4 hours" 2>&1)
if echo "$DONE_OUT12" | grep -q 'ACCEPTANCE SKIPPED' && echo "$DONE_OUT12" | grep -q 'verdict: pass'; then
    echo "           PASS: --skip-acceptance recorded reason and closed task"
else
    echo "           FAIL: --skip-acceptance did not work: $DONE_OUT12"
    FAIL=1
fi

# ── Check 13: T217 — audit flags done task with no acceptance= ────────────
echo "        13. T217: audit warns on done task with no acceptance= declared"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA220":{"status":"done","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
AUDIT_T217=$(cd "$TMPDIR" && "$MG" audit 2>&1)
if echo "$AUDIT_T217" | grep -q "no acceptance= declared"; then
    echo "           PASS: audit warned about missing acceptance"
else
    echo "           FAIL: audit did not warn about missing acceptance"
    FAIL=1
fi

# ── Check 14: T295 — acceptance with nonexistent cmd reports CANNOT RUN ──
echo "        14. T295: nonexistent acceptance command reports CANNOT RUN (not FAILED)"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA221":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"nonexistent-command-T295-seeded","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
DONE_OUT14=$(cd "$TMPDIR" && "$MG" done TA221 --impression "TA221 control" 2>&1) || true
if echo "$DONE_OUT14" | grep -q "CANNOT RUN" && echo "$DONE_OUT14" | grep -q "infrastructure fault"; then
    echo "           PASS: nonexistent acceptance reports CANNOT RUN + infrastructure fault"
else
    echo "           FAIL: expected CANNOT RUN, got: $DONE_OUT14"
    FAIL=1
fi

# ── Check 15: T295 — acceptance with exit-1 command reports ACCEPTANCE FAILED ──
echo "        15. T295: failing acceptance command reports ACCEPTANCE FAILED"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA222":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"exit 1","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
DONE_OUT15=$(cd "$TMPDIR" && "$MG" done TA222 --impression "TA222 control" 2>&1) || true
if echo "$DONE_OUT15" | grep -q "ACCEPTANCE FAILED" && echo "$DONE_OUT15" | grep -q "exited with code 1"; then
    echo "           PASS: failing acceptance reports ACCEPTANCE FAILED with exit code"
else
    echo "           FAIL: expected ACCEPTANCE FAILED, got: $DONE_OUT15"
    FAIL=1
fi

# ── Check 16: T295 — audit surfaces skip-acceptance uses ────────────────────
echo "        16. T295: audit surfaces --skip-acceptance uses"

# T848: a DIRECT store write bypasses managent, so the S10 store-loss
# census would read the next managent invocation as a shrink and refuse
# it.  Reset the census (the scratch-repo.sh remedy) after every direct
# write so the fixture sees the store the way the fixture made it.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA223":{"status":"done","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","acceptance":"true","skip_acceptance_reason":"test skip reason","claim_count":1}}
JSONEOF
rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
AUDIT_T295=$(cd "$TMPDIR" && "$MG" audit 2>&1)
if echo "$AUDIT_T295" | grep -q "closed with --skip-acceptance" && echo "$AUDIT_T295" | grep -q "test skip reason"; then
    echo "           PASS: audit surfaced skip-acceptance with reason"
else
    echo "           FAIL: audit did not surface skip-acceptance"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# ── T497: ONE status source — the kanban store (T446 → T464 → T497) ───────
# Status has exactly one source: tasks.json (the kanban store), written only
# by managent verbs. The assertion ledger is an append-only event log of
# console-lifecycle facts; its latest entry on a row renders as an ANNOTATION
# (history) in status/show output, never as the effective status. T464 made
# the ledger authoritative in both directions; T497 reverses that — the live
# defect was A0017 (T452 dispatchable) overriding a live in_progress kanban.
# All arms run against the scratch store — never the live one.
# ══════════════════════════════════════════════════════════════════════════

mkdir -p "$TMPDIR/docs/infra/assertion-ledger"
LEDGER="$TMPDIR/docs/infra/assertion-ledger/assertions.jsonl"

# --- T464 seed helpers -----------------------------------------------------
t464_disp() { # $1=id
    printf '"%s":{"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}
t464_inprog() { # $1=id  $2=agent
    printf '"%s":{"status":"in_progress","agent":"%s","model":"%s","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$2" "$1"
}
t464_seed() { # $1 = comma-joined task records
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1, "assertion_next": 1}\n}\n' "$1" > "$TMPDIR/docs/infra/managent/tasks.json"
    rm -f "$TMPDIR/docs/infra/managent/store-census.json"  # T848: reset census after direct write
}
t464_assert() { # $1=assertion-id $2=row $3=status
    printf '{"id":"%s","ts":"2026-08-18T17:10:20Z","actor":"test","verb":"asserted","object":"%s","basis":"performed","meta":{"status":"%s","note":"seeded regression"}}\n' "$1" "$2" "$3" >> "$LEDGER"
}

# ── Check 17: T497 — a `closed` assertion is an annotation, not authority ──
echo "        17. T497: closed assertion annotates but does not drop a row from the kanban"

: > "$LEDGER"
t464_seed "$(t464_disp T464A),$(t464_inprog T464B claude-opus-5)"
t464_assert A0005 T464A closed
t464_assert A0012 T464B closed

# T464A is dispatchable in the kanban; the closed assertion must NOT make it
# done. T464B is in_progress in the kanban; the closed assertion must NOT drop
# it from liveness. Both keep their kanban-store status and gain an (asserted)
# annotation.
STATUS_JSON=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
fails = []
t464a = by_id.get("T464A")
t464b = by_id.get("T464B")
if t464a is None or t464a.get("status") != "dispatchable" or t464a.get("asserted") != "A0005":
    fails.append("T464A should be dispatchable (kanban)+asserted=A0005, got %r" % t464a)
if t464b is None or t464b.get("status") != "in_progress" or t464b.get("asserted") != "A0012":
    fails.append("T464B should be in_progress (kanban)+asserted=A0012, got %r" % t464b)
# T497: the live claim (identifier) renders even when an assertion is present.
if t464b is not None and t464b.get("identifier") is None:
    fails.append("T464B should still show its identifier (live claim), got %r" % t464b)
if fails:
    for f in fails:
        print("           FAIL: " + f)
    sys.exit(1)
print("           PASS: closed-asserted rows keep kanban status with (asserted) markers")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

LIVENESS_OUT=$(cd "$TMPDIR" && "$MG" liveness 2>/dev/null)
if echo "$LIVENESS_OUT" | grep -q 'T464B'; then
    echo "           PASS: closed-asserted T464B still listed by liveness (kanban in_progress)"
else
    echo "           FAIL: closed-asserted T464B dropped from liveness"
    FAIL=1
fi

# A closed assertion on a dispatchable row does NOT suppress next — the row is
# dispatchable in the kanban, so next hands it out. (Run on a fresh seed so the
# claim does not mutate the status read above.)
t464_seed "$(t464_disp T464C)"
t464_assert A0007 T464C closed
NEXT_OUT=$(cd "$TMPDIR" && "$MG" next 2>&1) || true
if echo "$NEXT_OUT" | grep -q 'claimed T464C'; then
    echo "           PASS: next hands out a dispatchable row despite a closed assertion"
else
    echo "           FAIL: next refused a dispatchable row because of a closed assertion: $NEXT_OUT"
    FAIL=1
fi

# ── Check 18: T497 — a `dispatchable` assertion does NOT re-queue a stored in_progress row (the T452 arm) ──
echo "        18. T497: dispatchable assertion does not re-queue a stored in_progress row (T452 arm)"

: > "$LEDGER"
t464_seed "$(t464_inprog T464D minimax-m3)"
t464_assert A0017 T464D dispatchable

STATUS_JSON=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
t = by_id.get("T464D")
if t is None or t.get("status") != "in_progress" or t.get("asserted") != "A0017":
    print("           FAIL: T464D should be in_progress (kanban)+asserted=A0017, got %r" % t)
    sys.exit(1)
# T497: the live claim (identifier) renders — the stale assertion does not hide it.
if t.get("identifier") is None:
    print("           FAIL: T464D should still show its identifier (live claim), got %r" % t)
    sys.exit(1)
print("           PASS: T464D renders in_progress (kanban) with (asserted: A0017) annotation")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# show renders the assertion as a history annotation line, not as the status.
SHOW_OUT=$(cd "$TMPDIR" && "$MG" show T464D 2>/dev/null)
if echo "$SHOW_OUT" | grep -q '^  T464D  in_progress' && echo "$SHOW_OUT" | grep -q 'assertion: A0017'; then
    echo "           PASS: show renders kanban in_progress + assertion annotation line"
else
    echo "           FAIL: show did not render the T452 shape correctly: $SHOW_OUT"
    FAIL=1
fi

# next must NOT hand out T464D — it is in_progress in the kanban, and the
# stale dispatchable assertion no longer re-queues it. (This is the exact
# T452 defect: a stale event log overrode a live kanban truth.)
NEXT_OUT=$(cd "$TMPDIR" && "$MG" next 2>&1) || true
if echo "$NEXT_OUT" | grep -q 'claimed T464D'; then
    echo "           FAIL: next handed out T464D — the stale dispatchable assertion re-queued a live row"
    FAIL=1
else
    echo "           PASS: next refused T464D (kanban in_progress wins over stale dispatchable assertion)"
fi

# ── Check 21: T497 — a `done` assertion does NOT close a stored in_progress row ──
echo "        21. T497: done assertion does not close a stored in_progress row (null arm 2)"

: > "$LEDGER"
t464_seed "$(t464_inprog T464G claude-opus-5)"
t464_assert A0019 T464G done

STATUS_JSON=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
t = by_id.get("T464G")
if t is None or t.get("status") != "in_progress" or t.get("asserted") != "A0019":
    print("           FAIL: T464G should be in_progress (kanban)+asserted=A0019, got %r" % t)
    sys.exit(1)
print("           PASS: T464G renders in_progress (kanban) with (asserted: A0019) annotation")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# next must NOT hand out T464G (kanban in_progress); the done assertion is only
# an annotation and does not close the row.
NEXT_OUT=$(cd "$TMPDIR" && "$MG" next 2>&1) || true
if echo "$NEXT_OUT" | grep -q 'claimed T464G'; then
    echo "           FAIL: next handed out T464G — a done assertion closed a live row"
    FAIL=1
else
    echo "           PASS: next refused T464G (kanban in_progress wins over done assertion)"
fi

# ── Check 19: T464 — retire moves a dispatchable row to archive with an epitaph ──
echo "        19. T464: retire moves a dispatchable row to archive with an epitaph"

: > "$LEDGER"
t464_seed "$(t464_disp T464E)"

RETIRE_OUT=$(cd "$TMPDIR" && "$MG" retire T464E --note "folded into T464; no deliverables ever produced" 2>&1)
if echo "$RETIRE_OUT" | grep -q 'retired T464E'; then
    echo "           PASS: retire accepted a dispatchable row"
else
    echo "           FAIL: retire did not move T464E: $RETIRE_OUT"
    FAIL=1
fi

LIVE_JSON=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
python3 - "$LIVE_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
if any(d["id"] == "T464E" for d in data):
    print("           FAIL: T464E still in the live store after retire")
    sys.exit(1)
print("           PASS: T464E absent from the live store")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

python3 - "$TMPDIR/docs/infra/managent/archive.json" <<'PYEOF'
import sys, json
d = json.load(open(sys.argv[1]))
if d.get("T464E") is None or d["T464E"].get("epitaph") != "folded into T464; no deliverables ever produced":
    print("           FAIL: epitaph missing or wrong in archive.json: %r" % d.get("T464E"))
    sys.exit(1)
print("           PASS: epitaph left on the archived record")
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── Check 20: T464 — null arm: no ledger file → views behave as before ──────
echo "        20. T464: null arm (no ledger file) leaves every view unchanged"

rm -f "$LEDGER"
t464_seed "$(t464_disp T464F)"

NULL_STATUS=$(cd "$TMPDIR" && "$MG" status 2>/dev/null)
if echo "$NULL_STATUS" | grep -q 'T464F' && ! echo "$NULL_STATUS" | grep -q 'asserted'; then
    echo "           PASS: T464F renders dispatchable with no asserted marker"
else
    echo "           FAIL: null-arm status misrendered:"
    echo "$NULL_STATUS"
    FAIL=1
fi

NULL_NEXT=$(cd "$TMPDIR" && "$MG" next 2>&1) || true
if echo "$NULL_NEXT" | grep -q 'claimed T464F'; then
    echo "           PASS: next hands out T464F with no ledger (unchanged)"
else
    echo "           FAIL: null-arm next did not claim T464F: $NULL_NEXT"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T204/T209/T213/T217/T295/T464/T497: ALL CHECKS PASS"
else
    echo "  T204/T209/T213/T217/T295/T464/T497: SOME CHECKS FAILED"
fi
exit "$FAIL"
