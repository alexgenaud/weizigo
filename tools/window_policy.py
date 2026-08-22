#!/usr/bin/env python3
"""tools/window_policy.py — the T628 rolling-window resilience policy,
corrected by T677: a family cooldown arms ONLY from a terminal RUN RECORD
of a lane of that family.  Worker stdout is not evidence.

Defect 1 (2026-08-22 12:47Z): five claude lanes (T615/T616/T617/T621/T622)
died of the Claude 5-hour session limit — the provider's terminal message
"You've hit your session limit · resets 3pm (Europe/Oslo)".  Nothing parsed
the reset, nothing stopped re-dispatch into the dead window (the rows were
healed and immediately re-fired), the deaths scored verified=fail in the
ladder, and the fleet sat idle past the 13:00Z reset until a human asked.

Defect 2 (T677, 2026-08-22 ~21:30Z): the watcher's log-grep fallback armed
a CLAUDE cooldown from a LIVE DEEPSEEK lane (T653) whose log merely quoted
the provider's limit template — its brief told it to read
wall-canary-preregistration.md, which quotes "You've hit your session limit
· resets <time> (Europe/Oslo)" — and the same quoted document carries
"tokens: no reading", which the failure-evidence regex matched within 400
bytes.  The "<time>" did not parse, so the 6h FALLBACK_COOLDOWN_SECONDS
armed against the wrong family, from a living lane, on a documentation
string; and because the fallback anchored on the live log's moving mtime,
the lockout extended itself on every dispatch.  It was the fourth instance
of the T526/T601/T643 defect class — T625 and T630 had already fixed the
refusal classifier by classifying from the runner's own terminal record
and treating worker output as untrusted; T628 reintroduced the grep in the
window watcher.  T677 applies the same architectural correction here.  The
guard's PURPOSE was sound; its EVIDENCE SOURCE was wrong.

This module ships three mechanisms, each a tool behaviour, not a prose rule:

  1. RESET-TIME WATCHER — on a provider-limit classification, arm a
     family-level cooldown (appetite OFF) and schedule a re-dispatch
     nudge at reset + a small jitter.  The classification reads ONLY the
     runner's own run record (the D021 principle), in order:
       1. the run record's T628 stamp (provider_limit /
          provider_reset_epoch / provider_reset_text — written by
          tools/runner at finalize; T659 holds the file; the stamp is
          the forward source and the watcher prefers it);
       2. the run record's T629 killed_by=provider-limit (the runner's
          enumerated vocabulary on the kill paths).
     The worker log is NEVER read (T677).  A lane with no terminal record
     (no exit/end — still running, or a runner crash before finalize) is
     not a death and arms nothing.  The family being cooled down is the
     death record's OWN model field — never proximity, never the log.
  2. TOKEN BUDGET GUARD — a rolling 5-hour meter per family from the
     runner usage records (tokens_in/tokens_out on completed attempts).
     A lane whose estimated tokens exceed the remaining window budget is
     refused at dispatch with an honest reason; the meter degrades
     appetite to CONSERVE at a threshold and to HARD-OFF at the refusal
     point.
  3. FAMILY FAN-OUT CAP — sized from the meter (a nearly-exhausted window
     shrinks the cap: floor(remaining / estimate)), and forced to 1 during
     the post-reset probe window.  The probe is the verify-don't-assume
     half of the non-goal: the watcher never calendar-trusts a reset, it
     re-dispatches ONE probe lane first; if the probe dies of the same
     limit, a fresh terminal message re-arms the cooldown automatically.

  T677's fallback for an UNPARSEABLE reset: arm the cooldown for a SHORT,
  death-anchored horizon (FALLBACK_COOLDOWN_SECONDS, default 30 min —
  WEIZIGO_WINDOW_FALLBACK_SECONDS to tune), then the watch() nudge fires
  and the one-lane probe re-checks the provider.  The old 6h bound was not
  conservative, just expensive: it was uncheckable, it anchored to a live
  log's moving mtime (self-extension), and it locked the family out for
  hours past a same-day reopen (the 12:47Z outage reopened at 13:00Z — a
  6h fallback would have idled the fleet until ~18:47Z).  A 30-minute
  fallback anchored to the DEATH moment is stable (no self-extension) and
  bounded: worst case the family idles ≤ horizon + probe window past the
  real reopen, and every cycle costs one cheap lane, not six hours.

Consumers:
  bin/dispatch        the dispatch gate (cooldown refusal — overridable
                      with --override-window-cooldown=<reason>, recorded
                      to untracked/fleet-window-overrides.jsonl (T677);
                      budget refusal; probe concurrency) — the last gate
                      before a lane starts, so even a hand dispatch is
                      stopped;
  tools/fleet-keeper.sh  the loop-side watcher (watch() each iteration:
                      arm/nudge/probe state + appetite override + cap
                      sizing);
  tools/runner        (future) stamps provider_limit/provider_reset_epoch
                      on the run record at finalize — T659 holds the file;
                      window_policy already reads the record's killed_by
                      (T629) and parses provider_reset_text, so the
                      policy is live without the stamp.

Blind spots (recorded for the meter's owners):
  * a provider-limit KILLED lane records zero usage (is_error envelope) —
    the meter can only see what completed runs reported; the cooldown is
    the primary defence, the meter the anticipatory one;
  * the window budget default (5M tokens / 5h for claude) is an
    observed-failure-informed placeholder — 5 lanes x ~1.3M died at
    12:47Z — not a published provider number; tune via
    WEIZIGO_WINDOW_BUDGET_<FAMILY> once the meter has real data;
  * no cross-family generalization until a second family exhibits a
    windowed limit (the brief's non-goal);
  * a provider-limit death whose run record predates T629's vocabulary
    (the 2026-08-22 outage lanes) arms nothing — the record is the only
    evidence, and those records carry no classification (T677, deliberate:
    the kept logs are quotes, not terminal state).

Standard library only (Python 3.9+: zoneinfo for the reset-time timezone).
"""

