#!/usr/bin/env bash
# regression-provider-error-exit.sh — T934 controls for provider errors
#
# Short name: a provider refused service 20 times and the lane reported success.
#
# Landmark: advances L1 (the dashboard tells the truth) — a lane that could not run
# must not report the same exit code as one that ran.
#
# Controls:
#   null      : a worker that really runs → exit 0, tokens present
#   seeded    : a stubbed provider returning 429 → must NOT exit 0, must name the error

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../.."
FAIL=0

# T934: provider error must not exit 0. Distinguish three cases:
#   1. Worker ran and finished → exit 0 with tokens
#   2. Worker ran and was killed → exit 124 with kill reason
#   3. Worker was never served → provider errors in stderr, killed_by=provider-error

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t934-provider-XXXXXX)" || {
    echo "regression-provider-error-exit.sh: FATAL — scratch mktemp failed; refusing to run" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t934@test
git config user.name T934
echo base > README.md
mkdir -p docs untracked docs/infra/managent findings bin tools docs/epistemic
printf 'untracked/\n' > .gitignore

# ── helper: run a worker via tools/runner and capture result ──────────
run_worker() {
    local model="$1"
    local brief="$2"
    # Use runner with a small pi-based worker; the fixture injects stderr
    # provider errors we can check.
    local cmd=(tools/runner --ram-mb 256 --max-wall 60 --max-cpu 60
                --task-id T934 -- -p "$brief")
    "${cmd[@]}" 2>/tmp/t934-stderr.txt
    local rc=$?
    local tokens="0"
    # Check if tokens were captured
    if [ -f untracked/runs/T934.json ]; then
        tokens=$(python3 -c "
import json
try:
    with open('untracked/runs/T934.json') as f:
        r = json.load(f)
    t = r.get('tokens_in', 0)
    print(t if t is not None else 0)
except: print(0)
")
    fi
    local stderr_tail="$(tail -5 /tmp/t934-stderr.txt 2>/dev/null || true)"
    printf "model=%s rc=%d tokens=%s stderr_tail=%s\n" "$model" "$rc" "$tokens" "$stderr_tail"
    # Return: rc, tokens, stderr content
    printf '%d|%s|%s\n' "$rc" "$tokens" "$stderr_tail"
}

# ── null control: a worker that really runs → exit 0, tokens present ────
# This test uses a simple pi worker that completes successfully.
echo "=== null control: worker that really runs → exit 0, tokens present ==="
null_result=$(run_worker "pi" "Follow untracked/T934-null-control.md 2>/dev/null")
null_rc=$(echo "$null_result" | cut -d'|' -f1)
null_tokens=$(echo "$null_result" | cut -d'|' -f2)
echo "null rc=$null_rc tokens=$null_tokens"
if [ "$null_rc" != "0" ]; then
    echo "FAIL: null control expected rc=0, got $null_rc"
    FAIL=1
elif [ "$null_tokens" = "0" ]; then
    echo "FAIL: null control expected tokens present, got none"
    FAIL=1
else
    echo "PASS: null control — exit 0 with tokens present"
fi

# ── seeded-defect control: stubbed provider returning 429 → must NOT exit 0 ─
echo ""
echo "=== seeded-defect control: stubbed provider returning 429 → must NOT exit 0 ==="
# Create a fixture that simulates a provider returning 429
mkdir -p tools/fixtures
cat > tools/fixtures/refusal-429-provider.fixture << 'FIEND'
[runner] argv = pi --provider openrouter --model pi-v1 --mode json -p 'Follow untracked/T934-seeded-control.md 2>/dev/null'
[runner] guards: rss 256 MB, progress-timeout 60s (10'000), fallback: wall 60s cpu 60s (silent children), poll = 250 ms
[runner] process walker: ps (darwin)
[runner] task identity: T934 (source: MANAGENT_TASK_ID)
429: {"message":"Provider returned error","code":429,"metadata":{"raw":"stealth/ox-alpha is temporarily rate-limited upstream.","provider_name":"Stealth","limit_source":"upstream_provider_shared_pool"}}
Error: exit status 1
FIEND

seeded_result=$(run_worker "openrouter" "Follow untracked/T934-seeded-control.md 2>/dev/null")
seeded_rc=$(echo "$seeded_result" | cut -d'|' -f1)
seeded_tokens=$(echo "$seeded_result" | cut -d'|' -f2)
seeded_stderr=$(echo "$seeded_result" | cut -d'|' -f3)

echo "seeded rc=$seeded_rc tokens=$seeded_tokens"
echo "seeded stderr contains 429: $(echo "$seeded_stderr" | grep -c '429' || echo 0)"

# Check: seeded control must NOT exit 0
if [ "$seeded_rc" = "0" ]; then
    echo "FAIL: seeded control expected rc != 0 (provider error should prevent exit 0), got rc=0"
    FAIL=1
else
    echo "PASS: seeded control — exit != 0 as expected (provider error detected)"
fi

# Check: seeded control should have tokens absent or provider error reported
if [ "$seeded_tokens" != "0" ]; then
    echo "WARN: seeded control tokens=$seeded_tokens — expected tokens absent for provider error case"
fi

# Check: stderr should contain the 429 error message
if echo "$seeded_stderr" | grep -q '429'; then
    echo "PASS: seeded control stderr contains 429 error message"
else
    echo "FAIL: seeded control stderr should contain 429 error message"
    FAIL=1
fi

echo ""
if [ $FAIL -eq 0 ]; then
    echo "ALL CONTROLS PASSED"
else
    echo "SOME CONTROLS FAILED"
    exit 1
fi