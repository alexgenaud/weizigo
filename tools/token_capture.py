#!/usr/bin/env python3
"""Mechanical per-task token capture (T521, D-a — capture path).

G1 IS RUN-TIME, NOT RETROACTIVE (D043, 2026-08-20): tokens are captured at
dispatch or LOST. Every prior race ended at n=0 readings because capture was
by seat memory after the fact, or never. This instrument IS the capture
path — the code the lane wrapper (tools/runner) and the dispatchers
(bin/subagent, tools/bakeoff.sh) call AT DISPATCH TIME:

  parse_claude_envelope(raw)  -> (text, usage, meta)
      `claude -p --output-format json` stdout: the runner extracts BOTH the
      result text (forwarded to the lane's stdout, so verification and
      grading see the answer) and the usage counts (recorded mechanically),
      plus the resumable session handle (T552).  Ground truth shape, claude
      2.1.237, probed irl 2026-08-20: single-line JSON {type:'result',
      subtype:'success', result:<text>, is_error:bool, session_id:<uuid>,
      usage:{input_tokens, output_tokens, cache_read_input_tokens,
      cache_creation_input_tokens, output_tokens_details:{thinking_tokens}}}.  The
      session handle rides in meta (session_id / session_id_present) so the
      envelope is parsed ONCE — never a second parser (T517 single-source
      lesson).

  write_tees(root, task, ts, provider, stdout_text, stderr_text)
      deepseek/pi and ollama/qwen lanes produce no structured usage line, so
      the COMPLETE raw stdout+stderr of every run is teed per task to
      untracked/tokens/ — any usage line the harness ever prints survives.

  append_ledger(root, entry)
      one JSON line per run in untracked/tokens/tokens.jsonl. A task with
      no reading is recorded MISSING EXPLICITLY with a reason — reported as
      such, never estimated, never a blank cell (the 6/6 blank
      tokens.template.md with n=0 is the recorded breach this replaces).

The G1 join surface the grand-race harness (tools/bakeoff.sh) calls —
`--json --cwd <root> --since <date>` — builds the per-model `models` map
from the dispatch-time ledger first; a label with any real ledger reading
uses ONLY the ledger (capture-time wins). Labels with no ledger reading fall
back to the pi session scan (the harness's own meter for pi lanes: a `usage`
object on every assistant turn of every session JSONL under
~/.pi/agent/sessions/<cwd-slug>/). Claude labels have no session record, so
their numbers come from the ledger or are absent (rows dispatched before
capture landed are permanently missing — launch-haste, not a protocol
change; reported via the `missing` section and the bakeoff null+reason path).

READ-ONLY except the two deliberate writes above: the tee files and the
ledger, both under <root>/untracked/tokens/. Nothing else is written.

Token fields (normalized per the harness `usage` object; a missing key is 0):
  input        fresh prompt tokens (non-cached)
  cache_read   cached prompt tokens read from context
  cache_write  prompt tokens written to the cache
  output       completion tokens
  reasoning    reasoning tokens (present only on reasoning-capable models)
  total        the harness's own totalTokens figure (computed for claude)

Derived for the grand-race ledger schema (§6: tokens_in / tokens_out):
  tokens_in  = input + cache_read   (everything the model read)
  tokens_out = output               (everything the model wrote)

Prices are deliberately NOT surfaced: the tokens-now-prices-later doctrine
(docs/infra/bakeoff.md) records the measured quantity, never a dollar figure.

Model tags are canonicalized by RESOLVING the single transform
(src/managent/main.zig canonicalizeModelTag via tools/model_tags.py) — one
canonicalizer, not four (T801): strip `:cloud`, `kimi-k2.7-code` ->
`kimi-k2.7`, `stealth/ox-alpha` -> `oxalpha`; an unrecognized non-empty tag
is rejected, never passed through unchanged.

Task: T521 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20
"""
import argparse
import datetime
import json
import os
import re
import sys

