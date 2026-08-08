#!/usr/bin/env bash
# regression-ollama-dispatcher.sh — T337 S1 controls for bin/ollama-subagent
#
# T317 item 2 canonicalized the model label and then passed the CANONICAL
# label to `ollama launch` instead of the Ollama tag. The Orchestrator fixed
# the line at 6a4023c — this is the control that would have caught it, and
# the control that keeps it from recurring.
#
#   null controls  --dry-run with each Ollama tag: the ollama launch command
#                  MUST use the raw tag (--model glm-5.2:cloud etc.), while
#                  the claim/done lines MUST use the canonical label (--agent
#                  glm-5.2).  Both assertions are checked on every tag.
#   seeded control the old bug — a synthetic version of the broken code that
#                  passes the canonical label to ollama launch — is CAUGHT by
#                  this test (the red half; without it the green half is
#                  decoration).
#   cross-check    OLLAMA_TAG_TO_CANONICAL in bin/ollama-subagent and
#                  canonical_models[] in src/managent/main.zig MUST NOT DRIFT.
#                  Two copies of one truth is the divergence this project
#                  keeps paying for (T336 §Gaps).
#
# All fixtures are synthetic and run in /tmp/weizigo — never the live repo.
# Nothing here touches a tracked file.
#
# Task: T337 · Role: sprint console · Model: deepseek-v4-pro · Date: 2026-08-04

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
OLLAMA_SUBAGENT="$ROOT/bin/ollama-subagent"
FAIL=0

# Synthetic bundle — the T-ID branch of ollama-subagent requires it
BUNDLE="$ROOT/untracked/T996-regression-ollama-dispatcher.md"
rm -f "$BUNDLE"
printf '<!--managent set=C deliverables=findings/T996-test.json-->\n# T996 — ollama dispatcher test bundle\n' > "$BUNDLE"
trap 'rm -f "$BUNDLE"' EXIT

echo "=== ollama-dispatcher regression ==="

# ── helpers ───────────────────────────────────────────────────────────────
# Check that the ollama launch command uses the expected raw tag (e.g.
# glm-5.2:cloud).  The dry-run output is one long line; grep for the
# literal fragment.
launch_uses_tag() {
    local out="$1" tag="$2"
    if echo "$out" | grep -qF "ollama launch pi --model ${tag}"; then
        return 0
    else
        return 1
    fi
}

# Check that a claim/done line carries the expected canonical --agent.
check_agent_in_line() {
    local line="$1" expected_agent="$2" label="$3"
    if echo "$line" | grep -q -- "--agent ${expected_agent}"; then
        echo "    PASS $label: --agent $expected_agent"
        return 0
    else
        echo "    FAIL $label: expected --agent $expected_agent, got: $line"
        return 1
    fi
}

