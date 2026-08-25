#!/usr/bin/env bash
# regression-request-accounting.sh — T850 controls for
# tools/request-accounting.py (the per-model, per-window request counter).
#
# This row MEASURES; it adds no gate. The controls below pin the honesty
# rule (UNKNOWN, never 0, never the total) and the two harness joins
# (docs/infra/request-accounting.md) against SYNTHETIC fixtures under a
# scratch root passed via --root — never the live tree, never a real
# provider log except by explicit --ollama-log override.
#
# Arm count: 8 (A..H).
#   A. null control            zero run records in the window -> the
#                              report says so explicitly; fleet_total_
#                              requests is null, never a printed 0.
#   B. replay control           a fixture pi session with exactly 547
#                              assistant-role "type":"message" lines,
#                              joined via session_path -> counted as
#                              547 requests for that model (T850 fact 2's
#                              547-message glm transcript, reproduced as
#                              an engineered fixture, not a live path).
#   C. starvation control       three ollama-family lanes seeded so one
#                              model holds ~99% of the family's known
#                              requests -> starvation=true, surfaced in
#                              both JSON and the text report.
#   D. unattributable control   a session-less pi lane and an
#                              unrecognized-harness lane -> both report
#                              UNKNOWN with a reason, contribute 0 to
#                              requests (never folded into a measured
#                              zero) and are excluded from the family/
#                              fleet total's numerator.
#   E. window-boundary control  four events straddling both window edges
#                              -> exactly the two INSIDE the half-open
#                              [start, end) window are counted.
#   F. one-window-definition    tools/request-accounting.py's default
#                              window length IS tools/window_policy.
#                              WINDOW_SECONDS (import identity, not a
#                              second literal).
#   G. claude num_turns join    a claude attempt's teed envelope carries
#                              num_turns independent of is_error -> the
#                              report attributes that many requests to
#                              the claude model, anchored at the
#                              attempt's own timestamp.
#   H. ollama [GIN] cross-check a synthetic ollama server log is counted
#                              in-window and reported beside the known
#                              family total, discrepancy stated, never
#                              silently reconciled.
#
# Task: T850 · Role: leaf · Model: claude-sonnet-5 · Date: 2026-08-24
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TOOL="$ROOT/tools/request-accounting.py"
FAIL=0

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/weizigo-reqacct.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

reset_root() {
    rm -rf "$WORK/untracked"
    mkdir -p "$WORK/untracked/runs" "$WORK/untracked/tokens/sessions"
}

echo "=== regression-request-accounting: 8 arms (A-H) ==="

# ── Arm A: null control ────────────────────────────────────────────────────
echo ""
echo "arm A: null control — no run records in the window"
reset_root
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 1000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
assert r["status"] == "empty-window", r["status"]
assert r["fleet_total_requests"] is None, r["fleet_total_requests"]
assert r["models"] == {}, r["models"]
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "empty window reported explicitly; fleet_total_requests is null, models={}"
else
    fail "arm A did not produce the expected empty-window shape"
fi

