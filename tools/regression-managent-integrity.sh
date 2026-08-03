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

# ── T268: the deployed copy must BE what we built ────────────────────
# bin/managent is the binary every check below executes. If it is stale
# relative to zig-out/bin/managent, the whole regression measures a binary
# nobody can reconstruct. Compare the version stamps (deployed != built is
# the stale-bin signal T264's stamping exists to expose).
stamp_of() {
    "$1" --version 2>&1 | grep -oE '[a-z][a-z0-9-]* [0-9a-f]{7}(-dirty)? built' | head -1 | sed 's/ built$//' || true
}

BUILT_STAMP=$(stamp_of "$PROJECT/zig-out/bin/managent")
DEPLOYED_STAMP=$(stamp_of "$MG")
echo "  T268: deployed stamp check"
if [ -z "$DEPLOYED_STAMP" ]; then
    echo "    FAIL: bin/managent missing or unstamped — run 'zig build deploy-managent'"
    FAIL=1
elif [ "$BUILT_STAMP" = "$DEPLOYED_STAMP" ]; then
    echo "    PASS: deployed bin/$DEPLOYED_STAMP == built zig-out/$BUILT_STAMP"
else
    echo "    FAIL: deployed bin/$DEPLOYED_STAMP != built zig-out/$BUILT_STAMP — bin/ is stale"
    FAIL=1
fi

# ── Setup: temp store in /tmp/weizigo (disposable; the `ephemeral`
#    indirection was retired 2026-08-03, T286) ────────────────────────────
TMPDIR="$(mktemp -d /tmp/weizigo/managent-integrity-XXXXXX)"
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

# Seed an existing task T105 with next_id=105 (next_id ≤ max T-ID → collision)
# When suggest runs, it will read next_id=105 and mint T105, clobbering this one.
EXISTING_BUNDLE="untracked/T105-important-experiment.md"
echo "# T105 — important experiment" > "$TMPDIR/$EXISTING_BUNDLE"

# Record the bundle content hash for survival check
BUNDLE_HASH_BEFORE="$(sha256sum "$TMPDIR/$EXISTING_BUNDLE" | cut -d' ' -f1)"

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

echo ""
echo "  T204 regression: managent integrity"

# ── Check 1: suggest does not destroy existing task record ───────────────────
echo "        1. suggest preserves existing task record"

ORIG_TASK_COUNT=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null)
echo "           tasks before suggest: $ORIG_TASK_COUNT"

# Run suggest — note: this will try to read state_path from the repo root,
# but the binary finds repo root from cwd. We run from TMPDIR.
(cd "$TMPDIR" && "$MG" suggest "test-slug" 2>/dev/null) || true

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

# Running suggest should auto-correct and mint T106, not T100 or T105
SUGGEST_OUT=$(cd "$TMPDIR" && "$MG" suggest "auto-correct-test" 2>/dev/null)
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

SUGGEST_OUT2=$(cd "$TMPDIR" && "$MG" suggest "t209-test" --model DSPro 2>/dev/null)
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
SUGGEST_OUT3=$(cd "$TMPDIR" && "$MG" suggest "t213-pass" --model DSPro 2>/dev/null)
T213_TID=$(echo "$SUGGEST_OUT3" | sed 's/.*T\([0-9]*\).*/\1/')
# Create deliverable file so done-check passes
BUNDLE_PATH="$TMPDIR/untracked/T${T213_TID}-t213-pass.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH"
echo "# T$T213_TID — t213-pass" >> "$BUNDLE_PATH"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID" 2>/dev/null)
DONE_OUT=$(cd "$TMPDIR" && "$MG" done "T$T213_TID" 2>&1)
if echo "$DONE_OUT" | grep -q 'verdict: pass'; then
    echo "           PASS: default verdict is pass"
else
    echo "           FAIL: expected verdict pass, got: $DONE_OUT"
    FAIL=1
fi

# ── Check 7: T213 — done --fail backward compat ────────────────────────────
echo "        7. T213: done --fail backward compat sets verdict=blocked"

SUGGEST_OUT4=$(cd "$TMPDIR" && "$MG" suggest "t213-fail" --model DSPro 2>/dev/null)
T213_TID2=$(echo "$SUGGEST_OUT4" | sed 's/.*T\([0-9]*\).*/\1/')
BUNDLE_PATH2="$TMPDIR/untracked/T${T213_TID2}-t213-fail.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH2"
echo "# T$T213_TID2 — t213-fail" >> "$BUNDLE_PATH2"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID2" 2>/dev/null)
DONE_OUT2=$(cd "$TMPDIR" && "$MG" done "T$T213_TID2" --fail 2>&1)
if echo "$DONE_OUT2" | grep -q 'verdict: blocked'; then
    echo "           PASS: --fail sets verdict=blocked"
else
    echo "           FAIL: expected verdict blocked, got: $DONE_OUT2"
    FAIL=1
fi

# ── Check 8: T213 — reject non-pass without --note ─────────────────────────
echo "        8. T213: reject non-pass verdict without --note"