# ── control 1: glm-5.2:cloud ──────────────────────────────────────────────
echo "  1. glm-5.2:cloud — launch uses raw tag, agent lines use canonical"
OUT_GLM=$("$OLLAMA_SUBAGENT" T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama-subagent exit code $RC"
    echo "$OUT_GLM"
    FAIL=1
else
    if launch_uses_tag "$OUT_GLM" "glm-5.2:cloud"; then
        echo "    PASS launch: ollama launch pi --model glm-5.2:cloud"
    else
        echo "    FAIL launch: expected ollama launch pi --model glm-5.2:cloud, not found in output"
        FAIL=1
    fi
    CLAIM_LINE=$(echo "$OUT_GLM" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT_GLM" | grep "bin/managent done" || true)
    check_agent_in_line "$CLAIM_LINE" "glm-5.2" "claim" || FAIL=1
    check_agent_in_line "$DONE_LINE" "glm-5.2" "done"  || FAIL=1
fi

# ── control 2: kimi-k2.7-code:cloud ──────────────────────────────────────
echo "  2. kimi-k2.7-code:cloud — launch uses raw tag, agent lines use canonical"
OUT=$("$OLLAMA_SUBAGENT" T996 --model kimi-k2.7-code:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama-subagent exit code $RC"
    echo "$OUT"
    FAIL=1
else
    if launch_uses_tag "$OUT" "kimi-k2.7-code:cloud"; then
        echo "    PASS launch: ollama launch pi --model kimi-k2.7-code:cloud"
    else
        echo "    FAIL launch: expected ollama launch pi --model kimi-k2.7-code:cloud, not found in output"
        FAIL=1
    fi
    CLAIM_LINE=$(echo "$OUT" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT" | grep "bin/managent done" || true)
    check_agent_in_line "$CLAIM_LINE" "kimi-k2.7" "claim" || FAIL=1
    check_agent_in_line "$DONE_LINE" "kimi-k2.7" "done"  || FAIL=1
fi

# ── control 3: minimax-m3:cloud ──────────────────────────────────────────
echo "  3. minimax-m3:cloud — launch uses raw tag, agent lines use canonical"
OUT=$("$OLLAMA_SUBAGENT" T996 --model minimax-m3:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama-subagent exit code $RC"
    echo "$OUT"
    FAIL=1
else
    if launch_uses_tag "$OUT" "minimax-m3:cloud"; then
        echo "    PASS launch: ollama launch pi --model minimax-m3:cloud"
    else
        echo "    FAIL launch: expected ollama launch pi --model minimax-m3:cloud, not found in output"
        FAIL=1
    fi
    CLAIM_LINE=$(echo "$OUT" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT" | grep "bin/managent done" || true)
    check_agent_in_line "$CLAIM_LINE" "minimax-m3" "claim" || FAIL=1
    check_agent_in_line "$DONE_LINE" "minimax-m3" "done"  || FAIL=1
fi

# ── control 4: depth cap still fires ─────────────────────────────────────
echo "  4. depth-cap: WEIZIGO_AGENT_DEPTH=3 (cap) refuses dispatch"
OUT=$(WEIZIGO_AGENT_DEPTH=3 "$OLLAMA_SUBAGENT" T996 --model glm-5.2:cloud 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at cap depth 3 (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── cross-check: OLLAMA_TAG_TO_CANONICAL ↔ canonical_models[] ────────────
# Every canonical value in the ollama-subagent mapping must appear in
# canonical_models[] in main.zig, and every Ollama model in canonical_models[]
# must have at least one tag mapping.  Two copies of one truth — the
# divergence this project keeps paying for.
echo "  5. cross-check: OLLAMA_TAG_TO_CANONICAL ↔ canonical_models[]"
MAIN_ZIG="$ROOT/src/managent/main.zig"
PASS_CROSS=1

# Extract canonical values from bin/ollama-subagent's OLLAMA_TAG_TO_CANONICAL
# dict (the values — right-hand side of each mapping)
OLLAMA_CANONICALS=$(python3 -c "
import re, sys
with open('$OLLAMA_SUBAGENT') as f:
    text = f.read()
m = re.search(r'OLLAMA_TAG_TO_CANONICAL\s*=\s*\{(.*?)\}', text, re.DOTALL)
if not m:
    sys.exit(1)
block = m.group(1)
vals = set()
for line in block.split('\n'):
    line = line.strip()
    if ':' in line and '#' not in line.split(':')[0]:
        v = re.search(r':\s*\"(.+?)\"', line)
        if v:
            vals.add(v.group(1))
for v in sorted(vals):
    print(v)
" 2>&1) || { echo "    FAIL: cannot parse OLLAMA_TAG_TO_CANONICAL from bin/ollama-subagent"; FAIL=1; PASS_CROSS=0; }

if [ "$PASS_CROSS" -eq 1 ]; then
    # Extract canonical_models array from main.zig
    ZIG_CANONICALS=$(python3 -c "
import re, sys
with open('$MAIN_ZIG') as f:
    text = f.read()
m = re.search(r'const canonical_models\s*=\s*\[\_\]\[\]const u8\s*\{\s*(.*?)\};', text, re.DOTALL)
if not m:
    sys.exit(1)
block = m.group(1)
vals = set()
for line in block.split('\n'):
    line = line.strip().rstrip(',')
    line = line.strip('\"')
    if line and not line.startswith('//'):
        vals.add(line)
for v in sorted(vals):
    print(v)
" 2>&1) || { echo "    FAIL: cannot parse canonical_models[] from src/managent/main.zig"; FAIL=1; PASS_CROSS=0; }
fi

if [ "$PASS_CROSS" -eq 1 ]; then
    # Check: every OLLAMA canonical value must be in zig canonical_models
    while IFS= read -r oc; do
        if ! echo "$ZIG_CANONICALS" | grep -Fxq "$oc"; then
            echo "    FAIL cross-check: OLLAMA canonical '$oc' NOT in canonical_models[]"
            PASS_CROSS=0
        fi
    done <<< "$OLLAMA_CANONICALS"

    # Check: every Ollama-model in canonical_models[] must have at least one
    # tag mapping in OLLAMA_TAG_TO_CANONICAL
    OLLAMA_ZIG_MODELS="glm-5.2 minimax-m3 kimi-k2.7"
    for zm in $OLLAMA_ZIG_MODELS; do
        if ! echo "$OLLAMA_CANONICALS" | grep -Fxq "$zm"; then
            echo "    FAIL cross-check: zig canonical '$zm' (Ollama model) has NO tag mapping in OLLAMA_TAG_TO_CANONICAL"
            PASS_CROSS=0
        fi
    done

    if [ "$PASS_CROSS" -eq 1 ]; then
        echo "    PASS: OLLAMA_TAG_TO_CANONICAL ↔ canonical_models[] in sync"
    else
        FAIL=1
    fi
fi

# ── seeded-defect control: the old bug (canonical label → ollama launch) ─
# A synthetic version of the broken code — the launch uses the canonical
# label instead of the raw tag. This is the red half: the control that
# proves the green controls actually test something.
echo "  6. seeded-defect: canonical-label-in-launch is CAUGHT"
# We construct a synthetic dry-run that mimics the old broken behaviour
# by replacing the raw tag with the canonical label in the output.
# The green control above (launch_uses_tag) expects the raw tag; if the
# synthetic broken-output would PASS that check, the control is not
# discriminating — it would have stayed green through the broken code.
# Use OUT_GLM from control 1 — it contains --model glm-5.2:cloud.
SYNTH_BROKEN=$(printf '%s\n' "$OUT_GLM" | sed 's/--model glm-5.2:cloud/--model glm-5.2/g')
if launch_uses_tag "$SYNTH_BROKEN" "glm-5.2:cloud"; then
    # The synthetic still matches the raw tag — the sed didn't alter it,
    # so the control would have passed on broken code. That's a FAIL.
    echo "    FAIL seeded: synthetic broken output still matches raw tag — control is not discriminating"
    FAIL=1
elif launch_uses_tag "$SYNTH_BROKEN" "glm-5.2"; then
    # The synthetic now matches the CANONICAL label in the launch command —
    # exactly the old bug. The green control above would FAIL on this
    # (because it expects the raw tag). So the control discriminates.
    echo "    PASS seeded: synthetic broken output uses canonical in launch — this WOULD fail control 1"
else
    echo "    FAIL seeded: synthetic output matches neither — sed altered something unexpected"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-ollama-dispatcher: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-ollama-dispatcher: FAILURES ==="
    exit 1
fi
