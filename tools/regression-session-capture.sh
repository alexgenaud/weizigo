#!/usr/bin/env bash
# regression-session-capture.sh — controls for T552 (the resumable session
# handle, captured at dispatch beside the token counts).
#
# The gap (T552, 2026-08-20): a finished lane's directory holds out.md,
# out.sanitized.md and trailer.log — and no session id.  Every `claude -p`
# / pi invocation is one-shot: it answers, exits, and its reasoning is
# unreachable; asking a lane "why did you decide X?" means dispatching a
# fresh instance to read the artifact as a stranger.  We were already 90%
# of the way there: bin/subagent passes `--output-format json` (T521, token
# capture), and that envelope carries a session identifier the parser read
# past.  This row records it — same three surfaces as the token counts
# (run record, lane trailer, ledger line), same null-with-a-reason rule
# for families that offer no resumable handle.
#
# The envelope parse stays SINGLE-SOURCED in tools/token-capture.py
# parse_claude_envelope() (the T517 lesson: never a second parser); the
# runner reads one more field out of the meta it already gets.
#
# Arms (synthetic shims in a scratch repo under /tmp/weizigo — never the
# live tree, never real credentials, no tokens spent):
#
#   A. envelope parse   a claude envelope WITH a session_id yields the
#                       handle; one WITHOUT yields null + a flag saying
#                       the field was absent; garbage yields neither —
#                       nothing is ever invented
#   B. seeded, e2e      fake-claude shim whose envelope carries a session
#                       id -> the id appears in the run record, the
#                       trailer line (`[runner] session_id=...`, the
#                       bakeoff lane record), and the ledger line.  RED
#                       against the pre-T552 code (quoted in the findings).
#   C. null, e2e        fake-claude shim whose envelope has NO session
#                       field -> recorded null with a reason, never blank,
#                       nothing invented
#   D. null, pi lane    a fake pi shim (no envelope at all) -> null with a
#                       reason naming the family; the lane's stdout and
#                       token-missing behaviour are unchanged (a normal
#                       dispatch is unaffected beyond the extra field)
#   E. resume (manual)  a captured handle is only worth anything if it
#                       resumes.  The round trip — dispatch, exit, resume
#                       the captured id, get a coherent continuation — is
#                       proven irl against real claude and real pi (see
#                       findings/T552-session-capture.json).  Automation
#                       here would need real credentials, which these
#                       controls never touch (T521 rule), so the arm is a
#                       documented procedure, not an automated check.
#
# Task: T552 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
RUNNER="$ROOT/tools/runner"
TOOL="$ROOT/tools/token-capture.py"
FAIL=0

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t552-session-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q
git config user.email t552@test
git config user.name T552
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

echo "=== regression-session-capture (T552) ==="

if ! test -f "$TOOL"; then
    echo "FATAL: $TOOL missing — the instrument must exist"
    exit 1
fi

# ── shims (never real binaries, never credentials) ─────────────────────────
# A fake `claude -p --output-format json`: the v2.1.237 envelope shape
# (recorded irl 2026-08-20) WITH a top-level session_id — the resumable
# handle.
cat > fake-claude <<'SHIM'
#!/usr/bin/env python3
import json, sys
sys.stdout.write(json.dumps({
    "type": "result", "subtype": "success", "is_error": False,
    "session_id": "sess-552-seeded-abc123",
    "result": "T552-E2E nonce-echo ok",
    "num_turns": 1, "stop_reason": "end_turn",
    "usage": {
        "input_tokens": 11, "output_tokens": 22,
        "cache_read_input_tokens": 33, "cache_creation_input_tokens": 44,
        "output_tokens_details": {"thinking_tokens": 5},
        "service_tier": "standard",
    },
}) + "\n")
sys.exit(0)
SHIM

# The same envelope WITHOUT the session_id field — the null control: a
# shape change (or an error envelope) must record null + reason, never a
# blank, never an invented id.
cat > fake-claude-nosession <<'SHIM'
#!/usr/bin/env python3
import json, sys
sys.stdout.write(json.dumps({
    "type": "result", "subtype": "success", "is_error": False,
    "result": "T552-NULL no handle",
    "num_turns": 1, "stop_reason": "end_turn",
    "usage": {
        "input_tokens": 1, "output_tokens": 2,
        "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0,
        "output_tokens_details": {"thinking_tokens": 0},
    },
}) + "\n")
sys.exit(0)
SHIM

