#!/usr/bin/env bash
# regression-token-capture.sh — controls for tools/token-capture.py and the
# T521 capture path (tools/runner + bin/subagent + tools/bakeoff.sh).
#
# G1 is RUN-TIME, NOT RETROACTIVE (D043, 2026-08-20): tokens are captured at
# dispatch or LOST — every prior race ended with n=0 readings because the
# capture happened by seat memory after the fact, or not at all.  This
# regression pins the MECHANICAL capture path against synthetic fixtures
# (fake claude/pi shims in a scratch repo under /tmp/weizigo — never the
# live tree, never real credentials, no tokens spent):
#
#   A. envelope parse   a synthetic `claude -p --output-format json`
#                       envelope (the v2.1.237 ground-truth shape, recorded
#                       irl on 2026-08-20) extracts BOTH the result text and
#                       the usage counts; tokens_in == input+cache_read,
#                       tokens_out == output; an is_error envelope with zero
#                       usage is a missing-with-reason, never a 0/0 reading
#   B. claude lane e2e  tools/runner wrapping a fake claude shim: the lane's
#                       run record carries tokens_in/tokens_out/source, the
#                       trailer prints `[runner] tokens_in=.. tokens_out=..`
#                       (the bakeoff G1 trailer path), the lane stdout is the
#                       UNWRAPPED text (never the envelope), the ledger gets a
#                       reading, and the raw envelope is teed to disk
#   C. pi lane e2e      a fake pi shim: raw stdout+stderr are teed per task
#                       to disk (any usage lines survive), and the ledger
#                       records tokens missing EXPLICITLY with a reason —
#                       never estimated, never a blank cell
#   D. G1 join          token-capture.py --json --cwd <root> --since <date>
#                       builds the models map the bakeoff joins on: the
#                       dispatch-time ledger reading wins for claude labels,
#                       the pi session scan fills pi labels, and `missing`
#                       reports every missing record by task
#   E. no blank cells   every ledger line carries exactly one of (reading +
#                       source) or (missing_reason) — never both, never neither
#
# The session-scan reader (T521.1) keeps a mode of its own: attribution,
# seeded sums, canonicalization and unattributed reporting are still pinned
# by arms G/H/I below against a SYNTHETIC session dir.
#
# Task: T521 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20

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
WORK="$(mktemp -d /tmp/weizigo/t521-capture-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
cd "$WORK"
git init -q
git config user.email t521@test
git config user.name T521
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

echo "=== regression-token-capture (T521) ==="

if ! test -f "$TOOL"; then
    echo "FATAL: $TOOL missing — the instrument must exist"
    exit 1
fi

# ── shims (never real binaries, never credentials) ─────────────────────────
cat > fake-claude <<'SHIM'
#!/usr/bin/env python3
# A fake `claude -p --output-format json`: writes the v2.1.237 envelope
# shape recorded irl on 2026-08-20 (single-line JSON, type=result,
# result=<text>, usage with snake_case token keys).
import json, sys
envelope = {
    "type": "result", "subtype": "success", "is_error": False,
    "result": "T521-E2E nonce-echo ok",
    "num_turns": 1, "stop_reason": "end_turn",
    "usage": {
        "input_tokens": 11, "output_tokens": 22,
        "cache_read_input_tokens": 33, "cache_creation_input_tokens": 44,
        "output_tokens_details": {"thinking_tokens": 5},
        "service_tier": "standard",
    },
    "modelUsage": {"claude-sonnet-5": {"inputTokens": 11, "outputTokens": 22,
        "cacheReadInputTokens": 33, "cacheCreationInputTokens": 44}},
}
sys.stdout.write(json.dumps(envelope) + "\n")
sys.exit(0)
SHIM

cat > fake-claude-error <<'SHIM'
#!/usr/bin/env python3
# is_error envelope with zero usage — an api error must be missing-with-
# reason, never a 0/0 reading.
import json, sys
sys.stdout.write(json.dumps({
    "type": "result", "subtype": "error", "is_error": True,
    "result": "api error: bad model", "terminal_reason": "api_error",
    "usage": {"input_tokens": 0, "output_tokens": 0,
              "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0,
              "output_tokens_details": {"thinking_tokens": 0}},
}) + "\n")
sys.exit(1)
SHIM