# T801: the serving-tag -> canonical transform now lives in ONE place
# (src/managent/main.zig canonicalizeModelTag) and is RESOLVED here via
# tools/model_tags.py (which shells out to `managent models --tags --json`,
# cached) — never reimplemented.  model_tags.py sits beside this file, so
# make this directory importable under every load mechanism (the runner's
# spec_from_file_location, tests/unit/_load.py, a bare python3 run).
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)
import model_tags as _mt  # noqa: E402
from model_tags import UnknownModelTag  # noqa: E402

# Usage keys summed per assistant turn.  A key missing from a turn counts 0.
TOKEN_KEYS = ["input", "output", "cache_read", "cache_write", "reasoning", "total"]

# claude envelope (snake_case, v2.1.237 ground truth) -> internal keys.
CLAUDE_USAGE_KEYS = {
    "input": "input_tokens",
    "output": "output_tokens",
    "cache_read": "cache_read_input_tokens",
    "cache_write": "cache_creation_input_tokens",
}


def __getattr__(name):
    # T801: CANONICAL_MODELS / SERVING_TAG_MAP survive only as the READ
    # surface older consumers and the unit tests reach through.  They are
    # resolved from the single source on first access and then cached as
    # module globals; the transform itself is model_tags.canon_tag below.
    if name == "CANONICAL_MODELS":
        val = _mt.canonical_models()
        globals()["CANONICAL_MODELS"] = val
        return val
    if name == "SERVING_TAG_MAP":
        val = _mt.serving_tag_map()
        globals()["SERVING_TAG_MAP"] = val
        return val
    raise AttributeError("module %r has no attribute %r" % (__name__, name))


def _empty_meta():
    """The meta dict for output with no parseable envelope: no error, no
    terminal reason, and no session handle (session_id None, present=False)
    so callers can always read the same keys."""
    return {
        "is_error": False,
        "terminal_reason": None,
        "session_id": None,
        "session_id_present": False,
    }


def canon_tag(tag):
    """The serving-tag -> canonical transform, RESOLVED from the single source
    (src/managent/main.zig canonicalizeModelTag via `managent models --tags`)
    — a thin reader, not a second copy (T801).

    STRICT boundary: `stealth/ox-alpha` -> `oxalpha` and
    `kimi-k2.7-code:cloud` -> `kimi-k2.7` exactly as managent does; an
    unrecognized non-empty tag raises UnknownModelTag instead of being passed
    through unchanged (pass-through is how a serving tag reached the ledger,
    T746/T276).  None / '' / whitespace resolve to '' (no model).
    """
    return _mt.canon_tag(tag)


def slug(cwd):
    """Map a cwd to the pi harness session-directory slug.

    `/Users/alex/Project/Zig/weizigo` -> `--Users-alex-Project-Zig-weizigo--`
    (leading `/` stripped, `/` -> `-`, wrapped in `--` on each side — matches
    the harness's actual on-disk names).
    """
    return "--" + cwd.lstrip("/").replace("/", "-") + "--"


def default_sessions_dir(cwd):
    return os.path.join(os.path.expanduser("~"), ".pi", "agent", "sessions", slug(cwd))


def tokens_dir(root):
    """untracked/tokens/ — the ledger + tee home. Created on first write."""
    return os.path.join(root, "untracked", "tokens")


def ledger_path(root):
    return os.path.join(tokens_dir(root), "tokens.jsonl")


def _sanitize(seg):
    """Filesystem-safe filename segment from a task identity / timestamp."""
    return "".join(ch if (ch.isalnum() or ch in "._-") else "_" for ch in seg)


def write_tees(root, task, ts, provider, stdout_text, stderr_text):
    """Tee the COMPLETE raw stdout+stderr of one run to disk, per task.

    Returns (out_path, err_path), or (None, None) when root is falsy.  Any
    usage line the harness ever prints survives here — the deepseek/pi and
    ollama/qwen lanes have no structured usage envelope, so this tee IS the
    capture for them (D043 item 2).
    """
    if not root:
        return None, None
    d = tokens_dir(root)
    try:
        os.makedirs(d, exist_ok=True)
    except OSError:
        return None, None
    base = f"{_sanitize(task or 'unknown')}.{_sanitize(ts or 'nots')}.{_sanitize(provider or 'none')}"
    out_path = os.path.join(d, base + ".stdout.log")
    err_path = os.path.join(d, base + ".stderr.log")
    try:
        with open(out_path, "w") as f:
            f.write(stdout_text or "")
        with open(err_path, "w") as f:
            f.write(stderr_text or "")
        return out_path, err_path
    except OSError:
        return None, None