import calendar
import glob
import json
import os
import random
import re
import sys
import time
from zoneinfo import ZoneInfo

# ── constants ─────────────────────────────────────────────────────────────

# The Claude 5-hour session limit is a rolling window; the meter prices
# tokens consumed inside the last WINDOW_SECONDS.
WINDOW_SECONDS = 5 * 3600

# "You've hit your session limit · resets 3pm (Europe/Oslo)" — the reset is
# a day-relative wall time in a named IANA zone.  This parses the RESET
# TEXT FROM THE RUN RECORD (provider_reset_text); the worker log is never
# scanned (T677).
RESET_RX = re.compile(
    r"resets?\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)\s*\(([^)]+)\)", re.I)

# The windowed family: the four claude labels run through the same headless
# claude harness and share the provider's session window.  (The keeper
# treats claude-fable-5 as its own "fable" appetite family; for the WINDOW
# they are one provider — T615 was a fable lane and died with the rest.)
CLAUDE_LABELS = ("claude-opus-5", "claude-sonnet-5", "claude-haiku-4-5-20251001",
                 "claude-fable-5")
FAMILY_OF = {}
for _l in CLAUDE_LABELS:
    FAMILY_OF[_l] = "claude"

# The per-family 5-hour window budget in input tokens.  Default: 5M —
# five lanes of ~1.3M each died at 12:47Z on 2026-08-22, so 5M is
# conservative against the observed failure point and leaves room for a
# probe.  A measured provider number replaces it (env override per family:
# WEIZIGO_WINDOW_BUDGET_CLAUDE).  Blind spot recorded in the docstring.
DEFAULT_WINDOW_BUDGET = 5_000_000

# The meter degrades appetite to CONSERVE at this fraction of the budget.
CONSERVE_RATIO = 0.75

# The estimate for a lane with no observed data for its family (tokens_in).
# T620 alone read 1,386,293 input tokens; ~1.3M is the observed lane size.
DEFAULT_LANE_ESTIMATE = 1_300_000