# A fake `pi` lane: plain text, no structured envelope — the pi/ollama
# reality.  pi persists its session to disk but never prints the id.
cat > fake-pi <<'SHIM'
#!/usr/bin/env python3
import sys
sys.stdout.write("plain lane output\n")
sys.stderr.write("pi: some diagnostic\n")
sys.exit(0)
SHIM

chmod +x fake-claude fake-claude-nosession fake-pi

# ── A. envelope parse (unit arm, against the real instrument) ──────────────
echo "  A. envelope parse: session_id surfaced; absent = null+flag; garbage = neither"
A_OUT=$(python3 - "$TOOL" <<'PYEOF'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("tc", sys.argv[1])
tc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tc)
# seeded: envelope WITH session_id
env = {"type": "result", "subtype": "success", "result": "hi",
       "session_id": "sess-552-seeded-abc123", "is_error": False,
       "usage": {"input_tokens": 1, "output_tokens": 2,
                 "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}
text, usage, meta = tc.parse_claude_envelope(json.dumps(env))
assert text == "hi" and usage["output"] == 2, (text, usage)
assert meta["session_id"] == "sess-552-seeded-abc123", meta
assert meta["session_id_present"] is True, meta
# null: same envelope WITHOUT the field
env2 = dict(env); del env2["session_id"]
_, _, meta2 = tc.parse_claude_envelope(json.dumps(env2))
assert meta2["session_id"] is None, meta2
assert meta2["session_id_present"] is False, meta2
# garbage -> neither, never invented
t4, u4, meta4 = tc.parse_claude_envelope("not json at all")
assert t4 == "not json at all" and u4 is None, (t4, u4)
assert meta4["session_id"] is None and meta4["session_id_present"] is False, meta4
print("OK")
PYEOF
)
if [ "$A_OUT" = "OK" ]; then
    pass "envelope parse surfaces session_id; absent is null+flag; garbage invents nothing"
else
    fail "envelope parse: $A_OUT"
fi

# ── B. seeded claude lane e2e: session id lands on all three surfaces ─────
echo "  B. seeded claude lane: run record + trailer + ledger carry the session id"
export MANAGENT_TASK_ID=T552SEED
OUT_B=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-claude -p 'hi' --model claude-sonnet-5 --output-format json 2>"$WORK/claude.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "seeded claude lane runner rc=$RC"; sed 's/^/    | /' "$WORK/claude.err" | head -20
else
    # stdout must still be the UNWRAPPED text (no behaviour change)
    if [ "$OUT_B" = "T552-E2E nonce-echo ok" ]; then
        pass "lane stdout is the unwrapped result text (unchanged)"
    else
        fail "lane stdout unwrap: got '$OUT_B'"
    fi
    # trailer line (the bakeoff lane record: trailer.log captures stderr)
    if grep -q "\[runner\] session_id=sess-552-seeded-abc123" "$WORK/claude.err"; then
        pass "trailer carries session_id=sess-552-seeded-abc123"
    else
        fail "trailer session line missing"; grep "session" "$WORK/claude.err" | sed 's/^/    | /'
    fi
    # run record carries the handle
    REC="$WORK/untracked/runs/T552SEED.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('session_id')=='sess-552-seeded-abc123', d
assert d.get('session_reason') is None, d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "run record carries session_id (reason null)"
    else
        fail "run record session missing"; cat "$REC" 2>/dev/null | head -5
    fi
    # ledger line carries the handle
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && grep -q '"task": "T552SEED"' "$LED" \
       && grep -q '"session_id": "sess-552-seeded-abc123"' "$LED"; then
        pass "ledger line carries session_id"
    else
        fail "ledger session missing"; cat "$LED" 2>/dev/null | head -5
    fi
fi

# ── C. null claude lane e2e: envelope without the field → null + reason ───
echo "  C. null claude lane: no session field -> recorded null with a reason, nothing invented"
export MANAGENT_TASK_ID=T552NULL
OUT_C=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-claude-nosession -p 'hi' --model claude-sonnet-5 --output-format json 2>"$WORK/claude-null.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "null claude lane runner rc=$RC"; sed 's/^/    | /' "$WORK/claude-null.err" | head -20
else
    REC="$WORK/untracked/runs/T552NULL.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('session_id') is None, d
assert d.get('session_reason'), d
# nothing invented: the ONLY session_id value in the record is the null
assert '\"session_id\": null' in json.dumps(d), d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "run record: session_id null + explicit reason, no invented id"
    else
        fail "null run record"; cat "$REC" 2>/dev/null | head -5
    fi
    if grep -q "\[runner\] session: no handle — " "$WORK/claude-null.err"; then
        pass "trailer reports session: no handle with a reason"
    else
        fail "null trailer session line"; grep "session" "$WORK/claude-null.err" | sed 's/^/    | /'
    fi
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && python3 -c "
import json,sys
for line in open('$LED'):
    e=json.loads(line)
    if e.get('task')=='T552NULL':
        assert e.get('session_id') is None, e
        assert e.get('session_reason'), e
        print('OK')" 2>/dev/null | grep -q OK; then
        pass "ledger: session_id null + reason, never blank"
    else
        fail "null ledger"; cat "$LED" 2>/dev/null | head -5
    fi
fi

# ── D. pi lane e2e: no envelope -> family-naming null; lane unchanged ─────
echo "  D. pi lane: null + reason naming the family; stdout + tokens unchanged"
export MANAGENT_TASK_ID=T552PI
OUT_D=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-pi --provider deepseek --model deepseek-v4-pro -p 'hi' 2>"$WORK/pi.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "pi lane runner rc=$RC"; sed 's/^/    | /' "$WORK/pi.err" | head -10
else
    if [ "$OUT_D" = "plain lane output" ]; then
        pass "pi lane stdout forwarded unchanged"
    else
        fail "pi lane stdout: got '$OUT_D'"
    fi
    REC="$WORK/untracked/runs/T552PI.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('session_id') is None, d
r = d.get('session_reason') or ''
assert 'pi' in r.lower(), d   # the reason names the family honestly
assert d.get('tokens_in') is None and d.get('tokens_missing_reason'), d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "pi run record: session null + family-naming reason; token missing unchanged"
    else
        fail "pi run record"; cat "$REC" 2>/dev/null | head -5
    fi
    if grep -q "\[runner\] session: no handle — " "$WORK/pi.err"; then
        pass "pi trailer reports session: no handle with a reason"
    else
        fail "pi trailer session line"; grep "session" "$WORK/pi.err" | sed 's/^/    | /'
    fi
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && python3 -c "
import json,sys
for line in open('$LED'):
    e=json.loads(line)
    if e.get('task')=='T552PI':
        assert e.get('session_id') is None and e.get('session_reason'), e
        assert e.get('tokens_in') is None and e.get('missing_reason'), e
        print('OK')" 2>/dev/null | grep -q OK; then
        pass "pi ledger: session null + reason; token missing unchanged"
    else
        fail "pi ledger"; cat "$LED" 2>/dev/null | head -5
    fi
fi

# ── E. resume (manual arm) ─────────────────────────────────────────────────
echo "  E. resume round trip: MANUAL — proven irl, see findings/T552-session-capture.json"
echo "      (automating needs real credentials, which these controls never touch)"
echo "      claude: dispatch -> envelope session_id -> 'claude -p -r <id>' resumes the"
echo "      same session with a coherent continuation (proven 2026-08-20, haiku probe)."
echo "      pi: dispatch -> session JSONL uuid under ~/.pi/agent/sessions/<cwd-slug>/ ->"
echo "      'pi --session <uuid>' resumes (proven 2026-08-20, qwen3.8:27b-mlx probe)."

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-session-capture: ALL PASS ==="
else
    echo "=== regression-session-capture: FAILURES ==="
    exit 1
fi