def append_ledger(root, entry):
    """Append one JSON line to untracked/tokens/tokens.jsonl.

    The record is a READING (tokens_in/tokens_out + source) or an explicit
    MISSING (nulls + missing_reason) — never both, never neither, never a
    blank cell.
    """
    if not root:
        return False
    d = tokens_dir(root)
    try:
        os.makedirs(d, exist_ok=True)
        with open(ledger_path(root), "a") as f:
            f.write(json.dumps(entry, sort_keys=True) + "\n")
        return True
    except OSError:
        return False


def parse_claude_envelope(raw):
    """Parse `claude -p --output-format json` stdout.

    Returns (text, usage, meta):
      text  the model's final answer text (the envelope's `result`); the
            raw output when no envelope parses (forwarded unchanged, so a
            shape change degrades to passthrough, never to silence).
      usage normalized dict {input, output, cache_read, cache_write,
            reasoning, total} or None when the output carries no usage.
      meta  {"is_error": bool, "terminal_reason": str|None} so the caller
            can decide reading vs missing (an api-error envelope with zero
            usage is MISSING, never a 0/0 reading).
    """
    text = raw or ""
    if not text.strip():
        return "", None, _empty_meta()
    obj = None
    # 1. whole-output parse (single-line or pretty-printed single object).
    candidates = [text]
    stripped = text.strip()
    if stripped and stripped != text:
        candidates.append(stripped)
    last = stripped.splitlines()[-1] if stripped else ""
    if last and last != stripped:
        candidates.append(last)
    for c in candidates:
        try:
            o = json.loads(c)
            if isinstance(o, dict):
                obj = o
                break
        except (ValueError, TypeError):
            continue
    # 2. JSONL stream (stream-json): keep the LAST parseable object — the
    #    usage envelope lives on the final `result` event.
    if obj is None:
        for line in text.splitlines():
            try:
                o = json.loads(line)
            except (ValueError, TypeError):
                continue
            if isinstance(o, dict):
                obj = o
    if not isinstance(obj, dict):
        return text, None, _empty_meta()
    meta = {
        "is_error": bool(obj.get("is_error")),
        "terminal_reason": obj.get("terminal_reason"),
        # T552: the resumable session handle.  session_id is the string
        # value (or None); session_id_present is True only for a usable
        # string handle, so a shape change degrades to null + a reason,
        # never a blank and never an invented id.
        "session_id": obj.get("session_id") if isinstance(obj.get("session_id"), str) else None,
        "session_id_present": isinstance(obj.get("session_id"), str),
    }
    result = obj.get("result")
    if not isinstance(result, str):
        result = text
    usage_obj = obj.get("usage")
    if not isinstance(usage_obj, dict):
        return result, None, meta

    def _num(k):
        v = usage_obj.get(k)
        return v if isinstance(v, (int, float)) else 0

    input_ = _num(CLAUDE_USAGE_KEYS["input"])
    output = _num(CLAUDE_USAGE_KEYS["output"])
    cache_read = _num(CLAUDE_USAGE_KEYS["cache_read"])
    cache_write = _num(CLAUDE_USAGE_KEYS["cache_write"])
    thinking = 0
    otd = usage_obj.get("output_tokens_details")
    if isinstance(otd, dict):
        t = otd.get("thinking_tokens")
        if isinstance(t, (int, float)):
            thinking = t
    usage = {
        "input": input_, "output": output,
        "cache_read": cache_read, "cache_write": cache_write,
        "reasoning": thinking,
        "total": input_ + output + cache_read + cache_write,
    }
    # An is_error envelope whose usage is present but all-zero is a MISSING,
    # never a legitimate-looking 0/0 reading (T794; the docstring's rule,
    # previously enforced only for the usage-absent shape).
    if meta["is_error"] and input_ == output == cache_read == cache_write == 0:
        return result, None, meta
    return result, usage, meta


