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
#                       reading, and the raw envelope is teed to disk.
#                       T558: the same surfaces additionally carry the split
#                       behind tokens_in — tokens_fresh (= input) and
#                       tokens_cache_read (= cache_read) — so the cost ladder
#                       can price cache reads differently from fresh input;
#                       tokens_in itself keeps its meaning (input+cache_read)
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

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$ROOT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t521-capture WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t521@test
git config user.name T521
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

# T801: the canonicalizer is INJECTED via WEIZIGO_CANONICALIZER_JSON so the
# runner and the token-capture CLI resolve the single transform from a fixture
# file (hermetic — no `managent models` fork, no managent build) instead of
# resolving a managent binary that does not exist in this scratch repo.  The
# synthetic model `alpha` joins the real canonical set so its turn attributes
# exactly as before; beta/gamma included for parity with the model-profiles
# fixture.
CANON="$WORK/canonicalizer.json"
python3 - "$CANON" <<'PYEOF'
import json, sys
json.dump({
    "canonical_models": [
        "alpha", "beta", "gamma",
        "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
        "claude-haiku-4-5-20251001", "deepseek-v4-pro", "deepseek-v4-flash",
        "glm-5.2", "minimax-m3", "kimi-k2.7", "qwen3.8:27b-mlx", "ox-alpha",
    ],
    "strip_suffix": ":cloud",
    "serving_tags": {
        "kimi-k2.7-code": "kimi-k2.7",
        "stealth/ox-alpha": "ox-alpha",
    },
}, open(sys.argv[1], "w"))
PYEOF
export WEIZIGO_CANONICALIZER_JSON="$CANON"

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
# error envelope -> usage present but all-zero => MISSING, never a 0/0
# reading (T794 corrected this arm: it previously asserted the zero dict,
# characterizing the very 0/0 reading the docstring forbids); the runner
# decides from meta["is_error"] either way
_, usage3, meta3 = tc.parse_claude_envelope(json.dumps(
    {"type": "result", "is_error": True, "result": "boom",
     "usage": {"input_tokens": 0, "output_tokens": 0,
               "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}}))
assert meta3["is_error"] and usage3 is None
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
        -- ./fake-claude -p 'hi' --model claude-sonnet-5 --output-format json \
           --provider claude 2>"$WORK/claude.err")
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
    # T558: the split rides the same trailer line — tokens_in keeps its
    # meaning (input+cache_read), fresh and cache_read ride beside it
    if grep -q "tokens_fresh=11 tokens_cache_read=33" "$WORK/claude.err"; then
        pass "trailer splits tokens_in into tokens_fresh=11 tokens_cache_read=33"
    else
        fail "trailer token split missing"; grep "tokens" "$WORK/claude.err" | sed 's/^/    | /'
    fi
    # run record tokens
    REC="$WORK/untracked/runs/T521CLAUDE.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('tokens_in')==44 and d.get('tokens_out')==22, d
assert d.get('tokens_source')=='claude-json-envelope', d
assert d.get('tokens_fresh')==11 and d.get('tokens_cache_read')==33, d
# D044: claude has no time-priced rate — band null with the family reason
assert d.get('rate_band') is None, d
assert 'subscription' in (d.get('rate_band_reason') or ''), d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "run record carries tokens_in/out/source"
    else
        fail "run record tokens missing"; cat "$REC" 2>/dev/null | head -5
    fi
    # ledger reading
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && grep -q '"task": "T521CLAUDE"' "$LED" \
       && grep -q '"tokens_in": 44' "$LED" && grep -q '"tokens_out": 22' "$LED" \
       && grep -q '"tokens_fresh": 11' "$LED" \
       && grep -q '"tokens_cache_read": 33' "$LED"; then
        pass "ledger records the claude reading (tokens_in/out + T558 split)"
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

# ── F. T662: pi-session meter e2e (seeded) ────────────────────────────────
# A pi lane whose dispatch passed `--session <path>` writes its session
# JSONL to that exact path; after the lane closes the runner reads the
# file and records the split.  pi's usage object carries input and
# cacheRead SEPARATELY, so a readable session yields a REAL split — never
# UNKNOWN.  Two assistant turns with seeded usage make the sums
# hand-checkable: input 107, cacheRead 240, output 53 -> tokens_in 347.
# RED against the pre-T662 code: the record said "no reading — the pi
# session JSONL is the retroactive meter" and nothing read it.
cat > fake-pi-session <<'SHIM'
#!/usr/bin/env python3
# A fake pi lane that behaves like the real one: writes its session JSONL
# to the `--session <path>` target (the exact file the runner reads after
# the child closes), then prints its reply.
import json, os, sys
path = None
for i, a in enumerate(sys.argv):
    if a == "--session" and i + 1 < len(sys.argv):
        path = sys.argv[i + 1]
        break
def line(o): return json.dumps(o)
if path:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(line({"type": "session", "version": 3, "id": "t662-sess-1",
                      "timestamp": "2026-08-22T00:00:00Z", "cwd": "/repo"}) + "\n")
        f.write(line({"type": "message", "id": "u1", "parentId": "t662-sess-1",
                      "timestamp": "2026-08-22T00:00:01Z",
                      "message": {"role": "user", "content": [{"type": "text",
                          "text": "Follow untracked/T662F-x.md"}]}}) + "\n")
        f.write(line({"type": "message", "id": "a1", "parentId": "u1",
                      "timestamp": "2026-08-22T00:00:02Z",
                      "message": {"role": "assistant", "content": [{"type": "text", "text": "x"}],
                                  "provider": "deepseek", "model": "deepseek-v4-pro",
                                  "usage": {"input": 100, "output": 50, "cacheRead": 200,
                                            "cacheWrite": 10, "reasoning": 0,
                                            "totalTokens": 360}}}) + "\n")
        f.write(line({"type": "message", "id": "a2", "parentId": "a1",
                      "timestamp": "2026-08-22T00:00:03Z",
                      "message": {"role": "assistant", "content": [{"type": "text", "text": "y"}],
                                  "provider": "deepseek", "model": "deepseek-v4-pro",
                                  "usage": {"input": 7, "output": 3, "cacheRead": 40,
                                            "cacheWrite": 0, "reasoning": 0,
                                            "totalTokens": 50}}}) + "\n")
sys.stdout.write("pi session lane output\n")
sys.exit(0)
SHIM
chmod +x fake-pi-session

echo "  F. pi-session meter: --session path read after close -> split recorded"
export MANAGENT_TASK_ID=T662F
OUT_F=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-pi-session --provider deepseek --model deepseek-v4-pro \
           --session untracked/sessions/T662F.jsonl -p 'hi' 2>"$WORK/pi-f.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "pi-session lane runner rc=$RC"; sed 's/^/    | /' "$WORK/pi-f.err" | head -20
else
    if [ "$OUT_F" = "pi session lane output" ]; then
        pass "pi-session lane stdout forwarded unchanged"
    else
        fail "pi-session lane stdout: got '$OUT_F'"
    fi
    REC="$WORK/untracked/runs/T662F.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('tokens_in')==347, d.get('tokens_in')   # 107 fresh + 240 cache_read
assert d.get('tokens_fresh')==107, d
assert d.get('tokens_cache_read')==240, d
assert d.get('tokens_out')==53, d
assert d.get('tokens_source')=='pi-session-jsonl', d
assert d.get('tokens_fresh')+d.get('tokens_cache_read')==d.get('tokens_in'), d
assert d.get('session_id')=='t662-sess-1', d
assert d.get('session_reason') is None, d
assert d.get('session_path','').endswith('T662F.jsonl'), d
assert d.get('session_path_reason') is None, d
# D044: the deepseek band is computed at write time from the run's own
# start — same input, same output as the instrument's own function.
import importlib.util, os
spec = importlib.util.spec_from_file_location('tc', '$TOOL')
tcm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tcm)
assert d.get('rate_band') == tcm.deepseek_rate_band(d.get('start')), d
assert d.get('rate_band_reason') is None, d
print('OK')" 2>/dev/null | grep -q OK; then
        pass "run record: pi session meter split (347=107+240) + session id + path"
    else
        fail "pi-session run record"; cat "$REC" 2>/dev/null | head -5
    fi
    if grep -q "tokens_in=347 tokens_out=53 tokens_fresh=107 tokens_cache_read=240" "$WORK/pi-f.err"; then
        pass "trailer carries the pi session split"
    else
        fail "pi-session trailer split missing"; grep "tokens" "$WORK/pi-f.err" | sed 's/^/    | /'
    fi
    if grep -q "session_id=t662-sess-1" "$WORK/pi-f.err"; then
        pass "trailer carries the resumable session id"
    else
        fail "pi-session trailer id missing"; grep "session" "$WORK/pi-f.err" | sed 's/^/    | /'
    fi
    LED="$WORK/untracked/tokens/tokens.jsonl"
    if test -f "$LED" && python3 -c "
import json,sys
for line in open('$LED'):
    e=json.loads(line)
    if e.get('task')=='T662F':
        assert e.get('tokens_in')==347 and e.get('tokens_fresh')==107, e
        assert e.get('tokens_cache_read')==240 and e.get('tokens_out')==53, e
        assert e.get('source')=='pi-session-jsonl', e
        assert e.get('session_id')=='t662-sess-1', e
        assert e.get('session_path','').endswith('T662F.jsonl'), e
        assert e.get('rate_band') in ('peak','off-peak'), e
        assert e.get('rate_band_reason') is None, e
        print('OK')" 2>/dev/null | grep -q OK; then
        pass "ledger carries the pi session meter reading (split + id + path + band)"
    else
        fail "pi-session ledger"; cat "$LED" 2>/dev/null | head -5
    fi
fi

# ── G. T662: session file MISSING -> UNKNOWN, loudly, never 0 ─────────────
# A lane whose dispatch named a session path but whose session file does
# not exist after close (pi never wrote it: launch crash, kill before
# header) must record UNKNOWN — all three token fields None with a reason
# NAMING the missing file.  Never 0 (a free lane in the ladder), never the
# total (a fabricated reading).  RED against pre-T662: indistinguishable
# from any other pi lane.
cat > fake-pi-nosession <<'SHIM'
#!/usr/bin/env python3
# A fake pi lane that NEVER writes its session file — the missing-file
# control.
import sys
sys.stdout.write("pi lane, no session written\n")
sys.exit(0)
SHIM
chmod +x fake-pi-nosession

echo "  G. missing session file -> UNKNOWN, loudly, never 0 / never the total"
export MANAGENT_TASK_ID=T662G
OUT_G=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-pi-nosession --provider deepseek --model deepseek-v4-flash \
           --session untracked/sessions/T662G.jsonl -p 'hi' 2>"$WORK/pi-g.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "missing-session lane runner rc=$RC"; sed 's/^/    | /' "$WORK/pi-g.err" | head -20
else
    REC="$WORK/untracked/runs/T662G.json"
    if test -f "$REC" && python3 -c "
import json,sys
d=json.load(open('$REC'))
assert d.get('tokens_in') is None, d
assert d.get('tokens_fresh') is None, d
assert d.get('tokens_cache_read') is None, d
assert d.get('tokens_out') is None, d
mr=d.get('tokens_missing_reason') or ''
assert 'session file missing' in mr, mr
assert 'T662G.jsonl' in mr, mr
sr=d.get('session_reason') or ''
assert 'session file missing' in sr, sr
print('OK')" 2>/dev/null | grep -q OK; then
        pass "missing session file: all fields None + reason naming the file (UNKNOWN)"
    else
        fail "missing-session record"; cat "$REC" 2>/dev/null | head -5
    fi
    if grep -q "tokens: no reading" "$WORK/pi-g.err"; then
        pass "trailer reports the missing reading loudly"
    else
        fail "missing-session trailer"; grep "tokens" "$WORK/pi-g.err" | sed 's/^/    | /'
    fi
fi

# ── H. T662 null: an already-recorded lane is untouched (no back-fill) ────
# A reconstructed token count is a fabricated one (T662 null control).
# Seed a run record + ledger line for T662H, then run a NEW attempt of the
# same task: the T650 archive of the old record must be BYTE-IDENTICAL to
# the seed (no session_path stamped into history, no reading invented),
# and the old ledger line must survive verbatim.
echo "  H. null: an already-recorded lane is untouched; no back-fill"
mkdir -p "$WORK/untracked/runs"
cat > "$WORK/untracked/runs/T662H.json" <<'SEED'
{"task": "T662H", "attempt": 1, "pid": 111, "start": "2026-08-22T00:00:00Z",
 "command": "old attempt", "tokens_in": 999, "tokens_out": 1,
 "tokens_fresh": 1, "tokens_cache_read": 998, "tokens_source": "claude-json-envelope",
 "session_id": "old-sess", "seed_marker": true}
SEED
SEED_BEFORE=$(sha256sum "$WORK/untracked/runs/T662H.json" | cut -d' ' -f1)
mkdir -p "$WORK/untracked/tokens"
printf '%s\n' '{"task": "T662H", "ts": "2026-08-22T00:00:00Z", "tokens_in": 999, "tokens_out": 1, "source": "claude-json-envelope", "seed_marker": true}' >> "$WORK/untracked/tokens/tokens.jsonl"

export MANAGENT_TASK_ID=T662H
OUT_H=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 30 \
        -- ./fake-pi --provider deepseek --model deepseek-v4-flash -p 'hi' 2>"$WORK/pi-h.err")
RC=$?
unset MANAGENT_TASK_ID

if [ "$RC" -ne 0 ]; then
    fail "null lane runner rc=$RC"; sed 's/^/    | /' "$WORK/pi-h.err" | head -20
else
    # T650: the new attempt archives the bare record to <task>.1.json and
    # writes a fresh bare.  The ARCHIVE must be byte-identical to the seed
    # — history is never rewritten, never back-filled.
    ARCH="$WORK/untracked/runs/T662H.1.json"
    if test -f "$ARCH"; then
        SEED_AFTER=$(sha256sum "$ARCH" | cut -d' ' -f1)
        if [ "$SEED_AFTER" = "$SEED_BEFORE" ]; then
            pass "old attempt archived byte-identical — no back-fill, no invented reading"
        else
            fail "old attempt REWRITTEN by the new run (archive differs from seed)"
            diff "$ARCH" "$WORK/untracked/runs/T662H.json" | head -10
        fi
    else
        fail "no archived attempt T662H.1.json found"; ls "$WORK/untracked/runs/" | sed 's/^/    | /'
    fi
    # the seed's ledger line survives verbatim (the new run appends only)
    if grep -q '"seed_marker": true' "$WORK/untracked/tokens/tokens.jsonl"; then
        pass "pre-existing ledger line untouched (new run appends, never rewrites)"
    else
        fail "pre-existing ledger line destroyed"
    fi
fi

# ── J. T662: economy recompute by hand and from the records agree ────────
# Ruling 35: economy = verified findings / output tokens.  The METER feeds
# it, so the meter must reproduce a hand computation exactly.  Two seeded
# readings exist in this scratch run: T521CLAUDE (arm B: 11 fresh + 33
# cache_read = 44 in, 22 out) and T662F (arm F: 107 + 240 = 347 in, 53
# out).  Recompute the derived fields from the RAW seeded usage by hand,
# then read the records: they must agree.  The UNKNOWN record (T662G) must
# be EXCLUDED — a record whose split is None may never enter an economy.
echo "  J. economy: hand recompute over the seeded set == records; UNKNOWN excluded"
if python3 -c "
import json, sys
# hand computation from the SEEDED usage values (the fixtures, not the records)
claude = {'fresh': 11, 'cache_read': 33, 'out': 22}
pi     = {'fresh': 107, 'cache_read': 240, 'out': 53}
known = {'T521CLAUDE': claude, 'T662F': pi}
recs = {}
for tid in known:
    d = json.load(open('$WORK/untracked/runs/%s.json' % tid))
    recs[tid] = d
    want = known[tid]
    assert d.get('tokens_in') == want['fresh'] + want['cache_read'], (tid, d)
    assert d.get('tokens_fresh') == want['fresh'], d
    assert d.get('tokens_cache_read') == want['cache_read'], d
    assert d.get('tokens_out') == want['out'], d
# economy (output per input) computed from the seeds == computed from the records
eco_by_hand = sum(k['out'] for k in known.values()) / sum(k['fresh'] + k['cache_read'] for k in known.values())
eco_by_recs = sum(recs[t]['tokens_out'] for t in known) / sum(recs[t]['tokens_in'] for t in known)
assert abs(eco_by_hand - eco_by_recs) < 1e-12, (eco_by_hand, eco_by_recs)
# the UNKNOWN record is excluded: its split fields are None and it has no
# tokens_in — an economy over it is impossible, and must never default to 0
u = json.load(open('$WORK/untracked/runs/T662G.json'))
assert u.get('tokens_in') is None and u.get('tokens_fresh') is None, u
assert u.get('tokens_cache_read') is None, u
print('OK')" 2>/dev/null | grep -q OK; then
    pass "hand recompute over the seeded set == records; UNKNOWN record excluded"
else
    fail "economy recompute"; ls "$WORK/untracked/runs/" | sed 's/^/    | /'
fi

# ── K. D044: the deepseek peak/off-peak band (unit + e2e) ─────────────────
# measurement-methodology.md §1b: peak = 01:00-04:00 and 06:00-10:00 UTC
# on weekdays; off-peak otherwise, with the weekend override (UTC Fri
# 16:00 -> Sun 16:00) half all day.  The band is computed at write time
# from the run's own timestamp, so a later reader never re-derives the
# calendar rule from a bare count.  Unit arm: fixed timestamps, known
# bands.  (The e2e arm lives in F: the record's band equals the
# instrument's own function of the record's start; the claude null is in
# arm B: null + a reason naming the subscription.)
echo "  K. rate band: fixed timestamps -> known peak/off-peak; unparseable -> None"
K_OUT=$(python3 - "$TOOL" <<'PYEOF'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("tc", sys.argv[1])
tc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tc)
# weekdays verified 2026-08-18 Tue, 08-21 Fri, 08-22 Sat, 08-23 Sun, 08-24 Mon
assert tc.deepseek_rate_band("2026-08-18T02:00:00Z") == "peak"     # Tue 02:00
assert tc.deepseek_rate_band("2026-08-18T05:00:00Z") == "off-peak"  # Tue 05:00
assert tc.deepseek_rate_band("2026-08-18T07:00:00Z") == "peak"     # Tue 07:00
assert tc.deepseek_rate_band("2026-08-18T10:00:00Z") == "off-peak"  # Tue 10:00
assert tc.deepseek_rate_band("2026-08-21T07:00:00Z") == "peak"     # Fri 07:00, before override
assert tc.deepseek_rate_band("2026-08-21T17:00:00Z") == "off-peak"  # Fri 17:00, override
assert tc.deepseek_rate_band("2026-08-22T12:00:00Z") == "off-peak"  # Sat
assert tc.deepseek_rate_band("2026-08-23T07:00:00Z") == "off-peak"  # Sun 07:00 — peak HOUR, override wins
assert tc.deepseek_rate_band("2026-08-24T02:00:00Z") == "peak"     # Mon 02:00, override over
assert tc.deepseek_rate_band("not a time") is None
assert tc.deepseek_rate_band("") is None
print("OK")
PYEOF
)
if [ "$K_OUT" = "OK" ]; then
    pass "band math: peak/off-peak/override boundaries + unparseable None"
else
    fail "rate band unit: $K_OUT"
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-token-capture: ALL PASS ==="
else
    echo "=== regression-token-capture: FAILURES ==="
    exit 1
fi