# ── Arm B: replay control (547 assistant messages) ────────────────────────
echo ""
echo "arm B: replay control — 547-line pi session fixture -> 547 requests"
reset_root
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
sess = os.path.join(work, "untracked", "tokens", "sessions", "T900-replay.jsonl")
with open(sess, "w") as f:
    f.write(json.dumps({"type": "session", "version": 3, "id": "fixture-b",
                         "timestamp": "2026-08-24T05:00:00.000Z",
                         "cwd": "/tmp/fixture"}) + "\n")
    for i in range(547):
        f.write(json.dumps({
            "type": "message", "timestamp": "2026-08-24T05:%02d:%02dZ" % ((i // 60) % 60, i % 60),
            "message": {"role": "assistant", "usage": {"input": 1, "output": 1}},
        }) + "\n")
rec = {
    "task": "T900", "model": "glm-5.2",
    "command": "ollama launch pi --model glm-5.2:cloud -y -- --session %s -p 'Follow untracked/T900.md'" % sess,
    "start": "2026-08-24T05:00:01Z", "end": "2026-08-24T05:30:00Z",
    "session_path": sess, "session_path_reason": None,
}
with open(os.path.join(work, "untracked", "runs", "T900.json"), "w") as f:
    json.dump(rec, f)
PYEOF
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 36000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
m = r["models"]["glm-5.2"]
assert m["requests"] == 547, m["requests"]
assert m["unattributable_attempts"] == 0, m
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "547-message session transcript counted as exactly 547 requests for glm-5.2"
else
    fail "arm B: glm-5.2 requests != 547"
fi

# ── Arm C: starvation control (seeded ~99%) ────────────────────────────────
echo ""
echo "arm C: starvation control — one ollama model holds ~99% of family requests"
reset_root
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]

def write_session(name, n, minute):
    p = os.path.join(work, "untracked", "tokens", "sessions", name)
    with open(p, "w") as f:
        f.write(json.dumps({"type": "session", "id": name, "timestamp": "2026-08-24T05:00:00.000Z", "cwd": "/tmp"}) + "\n")
        for i in range(n):
            f.write(json.dumps({"type": "message",
                                 "timestamp": "2026-08-24T%02d:%02d:%02dZ" % (5, minute, i % 60),
                                 "message": {"role": "assistant"}}) + "\n")
    return p

def write_run(task, model, sess_path):
    rec = {"task": task, "model": model,
           "command": "ollama launch pi --model %s -y -- --session %s -p 'x'" % (model, sess_path),
           "start": "2026-08-24T05:00:01Z", "end": "2026-08-24T05:10:00Z",
           "session_path": sess_path, "session_path_reason": None}
    with open(os.path.join(work, "untracked", "runs", task + ".json"), "w") as f:
        json.dump(rec, f)

write_run("T910", "minimax-m3", write_session("T910.jsonl", 99, 1))
write_run("T911", "glm-5.2", write_session("T911.jsonl", 1, 2))
write_run("T912", "kimi-k2.7", write_session("T912.jsonl", 1, 3))
PYEOF
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 36000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
m = r["models"]["minimax-m3"]
assert m["requests"] == 99, m
assert m["starvation"] is True, m
assert m["share_of_family_pct"] >= 90.0, m
others_flagged = any(r["models"][x]["starvation"] for x in ("glm-5.2", "kimi-k2.7"))
assert not others_flagged
print("OK")
PYEOF
RC=$?
TXT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 36000)
if [ $RC -eq 0 ] && echo "$TXT" | grep -q "STARVATION"; then
    pass "minimax-m3 at 99/101 (98.0%) flagged starvation=true in JSON and text report; siblings not flagged"
else
    fail "arm C: starvation flag missing from JSON or text report"
fi

# ── Arm D: unattributable control ──────────────────────────────────────────
echo ""
echo "arm D: unattributable control — no session_path, and unrecognized harness"
reset_root
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
runs = os.path.join(work, "untracked", "runs")
# a pi/openrouter lane dispatched without --session (the oxalpha shape)
with open(os.path.join(runs, "T920.json"), "w") as f:
    json.dump({"task": "T920", "model": "oxalpha",
               "command": "pi --provider openrouter --model stealth/ox-alpha -p 'x'",
               "start": "2026-08-24T05:00:00Z", "end": "2026-08-24T05:10:00Z",
               "session_path": None,
               "session_path_reason": "pi/ollama lane without --session"}, f)
# a lane whose command matches neither harness
with open(os.path.join(runs, "T921.json"), "w") as f:
    json.dump({"task": "T921", "model": "deepseek-v4-flash",
               "command": "./some-other-wrapper.sh --model deepseek-v4-flash",
               "start": "2026-08-24T05:05:00Z", "end": "2026-08-24T05:15:00Z"}, f)
# one KNOWN reading from a third model, to prove the total counts it and
# nothing else
sess = os.path.join(work, "untracked", "tokens", "sessions", "T922.jsonl")
with open(sess, "w") as f:
    f.write(json.dumps({"type": "session", "id": "s", "timestamp": "2026-08-24T05:00:00.000Z", "cwd": "/tmp"}) + "\n")
    f.write(json.dumps({"type": "message", "timestamp": "2026-08-24T05:01:00Z",
                         "message": {"role": "assistant"}}) + "\n")
with open(os.path.join(runs, "T922.json"), "w") as f:
    json.dump({"task": "T922", "model": "kimi-k2.7",
               "command": "pi --provider ollama --model kimi-k2.7 --session %s -p 'x'" % sess,
               "start": "2026-08-24T05:00:01Z", "end": "2026-08-24T05:10:00Z",
               "session_path": sess, "session_path_reason": None}, f)