# ── pi session scan (the reader mode; retroactive meter for pi lanes) ──────

def _usage_zero():
    return {k: 0 for k in TOKEN_KEYS}


def _add_usage(acc, usage):
    """Add a harness `usage` object into acc (mutating acc)."""
    if not isinstance(usage, dict):
        return
    for k in TOKEN_KEYS:
        v = usage.get(_harness_key(k), 0)
        if isinstance(v, (int, float)):
            acc[k] += v


def _harness_key(k):
    """Map an internal snake_case token key to the harness's usage-object key."""
    return {
        "input": "input",
        "output": "output",
        "cache_read": "cacheRead",
        "cache_write": "cacheWrite",
        "reasoning": "reasoning",
        "total": "totalTokens",
    }[k]


# ── T662: the per-lane pi-session meter reader ────────────────────────────
# The runner calls read_pi_session() after a pi/ollama lane closes, with
# the session path it passed at dispatch (`--session <path>`).  This is
# the "retroactive meter" made deterministic: the file is per-lane, so no
# attribution by prompt text is needed (the G1 scan below is the fallback
# for lanes that predate the dispatch path).


def read_pi_session(path):
    """Read ONE pi session JSONL as the lane's token meter (T662).

    Returns {"ok": True, "input", "output", "cache_read", "cache_write",
    "reasoning", "turns", "session_id"} or {"ok": False, "reason"}.
    The failure reasons are DISTINCT because each means something
    different for the economy ladder:

      - "session file missing: <path>"   (pi never wrote the file)
      - "session file unreadable: <err>" (IO error)
      - "no session header"              (empty / truncated file)
      - "no usage-bearing turns"         (no completed model call)

    A caller must treat ok=False as UNKNOWN — never 0, never the total.
    Usage is summed over every assistant turn AND every summary/compaction
    entry (pi's footer totals count both); a missing usage key counts 0
    (pi normalizes the usage object shape for every provider — the same
    key set was observed for deepseek and local ollama).
    """
    if not os.path.isfile(path):
        return {"ok": False, "reason": "session file missing: %s" % path}
    acc = {k: 0 for k in TOKEN_KEYS}
    session_id = None
    turns = 0
    bad = 0
    try:
        fh = open(path, errors="replace")
    except OSError as e:
        return {"ok": False, "reason": "session file unreadable: %s" % e}
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except ValueError:
                bad += 1
                continue
            if not isinstance(o, dict):
                bad += 1
                continue
            t = o.get("type")
            if t == "session":
                if isinstance(o.get("id"), str):
                    session_id = o["id"]
                continue
            m = o.get("message")
            if t == "message" and isinstance(m, dict) and m.get("role") == "assistant":
                turns += 1
                _add_usage(acc, m.get("usage"))
            elif t in ("summary", "compaction") and isinstance(o.get("usage"), dict):
                # pi's footer totals include the usage of summary generation.
                _add_usage(acc, o.get("usage"))
    if session_id is None:
        return {"ok": False,
                "reason": "no session header in %s" % os.path.basename(path)}
    if turns == 0:
        return {"ok": False,
                "reason": "no usage-bearing turns in %s" % os.path.basename(path)}
    return {"ok": True,
            "input": acc["input"], "output": acc["output"],
            "cache_read": acc["cache_read"], "cache_write": acc["cache_write"],
            "reasoning": acc["reasoning"], "turns": turns,
            "session_id": session_id}


# ── D044 (2026-08-22): the deepseek time-pricing band ─────────────────────
# Operator ruling in measurement-methodology.md §1b: deepseek is per-token
# at a clock-varying rate — peak 01:00-04:00 and 06:00-10:00 UTC at full
# rate, every other hour half, and UTC Fri 16:00 -> Sun 16:00 (Saturday +
# Sunday Beijing time) half regardless of hour.  The band is a fact about
# WHEN the run happened and is computed at write time, so a later reader
# never re-derives a calendar rule from a bare count.  DeepSeek only — the
# other families have no time-priced rate (claude: subscription occupancy;
# ollama: credits; local: the machine).


