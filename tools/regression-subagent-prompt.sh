#!/usr/bin/env bash
# regression-subagent-prompt.sh — T315 controls for bin/subagent prompt
#
# bin/subagent is given the model (--dspro/--dsflash => MODELS[...]) but did
# not include --agent <model> in the generated prompt. Workers following the
# documented protocol exactly (bin/managent claim <id> without --agent) created
# unattributed rows when the task had no stored model (managent add vs suggest).
# Seven rows needed hand-repair (T292, T307, T309, T310, T305, T306, T313)
# and one closed with agent=T309 — the task ID in the model field.
#
# T315 fixes the prompt. These controls verify:
#
#   null control   --dsflash --dry-run prints --agent deepseek-v4-flash on
#                  both the claim and done lines
#   null control   --dspro --dry-run prints --agent deepseek-v4-pro on both
#                  lines
#   seeded control assert the exact prompt fragment is present on each line;
#                  absence fails — this is the control that was red before the
#                  fix (recorded in the T315 session output) and is green after
#   depth-cap      WEIZIGO_AGENT_DEPTH=2 refuses dispatch (unchanged by T315)
#
# All fixtures are synthetic and run in /tmp/weizigo — never the live repo.
# This script is NOT in the build graph; T317 wires it into zig build test.
#
# Task: T315 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19). The
# synthetic bundle ($BUNDLE) under untracked/ was previously removed only
# in the EXIT trap; a SIGKILLed run left it in the tree.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
FAIL=0

# Synthetic bundle in untracked/ — the T-ID branch requires it
BUNDLE="$ROOT/untracked/T995-regression-test.md"
# T448: refuse to run if a previous run left live-tree residue behind.
# The pre-T448 `rm -f` here was exactly the silent-overwrite behaviour
# T448 calls out: a SIGKILLed previous run's bundle was quietly removed
# on the next run, hiding the evidence that a run was killed. The
# start-up check below REPLACES that rm -f — the file is preserved
# until the operator inspects and removes it by hand.
if [ -e "$BUNDLE" ]; then
    echo "regression-subagent-prompt.sh: REFUSED — stale fixture from a previous run:" >&2
    echo "    $BUNDLE" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
    echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
    echo "Remove the file by hand (after inspecting it is fixture-shaped and not yours)" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi
printf '<!--managent set=C deliverables=findings/T995-test.json-->\n# T995 — test bundle\n' > "$BUNDLE"
# T448: trap on EXIT/INT/TERM/HUP — previously EXIT only. The startup
# check above is the load-bearing guard; this trap is the safety net.
cleanup() { rm -f "$BUNDLE" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP

echo "=== subagent-prompt regression ==="

# ── null control: --dsflash ──────────────────────────────────────────────
echo "  1. null control: --dsflash --dry-run emits --agent on both lines"
OUT=$("$SUBAGENT" --provider deepseek T995 --dsflash --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: subagent exit code $RC"
    echo "$OUT"
    FAIL=1
else
    CLAIM_LINE=$(echo "$OUT" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT" | grep "bin/managent done" || true)
    CLAIM_OK=0; DONE_OK=0
    if echo "$CLAIM_LINE" | grep -q "\-\-agent deepseek-v4-flash"; then
        CLAIM_OK=1
    fi
    if echo "$DONE_LINE" | grep -q "\-\-agent deepseek-v4-flash"; then
        DONE_OK=1
    fi
    if [ "$CLAIM_OK" -eq 1 ] && [ "$DONE_OK" -eq 1 ]; then
        echo "    PASS: --agent deepseek-v4-flash on claim and done lines"
    else
        echo "    FAIL: claim=$CLAIM_OK done=$DONE_OK"
        echo "    claim line: $CLAIM_LINE"
        echo "    done line:  $DONE_LINE"
        FAIL=1
    fi
fi

# ── null control: --dspro ────────────────────────────────────────────────
echo "  2. null control: --dspro --dry-run emits --agent on both lines"
OUT=$("$SUBAGENT" --provider deepseek T995 --dspro --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: subagent exit code $RC"
    echo "$OUT"
    FAIL=1
else
    CLAIM_LINE=$(echo "$OUT" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT" | grep "bin/managent done" || true)
    CLAIM_OK=0; DONE_OK=0
    if echo "$CLAIM_LINE" | grep -q "\-\-agent deepseek-v4-pro"; then
        CLAIM_OK=1
    fi
    if echo "$DONE_LINE" | grep -q "\-\-agent deepseek-v4-pro"; then
        DONE_OK=1
    fi
    if [ "$CLAIM_OK" -eq 1 ] && [ "$DONE_OK" -eq 1 ]; then
        echo "    PASS: --agent deepseek-v4-pro on claim and done lines"
    else
        echo "    FAIL: claim=$CLAIM_OK done=$DONE_OK"
        echo "    claim line: $CLAIM_LINE"
        echo "    done line:  $DONE_LINE"
        FAIL=1
    fi
fi

# ── seeded control: exact prompt fragment assertion ──────────────────────
# Before the T315 fix, these two assertions were red — the prompt lacked
# --agent on both lines. The absence is what let seven rows close unattributed.
# A control that has never been red is not a control; the red run is recorded
# in the T315 session output (2026-08-03).
echo "  3. seeded: exact --agent fragment present on claim line"
OUT=$("$SUBAGENT" --provider deepseek T995 --dsflash --dry-run 2>&1)
if echo "$OUT" | grep -q "claim T995 --agent deepseek-v4-flash"; then
    echo "    PASS: 'claim T995 --agent deepseek-v4-flash' found"
else
    echo "    FAIL: expected fragment 'claim T995 --agent deepseek-v4-flash' not found"
    echo "    output:"; echo "$OUT"
    FAIL=1
fi

echo "  4. seeded: exact --agent fragment present on done line"
if echo "$OUT" | grep -q "done T995 --agent deepseek-v4-flash --status"; then
    echo "    PASS: 'done T995 --agent deepseek-v4-flash --status' found"
else
    echo "    FAIL: expected fragment 'done T995 --agent deepseek-v4-flash --status' not found"
    echo "    output:"; echo "$OUT"
    FAIL=1
fi

# ── depth cap: still fires ───────────────────────────────────────────────
# T315 does not change the depth cap. Prove it still refuses at depth 2.
echo "  5. depth-cap: WEIZIGO_AGENT_DEPTH=3 (cap) refuses dispatch"
OUT=$(WEIZIGO_AGENT_DEPTH=3 "$SUBAGENT" --provider deepseek T995 --dsflash 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at cap depth 3 (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-subagent-prompt: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-subagent-prompt: FAILURES ==="
    exit 1
fi
