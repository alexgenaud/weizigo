#!/usr/bin/env bash
# regression-ollama-dispatcher.sh — T337 S1 controls for the Ollama dispatch path
# (bin/subagent --provider ollama; the bin/ollama-subagent wrapper was removed by T527)
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
#   cross-check    OLLAMA_TAG_TO_CANONICAL in bin/subagent and
#                  canonical_models[] in src/managent/main.zig MUST NOT DRIFT.
#                  Two copies of one truth is the divergence this project
#                  keeps paying for (T336 §Gaps).
#
# All fixtures are synthetic and run in /tmp/weizigo — never the live repo.
# Nothing here touches a tracked file.
#
# Task: T337 · Role: sprint console · Model: deepseek-v4-pro · Date: 2026-08-04
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19). The
# synthetic bundle ($BUNDLE) under untracked/ was previously removed only
# in the EXIT trap; a SIGKILLed run left it in the tree.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
# T527 (T428 Phase B): the bin/ollama-subagent wrapper is removed; the Ollama
# dispatcher IS bin/subagent --provider ollama. Same controls, new entry point.
ollama_sub() { "$SUBAGENT" --provider ollama "$@"; }
# T527: clear inherited depth — a depth-3 leaf running this suite would see
# every dry-run REFUSED at the cap (the refusal is bin/subagent's, correct in
# production, environmental noise here). Controls that test the cap set
# WEIZIGO_AGENT_DEPTH explicitly per call, which still overrides this.
unset WEIZIGO_AGENT_DEPTH
# T440: the tag table moved into bin/subagent when T437 merged the pair.
TAG_TABLE_SRC="$ROOT/bin/subagent"
FAIL=0

# Synthetic bundle — the T-ID branch of the dispatcher requires it
BUNDLE="$ROOT/untracked/T996-regression-ollama-dispatcher.md"
# T448: refuse to run if a previous run left live-tree residue behind.
# The pre-T448 `rm -f` here was exactly the silent-overwrite behaviour
# T448 calls out: a SIGKILLed previous run's bundle was quietly removed
# on the next run, hiding the evidence that a run was killed. The
# start-up check below REPLACES that rm -f — the file is preserved
# until the operator inspects and removes it by hand.
if [ -e "$BUNDLE" ]; then
    echo "regression-ollama-dispatcher.sh: REFUSED — stale fixture from a previous run:" >&2
    echo "    $BUNDLE" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
    echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
    echo "Remove the file by hand (after inspecting it is fixture-shaped and not yours)" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi
printf '<!--managent set=C deliverables=findings/T996-test.json-->\n# T996 — ollama dispatcher test bundle\n' > "$BUNDLE"
# T448: trap on EXIT/INT/TERM/HUP — previously EXIT only. The startup
# check above is the load-bearing guard; this trap is the safety net.
cleanup() { rm -f "$BUNDLE" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP

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
OUT_GLM=$(ollama_sub T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama dispatch exit code $RC"
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
OUT=$(ollama_sub T996 --model kimi-k2.7-code:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama dispatch exit code $RC"
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
OUT=$(ollama_sub T996 --model minimax-m3:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama dispatch exit code $RC"
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

# ── control 4: qwen3.8:27b-mlx (T463) ──────────────────────────────────
# qwen3.8:27b-mlx is the exact serving identity (T463) — raw tag and
# canonical label coincide, so the assertion is that the mapping resolves
# to the canonical and the prompt carries it on the claim/done lines,
# while the launch still uses the raw tag.
echo "  4. qwen3.8:27b-mlx — launch uses raw tag, agent lines use canonical"
OUT_QWEN=$(ollama_sub T996 --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: ollama dispatch exit code $RC"
    echo "$OUT_QWEN"
    FAIL=1
else
    if launch_uses_tag "$OUT_QWEN" "qwen3.8:27b-mlx"; then
        echo "    PASS launch: ollama launch pi --model qwen3.8:27b-mlx"
    else
        echo "    FAIL launch: expected ollama launch pi --model qwen3.8:27b-mlx, not found in output"
        FAIL=1
    fi
    CLAIM_LINE=$(echo "$OUT_QWEN" | grep "FIRST: bin/managent claim" || true)
    DONE_LINE=$(echo "$OUT_QWEN" | grep "bin/managent done" || true)
    check_agent_in_line "$CLAIM_LINE" "qwen3.8:27b-mlx" "claim" || FAIL=1
    check_agent_in_line "$DONE_LINE" "qwen3.8:27b-mlx" "done"  || FAIL=1
fi

# ── control 5: depth cap still fires ─────────────────────────────────────
echo "  5. depth-cap: WEIZIGO_AGENT_DEPTH=3 (cap) refuses dispatch"
OUT=$(WEIZIGO_AGENT_DEPTH=3 ollama_sub T996 --model glm-5.2:cloud 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at cap depth 3 (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── cross-check: OLLAMA_TAG_TO_CANONICAL ↔ canonical_models[] ────────────
# Every canonical value in the bin/subagent tag mapping must appear in
# canonical_models[] in main.zig, and every Ollama model in canonical_models[]
# must have at least one tag mapping.  Two copies of one truth — the
# divergence this project keeps paying for.
echo "  6. cross-check: OLLAMA_TAG_TO_CANONICAL ↔ canonical_models[]"
MAIN_ZIG="$ROOT/src/managent/main.zig"
PASS_CROSS=1

# Extract canonical values from the OLLAMA_TAG_TO_CANONICAL dict (the values —
# right-hand side of each mapping). T440: the table lives in bin/subagent since
# T437 merged the pair; the cross-check reads the source of truth directly.
OLLAMA_CANONICALS=$(python3 -c "
import re, sys
with open('$TAG_TABLE_SRC') as f:
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
" 2>&1) || { echo "    FAIL: cannot parse OLLAMA_TAG_TO_CANONICAL from bin/subagent"; FAIL=1; PASS_CROSS=0; }

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
    OLLAMA_ZIG_MODELS="glm-5.2 minimax-m3 kimi-k2.7 qwen3.8:27b-mlx"
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
echo "  7. seeded-defect: canonical-label-in-launch is CAUGHT"
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
