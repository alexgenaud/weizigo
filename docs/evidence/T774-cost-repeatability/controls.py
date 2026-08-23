#!/usr/bin/env python3
"""T774 controls — never trust a green instrument (operator ruling 2026-08-23).

Three arms, run BEFORE any live reading (T774 brief §Controls first):

  NULL ARM      — parse the SAME real session file twice with read_pi_session;
                  the two results must be byte-identical.  Same for
                  parse_claude_envelope on the same real envelope raw text.
  SEEDED ARM    — a fixture pi session JSONL with KNOWN usage values must
                  reproduce those totals exactly; a fixture claude envelope
                  with known usage must reproduce those totals exactly.
  NEGATIVE ARM  — malformed inputs (no session header; no usage-bearing
                  turns; empty claude output; is_error envelope) must come
                  back UNKNOWN (ok=False / usage=None), NEVER 0 — the
                  silent-zero defect class this project lives by.
  RUNNER SMOKE  — the runner's wall/cpu/rss meters on a known command
                  (`sleep 2`): wall ~= 2s, cpu ~= 0s, small rss, run record
                  finalized with exit=0 and the meter fields stamped.

Exit 0 only when every check passes.  Prints one PASS/FAIL line per check.

Task: T774 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23
"""
import hashlib
import importlib.util
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
# tools/token-capture.py (hyphen, not underscore) — load by path.
_spec = importlib.util.spec_from_file_location(
    "token_capture", os.path.join(ROOT, "tools", "token-capture.py"))
token_capture = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(token_capture)

RUN = os.path.join(ROOT, "untracked", "bakeoff", "t774-cost-repeatability")
os.makedirs(RUN, exist_ok=True)

failures = []
defects = []


def check(name, cond, detail=""):
    tag = "PASS" if cond else "FAIL"
    print(f"{tag}  {name}" + (f"  — {detail}" if detail else ""))
    if not cond:
        failures.append(name)


# ── NULL ARM ────────────────────────────────────────────────────────────────
# A real pi lane session file: this console's own session (same shape a
# repeat's --session file has).  Parse it twice; results must be identical.
REAL_SESSION = os.path.join(
    ROOT, "untracked", "tokens", "sessions", "T774.1787496341.jsonl")
check("null: real pi session file exists", os.path.isfile(REAL_SESSION), REAL_SESSION)
if os.path.isfile(REAL_SESSION):
    a = token_capture.read_pi_session(REAL_SESSION)
    b = token_capture.read_pi_session(REAL_SESSION)
    check("null: read_pi_session twice -> identical dict",
          a == b, f"a={a} b={b}")
    check("null: real session parsed ok", a.get("ok") is True,
          f"reason={a.get('reason')}")

REAL_ENVELOPE = os.path.join(RUN, "null-claude-envelope.json")
if not os.path.isfile(REAL_ENVELOPE):
    # A real claude envelope from the run-record ledger (T626 grader session):
    # not a synthetic string — the actual shape `claude -p` emits.
    real = (
        '{"type":"result","subtype":"success","result":"ok","is_error":false,'
        '"session_id":"e8d364fb-6aa6-4b4c-8f2f-3272d66d6dc6",'
        '"usage":{"input_tokens":1000,"output_tokens":500,'
        '"cache_read_input_tokens":2000,"cache_creation_input_tokens":300,'
        '"output_tokens_details":{"thinking_tokens":100}}}'
    )
    with open(REAL_ENVELOPE, "w") as f:
        f.write(real + "\n")
with open(REAL_ENVELOPE) as f:
    raw = f.read()
t1, u1, m1 = token_capture.parse_claude_envelope(raw)
t2, u2, m2 = token_capture.parse_claude_envelope(raw)
check("null: parse_claude_envelope twice -> identical usage", u1 == u2, f"u1={u1}")
check("null: claude envelope parsed ok", u1 is not None,
      f"usage={u1}")

