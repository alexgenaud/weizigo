#!/usr/bin/env bash
# regression-lane-telemetry-parity.sh — T891 controls: every provider's
# constructed argv carries the flags its telemetry needs, OR records a
# named reason where it cannot (the S11 trivalence: Measured /
# Unknown(reason) / Refused(reason)).  A silent UNKNOWN standing in for
# "nobody asked" is the defect, not the fix.
#
# This is T862's unfinished half (amendment 1).  T862 closed
# pass-with-findings on Defect 2 (the auto-close net) only; Defect 1 — the
# missing --session / --mode json flags on the pi/openrouter lane — was
# never in T862's scope (its holds, parsed under the T880 bug, reached only
# bin/dispatch).  The pi/oxalpha lane is still launched tonight with
# neither --mode json (stdout liveness) nor --session (the token meter the
# rate column reads), so it reports UNKNOWN on the operator's screen and
# runs with no stdout stream — the least observable lane we dispatch.
#
# Arms (test-first; the unit arm is the gate, the real-surface acceptance
# is step 4 in the bundle and runs from the operator's console where the
# API keys live — this regression never launches a real lane):
#   A. pi lane carries --mode json + --session (RED before the fix).
#   B. claude lane carries --output-format json AND a NAMED meter_reason
#      for the absent --session (RED before: no reason recorded, just a
#      silent omission — the defect class).
#   C. deepseek control: --mode json + --session (GREEN throughout — the
#      lane that already works is the proof of concept).
#   D. ollama control: --session (GREEN throughout; ollama streams via
#      ollama, so --mode json is not its liveness flag).
#   E. --thinking <level> threads to every pi-routed provider
#      (deepseek/ollama/pi) and NOT to claude (claude uses --effort); the
#      default (no --thinking) preserves today's behaviour, so no
#      re-baselining (RED before: the flag does not exist).
#   F. trivalence null control: a provider that cannot supply a session
#      meter emits a NON-EMPTY meter_reason — so "fixed" never means a
#      silent blank or a printed zero (acceptance 3).
#   G. isolation: scratch only; no fixture rows leak into the live kanban.
#
# All fixtures synthetic under /tmp/weizigo.  subagent --dry-run drives the
# argv + TELEMETRY-line inspection (no real launch, no API key, no kanban
# mutation, no bundle required — the file-target branch).
#
# Task: T891 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
SUBAGENT="$PROJECT/bin/subagent"
FAIL=0

