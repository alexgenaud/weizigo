#!/usr/bin/env bash
# regression-depth-enforcement.sh — T321 controls for the depth cap on the Ollama path
#
# T320 found the depth cap guards exactly one edge (DeepSeek->DeepSeek via
# bin/subagent); the Ollama path (ollama launch pi) has no depth check, no
# increment, and DEEPSEEK_API_KEY is present in Ollama workers (so an Ollama
# leaf can dispatch DeepSeek when depth < 2 — confirmed by a REAL dispatch in
# the T321 session, not merely dry-run).
#
# T321 ruling: (b) — wrap the Ollama launch with bin/ollama-subagent, mirroring
# the bin/subagent contract (refuse at worker depth, stamp child at depth 2),
# plus (a)'s honest documentation. (c) — strip DEEPSEEK_API_KEY from Ollama
# children — is NOT moot (the real dispatch proved the capability) but is held
# for the human's explicit word and is NOT implemented here.
#
# Controls (option b):
#   null-1   bin/ollama-subagent at human depth (unset -> 1) is NOT refused
#            (--dry-run prints the command, RC 0)
#   null-2   bin/ollama-subagent at depth 1 is NOT refused
#   seeded-1 bin/ollama-subagent at the worker depth (2) IS refused — this was
#            red pre-fix (no tool, no refusal) and is green post-fix
#   seeded-2 bin/ollama-subagent fail-closes on an unreadable depth (refused)
#   seeded-3 bin/subagent's DeepSeek->DeepSeek refusal STILL fires at depth 2
#            (the bar: the existing edge must still be guarded after the change)
#   doc-1    subdelegation.md records the ruling and the three paths
#   doc-2    subdelegation.md records the attribution rule (never self-report)
#
# All fixtures are synthetic and run against the live repo's bin/ + docs/. The
# T-ID branch of bin/ollama-subagent needs a synthetic bundle in untracked/.
# This script is NOT in the build graph; wiring it into `zig build test` is a
# separate row.
#
# Task: T321 · Role: worker · Model: glm-5.2 · Date: 2026-08-03

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
OLLAMA_SUB="$ROOT/bin/ollama-subagent"
DOC="$ROOT/docs/infra/agents/subdelegation.md"
FAIL=0

# Synthetic bundle in untracked/ — the T-ID branch requires it
BUNDLE="$ROOT/untracked/T996-regression-depth.md"
rm -f "$BUNDLE"
printf '<!--managent set=C deliverables=findings/T996-test.json-->\n# T996 — depth-enforcement test bundle\n' > "$BUNDLE"
trap 'rm -f "$BUNDLE"' EXIT

echo "=== depth-enforcement regression (T321, option b) ==="

# ── null-1: human depth (unset) is NOT refused ───────────────────────────
echo "  1. null: bin/ollama-subagent at depth unset is NOT refused"
OUT=$(env -u WEIZIGO_AGENT_DEPTH "$OLLAMA_SUB" T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ollama launch pi --model glm-5.2:cloud"; then
    echo "    PASS: prints command, RC 0 (not refused)"
else
    echo "    FAIL: RC=$RC"; echo "$OUT" | head -3 | sed 's/^/      /'
    FAIL=1
fi

# ── null-2: depth 1 is NOT refused ──────────────────────────────────────
echo "  2. null: bin/ollama-subagent at depth 1 is NOT refused"
OUT=$(WEIZIGO_AGENT_DEPTH=1 "$OLLAMA_SUB" T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^WEIZIGO_AGENT_DEPTH=2"; then
    echo "    PASS: stamps child depth 2, RC 0 (not refused)"
else
    echo "    FAIL: RC=$RC"; echo "$OUT" | head -3 | sed 's/^/      /'
    FAIL=1
fi

# ── seeded-1: worker depth (2) IS refused — red pre-fix, green post-fix ──
echo "  3. seeded: bin/ollama-subagent at worker depth 2 IS refused"
OUT=$(WEIZIGO_AGENT_DEPTH=2 "$OLLAMA_SUB" T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at depth 2 (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── seeded-2: unreadable depth fail-closes to worker ────────────────────
echo "  4. seeded: bin/ollama-subagent fail-closes on an unreadable depth"
OUT=$(WEIZIGO_AGENT_DEPTH=garbage "$OLLAMA_SUB" T996 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: garbage depth treated as worker (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── seeded-3: bin/subagent DeepSeek->DeepSeek refusal still fires (bar) ──
echo "  5. seeded: bin/subagent STILL refuses DeepSeek dispatch at depth 2"
OUT=$(WEIZIGO_AGENT_DEPTH=2 "$SUBAGENT" T996 --dspro --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: existing edge still guarded (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── doc-1: subdelegation.md records the ruling and the three paths ──────
echo "  6. doc: subdelegation.md records the ruling + three paths"
if grep -q "Depth-enforcement ruling (T321" "$DOC" \
   && grep -q "Ollama → DeepSeek is real, not hypothetical" "$DOC" \
   && grep -q "depth stamp travels" "$DOC"; then
    echo "    PASS: ruling, real-dispatch finding, and path-3 note all present"
else
    echo "    FAIL: ruling/paths not found in $DOC"
    FAIL=1
fi

# ── doc-2: subdelegation.md records the attribution rule ─────────────────
echo "  7. doc: subdelegation.md records the attribution rule (never self-report)"
if grep -q "Attribution never asks the model" "$DOC" \
   && grep -q "never from the model's self-report" "$DOC"; then
    echo "    PASS: attribution rule present"
else
    echo "    FAIL: attribution rule not found in $DOC"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-depth-enforcement: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-depth-enforcement: FAILURES ==="
    exit 1
fi