def deepseek_rate_band(ts_iso):
    """Return 'peak' | 'off-peak' for a run's UTC timestamp, or None when
    the timestamp cannot be parsed (the caller records None + a reason, or
    leaves the reading unbanded — never a guessed band)."""
    if not ts_iso:
        return None
    try:
        s = ts_iso.strip()
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        dt = datetime.datetime.fromisoformat(s)
    except ValueError:
        return None
    utc = dt.astimezone(datetime.timezone.utc)
    wd = utc.weekday()   # Mon=0 .. Sun=6
    hour = utc.hour
    # weekend override: UTC Fri 16:00 -> Sun 16:00 is off-peak all day
    in_override = (wd == 4 and hour >= 16) or wd == 5 or (wd == 6 and hour < 16)
    if in_override:
        return "off-peak"
    if (1 <= hour < 4) or (6 <= hour < 10):
        return "peak"
    return "off-peak"


def _first_user_text(lines):
    """Return the text of the first user message in a session file's lines."""
    for line in lines:
        try:
            o = json.loads(line)
        except (ValueError, TypeError):
            continue
        m = o.get("message")
        if o.get("type") == "message" and isinstance(m, dict) and m.get("role") == "user":
            parts = []
            for c in m.get("content", []):
                if isinstance(c, dict) and c.get("type") == "text":
                    parts.append(c.get("text", ""))
            return "".join(parts)
    return ""


def extract_task(text):
    """The task id a dispatch prompt names, or None.

    Priority (T794): 1. the canonical instruction line
    `Follow untracked/T<id>-<slug>.md`; 2. the `claim T<id>` line of the
    dispatch preamble; 3. any other `untracked/T<id>` mention.  A bare
    `T<id>` mention is NOT matched — prose referencing another task must not
    mis-attribute a session — and a brief that cites ANOTHER row's bundle in
    its prose attributes to the Follow'd task, not the citation (the
    first-match defect this order replaces).
    """
    if not text:
        return None
    m = re.search(r"Follow\s+untracked/T(\d+)", text)
    if m:
        return "T" + m.group(1)
    m = re.search(r"claim\s+T(\d+)", text)
    if m:
        return "T" + m.group(1)
    m = re.search(r"untracked/T(\d+)", text)
    if m:
        return "T" + m.group(1)
    return None


def parse_session(path):
    """Parse one session JSONL into a per-session record.

    Returns None for a file with no assistant turns (nothing to measure) —
    the caller still counts it as a scanned file for the summary.
    """
    rec = {
        "file": os.path.basename(path),
        "start": None,
        "cwd": None,
        "task": None,
        "provider": None,
        "turns": 0,
        "tokens": _usage_zero(),
        "model_turns": {},   # canonical model -> turn count
        "bad_lines": 0,
        # T801: turns whose model tag is not a canonical label are PRESENT
        # and labeled (never silently attributed, never a fake label).
        "noncanonical_turns": 0,
        # T662: the resumable handle (the session header's id), so the
        # scan path can name a session file the way the lane records do.
        "session_id": None,
    }
    try:
        fh = open(path, errors="replace")
    except OSError:
        return None
    with fh:
        first_user = None
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except ValueError:
                rec["bad_lines"] += 1
                continue
            t = o.get("type")
            if t == "session":
                rec["start"] = o.get("timestamp")
                rec["cwd"] = o.get("cwd")
                if isinstance(o.get("id"), str):
                    rec["session_id"] = o["id"]
                continue
            m = o.get("message")
            if t == "message" and isinstance(m, dict):
                if m.get("role") == "user" and first_user is None:
                    first_user = _first_user_text([line])
                elif m.get("role") == "assistant":
                    rec["turns"] += 1
                    try:
                        model = canon_tag(m.get("model") or "")
                    except UnknownModelTag:
                        # T801: an unrecognized tag is not a model label —
                        # the turn's TOKENS still count (the meter is not
                        # attribution), but the turn is not attributed to a
                        # model and the count records it loudly.
                        model = None
                        rec["noncanonical_turns"] += 1
                    if not rec["provider"] and m.get("provider"):
                        rec["provider"] = m.get("provider")
                    if model:
                        rec["model_turns"][model] = rec["model_turns"].get(model, 0) + 1
                    _add_usage(rec["tokens"], m.get("usage"))

    if rec["turns"] == 0:
        return None
    if first_user is None:
        first_user = ""
    rec["task"] = extract_task(first_user)
    # Dominant model (by turn count), ties broken lexicographically.
    if rec["model_turns"]:
        rec["model"] = max(rec["model_turns"], key=lambda m: (rec["model_turns"][m], m))
    else:
        rec["model"] = None
    # Derived grand-race ledger fields.
    rec["tokens_in"] = rec["tokens"]["input"] + rec["tokens"]["cache_read"]
    rec["tokens_out"] = rec["tokens"]["output"]
    return rec