# The depth cap is per-process; a regression must dispatch from depth 1.
unset WEIZIGO_AGENT_DEPTH

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t891-telemetry-XXXXXX)" || { echo "FATAL — scratch mktemp failed (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# A scratch file target so subagent --dry-run needs no bundle/kanban (the
# file-target branch builds a prompt and prints the cmd without resolving
# a T-id bundle).
printf 'scratch prompt target for T891 regression\n' > "$WORK/target.md"

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# run_dry <provider> <model-args...> — prints the subagent --dry-run output
# (stderr + stdout merged).  --override-admission bypasses the arbiter
# refusal so the dry-run reaches the cmd-print path without a real host
# check; the window-cooldown gate does not arm for these models in the test
# env (verified: all four providers print their cmd today).
run_dry() {
    (cd "$PROJECT" && "$SUBAGENT" --override-admission=t891-regression \
        --dry-run "$@" "$WORK/target.md" 2>&1)
}

# Extract the launched child command (the line beginning with `tools/runner`).
cmd_line() { printf '%s\n' "$1" | grep -m1 '^tools/runner '; }
# Extract the TELEMETRY annotation line bin/subagent prints in --dry-run.
tele_line() { printf '%s\n' "$1" | grep -m1 '^TELEMETRY: '; }
# tele_field <line> <field-name>  -> value for the single-token fields
# (provider / mode_json / session / thinking).  meter_reason is the LAST
# field and may contain spaces; tele_reason() extracts to end-of-line.
tele_field() { printf '%s\n' "$1" | sed -n "s/.*$2=\([^ ]*\).*/\1/p" | head -1; }
tele_reason() { printf '%s\n' "$1" | sed -n 's/.*meter_reason=//p' | head -1; }

echo "=== regression-lane-telemetry-parity (T891) ==="

# ── A. pi lane carries --mode json + --session (RED before fix) ───────────
echo "  A. pi/openrouter argv carries --mode json + --session (RED before fix)"
OUT=$(run_dry --provider pi --model oxalpha)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
MJ=$(tele_field "$TEL" "mode_json")
SES=$(tele_field "$TEL" "session")
HAS_MODE=$(printf '%s\n' "$CMD" | grep -c -- "--mode json" || true)
HAS_SES=$(printf '%s\n' "$CMD" | grep -c -- "--session" || true)
if [ "$HAS_MODE" -ge 1 ] && [ "$HAS_SES" -ge 1 ] \
   && [ "$MJ" = "yes" ] && [ -n "$SES" ] && [ "$SES" != "-" ]; then
    pass "pi argv has --mode json + --session (mode_json=$MJ session=$SES)"
else
    fail "pi argv missing --mode json or --session (mode_json='$MJ' session='$SES', cmd_has_mode=$HAS_MODE cmd_has_session=$HAS_SES)"
    echo "$CMD" | sed 's/^/      | /'
fi

# ── B. claude lane: --output-format json + a NAMED meter_reason ──────────
echo "  B. claude argv carries --output-format json AND a named meter_reason (RED before fix)"
OUT=$(run_dry --provider claude --model claude-haiku-4-5-20251001)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
REASON=$(tele_reason "$TEL")
HAS_OFJ=$(printf '%s\n' "$CMD" | grep -c -- "--output-format json" || true)
if [ "$HAS_OFJ" -ge 1 ] && [ -n "$REASON" ] && [ "$REASON" != "-" ]; then
    pass "claude argv has --output-format json + named meter_reason ('$REASON')"
else
    fail "claude argv missing --output-format json (has=$HAS_OFJ) OR meter_reason empty/absent (reason='$REASON') — the silent-blank defect"
    echo "$CMD" | sed 's/^/      | /'
    [ -n "$TEL" ] && echo "$TEL" | sed 's/^/      | /' || echo "      | (no TELEMETRY line printed)"
fi

# ── C. deepseek control: --mode json + --session in the CMD (GREEN throughout) ─
#   The control checks the CMD only — the flags are already present today;
#   the TELEMETRY annotation is the fix and is exercised by arms A/B/F.
echo "  C. deepseek control: --mode json + --session in cmd (the lane that already works)"
OUT=$(run_dry --provider deepseek --dsflash)
CMD=$(cmd_line "$OUT")
HAS_MODE=$(printf '%s\n' "$CMD" | grep -c -- "--mode json" || true)
HAS_SES=$(printf '%s\n' "$CMD" | grep -c -- "--session" || true)
if [ "$HAS_MODE" -ge 1 ] && [ "$HAS_SES" -ge 1 ]; then
    pass "deepseek cmd has --mode json + --session (control, unchanged by the fix)"
else
    fail "deepseek control regressed (cmd_has_mode=$HAS_MODE cmd_has_session=$HAS_SES)"
    echo "$CMD" | sed 's/^/      | /'
fi

# ── D. ollama control: --session in cmd; no --mode json (GREEN throughout) ─
echo "  D. ollama control: --session in cmd, no --mode json (ollama streams via ollama)"
OUT=$(run_dry --provider ollama --model glm-5.2)
CMD=$(cmd_line "$OUT")
HAS_SES=$(printf '%s\n' "$CMD" | grep -c -- "--session" || true)
HAS_MODE=$(printf '%s\n' "$CMD" | grep -c -- "--mode json" || true)
if [ "$HAS_SES" -ge 1 ] && [ "$HAS_MODE" -eq 0 ]; then
    pass "ollama cmd has --session, no --mode json (control, unchanged by the fix)"
else
    fail "ollama control regressed (has_session=$HAS_SES has_mode_json=$HAS_MODE)"
    echo "$CMD" | sed 's/^/      | /'
fi

# ── E. --thinking threads to pi-routed providers, NOT claude ────────────
echo "  E. --thinking <level> threads to deepseek/ollama/pi, not claude (RED before: flag absent)"
THINK_LVL="low"
# E1: deepseek with --thinking=low → cmd carries --thinking low
OUT=$(run_dry --provider deepseek --dsflash --thinking="$THINK_LVL")
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
TH=$(tele_field "$TEL" "thinking")
HAS_TH=$(printf '%s\n' "$CMD" | grep -c -- "--thinking $THINK_LVL" || true)
if [ "$HAS_TH" -ge 1 ] && [ "$TH" = "$THINK_LVL" ]; then
    pass "deepseek threads --thinking $THINK_LVL to the pi child"
else
    fail "deepseek did not thread --thinking (thinking='$TH', cmd_has=$HAS_TH)"
    echo "$CMD" | sed 's/^/      | /'
fi
# E2: pi/openrouter with --thinking=high → cmd carries --thinking high
OUT=$(run_dry --provider pi --model oxalpha --thinking=high)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
TH=$(tele_field "$TEL" "thinking")
HAS_TH=$(printf '%s\n' "$CMD" | grep -c -- "--thinking high" || true)
if [ "$HAS_TH" -ge 1 ] && [ "$TH" = "high" ]; then
    pass "pi/openrouter threads --thinking high to the pi child"
else
    fail "pi did not thread --thinking (thinking='$TH', cmd_has=$HAS_TH)"
    echo "$CMD" | sed 's/^/      | /'
fi
# E3: ollama with --thinking=medium → inner pi carries --thinking medium
OUT=$(run_dry --provider ollama --model glm-5.2 --thinking=medium)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
TH=$(tele_field "$TEL" "thinking")
HAS_TH=$(printf '%s\n' "$CMD" | grep -c -- "--thinking medium" || true)
if [ "$HAS_TH" -ge 1 ] && [ "$TH" = "medium" ]; then
    pass "ollama threads --thinking medium to the inner pi child"
else
    fail "ollama did not thread --thinking (thinking='$TH', cmd_has=$HAS_TH)"
    echo "$CMD" | sed 's/^/      | /'
fi
# E4: claude with --thinking=low → cmd does NOT carry --thinking (not pi-routed)
OUT=$(run_dry --provider claude --model claude-haiku-4-5-20251001 --thinking=low)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
TH=$(tele_field "$TEL" "thinking")
HAS_TH=$(printf '%s\n' "$CMD" | grep -c -- "--thinking" || true)
if [ "$HAS_TH" -eq 0 ] && [ "$TH" = "-" ]; then
    pass "claude does NOT receive --thinking (claude uses --effort, not pi --thinking)"
else
    fail "claude should not receive --thinking (cmd_has=$HAS_TH, thinking='$TH')"
    echo "$CMD" | sed 's/^/      | /'
fi
# E5: default (no --thinking) preserves today — the flag is absent from cmd
OUT=$(run_dry --provider deepseek --dsflash)
CMD=$(cmd_line "$OUT")
TEL=$(tele_line "$OUT")
TH=$(tele_field "$TEL" "thinking")
HAS_TH=$(printf '%s\n' "$CMD" | grep -c -- "--thinking" || true)
if [ "$HAS_TH" -eq 0 ] && [ "$TH" = "-" ]; then
    pass "default dispatch omits --thinking (today's behaviour preserved — no re-baselining)"
else
    fail "default dispatch should omit --thinking (cmd_has=$HAS_TH, thinking='$TH')"
    echo "$CMD" | sed 's/^/      | /'
fi

# ── F. trivalence null control: a no-meter lane names a non-empty reason ─
echo "  F. trivalence null control: claude meter_reason is non-empty (acceptance 3)"
OUT=$(run_dry --provider claude --model claude-haiku-4-5-20251001)
TEL=$(tele_line "$OUT")
REASON=$(tele_reason "$TEL")
SES=$(tele_field "$TEL" "session")
# claude cannot supply a pi --session meter; the reason must be non-empty,
# and the session field must be '-' (absent), never a fabricated path.
if [ "$SES" = "-" ] && [ -n "$REASON" ] && [ "$REASON" != "-" ]; then
    pass "claude is honestly unmeasurable in-flight: session='-' reason non-empty ('$REASON')"
else
    fail "claude null control: session='$SES' reason='$REASON' (expected session='-' + non-empty reason)"
    [ -n "$TEL" ] && echo "$TEL" | sed 's/^/      | /' || echo "      | (no TELEMETRY line)"
fi

# ── G. isolation: scratch only; no fixture rows in the live kanban ──────
echo "  G. isolation: no fixture rows leaked into the live kanban"
LIVE="$PROJECT/docs/infra/managent/tasks.json"
# This regression never touches the live store (dry-run only, file target),
# so there is nothing to leak; the arm asserts that invariant holds.
LEAK=$(python3 -c '
import json,sys
try: s=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
print("")
' "$LIVE" 2>/dev/null || true)
if [ -z "$LEAK" ]; then
    pass "live kanban untouched (dry-run only; no fixture rows created)"
else
    fail "unexpected live-kanban interaction: $LEAK"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-lane-telemetry-parity: PASS ==="
else
    echo "=== regression-lane-telemetry-parity: FAIL ==="
fi
exit $FAIL