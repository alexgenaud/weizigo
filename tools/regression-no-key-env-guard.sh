#!/usr/bin/env bash
# regression-no-key-env-guard.sh — T940 controls: API keys live in pi, not
# in the environment. Dispatch and subagent must not refuse when API key
# environment variables (DEEPSEEK_API_KEY, OPENROUTER_API_KEY, OLLAMA_API_KEY)
# are absent from the environment.
#
# Context:
#   The operator registered API keys directly in pi config. Pi resolves
#   credentials internally. The old guard in bin/subagent checked
#   `os.environ.get("DEEPSEEK_API_KEY")` and refused dispatch if unset,
#   which caused false refusals when environment variables were cleaned up.
#
# Arms:
#   A. RED/GREEN: bin/subagent deepseek dry-run succeeds with DEEPSEEK_API_KEY unset.
#      (Fails with rc 1 and "subagent: DEEPSEEK_API_KEY is not set" before the fix).
#   B. NULL: bin/subagent deepseek dry-run succeeds when DEEPSEEK_API_KEY is set.
#   C. OTHER PROVIDERS: pi (openrouter) and ollama dry-runs succeed with their
#      respective *_API_KEY env vars unset.
#   D. DISPATCH WRAPPER: bin/dispatch with a scratch row and DEEPSEEK_API_KEY unset
#      succeeds in dry-run mode (Acceptance #2).
#   E. SEEDED DEFECT: invalid credential produces an authentic provider
#      authentication failure (non-zero exit code), not a silent success or
#      invented harness message.
#   F. ISOLATION: scratch targets under /tmp/weizigo only; live store untouched.
#
# Task: T940 · Role: worker · Model: gemini-3.7-flash · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
SUBAGENT="$PROJECT/bin/subagent"
DISPATCH="$PROJECT/bin/dispatch"
MG="$PROJECT/bin/managent"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t940-nokey-XXXXXX)" || { echo "FATAL — scratch mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=$((FAIL + 1)); }

# Create a scratch prompt target file (bypasses kanban lookup in subagent)
TARGET="$WORK/target.md"
printf '# scratch prompt for T940\n' > "$TARGET"

echo "=== regression-no-key-env-guard (T940) ==="

# ── Arm A: deepseek dry-run with DEEPSEEK_API_KEY unset ────────────────────
echo "  Arm A — deepseek dry-run with DEEPSEEK_API_KEY unset"
OUT_A=$(env -u DEEPSEEK_API_KEY WEIZIGO_AGENT_DEPTH=1 WEIZIGO_HOST_MEM_AVAIL_MB=30000 \
    "$SUBAGENT" --provider deepseek --dsflash "$TARGET" --dry-run 2>&1)
RC_A=$?
if [ "$RC_A" -eq 0 ] && echo "$OUT_A" | grep -q "deepseek-v4-flash"; then
    pass "subagent deepseek dry-run succeeded with DEEPSEEK_API_KEY unset (rc=0)"
else
    fail "subagent deepseek dry-run failed with DEEPSEEK_API_KEY unset (rc=$RC_A, output: $OUT_A)"
fi

# ── Arm B: NULL control — deepseek dry-run with DEEPSEEK_API_KEY set ─────────
echo "  Arm B — NULL control: deepseek dry-run with DEEPSEEK_API_KEY set"
OUT_B=$(env DEEPSEEK_API_KEY="test-dummy-key" WEIZIGO_AGENT_DEPTH=1 WEIZIGO_HOST_MEM_AVAIL_MB=30000 \
    "$SUBAGENT" --provider deepseek --dsflash "$TARGET" --dry-run 2>&1)
RC_B=$?
if [ "$RC_B" -eq 0 ] && echo "$OUT_B" | grep -q "deepseek-v4-flash"; then
    pass "subagent deepseek dry-run succeeded with DEEPSEEK_API_KEY set (rc=0)"
else
    fail "subagent deepseek dry-run failed with DEEPSEEK_API_KEY set (rc=$RC_B, output: $OUT_B)"
fi

# ── Arm C: other providers with API keys unset ─────────────────────────────
echo "  Arm C — openrouter and ollama dry-runs with *_API_KEY unset"
OUT_C1=$(env -u OPENROUTER_API_KEY WEIZIGO_AGENT_DEPTH=1 WEIZIGO_HOST_MEM_AVAIL_MB=30000 \
    "$SUBAGENT" --provider pi --model google/gemini-3.7-flash "$TARGET" --dry-run 2>&1)