SUGGEST_OUT5=$(cd "$TMPDIR" && "$MG" suggest "t213-nonote" --model DSPro 2>/dev/null)
T213_TID3=$(echo "$SUGGEST_OUT5" | sed 's/.*T\([0-9]*\).*/\1/')
BUNDLE_PATH3="$TMPDIR/untracked/T${T213_TID3}-t213-nonote.md"
echo "<!--managent set=A deliverables=-->" > "$BUNDLE_PATH3"
echo "# T$T213_TID3 — t213-nonote" >> "$BUNDLE_PATH3"
(cd "$TMPDIR" && "$MG" claim "T$T213_TID3" 2>/dev/null)
if (cd "$TMPDIR" && "$MG" done "T$T213_TID3" --status pass-with-findings 2>&1); then
    echo "           FAIL: pass-with-findings without --note should be rejected"
    FAIL=1
else
    echo "           PASS: pass-with-findings without --note rejected"
fi

# ── Check 9: T213 — verdict command backfill ───────────────────────────────
echo "        9. T213: verdict command backfills verdict on done task"

(cd "$TMPDIR" && "$MG" done "T$T213_TID3" --status pass --note "temp" 2>/dev/null)
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
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA217":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"true","claim_count":1}}
JSONEOF
DONE_OUT10=$(cd "$TMPDIR" && "$MG" done TA217 2>&1)
if echo "$DONE_OUT10" | grep -q 'verdict: pass' && echo "$DONE_OUT10" | grep -q 'acceptance: true OK'; then
    echo "           PASS: acceptance executed and task closed with pass"
else
    echo "           FAIL: acceptance did not run or task did not close: $DONE_OUT10"
    FAIL=1
fi

# ── Check 11: T217 — done with acceptance=false (failing command) ──────────
echo "        11. T217: acceptance=false rejects and task stays in_progress"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA218":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"false","claim_count":1}}
JSONEOF
if (cd "$TMPDIR" && "$MG" done TA218 2>&1); then
    echo "           FAIL: acceptance=false should have REJECTED"
    FAIL=1
else
    echo "           PASS: acceptance=false rejected, task stayed in_progress"
fi

# ── Check 12: T217 — --skip-acceptance bypasses acceptance ────────────────
echo "        12. T217: --skip-acceptance bypasses command and closes task"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA219":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"false","claim_count":1}}
JSONEOF
DONE_OUT12=$(cd "$TMPDIR" && "$MG" done TA219 --skip-acceptance "acceptance run takes 4 hours" 2>&1)
if echo "$DONE_OUT12" | grep -q 'ACCEPTANCE SKIPPED' && echo "$DONE_OUT12" | grep -q 'verdict: pass'; then
    echo "           PASS: --skip-acceptance recorded reason and closed task"
else
    echo "           FAIL: --skip-acceptance did not work: $DONE_OUT12"
    FAIL=1
fi

# ── Check 13: T217 — audit flags done task with no acceptance= ────────────
echo "        13. T217: audit warns on done task with no acceptance= declared"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA220":{"status":"done","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","claim_count":1}}
JSONEOF
AUDIT_T217=$(cd "$TMPDIR" && "$MG" audit 2>&1)
if echo "$AUDIT_T217" | grep -q "no acceptance= declared"; then
    echo "           PASS: audit warned about missing acceptance"
else
    echo "           FAIL: audit did not warn about missing acceptance"
    FAIL=1
fi

# ── Check 14: T295 — acceptance with nonexistent cmd reports CANNOT RUN ──
echo "        14. T295: nonexistent acceptance command reports CANNOT RUN (not FAILED)"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA221":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"nonexistent-command-T295-seeded","claim_count":1}}
JSONEOF
DONE_OUT14=$(cd "$TMPDIR" && "$MG" done TA221 2>&1) || true
if echo "$DONE_OUT14" | grep -q "CANNOT RUN" && echo "$DONE_OUT14" | grep -q "infrastructure fault"; then
    echo "           PASS: nonexistent acceptance reports CANNOT RUN + infrastructure fault"
else
    echo "           FAIL: expected CANNOT RUN, got: $DONE_OUT14"
    FAIL=1
fi

# ── Check 15: T295 — acceptance with exit-1 command reports ACCEPTANCE FAILED ──
echo "        15. T295: failing acceptance command reports ACCEPTANCE FAILED"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA222":{"status":"in_progress","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"acceptance":"exit 1","claim_count":1}}
JSONEOF
DONE_OUT15=$(cd "$TMPDIR" && "$MG" done TA222 2>&1) || true
if echo "$DONE_OUT15" | grep -q "ACCEPTANCE FAILED" && echo "$DONE_OUT15" | grep -q "exited with code 1"; then
    echo "           PASS: failing acceptance reports ACCEPTANCE FAILED with exit code"
else
    echo "           FAIL: expected ACCEPTANCE FAILED, got: $DONE_OUT15"
    FAIL=1
fi

# ── Check 16: T295 — audit surfaces skip-acceptance uses ────────────────────
echo "        16. T295: audit surfaces --skip-acceptance uses"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{"TA223":{"status":"done","agent":"test","bundle":"untracked/TA217-pass-test.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","acceptance":"true","skip_acceptance_reason":"test skip reason","claim_count":1}}
JSONEOF
AUDIT_T295=$(cd "$TMPDIR" && "$MG" audit 2>&1)
if echo "$AUDIT_T295" | grep -q "closed with --skip-acceptance" && echo "$AUDIT_T295" | grep -q "test skip reason"; then
    echo "           PASS: audit surfaced skip-acceptance with reason"
else
    echo "           FAIL: audit did not surface skip-acceptance"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T204/T209/T213/T217/T295: ALL CHECKS PASS"
else
    echo "  T204/T209/T213/T217/T295: SOME CHECKS FAILED"
fi
exit "$FAIL"