# Post-reset probe window: after a cooldown's nudge fires, the family runs
# at most ONE concurrent lane (the probe) for this long, unless a lane
# closes done first (the keeper clears it).
PROBE_WINDOW_SECONDS = 1800

# A provider-limit death whose reset cannot be parsed (or whose record
# carries no reset info at all) arms the cooldown for this horizon,
# ANCHORED TO THE DEATH MOMENT (stable across re-derivations — the T677
# self-extension came from anchoring to a live log's moving mtime), after
# which the watch() nudge opens the one-lane probe window and the provider
# is re-checked by a real lane.  T677's argument: the old 6h bound could
# not be checked, so it was not conservative, just expensive — it locked
# the family out for hours past a same-day reopen (12:47Z death, 13:00Z
# reset).  30 min ≥ the observed death→reset gap (13 min), short enough
# that a same-day reopen costs ≤ ~30 min of idle, long enough not to burn
# probe lanes every few minutes against a genuinely-closed window; a
# probe that dies of the same limit re-arms the cycle automatically.
FALLBACK_COOLDOWN_SECONDS = 30 * 60

# A provider-limit death arms the cooldown only when it is FRESH: within
# this horizon of the watcher's now.  The guard exists because the reset is
# day-relative ("resets 3pm") — an OLD death's next-3pm anchor can land in
# the future and wrongly close the window (the 2026-08-22 12:47Z logs would
# otherwise arm claude OFF until the next day, months after the window
# reopened).  The death's own time comes from its run record (end, or
# start+wall) — never from a log's mtime (T677).
ARM_FRESHNESS_SECONDS = 3 * 3600

# State file (under <root>/untracked/): the watcher's own memory — armed
# cooldowns, scheduled nudges, the probe window.
WINDOW_STATE_FILE = "fleet-window.json"

# Append-only audit log for the bin/dispatch override (T677): one JSON
# line per human dispatch past a window cooldown, reason required.
WINDOW_OVERRIDES_FILE = "fleet-window-overrides.jsonl"


def family_of(model):
    """→ the window family of a canonical model label, or 'other'."""
    return FAMILY_OF.get((model or "").split(":")[0], "other")


def fallback_cooldown_seconds():
    """The T677 fallback horizon for an unparseable reset.  Env override
    WEIZIGO_WINDOW_FALLBACK_SECONDS (tests + tuning), else the 30-min
    default.  The horizon is death-anchored (see family_cooldown)."""
    v = os.environ.get("WEIZIGO_WINDOW_FALLBACK_SECONDS")
    if v:
        try:
            n = int(v)
            if n > 0:
                return n
        except ValueError:
            pass
    return FALLBACK_COOLDOWN_SECONDS


def parse_reset_epoch(reset_text, after_epoch):
    """Parse a "resets 3pm (Europe/Oslo)" fragment → the next UTC epoch at
    or after `after_epoch` at which the window reopens, or None.

    The reset is day-relative: "3pm" means the next 3pm in the named zone
    after the death (a lane that dies at 12:47Z in CEST resets at 13:00Z
    the same day; a lane that dies after 3pm resets the next day).  The
    timezone is resolved via zoneinfo (stdlib on 3.9+); an unresolvable
    zone yields None (the caller falls back to the short horizon).
    """
    m = RESET_RX.search(reset_text or "")
    if not m:
        return None
    hour = int(m.group(1))
    minute = int(m.group(2) or 0)
    ampm = (m.group(3) or "am").lower()
    tzname = m.group(4).strip()
    if ampm == "pm" and hour < 12:
        hour += 12
    elif ampm == "am" and hour == 12:
        hour = 0
    try:
        tz = ZoneInfo(tzname)
    except Exception:
        return None
    # the reset is the next occurrence at-or-after the death moment
    base = time.gmtime(after_epoch)
    for day_offset in (0, 1):
        try:
            local = (base.tm_year, base.tm_mon, base.tm_mday + day_offset,
                     hour, minute, 0, 0, 0, -1)
            candidate = calendar.timegm(time.struct_time(local)) - _utcoffset(tz, local)
            if candidate >= after_epoch:
                return candidate
        except (ValueError, OverflowError):
            continue
    return None