def scan_sessions(sessions_dir, since=None, task=None, model=None):
    """Scan a pi session dir; return (sessions, tasks, models, unattributed, scanned)."""
    sessions = []
    if os.path.isdir(sessions_dir):
        try:
            names = sorted(os.listdir(sessions_dir))
        except OSError:
            names = []
        for name in names:
            if not name.endswith(".jsonl"):
                continue
            rec = parse_session(os.path.join(sessions_dir, name))
            if rec is None:
                continue
            sessions.append(rec)
    if since:
        sessions = [s for s in sessions if (s.get("start") or "") >= since]
    if task:
        sessions = [s for s in sessions if s.get("task") == task]
    if model:
        # T801: the --model filter arg is a boundary — an unknown label is
        # rejected loudly (a clean CLI error), never silently passed through.
        want = canon_tag(model)
        sessions = [s for s in sessions if (s.get("model") or "") == want]
    tasks = {}
    models = {}
    unattributed = _empty_agg()
    scanned = len(sessions)
    for s in sessions:
        if s["task"] is None:
            _fold(unattributed, s)
            continue
        t = tasks.setdefault(s["task"], {
            "model": None, "provider": None, "sessions": 0, "turns": 0,
            "tokens": _usage_zero(), "tokens_in": 0, "tokens_out": 0,
        })
        _fold(t, s)
        if s.get("model"):
            t["model"] = s["model"]
        if s.get("provider"):
            t["provider"] = s["provider"]
    for tid, t in tasks.items():
        m = t["model"]
        if m:
            a = models.setdefault(m, _empty_agg())
            a["sessions"] += t["sessions"]
            a["turns"] += t["turns"]
            for k in TOKEN_KEYS:
                a["tokens"][k] += t["tokens"][k]
            a["tokens_in"] += t["tokens_in"]
            a["tokens_out"] += t["tokens_out"]
            if "tasks" not in a:
                a["tasks"] = set()
            a["tasks"].add(tid)
    for m in models.values():
        m["tasks"] = sorted(m["tasks"])
    return sessions, tasks, models, unattributed, scanned


def _empty_agg():
    return {"sessions": 0, "turns": 0, "tokens": _usage_zero(),
            "tokens_in": 0, "tokens_out": 0}


def _fold(agg, s):
    agg["sessions"] += 1
    agg["turns"] += s["turns"]
    for k in TOKEN_KEYS:
        agg["tokens"][k] += s["tokens"][k]
    agg["tokens_in"] += s["tokens_in"]
    agg["tokens_out"] += s["tokens_out"]


# ── capture ledger (the dispatch-time truth) ───────────────────────────────

def load_ledger(root, since=None, task=None):
    """Read untracked/tokens/tokens.jsonl; return a list of entry dicts.

    Malformed lines are skipped with a count (a corrupt line must never
    poison the aggregate; the count is reported so absence of the count is
    not silence).
    """
    entries = []
    bad = 0
    if not root:
        return entries, bad
    path = ledger_path(root)
    if not os.path.isfile(path):
        return entries, bad
    try:
        fh = open(path)
    except OSError:
        return entries, bad
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except ValueError:
                bad += 1
                continue
            if not isinstance(e, dict):
                bad += 1
                continue
            if since and (e.get("ts") or "") < since:
                continue
            if task and e.get("task") != task:
                continue
            entries.append(e)
    return entries, bad