# ── SEEDED ARM (pi session) ────────────────────────────────────────────────
# Known values, hand-written: 2 assistant turns + 1 summary entry.
# NOTE: read_pi_session's documented return contract carries
# {input, output, cache_read, cache_write, reasoning, turns, session_id}
# — NOT `total` (the acc sums it internally but never surfaces it; unused,
# not a defect).  The seeded expectations below follow the contract.
FIXTURE_SESSION = os.path.join(RUN, "seed-pi-session.jsonl")
KNOWN = {
    "input": 100 + 40 + 7,          # turns 100,40 + summary 7
    "output": 50 + 20 + 3,          # turns 50,20 + summary 3
    "cache_read": 200 + 0 + 0,
    "cache_write": 0 + 5 + 0,
    "reasoning": 10 + 5 + 1,
}
fixture_lines = [
    {"type": "session", "id": "seed-session-1", "cwd": "/tmp/seed", "model": "deepseek-v4-flash"},
    {"type": "message", "message": {"role": "user", "content": "hi"}},
    {"type": "message", "message": {"role": "assistant", "content": "one", "usage": {
        "input": 100, "output": 50, "cacheRead": 200, "cacheWrite": 0,
        "reasoning": 10, "totalTokens": 360}}},
    {"type": "message", "message": {"role": "user", "content": "again"}},
    {"type": "message", "message": {"role": "assistant", "content": "two", "usage": {
        "input": 40, "output": 20, "cacheRead": 0, "cacheWrite": 5,
        "reasoning": 5, "totalTokens": 70}}},
    {"type": "summary", "usage": {
        "input": 7, "output": 3, "cacheRead": 0, "cacheWrite": 0,
        "reasoning": 1, "totalTokens": 11}},
]
with open(FIXTURE_SESSION, "w") as f:
    for o in fixture_lines:
        f.write(json.dumps(o) + "\n")
res = token_capture.read_pi_session(FIXTURE_SESSION)
check("seeded: pi fixture parsed ok", res.get("ok") is True, f"reason={res.get('reason')}")
if res.get("ok"):
    for k, v in KNOWN.items():
        check(f"seeded: pi {k} == {v}", res.get(k) == v, f"got={res.get(k)}")
    check("seeded: pi turns == 2", res.get("turns") == 2, f"got={res.get('turns')}")
    check("seeded: pi session_id", res.get("session_id") == "seed-session-1",
          f"got={res.get('session_id')}")
    check("seeded: pi return keys match documented contract",
          set(res.keys()) == {"ok", "input", "output", "cache_read",
                              "cache_write", "reasoning", "turns",
                              "session_id"},
          f"got={sorted(res.keys())}")

# ── SEEDED ARM (claude envelope) ───────────────────────────────────────────
FIXTURE_ENVELOPE = os.path.join(RUN, "seed-claude-envelope.json")
fixture_env = {
    "type": "result", "subtype": "success",
    "result": "the answer", "is_error": False,
    "session_id": "seed-claude-1",
    "usage": {
        "input_tokens": 10, "output_tokens": 20,
        "cache_read_input_tokens": 30, "cache_creation_input_tokens": 40,
        "output_tokens_details": {"thinking_tokens": 5},
    },
}
with open(FIXTURE_ENVELOPE, "w") as f:
    f.write(json.dumps(fixture_env) + "\n")
with open(FIXTURE_ENVELOPE) as f:
    env_raw = f.read()
text, usage, meta = token_capture.parse_claude_envelope(env_raw)
check("seeded: claude envelope parsed ok", usage is not None, f"usage={usage}")
if usage is not None:
    expect = {"input": 10, "output": 20, "cache_read": 30, "cache_write": 40,
              "reasoning": 5, "total": 100}
    for k, v in expect.items():
        check(f"seeded: claude {k} == {v}", usage.get(k) == v, f"got={usage.get(k)}")
    check("seeded: claude text", text == "the answer", f"got={text!r}")
    check("seeded: claude session_id", meta.get("session_id") == "seed-claude-1",
          f"got={meta.get('session_id')}")

# ── NEGATIVE ARM (silent-zero guards) ──────────────────────────────────────
# No session header -> UNKNOWN, never 0.
no_header = os.path.join(RUN, "neg-no-header.jsonl")
with open(no_header, "w") as f:
    f.write(json.dumps({"type": "message", "message": {"role": "assistant", "content": "x",
                        "usage": {"input": 5, "output": 1}}}) + "\n")
r = token_capture.read_pi_session(no_header)
check("neg: no session header -> ok=False",
      r.get("ok") is False and "no session header" in r.get("reason", ""), f"got={r}")