def _utcoffset(tz, local_tuple):
    """UTC offset (seconds) of `tz` at the (naive) wall time local_tuple."""
    try:
        from datetime import datetime
        dt = datetime(*local_tuple[:6])
        return tz.utcoffset(dt).total_seconds()
    except Exception:
        return 0


def _iso(epoch):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(epoch))


def _parse_iso_end(s):
    try:
        return calendar.timegm(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ"))
    except (TypeError, ValueError):
        return None


def _read_run_records(root):
    """Every run record under <root>/untracked/runs/ (bare + attempt
    archives; T650: each attempt is a file), keyed by task id with the
    latest attempt first."""
    out = {}
    if not root:
        return out
    d = os.path.join(root, "untracked", "runs")
    try:
        names = os.listdir(d)
    except OSError:
        return out
    for fn in names:
        if not fn.endswith(".json"):
            continue
        try:
            with open(os.path.join(d, fn), errors="replace") as f:
                rec = json.load(f)
        except (ValueError, OSError):
            continue
        tid = rec.get("task")
        if not tid:
            continue
        # the bare file is the latest attempt (T650); numbered archives are
        # older — the dict keeps the bare as the head.
        head = out.setdefault(tid, [])
        if fn == tid + ".json":
            head.insert(0, rec)
        else:
            head.append(rec)
    return out


def _terminal_state(root, task_id, now, records=None):
    """The provider-limit terminal state for one task, or None.

    EVIDENCE SOURCE (T677): the run record only — the runner's own
    terminal record.  Worker stdout is not evidence: a cooldown arms
    only when a lane of the family actually died and its record shows a
    provider-limit death.  Sources, in order:
      1. the run record's T628 stamp (provider_limit +
         provider_reset_epoch / provider_reset_text — the forward
         source, written by tools/runner at finalize; T659 holds the
         file);
      2. the run record's T629 killed_by=provider-limit (the runner's
         enumerated vocabulary on the kill paths).

    The log is NEVER read: T677's false cooldown (a live DeepSeek lane
    whose log quoted the provider's limit template armed claude OFF for
    6h) was the log path's fourth instance of the T526/T601/T643 defect
    class.  A lane with no terminal record (no exit/end — still running,
    or a runner crash before finalize) is not a death and arms nothing.

    Arming is FRESHNESS-BOUNDED (unchanged from T628): a death arms the
    cooldown only when it happened within ARM_FRESHNESS_SECONDS of now —
    a stale death's day-relative "resets 3pm" would otherwise close the
    window until the next day, months after it reopened.  The death's
    time comes from the record's end (or start+wall), never a log mtime.
    """
    if not root or not task_id:
        return None
    recs = records or {}
    death = None  # the freshest provider-limit death record for this task
    for rec in recs.get(task_id) or []:
        died = (rec.get("exit") not in (None, 0)
                or rec.get("killed") or rec.get("signal")
                or rec.get("killed_by") not in (None, "", "none"))
        if not died:
            continue
        pe = rec.get("provider_reset_epoch")
        if (rec.get("provider_limit")
                or rec.get("killed_by") == "provider-limit"
                or isinstance(pe, (int, float))
                or rec.get("provider_reset_text")):
            death = rec
    if death is None:
        return None
    death_end = _parse_iso_end(death.get("end") or "")
    if death_end is None and isinstance(death.get("start_epoch"), (int, float)):
        death_end = death["start_epoch"] + (death.get("wall") or 0)
    if death_end is None:
        death_end = now
    if now - death_end > ARM_FRESHNESS_SECONDS:
        return None  # stale death — the window has reopened since
    pe = death.get("provider_reset_epoch")
    reset_epoch = pe if isinstance(pe, (int, float)) else None
    reset_text = death.get("provider_reset_text") or ""
    if reset_epoch is None:
        reset_epoch = parse_reset_epoch(reset_text, death_end)
    return {
        "family": family_of(death.get("model")),
        "reason": death.get("provider_limit") or "provider-limit",
        "reset_epoch": reset_epoch,
        "reset_text": reset_text,
        "death_epoch": death_end,
    }


def family_cooldown(root, now=None):
    """→ {family: {until, source, reset_text, fallback}} — the families
    whose window is currently closed.

    Derived from the latest provider-limit terminal state per task — run
    records only (T677).  A family is in cooldown:
      * until the reset epoch when that reset is in the FUTURE (an old
        death whose reset has passed means the window already reopened —
        no cooldown, which is what makes stale records harmless);
      * a death whose reset cannot be parsed (or is absent) arms the
        FALLBACK horizon — 30 min by default, ANCHORED TO THE DEATH
        (death_epoch + fallback), so re-derivation is stable and the
        cooldown cannot extend itself (T677).  The watch() nudge fires
        at the horizon and re-checks the provider with ONE probe lane
        (verify-don't-assume); a fresh death re-arms automatically.

    The most recent death per family wins."""
    now = int(now if now is not None else time.time())
    records = _read_run_records(root)
    by_family = {}
    for tid in records:
        st = _terminal_state(root, tid, now, records)
        if st is None:
            continue
        fam = st["family"]
        until = st.get("reset_epoch")
        if until is None:
            # unparseable/absent reset: short death-anchored horizon, then
            # the probe verifies the provider — never a 6h assumption.
            until = st.get("death_epoch", now) + fallback_cooldown_seconds()
            fallback = True
        elif until <= now:
            continue  # window already reopened — no cooldown
        else:
            fallback = False
        # the freshest death per family arms (later deaths extend)
        prev = by_family.get(fam)
        if prev is None or st.get("death_epoch", 0) > prev.get("death_epoch", 0):
            by_family[fam] = {"until": until, "source": tid,
                              "reset_text": st.get("reset_text") or "",
                              "death_epoch": st.get("death_epoch", now),
                              "fallback": fallback}
    return by_family


def record_override(root, task_id, family, cooldown, reason, now=None):
    """Record a human dispatch past a window cooldown (T677): append one
    JSON line to <root>/untracked/fleet-window-overrides.jsonl and return
    its path (None on OSError).  Append-only, never overwritten — an
    override is an audit event, not state; the reason is the operator's
    assertion that they have checked the provider themselves."""
    if not reason or not reason.strip():
        return None
    now = int(now if now is not None else time.time())
    line = {
        "ts": _iso(now),
        "task": task_id,
        "family": family,
        "until": cooldown.get("until"),
        "source": cooldown.get("source"),
        "reset_text": cooldown.get("reset_text") or "",
        "fallback": bool(cooldown.get("fallback")),
        "reason": reason.strip(),
    }
    try:
        p = os.path.join(root, "untracked", WINDOW_OVERRIDES_FILE)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "a") as f:
            f.write(json.dumps(line, sort_keys=True) + "\n")
        return p
    except OSError:
        return None