def _ledger_reading(e):
    """True when the ledger entry carries a real reading (not a missing)."""
    return e.get("tokens_in") is not None or e.get("tokens_out") is not None


def merge_models(session_models, ledger_entries):
    """G1 join: the dispatch-time ledger wins for a label; the session scan
    fills labels with no ledger reading. Returns (models, missing).

    models[label] aggregates the REAL readings from the ledger when any
    exist for the label; otherwise the session-scan total for the label.
    missing[label-task] = the ledger's explicit missing records, so a task
    with no reading is reported with its reason — never a blank cell.
    """
    models = dict(session_models)
    ledger_by_model = {}
    missing = {}
    for e in ledger_entries:
        raw_model = e.get("model") or ""
        try:
            label = canon_tag(raw_model)
        except UnknownModelTag:
            # T801: an unrecognized model tag is present and labeled, never
            # silently attributed to a fake canonical label.
            label = None
        if _ledger_reading(e):
            if label is None:
                tid = e.get("task") or "unknown"
                missing[tid] = {
                    "model": raw_model,
                    "provider": e.get("provider"),
                    "ts": e.get("ts"),
                    "missing_reason": "unrecognized model tag %r" % raw_model,
                }
                continue
            a = ledger_by_model.setdefault(label, _empty_agg())
            a["sessions"] += 1
            a["turns"] += 0
            a["tokens_in"] += e.get("tokens_in") or 0
            a["tokens_out"] += e.get("tokens_out") or 0
            for k in TOKEN_KEYS:
                v = e.get(k)
                if isinstance(v, (int, float)):
                    a["tokens"][k] += v
        if not _ledger_reading(e):
            tid = e.get("task") or "unknown"
            missing[tid] = {
                "model": label if label is not None else raw_model,
                "provider": e.get("provider"),
                "ts": e.get("ts"),
                "missing_reason": e.get("missing_reason") or "no reason recorded",
            }
    for label, a in ledger_by_model.items():
        if "tasks" not in a:
            a["tasks"] = []
        a = dict(a)
        a["tasks"] = sorted(a["tasks"])
        models[label] = a
    return models, missing


def render_human(models, missing, unattributed, scanned, sessions_dir, ledger_entries):
    lines = []
    lines.append("per-model token totals (capture ledger wins; session scan fills):")
    lines.append("  %-20s %10s %10s %10s" % ("model", "tokens_in", "tokens_out", "total"))
    for m in sorted(models):
        a = models[m]
        lines.append("  %-20s %10d %10d %10d" % (
            m, a["tokens_in"], a["tokens_out"], a["tokens"]["total"]))
    lines.append("")
    lines.append("missing readings (explicit, never estimated):")
    if missing:
        for tid in sorted(missing):
            r = missing[tid]
            lines.append("  %-10s %-20s %s" % (tid, r["model"] or "-", r["missing_reason"]))
    else:
        lines.append("  (none)")
    lines.append("")
    lines.append("unattributed sessions: %d (tokens_in %d, tokens_out %d, total %d)" % (
        unattributed["sessions"], unattributed["tokens_in"],
        unattributed["tokens_out"], unattributed["tokens"]["total"]))
    lines.append("sessions scanned: %d (dir %s)" % (scanned, sessions_dir))
    lines.append("ledger records: %d (untracked/tokens/tokens.jsonl)" % len(ledger_entries))
    return "\n".join(lines)