cat > fake-pi <<'SHIM'
#!/usr/bin/env python3
# A fake `pi` lane: plain text on stdout (the reply), a diagnostic on
# stderr.  No structured usage line — that is the pi/ollama reality; the
# raw streams must still be teed and the reading recorded missing.
import sys
sys.stdout.write("plain lane output\n")
sys.stderr.write("pi: some diagnostic\n")
sys.exit(0)
SHIM

chmod +x fake-claude fake-claude-error fake-pi

# ── A. envelope parse (unit arm, against the real instrument) ──────────────
echo "  A. claude envelope parse: text + usage extracted; error is missing"
A_OUT=$(python3 - "$TOOL" <<'PYEOF'
import importlib.util, json, sys
spec = importlib.util.spec_from_file_location("tc", sys.argv[1])
tc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tc)
env = {"type": "result", "subtype": "success", "result": "hello world",
       "is_error": False,
       "usage": {"input_tokens": 11, "output_tokens": 22,
                 "cache_read_input_tokens": 33, "cache_creation_input_tokens": 44,
                 "output_tokens_details": {"thinking_tokens": 5}}}
text, usage, meta = tc.parse_claude_envelope(json.dumps(env))
assert text == "hello world", text
assert usage["input"] == 11 and usage["output"] == 22
assert usage["cache_read"] == 33 and usage["cache_write"] == 44
assert usage["reasoning"] == 5
assert usage["total"] == 11 + 22 + 33 + 44
assert not meta["is_error"]
# stream-json (JSONL) variant: usage lives on the final result event
jsl = "\n".join([
    json.dumps({"type": "system", "subtype": "init"}),
    json.dumps(env),
])
text2, usage2, meta2 = tc.parse_claude_envelope(jsl)
assert text2 == "hello world" and usage2["output"] == 22
# error envelope -> usage present but api-error zero => caller must treat as
# missing; the parser reports is_error so the runner can decide
_, usage3, meta3 = tc.parse_claude_envelope(json.dumps(
    {"type": "result", "is_error": True, "result": "boom",
     "usage": {"input_tokens": 0, "output_tokens": 0,
               "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}))
assert meta3["is_error"] and usage3 is not None
# garbage -> text passthrough, no usage
t4, u4, _ = tc.parse_claude_envelope("not json at all")
assert t4 == "not json at all" and u4 is None
print("OK")
PYEOF
)
if [ "$A_OUT" = "OK" ]; then
    pass "envelope parse extracts text + usage; error flagged; garbage passthrough"
else
    fail "envelope parse: $A_OUT"
fi

# ── B. claude lane end-to-end through tools/runner ─────────────────────────
echo "  B. claude lane: run record + trailer line + unwrapped stdout + ledger + tee"
export MANAGENT_TASK_ID=T521CLAUDE
OUT_B=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-claude -p 'hi' --model claude-sonnet-5 --output-format json 2>"$WORK/claude.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "claude lane runner rc=$RC"; sed 's/^/    | /' "$WORK/claude.err" | head -20
else
    # stdout must be the UNWRAPPED text, never the envelope
    if [ "$OUT_B" = "T521-E2E nonce-echo ok" ]; then
        pass "lane stdout is the unwrapped result text"
    else
        fail "lane stdout unwrap: got '$OUT_B'"
    fi
    # trailer line (the bakeoff G1 per-lane reading)
    if grep -q "\[runner\] tokens_in=44 tokens_out=22" "$WORK/claude.err"; then
        pass "trailer carries tokens_in=44 tokens_out=22"
    else
        fail "trailer tokens line missing"; grep "tokens" "$WORK/claude.err" | sed 's/^/    | /'
    fi
    # run record tokens
    REC="$WORK/untracked/runs/T521CLAUDE.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('tokens_in')==44 and d.get('tokens_out')==22, d
assert d.get('tokens_source')=='claude-json-envelope', d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "run record carries tokens_in/out/source"
    else
        fail "run record tokens missing"; cat "$REC" 2>/dev/null | head -5
    fi
    # ledger reading
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && grep -q '"task": "T521CLAUDE"' "$LED" \
       && grep -q '"tokens_in": 44' "$LED" && grep -q '"tokens_out": 22' "$LED"; then
        pass "ledger records the claude reading"
    else
        fail "ledger claude reading missing"; cat "$LED" 2>/dev/null | head -5
    fi
    # tee: raw envelope survives on disk (provider segment is the shim's
    # basename here, so glob on the task prefix only)
    if ls "$WORK"/untracked/tokens/T521CLAUDE.*.stdout.log >/dev/null 2>&1 \
       && grep -q '"result": "T521-E2E nonce-echo ok"' "$WORK"/untracked/tokens/T521CLAUDE.*.stdout.log; then
        pass "raw claude envelope teed to disk"
    else
        fail "claude tee missing"; ls "$WORK"/untracked/tokens/ 2>/dev/null | sed 's/^/    | /'
    fi
fi

# ── C. pi lane end-to-end: tee + explicit missing ─────────────────────────
echo "  C. pi lane: raw streams teed; ledger records missing with a reason"
export MANAGENT_TASK_ID=T521PI
OUT_C=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-pi --provider deepseek --model deepseek-v4-pro -p 'hi' 2>"$WORK/pi.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "pi lane runner rc=$RC"; sed 's/^/    | /' "$WORK/pi.err" | head -10
else
    if [ "$OUT_C" = "plain lane output" ]; then
        pass "pi lane stdout forwarded unchanged"
    else
        fail "pi lane stdout: got '$OUT_C'"
    fi
    if ls "$WORK"/untracked/tokens/T521PI.*.stdout.log >/dev/null 2>&1 \
       && grep -q "plain lane output" "$WORK"/untracked/tokens/T521PI.*.stdout.log \
       && ls "$WORK"/untracked/tokens/T521PI.*.stderr.log >/dev/null 2>&1 \
       && grep -q "pi: some diagnostic" "$WORK"/untracked/tokens/T521PI.*.stderr.log; then
        pass "pi raw stdout+stderr teed per task"
    else
        fail "pi tee missing"; ls "$WORK"/untracked/tokens/ 2>/dev/null | sed 's/^/    | /'
    fi
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && grep -q '"task": "T521PI"' "$LED" \
       && python3 -c "
import json
for line in open('$LED'):
    e=json.loads(line)
    if e.get('task')=='T521PI':
        assert e.get('tokens_in') is None and e.get('tokens_out') is None, e
        assert e.get('missing_reason'), e
        assert e.get('source') is None, e
        print('OK')" 2>/dev/null | grep -q OK; then
        pass "pi lane: missing recorded explicitly with a reason, never blank"
    else
        fail "pi ledger missing record"; cat "$LED" 2>/dev/null | head -5
    fi
    # run record carries the null + reason (self-describing)
    REC="$WORK/untracked/runs/T521PI.json"
    if test -f "$REC" && python3 -c "
import json
d=json.load(open('$REC'))
assert d.get('tokens_in') is None and d.get('tokens_out') is None, d
assert d.get('tokens_missing_reason'), d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "pi lane run record: null tokens + explicit reason"
    else
        fail "pi run record missing-reason"; cat "$REC" 2>/dev/null | head -5
    fi
fi

# ── D. G1 join: ledger reading wins for claude; session scan fills pi ─────
echo "  D. G1 join: models map from ledger (claude) + session scan (pi)"
SESS="$WORK/sessions"
mkdir -p "$SESS"
python3 - "$SESS" <<'PYEOF'
import json, os, sys
d = sys.argv[1]
def line(o): return json.dumps(o)
with open(os.path.join(d, "sessP.jsonl"), "w") as f:
    f.write(line({"type": "session", "version": 3, "id": "p",
                  "timestamp": "2026-08-20T00:00:00Z", "cwd": "/repo"}) + "\n")
    f.write(line({"type": "message", "id": "p1", "parentId": "p",
                  "timestamp": "2026-08-20T00:00:01Z",
                  "message": {"role": "user", "content": [{"type": "text",
                      "text": "Follow untracked/T521PI-missing.md\nFIRST: bin/managent claim T521PI --agent deepseek-v4-pro\n"}]}}) + "\n")
    f.write(line({"type": "message", "id": "p2", "parentId": "p1",
                  "timestamp": "2026-08-20T00:00:02Z",
                  "message": {"role": "assistant", "content": [{"type": "text", "text": "x"}],
                              "provider": "deepseek", "model": "deepseek-v4-pro",
                              "usage": {"input": 100, "output": 50, "cacheRead": 200,
                                        "cacheWrite": 10, "reasoning": 0,
                                        "totalTokens": 360}}}) + "\n")
PYEOF
# T521PI is missing in the ledger (arm C), so the join must fall back to the
# session scan for deepseek-v4-pro; T521CLAUDE has a real ledger reading.
JOIN_OUT=$(python3 "$TOOL" --json --cwd "$WORK" --sessions "$SESS" --since 2026-08-20)
if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
m = d.get('models') or {}
c = m.get('claude-sonnet-5')
assert c and c.get('tokens_in') == 44 and c.get('tokens_out') == 22, m
p = m.get('deepseek-v4-pro')
assert p and p.get('tokens_in') == 300 and p.get('tokens_out') == 50, m
miss = d.get('missing') or {}
assert 'T521PI' in miss, d.get('missing')
assert miss['T521PI'].get('missing_reason'), miss['T521PI']
print('OK')" "$JOIN_OUT" 2>/dev/null | grep -q OK; then
    pass "G1 join: ledger reading for claude, session fallback for pi, missing section"
else
    fail "G1 join"; echo "$JOIN_OUT" | head -c 1500 | sed 's/^/    | /'
fi

# ── E. no blank cells in the ledger ───────────────────────────────────────
echo "  E. ledger hygiene: every record is a reading or an explicit missing"
if python3 -c "
import json, sys
n = 0
for line in open('$WORK/untracked/tokens/tokens.jsonl'):
    e = json.loads(line)
    n += 1
    has_read = e.get('tokens_in') is not None or e.get('tokens_out') is not None
    has_reason = bool(e.get('missing_reason'))
    assert has_read != has_reason, ('both or neither', e)
    if has_read:
        assert e.get('source'), e
print('OK', n)" 2>/dev/null | grep -q OK; then
    pass "every ledger line is exactly one of reading-with-source or missing-with-reason"
else
    fail "ledger hygiene"; cat "$WORK/untracked/tokens/tokens.jsonl" 2>/dev/null | sed 's/^/    | /'
fi

# ── G/H/I. session-scan reader mode (T521.1 controls, kept) ───────────────
echo "  G. session-scan attribution + seeded sums (reader mode)"
# sessQ: two turns, task T888; sum must be hand-computable.
python3 - "$SESS" <<'PYEOF'
import json, os, sys
d = sys.argv[1]
def line(o): return json.dumps(o)
with open(os.path.join(d, "sessQ.jsonl"), "w") as f:
    f.write(line({"type": "session", "version": 3, "id": "q",
                  "timestamp": "2026-08-20T00:00:00Z", "cwd": "/repo"}) + "\n")
    f.write(line({"type": "message", "id": "q1", "parentId": "q",
                  "timestamp": "2026-08-20T00:00:01Z",
                  "message": {"role": "user", "content": [{"type": "text",
                      "text": "Follow untracked/T888-bar.md\n"}]}}) + "\n")
    f.write(line({"type": "message", "id": "q2", "parentId": "q1",
                  "timestamp": "2026-08-20T00:00:02Z",
                  "message": {"role": "assistant", "content": [{"type": "text", "text": "x"}],
                              "provider": "deepseek", "model": "alpha",
                              "usage": {"input": 100, "output": 50, "cacheRead": 1000,
                                        "cacheWrite": 10, "reasoning": 0,
                                        "totalTokens": 1150}}}) + "\n")
    f.write(line({"type": "message", "id": "q3", "parentId": "q2",
                  "timestamp": "2026-08-20T00:00:03Z",
                  "message": {"role": "user", "content": [{"type": "text", "text": "more"}]}}) + "\n")
    f.write(line({"type": "message", "id": "q4", "parentId": "q3",
                  "timestamp": "2026-08-20T00:00:04Z",
                  "message": {"role": "assistant", "content": [{"type": "text", "text": "y"}],
                              "provider": "deepseek", "model": "kimi-k2.7-code:cloud",
                              "usage": {"input": 200, "output": 60, "cacheRead": 1100,
                                        "cacheWrite": 5, "reasoning": 20,
                                        "totalTokens": 1380}}}) + "\n")
PYEOF
SCAN_OUT=$(python3 "$TOOL" --json --cwd "$WORK" --sessions "$SESS" --since 2026-08-20 --task T888)
if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
t = (d.get('tasks') or {}).get('T888')
assert t, d.get('tasks')
assert t['tokens_in'] == 100 + 1000 + 200 + 1100, t   # input + cache_read, both turns
assert t['tokens_out'] == 50 + 60, t
assert t['total'] == 1150 + 1380, t
m = t['model']
assert m == 'kimi-k2.7', m   # canonicalized (dominant turn wins; kimi-code:cloud -> kimi)
print('OK')" "$SCAN_OUT" 2>/dev/null | grep -q OK; then
    pass "session scan: attribution, seeded sums, canonicalization"
else
    fail "session scan"; echo "$SCAN_OUT" | head -c 800 | sed 's/^/    | /'
fi

# ── H. unattributed sessions are reported, never estimated ────────────────
echo "  H. unattributed session reported as such"
python3 - "$SESS" <<'PYEOF'
import json, os, sys
d = sys.argv[1]
with open(os.path.join(d, "sessR.jsonl"), "w") as f:
    f.write(json.dumps({"type": "session", "version": 3, "id": "r",
                        "timestamp": "2026-08-20T00:00:00Z", "cwd": "/repo"}) + "\n")
    f.write(json.dumps({"type": "message", "id": "r1", "parentId": "r",
                        "timestamp": "2026-08-20T00:00:01Z",
                        "message": {"role": "user", "content": [{"type": "text",
                            "text": "no task named here"}]}}) + "\n")
    f.write(json.dumps({"type": "message", "id": "r2", "parentId": "r1",
                        "timestamp": "2026-08-20T00:00:02Z",
                        "message": {"role": "assistant", "content": [{"type": "text", "text": "x"}],
                                    "provider": "deepseek", "model": "glm-5.2",
                                    "usage": {"input": 7, "output": 3, "cacheRead": 0,
                                              "cacheWrite": 0, "reasoning": 0,
                                              "totalTokens": 10}}}) + "\n")
PYEOF
SCAN_OUT2=$(python3 "$TOOL" --json --cwd "$WORK" --sessions "$SESS" --since 2026-08-20)
if python3 -c "
import json, sys
d = json.loads(sys.argv[1])
u = d.get('unattributed') or {}
assert u.get('sessions', 0) >= 1, u
assert u.get('tokens_in', 0) == 7, u
print('OK')" "$SCAN_OUT2" 2>/dev/null | grep -q OK; then
    pass "unattributed sessions reported separately, never folded into a task"
else
    fail "unattributed handling"
fi

# ── I. empty session dir / missing ledger → zero, exit 0 (no crash) ───────
echo "  I. absence is zero, not a crash"
EMPTY="$WORK/empty"
mkdir -p "$EMPTY"
if python3 "$TOOL" --json --cwd "$WORK" --sessions "$EMPTY" --since 2026-08-20 >/dev/null 2>&1 \
   && [ $? -eq 0 ]; then
    pass "empty session dir reports zero and exits 0"
else
    fail "empty session dir must not crash"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-token-capture: ALL PASS ==="
else
    echo "=== regression-token-capture: FAILURES ==="
    exit 1
fi