# ── the token meter ───────────────────────────────────────────────────────

def token_meter(root, now=None, window_s=WINDOW_SECONDS):
    """→ {family: {used_in, used_out, n, window_start}} — the rolling
    5-hour usage per family from COMPLETED run records (tokens_in /
    tokens_out, exit present, no harness kill).  A killed attempt's usage
    is censored (Ruling 32) and its envelope is usually absent anyway."""
    now = now if now is not None else time.time()
    win = {}
    for tid, recs in _read_run_records(root).items():
        for rec in recs:
            if rec.get("exit") is None or rec.get("exit") != 0:
                continue
            if rec.get("killed"):
                continue
            ti = rec.get("tokens_in")
            if ti is None:
                continue
            end = _parse_iso_end(rec.get("end") or "")
            if end is None and isinstance(rec.get("start_epoch"), (int, float)):
                end = rec["start_epoch"] + (rec.get("wall") or 0)
            if end is None or end < now - window_s or end > now + 60:
                continue
            fam = family_of(rec.get("model"))
            w = win.setdefault(fam, {"used_in": 0, "used_out": 0, "n": 0,
                                     "window_start": now - window_s})
            w["used_in"] += int(ti or 0)
            w["used_out"] += int(rec.get("tokens_out") or 0)
            w["n"] += 1
    return win


