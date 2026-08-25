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
# T527 (T428 Phase B, 2026-08-20): the bin/ollama-subagent wrapper is removed;
# the guarded Ollama path is bin/subagent --provider ollama. The controls below
# are unchanged in meaning — only the entry point moved.
#
# Controls (option b):
#   null-1   the ollama provider path at human depth (unset -> 1) is NOT refused
#            (--dry-run prints the command, RC 0)
#   null-2   the ollama provider path at depth 1 is NOT refused
#   seeded-1 the ollama provider path at the cap depth IS refused — this was
#            red pre-fix (no tool, no refusal) and is green post-fix
#   seeded-2 the ollama provider path fail-closes on an unreadable depth (refused)
#   seeded-3 bin/subagent's DeepSeek->DeepSeek refusal STILL fires at the cap
#            (the bar: the existing edge must still be guarded after the change)
#   doc-1    subdelegation.md records the ruling and the three paths
#   doc-2    subdelegation.md records the attribution rule (never self-report)
#
# All fixtures are synthetic and run against the live repo's bin/ + docs/. The
# T-ID branch of the dispatcher needs a synthetic bundle in untracked/.
# This script is NOT in the build graph; wiring it into `zig build test` is a
# separate row.
#
# Task: T321 · Role: worker · Model: glm-5.2 · Date: 2026-08-03
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19). The
# synthetic bundle ($BUNDLE) under untracked/ was previously removed only
# in the EXIT trap; a SIGKILLed run left it in the tree. T448 adds
# INT/TERM/HUP to the trap (safety net) and a start-up check that REFUSES
# to run if a fixture from a previous (killed) run is still present.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
# T527 (T428 Phase B): the bin/ollama-subagent wrapper is removed; the guarded
# Ollama path IS bin/subagent --provider ollama. Same controls, same semantics.
ollama_sub() { "$SUBAGENT" --provider ollama "$@"; }
# T913: every arm below dry-runs bin/subagent to assert DEPTH semantics — a
# deterministic property — but the dry-run reaches its command through the
# admission preview, whose verdict depends on host free memory at the moment
# of the run (observed 2026-08-25T04:5xZ: the pre-commit fast tier caught
# this script red on ARBITER WOULD REFUSE — glm-5.2:cloud now declares the
# wall-band 4608, up from the deleted provider-keyed 3328, so the refusal
# band widened).  The overrides keep the arms testing what they test;
# --dry-run records nothing anywhere (depth-cap arms 3/3c refuse at the
# depth gate BEFORE the preview, so the flags are inert there).
DEPTH_OVERRIDES=(--override-admission=t913-depth-arm --override-window-cooldown=t913-depth-arm)
ollama_sub() { "$SUBAGENT" --provider ollama "$@" "${DEPTH_OVERRIDES[@]}"; }
DOC="$ROOT/docs/infra/agents/subdelegation.md"
FAIL=0

# Synthetic bundle in untracked/ — the T-ID branch requires it
# T913: fixture id renumbered T996 -> T1025.  The pre-commit fast tier
# (T861) runs the subagent-coverage candidates CONCURRENTLY, and
# regression-ollama-dispatcher.sh also uses a T996 bundle — two live
# untracked/T996-*.md files made every subagent dry-run refuse with
# "expected one bundle for T996, found 2" (observed 2026-08-25T05:0xZ,
# reproduced by running both scripts in parallel).  T1025 is unused by
# any other regression script.
BUNDLE="$ROOT/untracked/T1025-regression-depth.md"
# T448: refuse to run if a previous run left live-tree residue behind.
# The pre-T448 `rm -f` here was exactly the silent-overwrite behaviour
# T448 calls out: a SIGKILLed previous run's bundle was quietly removed
# on the next run, hiding the evidence that a run was killed. The
# start-up check below REPLACES that rm -f — the file is preserved
# until the operator inspects and removes it by hand.
if [ -e "$BUNDLE" ]; then
    echo "regression-depth-enforcement.sh: REFUSED — stale fixture from a previous run:" >&2
    echo "    $BUNDLE" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
    echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
    echo "Remove the file by hand (after inspecting it is fixture-shaped and not yours)" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi
printf '<!--managent set=C deliverables=findings/T1025-test.json-->\n# T1025 — depth-enforcement test bundle\n' > "$BUNDLE"
# T448: trap on EXIT/INT/TERM/HUP — previously EXIT only. The startup
# check above is the load-bearing guard; this trap is the safety net.
cleanup() { rm -f "$BUNDLE" 2>/dev/null || true; }
trap cleanup EXIT INT TERM HUP

echo "=== depth-enforcement regression (T321, option b) ==="

# ── null-1: human depth (unset) is NOT refused ───────────────────────────
echo "  1. null: the ollama provider path at depth unset is NOT refused"
OUT=$( (unset WEIZIGO_AGENT_DEPTH; ollama_sub T1025 --model glm-5.2:cloud --dry-run) 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ollama launch pi --model glm-5.2:cloud"; then
    echo "    PASS: prints command, RC 0 (not refused)"
else
    echo "    FAIL: RC=$RC"; echo "$OUT" | head -3 | sed 's/^/      /'
    FAIL=1
fi

# ── null-2: depth 1 is NOT refused ──────────────────────────────────────
echo "  2. null: the ollama provider path at depth 1 is NOT refused"
OUT=$(WEIZIGO_AGENT_DEPTH=1 ollama_sub T1025 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^WEIZIGO_AGENT_DEPTH=2"; then
    echo "    PASS: stamps child depth 2, RC 0 (not refused)"
else
    echo "    FAIL: RC=$RC"; echo "$OUT" | head -3 | sed 's/^/      /'
    FAIL=1
fi

# ── seeded-1: the CAP depth (3) IS refused — recursion terminates ───────
# T431: the bound moved from 2 to 3 so a manager may delegate a manager. The
# bound itself is the principle and must still fire; only its value moved.
echo "  3. seeded: the ollama provider path at cap depth 3 IS refused"
OUT=$(WEIZIGO_AGENT_DEPTH=3 ollama_sub T1025 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at depth 3 (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── null-3 (T431): a MANAGER at depth 2 may dispatch, and stamps depth 3 ─
# This is the point of the change: a sprint console must be able to dispatch
# its own phase audits. Pre-T431 this was REFUSED, which is why sprints had
# to ask the human to paste their dispatches.
echo "  3b. null: the ollama provider path at manager depth 2 is NOT refused, stamps 3"
OUT=$(WEIZIGO_AGENT_DEPTH=2 ollama_sub T1025 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^WEIZIGO_AGENT_DEPTH=3"; then
    echo "    PASS: manager may dispatch; child stamped depth 3"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -2 | tr '\n' ' ')"
    FAIL=1
fi

# ── null-4 (T431): depth INCREMENTS, it is not stamped flat ─────────────
# Pre-T431 every child was stamped 2 regardless of the parent's depth, so
# depth carried no information about how deep the chain actually was.
echo "  3c. null: depth increments (1 -> 2), not stamped flat"
OUT=$(WEIZIGO_AGENT_DEPTH=1 "$SUBAGENT" --provider deepseek T1025 --dspro --dry-run "${DEPTH_OVERRIDES[@]}" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^WEIZIGO_AGENT_DEPTH=2"; then
    echo "    PASS: depth-1 parent stamps child 2"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -2 | tr '\n' ' ')"
    FAIL=1
fi

# ── seeded-2: unreadable depth fail-closes to worker ────────────────────
echo "  4. seeded: the ollama provider path fail-closes on an unreadable depth"
OUT=$(WEIZIGO_AGENT_DEPTH=garbage ollama_sub T1025 --model glm-5.2:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: garbage depth treated as worker (RC=$RC)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── seeded-3: bin/subagent DeepSeek->DeepSeek refusal still fires (bar) ──
echo "  5. seeded: bin/subagent STILL refuses DeepSeek dispatch at cap depth 3"
OUT=$(WEIZIGO_AGENT_DEPTH=3 "$SUBAGENT" --provider deepseek T1025 --dspro --dry-run "${DEPTH_OVERRIDES[@]}" 2>&1)
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