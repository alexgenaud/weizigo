#!/usr/bin/env python3
"""tools/request-accounting.py — T850: per-model, per-window request
accounting across the fleet's two dispatch harnesses.

Design: docs/infra/request-accounting.md (read that first — the source of
truth per harness, the join keys, the window definition, and what is
deliberately unmeasurable are argued there, not repeated here).

THIS TOOL MEASURES. IT DOES NOT CAP. No dispatch gate, no refusal, no
change to bin/dispatch, tools/fleet_caps.py, tools/window_policy.py or
tools/runner (T850's explicit out-of-scope list). A caller that wants to
act on a STARVATION flag does so in a separate, later row.

THE HONESTY RULE: an unattributable request is UNKNOWN, never 0 and never
folded into a total. Every place this module cannot join a run record to
its provider-request count returns a reason string, not a silent zero.

Usage:
  tools/request-accounting.py                    # text report, now, default window
  tools/request-accounting.py --json              # machine-readable
  tools/request-accounting.py --now <iso> --window-seconds <n>
  tools/request-accounting.py --ollama-log <path>  # override for testing

Task: T850 · Role: leaf · Model: claude-sonnet-5 · Date: 2026-08-24
"""
import argparse
import datetime
import importlib.util
import json
import os
import re
import sys
import time
from zoneinfo import ZoneInfo

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The starvation threshold: derived, not guessed (see request-accounting.md
# "Report shape"). tools/fleet_caps.py's ollama family cap is 5 lanes, so an
# even split is 20% each; 80% is 4x an even share, well below the 99.7%
# incident this row exists to catch and above any plausible healthy skew.
STARVATION_SHARE_PCT = 80.0

DEFAULT_OLLAMA_LOG = os.path.join(os.path.expanduser("~"), ".ollama", "logs", "server.log")
DEFAULT_OLLAMA_TZ = "Europe/Oslo"

_SIBLING_CACHE = {}


def _load_sibling(modname, filename, root):
    """Import a sibling tools/ module by file path (importlib, so the
    hyphenated tools/token-capture.py is importable — the same pattern
    tools/token-backfill.py and tools/runner already use)."""
    key = (modname, filename, root)
    if key in _SIBLING_CACHE:
        return _SIBLING_CACHE[key]
    path = os.path.join(root, "tools", filename)
    spec = importlib.util.spec_from_file_location(modname, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    _SIBLING_CACHE[key] = mod
    return mod


def window_policy():
    """Sibling modules are code, always loaded from THIS script's own
    tools/ directory (ROOT) — never from a --root data fixture, which
    names where the RUN RECORDS live, not where the tooling lives."""
    return _load_sibling("window_policy", "window_policy.py", ROOT)


def token_capture():
    return _load_sibling("token_capture", "token-capture.py", ROOT)


def fleet_caps():
    return _load_sibling("fleet_caps", "fleet_caps.py", ROOT)


def default_window_seconds():
    """The ONE window definition (T850 constraint): tools/window_policy's
    rolling-window length, never a second literal defined here."""
    return window_policy().WINDOW_SECONDS


# ── time helpers ───────────────────────────────────────────────────────────

def _iso_to_epoch(s):
    if not s or not isinstance(s, str):
        return None
    t = s.strip()
    if t.endswith("Z"):
        t = t[:-1] + "+00:00"
    try:
        return datetime.datetime.fromisoformat(t).timestamp()
    except ValueError:
        return None


def _iso(epoch):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def _sanitize(seg):
    return "".join(ch if (ch.isalnum() or ch in "._-") else "_" for ch in (seg or ""))


# ── run records ──────────────────────────────────────────────────────────

def load_run_records(root):
    """Every run record file directly under <root>/untracked/runs/ (the
    archive-*/ subdirectories are older attempts far outside any window
    this report computes, and are skipped for cost, not correctness).
    Each file is one dispatch ATTEMPT — attempts are counted separately;
    each is its own set of provider requests."""
    d = os.path.join(root, "untracked", "runs")
    out = []
    try:
        names = os.listdir(d)
    except OSError:
        return out
    for fn in names:
        p = os.path.join(d, fn)
        if not fn.endswith(".json") or not os.path.isfile(p):
            continue
        try:
            with open(p, errors="replace") as f:
                rec = json.load(f)
        except (OSError, ValueError):
            continue
        if rec.get("task") and rec.get("model"):
            out.append(rec)
    return out


_CLAUDE_CMD_RX = re.compile(r'(^|\s)claude\s+-p\b')
_PI_CMD_RX = re.compile(r'(^|\s)pi\s+(--|-p\b)')


def _harness_of(record):
    """'claude' | 'pi' | 'unknown' — read from the record's own command
    string, never guessed from the model label (in principle either
    harness could carry either label). An ollama-family dispatch is
    wrapped (`ollama launch pi --model ...`, verified against
    untracked/runs/T840.json), so the check is a token search, not a
    startswith — a wrapper prefix must not misclassify the harness."""
    cmd = record.get("command") or ""
    if _CLAUDE_CMD_RX.search(cmd):
        return "claude"
    if _PI_CMD_RX.search(cmd):
        return "pi"
    return "unknown"


# ── claude: num_turns from the teed envelope ───────────────────────────────

def _claude_tee_path(root, record):
    """The write_tees() path for this attempt, or None. Join key: <task>.
    <sanitized start>.claude.stdout.log — write_tees() and the run record
    are stamped from the SAME start_ts value (tools/runner:3789/3841), so
    this is a filename lookup, not a heuristic."""
    task, start = record.get("task"), record.get("start")
    if not task or not start:
        return None
    fn = "%s.%s.claude.stdout.log" % (_sanitize(task), _sanitize(start))
    p = os.path.join(root, "untracked", "tokens", fn)
    return p if os.path.isfile(p) else None


def claude_request_count(root, record):
    """→ (count:int|None, reason:str|None). Source: the raw envelope's
    own `num_turns` field — present on success AND is_error envelopes
    (verified against untracked/tokens/T836...claude.stdout.log, an
    is_error attempt that still carries num_turns=53). This is the number
    that was invisible from outside a single dispatch (T850 fact 2)."""
    path = _claude_tee_path(root, record)
    if path is None:
        return None, "no stdout tee for this attempt's start timestamp"
    try:
        with open(path, errors="replace") as f:
            raw = f.read()
    except OSError as e:
        return None, "tee unreadable: %s" % e
    stripped = raw.strip()
    if not stripped:
        return None, "tee is empty (lane produced no stdout)"
    obj = None
    for candidate in (stripped, stripped.splitlines()[-1] if "\n" in stripped else None):
        if candidate is None:
            continue
        try:
            o = json.loads(candidate)
        except ValueError:
            continue
        if isinstance(o, dict):
            obj = o
            break
    if obj is None:
        return None, "tee is not a parseable JSON envelope"
    nt = obj.get("num_turns")
    if not isinstance(nt, (int, float)):
        return None, "envelope carries no num_turns field"
    return int(nt), None


# ── pi harness: assistant-message events from the session transcript ──────

def _pi_assistant_events(path):
    """→ list of epoch timestamps, one per assistant-role message in a pi
    session JSONL — the finest-grained request timeline this repo has.
    Uses the SAME predicate tools/token-capture.py:read_pi_session() sums
    usage over (type=="message" and message.role=="assistant") — this
    module does not invent a second definition of "turn." Returns [] for
    a missing/unreadable/header-less file; never raises."""
    out = []
    try:
        fh = open(path, errors="replace")
    except OSError:
        return out
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if o.get("type") != "message":
                continue
            m = o.get("message")
            if isinstance(m, dict) and m.get("role") == "assistant":
                ts = _iso_to_epoch(o.get("timestamp"))
                if ts is not None:
                    out.append(ts)
    return out


# ── window collection ───────────────────────────────────────────────────────

def collect(root, window_start, window_end):
    """→ (per_model, any_attempts_seen).

    per_model: {model: {"family", "requests", "unattributable",
    "reasons": [str,...]}}. "requests" sums only KNOWN counts; an
    unattributable attempt bumps "unattributable" and records its reason,
    never the request count (the honesty rule).

    Two harnesses, two resolutions (docs/infra/request-accounting.md):
      claude — one event per ATTEMPT, weight = num_turns, anchored at the
        attempt's end (window membership is per-dispatch).
      pi     — one event per ASSISTANT MESSAGE, each with its own
        timestamp (window membership is per-request, exact).
    """
    tc = token_capture()
    fc = fleet_caps()
    per_model = {}
    any_seen = False

    def slot(model):
        return per_model.setdefault(model, {
            "family": fc.family_of(model), "requests": 0,
            "unattributable": 0, "reasons": [],
        })

    def mark_unknown(model, reason):
        s = slot(model)
        s["unattributable"] += 1
        if reason and reason not in s["reasons"]:
            s["reasons"].append(reason)

    for rec in load_run_records(root):
        model = rec["model"]
        start_e = _iso_to_epoch(rec.get("start"))
        end_e = _iso_to_epoch(rec.get("end")) or start_e
        harness = _harness_of(rec)

        if harness == "claude":
            if end_e is None or not (window_start <= end_e < window_end):
                continue
            any_seen = True
            count, reason = claude_request_count(root, rec)
            if count is None:
                mark_unknown(model, reason)
            else:
                slot(model)["requests"] += count
            continue

        if harness == "pi":
            sp = rec.get("session_path")
            if not sp:
                if end_e is not None and window_start <= end_e < window_end:
                    any_seen = True
                    mark_unknown(model, rec.get("session_path_reason")
                                 or rec.get("session_reason")
                                 or "no session_path recorded for this attempt")
                continue
            events = _pi_assistant_events(sp)
            in_win = [e for e in events if window_start <= e < window_end]
            if in_win:
                any_seen = True
                slot(model)["requests"] += len(in_win)
            elif end_e is not None and window_start <= end_e < window_end:
                any_seen = True
                parsed = tc.read_pi_session(sp)
                if not parsed.get("ok"):
                    mark_unknown(model, parsed.get("reason"))
                # else: a dispatch inside the window whose own requests all
                # fall outside it is a legitimate zero for this attempt —
                # nothing to add, nothing unattributable.
            continue

        # neither harness recognized: no join is attempted, but the
        # attempt still happened somewhen — record UNKNOWN if that
        # somewhen is inside the window, never a silent skip that would
        # make the window look quieter than it was.
        if end_e is not None and window_start <= end_e < window_end:
            any_seen = True
            mark_unknown(model, "unrecognized harness in command "
                         "(neither claude nor pi)")

    return per_model, any_seen


# ── ollama [GIN] cross-check ─────────────────────────────────────────────

GIN_RX = re.compile(
    r'^\[GIN\]\s+(?P<y>\d{4})/(?P<mo>\d{2})/(?P<d>\d{2})\s+-\s+'
    r'(?P<h>\d{2}):(?P<mi>\d{2}):(?P<s>\d{2})\s*\|\s*(?P<status>\d{3})\s*\|')


def ollama_gin_summary(path, window_start, window_end, tz_name=DEFAULT_OLLAMA_TZ):
    """→ {"ok": True, "total", "status_429"} or {"ok": False, "reason"}.

    The ollama server log's own timestamp carries no UTC offset — it is
    the host's local wall clock (T850 fact 4). Resolved via `tz_name`, the
    same zone tools/window_policy.py's reset-time parsing already trusts
    (one timezone assumption, one place). The log also carries every HTTP
    endpoint (health/status/tags, not only chat) — this is a cross-check
    on the TOTAL, never an attribution source (it carries no model field).
    """
    if not os.path.isfile(path):
        return {"ok": False, "reason": "ollama log not found: %s" % path}
    try:
        tz = ZoneInfo(tz_name)
    except Exception as e:
        return {"ok": False, "reason": "unresolvable timezone %s: %s" % (tz_name, e)}
    total = 0
    status_429 = 0
    try:
        fh = open(path, errors="replace")
    except OSError as e:
        return {"ok": False, "reason": "ollama log unreadable: %s" % e}
    with fh:
        for line in fh:
            m = GIN_RX.match(line)
            if not m:
                continue
            try:
                local_dt = datetime.datetime(
                    int(m["y"]), int(m["mo"]), int(m["d"]),
                    int(m["h"]), int(m["mi"]), int(m["s"]), tzinfo=tz)
            except ValueError:
                continue
            epoch = local_dt.timestamp()
            if not (window_start <= epoch < window_end):
                continue
            total += 1
            if m["status"] == "429":
                status_429 += 1
    return {"ok": True, "total": total, "status_429": status_429}


def ollama_cross_check(per_model, window_start, window_end, log_path=None):
    log_path = log_path or DEFAULT_OLLAMA_LOG
    known = sum(v["requests"] for v in per_model.values() if v["family"] == "ollama")
    gin = ollama_gin_summary(log_path, window_start, window_end)
    if not gin.get("ok"):
        return {"ok": False, "reason": gin.get("reason"),
                "ollama_family_known_requests": known}
    return {
        "ok": True,
        "gin_total_requests": gin["total"],
        "gin_status_429": gin["status_429"],
        "ollama_family_known_requests": known,
        "discrepancy": gin["total"] - known,
        "note": ("[GIN] counts every HTTP endpoint the ollama server serves "
                  "(health/status/tags polling, not only chat), so "
                  "gin_total_requests is an upper bound on chat requests, "
                  "not an equal count — the two numbers are reported side "
                  "by side and never reconciled into one."),
    }


# ── report assembly ─────────────────────────────────────────────────────

def build_report(root, now=None, window_seconds=None, ollama_log=None):
    now = now if now is not None else time.time()
    window_seconds = window_seconds if window_seconds is not None else default_window_seconds()
    window_start = now - window_seconds
    window_end = now

    per_model, any_seen = collect(root, window_start, window_end)

    if not any_seen:
        return {
            "status": "empty-window",
            "note": ("no dispatch attempts found in this window — nothing "
                     "to report, not a measured-zero fleet"),
            "generated": _iso(now), "window_seconds": window_seconds,
            "window_start": _iso(window_start), "window_end": _iso(window_end),
            "models": {}, "families": {}, "fleet_total_requests": None,
            "fleet_unattributable_attempts": 0,
        }

    families = {}
    for model, v in per_model.items():
        f = families.setdefault(v["family"], {"requests": 0, "unattributable": 0})
        f["requests"] += v["requests"]
        f["unattributable"] += v["unattributable"]

    fleet_total = sum(v["requests"] for v in per_model.values())
    fleet_unattributable = sum(v["unattributable"] for v in per_model.values())

    models_out = {}
    for model, v in sorted(per_model.items()):
        fam_total = families[v["family"]]["requests"]
        share_family = (100.0 * v["requests"] / fam_total) if fam_total else None
        share_fleet = (100.0 * v["requests"] / fleet_total) if fleet_total else None
        models_out[model] = {
            "family": v["family"],
            "requests": v["requests"],
            "unattributable_attempts": v["unattributable"],
            "unattributable_reasons": v["reasons"],
            "share_of_family_pct": (round(share_family, 1) if share_family is not None else None),
            "share_of_fleet_pct": (round(share_fleet, 1) if share_fleet is not None else None),
            "starvation": bool(share_family is not None and share_family >= STARVATION_SHARE_PCT),
        }

    report = {
        "status": "ok",
        "generated": _iso(now), "window_seconds": window_seconds,
        "window_start": _iso(window_start), "window_end": _iso(window_end),
        "models": models_out,
        "families": families,
        "fleet_total_requests": fleet_total,
        "fleet_unattributable_attempts": fleet_unattributable,
        "starvation_threshold_pct": STARVATION_SHARE_PCT,
    }
    report["ollama_cross_check"] = ollama_cross_check(
        per_model, window_start, window_end, ollama_log)
    return report


def render_text(report):
    lines = []
    lines.append("request accounting — window %s .. %s (%ds)" % (
        report["window_start"], report["window_end"], report["window_seconds"]))
    if report["status"] == "empty-window":
        lines.append("  EMPTY WINDOW: %s" % report["note"])
        return "\n".join(lines)
    for model, v in sorted(report["models"].items()):
        flag = "  *** STARVATION ***" if v["starvation"] else ""
        lines.append("  %-20s family=%-9s requests=%-6s share_family=%s%% share_fleet=%s%% unattributable=%d%s" % (
            model, v["family"], v["requests"],
            v["share_of_family_pct"], v["share_of_fleet_pct"],
            v["unattributable_attempts"], flag))
        for r in v["unattributable_reasons"]:
            lines.append("      UNKNOWN: %s" % r)
    lines.append("  fleet total (known) = %s, unattributable attempts = %d" % (
        report["fleet_total_requests"], report["fleet_unattributable_attempts"]))
    cc = report.get("ollama_cross_check") or {}
    if cc.get("ok"):
        lines.append("  ollama [GIN] cross-check: gin_total=%d gin_429=%d known=%d discrepancy=%d" % (
            cc["gin_total_requests"], cc["gin_status_429"],
            cc["ollama_family_known_requests"], cc["discrepancy"]))
    elif cc:
        lines.append("  ollama [GIN] cross-check: UNAVAILABLE (%s)" % cc.get("reason"))
    return "\n".join(lines)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--now", default=None, help="ISO timestamp; default = wall clock")
    ap.add_argument("--window-seconds", type=int, default=None)
    ap.add_argument("--ollama-log", default=None)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv[1:])
    now = _iso_to_epoch(args.now) if args.now else None
    report = build_report(args.root, now=now, window_seconds=args.window_seconds,
                          ollama_log=args.ollama_log)
    if args.json:
        print(json.dumps(report, sort_keys=True, indent=2))
    else:
        print(render_text(report))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