def budget_for(family):
    """The family's 5-hour window budget in input tokens.  Env override
    WEIZIGO_WINDOW_BUDGET_<FAMILY> (tests + tuning), else the default."""
    v = os.environ.get("WEIZIGO_WINDOW_BUDGET_" + family.upper())
    if v:
        try:
            return int(v)
        except ValueError:
            pass
    return DEFAULT_WINDOW_BUDGET


def estimate_lane_tokens(family, root, now=None):
    """Estimated input tokens for a new lane of `family`: the mean observed
    tokens_in of the family's completed records in the window, else the
    observed lane-size default (blind spot recorded in the docstring)."""
    now = now if now is not None else time.time()
    w = token_meter(root, now).get(family)
    if w and w["n"] > 0:
        return int(w["used_in"] / w["n"])
    return DEFAULT_LANE_ESTIMATE


def meter_level(family, root, now=None, budget=None):
    """→ 'SPEND' | 'CONSERVE' | 'HARD-OFF' for the family's window.

    CONSERVE once used >= CONSERVE_RATIO of the budget (the appetite
    degradation — the keeper and operators slow down before the wall);
    HARD-OFF once a NEW lane's estimate exceeds the remaining budget (the
    refusal point — a lane now would die mid-run)."""
    now = now if now is not None else time.time()
    budget = budget if budget is not None else budget_for(family)
    used = token_meter(root, now).get(family, {}).get("used_in", 0)
    remaining = budget - used
    if estimate_lane_tokens(family, root, now) > remaining:
        return "HARD-OFF"
    if used >= CONSERVE_RATIO * budget:
        return "CONSERVE"
    return "SPEND"


def budget_check(family, root, now=None, budget=None):
    """The dispatch gate's numbers: {allowed, level, used, remaining,
    estimate, budget}.  `allowed` is False exactly at HARD-OFF."""
    now = now if now is not None else time.time()
    budget = budget if budget is not None else budget_for(family)
    used = token_meter(root, now).get(family, {}).get("used_in", 0)
    estimate = estimate_lane_tokens(family, root, now)
    remaining = budget - used
    level = meter_level(family, root, now, budget)
    return {"allowed": level != "HARD-OFF", "level": level,
            "used": used, "remaining": remaining,
            "estimate": estimate, "budget": budget}