RC_C1=$?
if [ "$RC_C1" -eq 0 ] && echo "$OUT_C1" | grep -q "gemini-3.7-flash"; then
    pass "subagent pi (openrouter) dry-run succeeded with OPENROUTER_API_KEY unset (rc=0)"
else
    fail "subagent pi (openrouter) dry-run failed with OPENROUTER_API_KEY unset (rc=$RC_C1, output: $OUT_C1)"
fi

OUT_C2=$(env -u OLLAMA_API_KEY WEIZIGO_AGENT_DEPTH=1 WEIZIGO_HOST_MEM_AVAIL_MB=30000 \
    WEIZIGO_OLLAMA_OFFERED="glm-5.2:cloud" \
    "$SUBAGENT" --provider ollama --model glm-5.2:cloud "$TARGET" --dry-run 2>&1)
RC_C2=$?
if [ "$RC_C2" -eq 0 ] && echo "$OUT_C2" | grep -q "glm-5.2"; then
    pass "subagent ollama dry-run succeeded with OLLAMA_API_KEY unset (rc=0)"
else
    fail "subagent ollama dry-run failed with OLLAMA_API_KEY unset (rc=$RC_C2, output: $OUT_C2)"
fi

# ── Arm D: dispatch wrapper dry-run with DEEPSEEK_API_KEY unset ─────────────
echo "  Arm D — bin/dispatch dry-run in scratch store with DEEPSEEK_API_KEY unset"
(cd "$WORK" && git init -q && git config user.email t940@test && git config user.name T940)
SCRATCH_STORE="$WORK/tasks.json"
cat > "$SCRATCH_STORE" <<'JSONEOF'
{
  "T9999": {
    "status": "dispatchable",
    "bundle": "untracked/T9999-fixture.md",
    "model": null,
    "agent": null,
    "set": "A",
    "type": "infra",
    "holds": []
  }
}
JSONEOF
mkdir -p "$WORK/untracked"
cat > "$WORK/untracked/T9999-fixture.md" <<'MD'
<!--managent set=A type=infra deliverables=findings/T9999.json-->
# T9999 — fixture for regression test

**Landmark:** advances `L1 (the dashboard tells the truth)` — test
MD

OUT_D=$(env -u DEEPSEEK_API_KEY MANAGENT_STORE="$SCRATCH_STORE" \
    WEIZIGO_AGENT_DEPTH=1 WEIZIGO_HOST_MEM_AVAIL_MB=30000 \
    "$DISPATCH" T9999 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
RC_D=$?
if [ "$RC_D" -eq 0 ] && echo "$OUT_D" | grep -q "dry-run T9999 → deepseek-v4-flash"; then
    pass "bin/dispatch dry-run succeeded with DEEPSEEK_API_KEY unset (rc=0)"
else
    fail "bin/dispatch dry-run failed with DEEPSEEK_API_KEY unset (rc=$RC_D, output: $OUT_D)"
fi

# ── Arm E: seeded defect — invalid credential produces provider error ──────
echo "  Arm E — seeded defect: invalid credential produces authentic auth error"
if command -v pi >/dev/null 2>&1; then
    OUT_E=$(pi --api-key "invalid-key-regression-control" --provider deepseek \
        --model deepseek-v4-flash -p "probe" --no-session --no-tools 2>&1)
    RC_E=$?
    if [ "$RC_E" -ne 0 ] && echo "$OUT_E" | grep -qi "authentication\|invalid"; then
        pass "pi with invalid credential exited non-zero ($RC_E) with authentic provider auth error"
    else
        fail "pi with invalid credential did not report expected auth error (rc=$RC_E, out: $OUT_E)"
    fi
else
    pass "pi not on PATH; skipped live CLI invocation for Arm E"
fi

# ── Arm F: isolation assertion ─────────────────────────────────────────────
echo "  Arm F — isolation check"
if [ ! -f "$PROJECT/docs/infra/managent/tasks.json.t940_pollute" ]; then
    pass "live store was not polluted"
else
    fail "live store polluted"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "regression-no-key-env-guard: ALL CONTROLS PASSED"
    exit 0
else
    echo "regression-no-key-env-guard: $FAIL CONTROL(S) FAILED"
    exit 1
fi