PYEOF
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 36000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
ox = r["models"]["oxalpha"]
assert ox["requests"] == 0, ox
assert ox["unattributable_attempts"] == 1, ox
assert ox["unattributable_reasons"], ox
ds = r["models"]["deepseek-v4-flash"]
assert ds["requests"] == 0, ds
assert ds["unattributable_attempts"] == 1, ds
assert "unrecognized harness" in ds["unattributable_reasons"][0], ds
# the total must reflect ONLY the known kimi-k2.7 reading (1), never a
# folded-in zero for the two unattributable attempts
assert r["fleet_total_requests"] == 1, r["fleet_total_requests"]
assert r["fleet_unattributable_attempts"] == 2, r["fleet_unattributable_attempts"]
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "session-less and unrecognized-harness lanes report UNKNOWN with reasons; fleet total excludes both"
else
    fail "arm D: unattributable lanes were folded into a zero or the total"
fi

# ── Arm E: window-boundary control ─────────────────────────────────────────
echo ""
echo "arm E: window-boundary control — half-open [start, end)"
reset_root
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
# window: now=10:00:00Z, window_seconds=1000 -> start=09:43:20Z, end=10:00:00Z
sess = os.path.join(work, "untracked", "tokens", "sessions", "T930.jsonl")
events = [
    "2026-08-24T09:43:19Z",  # 1s BEFORE start -> excluded
    "2026-08-24T09:43:20Z",  # exactly start -> included
    "2026-08-24T09:59:59Z",  # 1s before end -> included
    "2026-08-24T10:00:00Z",  # exactly end/now -> excluded
]
with open(sess, "w") as f:
    f.write(json.dumps({"type": "session", "id": "s", "timestamp": events[0], "cwd": "/tmp"}) + "\n")
    for ts in events:
        f.write(json.dumps({"type": "message", "timestamp": ts,
                             "message": {"role": "assistant"}}) + "\n")
with open(os.path.join(work, "untracked", "runs", "T930.json"), "w") as f:
    json.dump({"task": "T930", "model": "minimax-m3",
               "command": "ollama launch pi --model minimax-m3 -y -- --session %s -p 'x'" % sess,
               "start": "2026-08-24T09:43:00Z", "end": "2026-08-24T10:00:00Z",
               "session_path": sess, "session_path_reason": None}, f)
PYEOF
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 1000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
m = r["models"]["minimax-m3"]
assert m["requests"] == 2, m
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "exactly the 2 in-window events counted (start inclusive, end exclusive); both out-of-window events excluded"
else
    fail "arm E: window-boundary membership wrong"
fi