def effective_cap(family, root, now=None, configured=None):
    """The family's concurrent-lane cap, sized from the meter.

    min(configured, floor(remaining / estimate) when the meter has data,
    1 during the post-reset probe window).  A nearly-exhausted window
    shrinks the cap before the refusal point; the probe gate opens the
    family one lane at a time after a reset (verify-don't-assume)."""
    now = now if now is not None else time.time()
    cap = configured
    # probe window: one lane at a time
    st = load_state(root).get(family)
    if st and st.get("probe_until") and now < st["probe_until"]:
        cap = 1 if cap is None else min(cap, 1)
        return cap
    w = token_meter(root, now).get(family)
    if w and w["n"] > 0:
        budget = budget_for(family)
        remaining = budget - w["used_in"]
        estimate = int(w["used_in"] / w["n"])
        if estimate > 0:
            meter_cap = max(1, remaining // estimate)
            cap = meter_cap if cap is None else min(cap, meter_cap)
    return cap


def family_inprog_count(family, rows):
    """The number of in_progress rows whose model is in `family` (fed by
    the caller's kanban snapshot; the probe gate uses it to allow only one
    lane after a reset)."""
    return sum(1 for r in rows
               if r.get("status") == "in_progress"
               and family_of(r.get("model") or (r.get("identifier") or "").split("/")[0])
               == family)


# ── watcher state: cooldown arm, nudge, probe ─────────────────────────────

def _state_path(root):
    return os.path.join(root, "untracked", WINDOW_STATE_FILE)


def load_state(root):
    try:
        with open(_state_path(root), "r") as f:
            return json.load(f) or {}
    except (OSError, ValueError):
        return {}


def save_state(root, state):
    try:
        os.makedirs(os.path.dirname(_state_path(root)), exist_ok=True)
        with open(_state_path(root), "w") as f:
            json.dump(state, f, sort_keys=True)
    except OSError:
        pass  # the watcher's memory is advisory; the refusal gate re-derives


def watch(root, now=None, jitter_max=0):
    """The watcher's one-shot step (called by tools/fleet-keeper.sh every
    iteration, and by the regression with an injected clock).

    Side effects on <root>/untracked/fleet-window.json:
      * arms a family cooldown the first time a reset is seen (nudge
        scheduled at reset + jitter — a NEWER reset re-arms); a fallback
        cooldown (unparseable reset, T677) names itself in the event line;
      * when now passes the nudge time, fires the nudge (the returned
        event line) and opens the PROBE window (effective cap 1);
      * drops state once the probe window has elapsed (the family is
        back to normal dispatch; a fresh death re-arms automatically).

    Returns the list of event lines to log (empty on a quiet iteration).
    """
    now = int(now if now is not None else time.time())
    state = load_state(root)
    events = []
    cooldowns = family_cooldown(root, now)
    for fam, c in cooldowns.items():
        st = state.get(fam)
        if st and st.get("reset_epoch") == c["until"] and st.get("nudged"):
            continue  # already armed + nudged for this reset
        if st is None or st.get("reset_epoch") != c["until"]:
            jitter = random.uniform(0, jitter_max) if jitter_max else 0
            state[fam] = {
                "armed_at": now,
                "reset_epoch": c["until"],
                "reset_text": c.get("reset_text") or "",
                "source": c.get("source") or "?",
                "fallback": bool(c.get("fallback")),
                "nudge_at": int(c["until"] + jitter),
                "nudged": False,
                "probe_until": None,
            }
            events.append(
                "window-cooldown: family %s OFF until %s (reset %r from %s%s)"
                % (fam, _iso(c["until"]), c.get("reset_text"), c.get("source"),
                   " — FALLBACK (reset unparseable); re-probing with ONE lane at reset"
                   if c.get("fallback") else ""))
    for fam, st in state.items():
        if st.get("nudged") or st.get("probe_until"):
            continue
        if now >= st.get("nudge_at", 0):
            st["nudged"] = True
            st["probe_until"] = now + PROBE_WINDOW_SECONDS
            events.append(
                "window-reset: family %s cooldown expired (reset %r + jitter) "
                "— re-probing with ONE lane (cap 1 until %s)"
                % (fam, st.get("reset_text"), _iso(st["probe_until"])))
    # drop families whose probe window has elapsed entirely
    for fam in [f for f, s in state.items()
                if s.get("probe_until") and now > s["probe_until"]]:
        del state[fam]
    if state:
        save_state(root, state)
    return events


def probe_active(family, root, now=None):
    """True while the post-reset probe window is open for `family` (the
    one-lane-at-a-time gate)."""
    now = now if now is not None else time.time()
    st = load_state(root).get(family)
    return bool(st and st.get("probe_until") and now < st["probe_until"])


def cooldown_active(family, cooldowns):
    """True when `family` is in the given cooldown map (a dispatch gate
    helper)."""
    return family in cooldowns


# ── CLI (the watcher as a one-shot, for a cron/launchd edge) ──────────────
def main(argv):
    root = os.getcwd()
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--root" and i + 1 < len(args):
            i += 1
            root = args[i]
        elif a.startswith("--root="):
            root = a.split("=", 1)[1]
        i += 1
    for ev in watch(root):
        print(ev)
    cds = family_cooldown(root)
    for fam, c in sorted(cds.items()):
        print("cooldown %s until %s (reset %r from %s%s)"
              % (fam, _iso(c["until"]), c["reset_text"], c["source"],
                 ", fallback" if c.get("fallback") else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