def main(argv):
    ap = argparse.ArgumentParser(prog="token-capture.py", add_help=True)
    ap.add_argument("--json", action="store_true",
                    help="machine-readable JSON to stdout (includes the per-session list)")
    ap.add_argument("--sessions", default=None,
                    help="session dir (default: ~/.pi/agent/sessions/<cwd-slug>)")
    ap.add_argument("--cwd", default=None,
                    help="cwd whose session slug and untracked/tokens/ to use (default: repo root)")
    ap.add_argument("--task", default=None, help="only report this task id")
    ap.add_argument("--model", default=None, help="only report this canonical model")
    ap.add_argument("--since", default=None,
                    help="only sessions started / records stamped on/after YYYY-MM-DD (inclusive)")
    args = ap.parse_args(argv)

    # T801: the --model filter is a boundary — reject an unknown label with
    # a clean CLI error before scanning, never a pass-through.
    if args.model:
        try:
            canon_tag(args.model)
        except UnknownModelTag as exc:
            print("error: %s" % exc, file=sys.stderr)
            return 2

    cwd = args.cwd or os.getcwd()
    sessions_dir = args.sessions or default_sessions_dir(cwd)

    sessions, tasks, models, unattributed, scanned = scan_sessions(
        sessions_dir, since=args.since, task=args.task, model=args.model)

    # Capture ledger: dispatch-time truth.  Real readings overlay the
    # session scan per task and per model; missing records are reported
    # explicitly, never dropped.
    ledger_entries, ledger_bad = load_ledger(cwd, since=args.since, task=args.task)
    for e in ledger_entries:
        if not _ledger_reading(e):
            continue
        tid = e.get("task")
        if tid and tid in tasks:
            t = tasks[tid]
            t["tokens_in"] = (e.get("tokens_in") or 0)
            t["tokens_out"] = (e.get("tokens_out") or 0)
            for k in TOKEN_KEYS:
                v = e.get(k)
                if isinstance(v, (int, float)):
                    t["tokens"][k] = v
            t["ledger"] = True
    models_joined, missing = merge_models(models, ledger_entries)
    if args.model:
        want = canon_tag(args.model)
        models_joined = {k: v for k, v in models_joined.items() if k == want}

    if args.json:
        out = {
            "generated": _today(),
            "sessions_dir": sessions_dir,
            "sessions_scanned": scanned,
            "ledger_records": len(ledger_entries),
            "ledger_bad_lines": ledger_bad,
            "tasks": {tid: _json_task(t) for tid, t in tasks.items()},
            "models": {m: _json_agg(a) for m, a in models_joined.items()},
            "missing": missing,
            "unattributed": _json_agg(unattributed),
            "sessions": [_json_session(s) for s in sessions],
        }
        print(json.dumps(out, sort_keys=True))
    else:
        print(render_human(models_joined, missing, unattributed, scanned,
                           sessions_dir, ledger_entries))
    return 0


def _json_task(t):
    return {
        "model": t["model"], "provider": t["provider"], "sessions": t["sessions"],
        "turns": t["turns"], "tokens_in": t["tokens_in"], "tokens_out": t["tokens_out"],
        "input": t["tokens"]["input"], "output": t["tokens"]["output"],
        "cache_read": t["tokens"]["cache_read"], "cache_write": t["tokens"]["cache_write"],
        "reasoning": t["tokens"]["reasoning"], "total": t["tokens"]["total"],
        "ledger": t.get("ledger", False),
    }


def _json_agg(a):
    out = {
        "sessions": a["sessions"], "turns": a["turns"],
        "tokens_in": a["tokens_in"], "tokens_out": a["tokens_out"],
        "input": a["tokens"]["input"], "output": a["tokens"]["output"],
        "cache_read": a["tokens"]["cache_read"], "cache_write": a["tokens"]["cache_write"],
        "reasoning": a["tokens"]["reasoning"], "total": a["tokens"]["total"],
    }
    if "tasks" in a:
        out["tasks"] = a["tasks"]
    return out


def _json_session(s):
    return {
        "file": s["file"], "start": s["start"], "cwd": s["cwd"],
        "task": s["task"], "model": s["model"], "provider": s["provider"],
        "turns": s["turns"], "tokens_in": s["tokens_in"], "tokens_out": s["tokens_out"],
        "input": s["tokens"]["input"], "output": s["tokens"]["output"],
        "cache_read": s["tokens"]["cache_read"], "cache_write": s["tokens"]["cache_write"],
        "reasoning": s["tokens"]["reasoning"], "total": s["tokens"]["total"],
        "session_id": s.get("session_id"),
    }


def _today():
    import time
    return time.strftime("%Y-%m-%d")


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