# ── Arm F: one-window-definition control ───────────────────────────────────
echo ""
echo "arm F: one window definition — no second WINDOW_SECONDS literal"
F_OUT=$(python3 - "$ROOT" <<'PYEOF'
import importlib.util, os, sys
root = sys.argv[1]
def load(modname, filename):
    path = os.path.join(root, "tools", filename)
    spec = importlib.util.spec_from_file_location(modname, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod
wp = load("window_policy", "window_policy.py")
ra = load("request_accounting", "request-accounting.py")
assert ra.default_window_seconds() == wp.WINDOW_SECONDS, (ra.default_window_seconds(), wp.WINDOW_SECONDS)
print("OK")
PYEOF
)
if [ "$F_OUT" = "OK" ]; then
    pass "request-accounting's default window length == window_policy.WINDOW_SECONDS (imported, not reinvented)"
else
    fail "arm F: $F_OUT"
fi

# ── Arm G: claude num_turns join ────────────────────────────────────────────
echo ""
echo "arm G: claude num_turns join — is_error envelope still carries num_turns"
reset_root
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
start = "2026-08-24T05:00:00Z"
tee_name = "T940.%s.claude.stdout.log" % start.replace(":", "_")
tee_path = os.path.join(work, "untracked", "tokens", tee_name)
envelope = {"is_error": True, "num_turns": 17, "session_id": "fixture-g",
            "usage": {"input_tokens": 0, "output_tokens": 0,
                      "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0},
            "result": "API Error: 529 Overloaded", "type": "result"}
with open(tee_path, "w") as f:
    f.write(json.dumps(envelope))
with open(os.path.join(work, "untracked", "runs", "T940.json"), "w") as f:
    json.dump({"task": "T940", "model": "claude-sonnet-5",
               "command": "claude -p 'x' --model claude-sonnet-5 --output-format json",
               "start": start, "end": "2026-08-24T05:20:00Z"}, f)
PYEOF
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T10:00:00Z" --window-seconds 36000 --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
m = r["models"]["claude-sonnet-5"]
assert m["requests"] == 17, m
assert m["unattributable_attempts"] == 0, m
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "is_error claude envelope's num_turns=17 attributed to claude-sonnet-5 despite the API error"
else
    fail "arm G: claude num_turns join failed"
fi

# ── Arm H: ollama [GIN] cross-check ────────────────────────────────────────
echo ""
echo "arm H: ollama [GIN] cross-check — reported beside the known total, never reconciled"
reset_root
GINLOG="$WORK/fake-server.log"
python3 - "$GINLOG" <<'PYEOF'
import sys
path = sys.argv[1]
lines = []
# 5 requests inside the window (09:00-10:00 local == within the 5h fixture
# window below), 2 of them 429; 1 request outside the window (must not count)
for hh, mm, ss, status in [
    (9, 0, 1, 200), (9, 10, 2, 200), (9, 20, 3, 429),
    (9, 30, 4, 429), (9, 40, 5, 200),
]:
    lines.append("[GIN] 2026/08/24 - %02d:%02d:%02d | %d | 1.0ms | 127.0.0.1 | GET \"/api/tags\"" % (hh, mm, ss, status))
lines.append("[GIN] 2026/08/23 - 09:00:00 | 200 | 1.0ms | 127.0.0.1 | GET \"/api/tags\"")  # outside window
with open(path, "w") as f:
    f.write("\n".join(lines) + "\n")
PYEOF
python3 - "$WORK" <<'PYEOF'
import json, os, sys
work = sys.argv[1]
sess = os.path.join(work, "untracked", "tokens", "sessions", "T950.jsonl")
with open(sess, "w") as f:
    f.write(json.dumps({"type": "session", "id": "s", "timestamp": "2026-08-24T07:00:00.000Z", "cwd": "/tmp"}) + "\n")
    f.write(json.dumps({"type": "message", "timestamp": "2026-08-24T07:15:00Z", "message": {"role": "assistant"}}) + "\n")
with open(os.path.join(work, "untracked", "runs", "T950.json"), "w") as f:
    json.dump({"task": "T950", "model": "glm-5.2",
               "command": "ollama launch pi --model glm-5.2:cloud -y -- --session %s -p 'x'" % sess,
               "start": "2026-08-24T07:00:01Z", "end": "2026-08-24T07:20:00Z",
               "session_path": sess, "session_path_reason": None}, f)
PYEOF
# the pi session's own timestamps are literal UTC; the fixture GIN log's
# lines are the host's LOCAL (Europe/Oslo, UTC+2 in August) wall clock, so
# local 09:00-09:40 is UTC 07:00-07:40 -> a window of [07:00Z, 08:00Z)
# covers both.
OUT=$(python3 "$TOOL" --root "$WORK" --now "2026-08-24T08:00:00Z" --window-seconds 3600 \
    --ollama-log "$GINLOG" --json)
python3 - "$OUT" <<'PYEOF'
import json, sys
r = json.loads(sys.argv[1])
cc = r["ollama_cross_check"]
assert cc["ok"], cc
assert cc["gin_total_requests"] == 5, cc
assert cc["gin_status_429"] == 2, cc
assert cc["ollama_family_known_requests"] == 1, cc
assert cc["discrepancy"] == 4, cc
assert "never reconciled" in cc["note"], cc
print("OK")
PYEOF
if [ $? -eq 0 ]; then
    pass "5 in-window [GIN] lines (2x 429) counted, 1 out-of-window line excluded; known=1, discrepancy=4, reported not reconciled"
else
    fail "arm H: ollama cross-check counts wrong"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-request-accounting: ALL PASS (8 arms) ==="
else
    echo "=== regression-request-accounting: FAILURES ==="
    exit 1
fi