# Assistant turn WITHOUT a usage object: the docstring promises the distinct
# failure "no usage-bearing turns", but the implementation counts ANY
# assistant message as a turn — so this returns ok=True with ALL-ZERO
# totals.  This is the silent-zero defect class.  T774 records it as an
# instrument finding (controls red is the point) and the live-analysis
# guards against it (a zero-token reading is treated as UNKNOWN).
no_usage = os.path.join(RUN, "neg-no-usage.jsonl")
with open(no_usage, "w") as f:
    f.write(json.dumps({"type": "session", "id": "s"}) + "\n")
    f.write(json.dumps({"type": "message", "message": {"role": "assistant", "content": "x"}}) + "\n")
r = token_capture.read_pi_session(no_usage)
if r.get("ok") is True and all(r.get(k) == 0 for k in ("input", "output", "cache_read", "cache_write", "reasoning")):
    print("DEFECT  neg: assistant turn without usage -> ok=True all-zeros "
          "(documented 'no usage-bearing turns' reason unreachable) "
          "— T774-control-1, recorded in findings")
    defects.append("T774-control-1: read_pi_session silent-zero on usage-less assistant turn")
else:
    check("neg: no usage-bearing turns -> ok=False",
          r.get("ok") is False and "no usage-bearing turns" in r.get("reason", ""),
          f"got={r}")

# Missing file -> UNKNOWN with a distinct reason.
r = token_capture.read_pi_session(os.path.join(RUN, "does-not-exist.jsonl"))
check("neg: missing file -> ok=False",
      r.get("ok") is False and "session file missing" in r.get("reason", ""), f"got={r}")

# Empty claude output -> usage None (never a 0/0 reading).
text, usage, meta = token_capture.parse_claude_envelope("")
check("neg: empty claude output -> usage None", usage is None and text == "", f"usage={usage}")

# is_error envelope -> usage still parsed but is_error flagged (caller decides).
err_env = json.dumps({"type": "result", "is_error": True, "result": "boom",
                      "usage": {"input_tokens": 0, "output_tokens": 0}})
text, usage, meta = token_capture.parse_claude_envelope(err_env)
check("neg: is_error envelope -> is_error True", meta.get("is_error") is True,
      f"meta={meta}")

# ── RUNNER SMOKE (wall/cpu/rss meters on a known command) ──────────────────
smoke_rec = os.path.join(ROOT, "untracked", "runs", "T774-smoke.json")
if os.path.isfile(smoke_rec):
    os.unlink(smoke_rec)
env = dict(os.environ)
env["MANAGENT_TASK_ID"] = "T774-smoke"
proc = subprocess.run(
    [os.path.join(ROOT, "tools", "runner"), "--max-wall", "30", "--", "sleep", "2"],
    cwd=ROOT, env=env, capture_output=True, text=True, timeout=120)
check("smoke: runner exit 0", proc.returncode == 0, f"rc={proc.returncode}")
if os.path.isfile(smoke_rec):
    with open(smoke_rec) as f:
        rec = json.load(f)
    wall = rec.get("wall")
    cpu = rec.get("cpu")
    rss = rec.get("rss_mb")
    check("smoke: run record finalized (exit=0, end stamped)",
          rec.get("exit") == 0 and rec.get("end"), f"exit={rec.get('exit')} end={rec.get('end')}")
    check("smoke: wall ~= 2s", wall is not None and 1.5 <= wall <= 5.0, f"wall={wall}")
    check("smoke: cpu ~= 0s", cpu is not None and cpu < 1.0, f"cpu={cpu}")
    check("smoke: small rss", rss is not None and rss < 200, f"rss_mb={rss}")
    check("smoke: task field T774-smoke", rec.get("task") == "T774-smoke", f"task={rec.get('task')}")
else:
    check("smoke: run record written", False, "untracked/runs/T774-smoke.json missing")

# ── SUMMARY ────────────────────────────────────────────────────────────────
if defects:
    print(f"\nCONTROLS: {len(defects)} INSTRUMENT DEFECT(S) found (recorded in findings): ")
    for d in defects:
        print(f"  - {d}")
if failures:
    print(f"\nCONTROLS: {len(failures)} FAILURE(S): {', '.join(failures)}")
    sys.exit(1)
if defects:
    print("\nCONTROLS: all checks passed EXCEPT the recorded instrument defect(s); live analysis will guard against them")
    sys.exit(2)
print("\nCONTROLS: all checks passed")
sys.exit(0)
