#!/usr/bin/env python3
"""Shared dispatch verification for bin/subagent — both provider branches (T411).

T408's kimi incident (2026-08-07): a dispatched agent replied exactly "OK."
and executed NOTHING — no claim, no ping, no done.  The row stayed
dispatchable.  It was caught only because the probe asserted on STORE STATE
rather than on the reply.  A silent wrong answer outranks a loud crash, and
an agent is the worst place for it: the natural check — reading the reply —
is exactly the thing being faked.

The principle this module implements:

    Never accept a self-report as evidence of work.  Assert on an observable
    side effect the agent could not produce without doing the work.

Three mechanisms, all mechanical and external to the worker's text:

  1. Nonce echo — a random token injected into the prompt; the worker's
     captured stdout must contain it.  A worker that never opened the prompt
     cannot produce it.  (The runner's argv echo — which also contains the
     token — goes to stderr, never the captured stdout, so the check is
     discriminating.)
  2. Declared side effects — the bundle's `deliverables=` paths must exist
     when the worker returns, and the kanban row must have left
     `dispatchable` (T408's own check, encoded once instead of per-probe).
  3. Per-model tally — one append-only line per dispatch into
     `docs/infra/model-perf.md` (path overridable via WEIZIGO_MODEL_PERF so
     tests never touch the live file), so claim-vs-verified becomes data
     rather than folklore.

Exit-code contract for the dispatchers:

    0  verification passed (side effects hold)
    2  verification FAILED — a loud report names every failing check

The verification never trusts the worker's text in either direction: a
"success" claim without side effects fails; a "failure" report WITH side
effects passes, and the dispatcher says it is believing the work, not the
text.  There is no silent retry: a failed dispatch is a failed dispatch, and
the report names the checks so the Orchestrator can adjudicate.

Task: T411 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-07

T631 (2026-08-22): this module is imported by bin/subagent from the COMMITTED
revision — `git show HEAD:tools/dispatch_verify.py` into a disposable temp
path — never the working tree (a mid-edit file cannot reach a running
verifier; the T616 incident was exactly that: a half-written working-tree
copy crashed heal_dispatch and left the row a silent in_progress zombie).
The pin lives at the import site (bin/subagent); `holds` protects writers
of this file from each other, the pin protects the in-flight dispatches
that read it.  WEIZIGO_DISPATCH_VERIFY_UNPINNED=1 forces a working-tree
import (developer escape hatch, loud warning).  If a heal STILL crashes —
a committed bug is the residual case the pin cannot cover — bin/subagent's
safety net catches it and appends a needs_manual_heal marker to this log
(see heal_dispatch below); the invariant is that a crashed heal never
leaves a row silently in_progress.
"""
import json
import os
import re
import secrets
import subprocess
import sys
import time

# Verdicts that mean "the worker claims the work was done."
SUCCESS_VERDICTS = ("pass", "pass-with-findings")
# Verdicts that mean "the worker reports the task did not succeed."
FAILURE_VERDICTS = ("blocked", "fail-found", "abandoned")

# F4/T513: the dispatcher is the SOLE automatic heal-reopen owner.  No other
# shipped script reopens a kanban row unattended — `untracked/watch-fleet.sh`
# at HEAD contains no heal (T492 dropped it) and `tools/fleet-keeper.sh` only
# observes heals (cooldown), it does not reopen.  Every assertion record
# written by `heal_dispatch` carries this value as `healed_by`, so the heals
# log is the census of who reopens: a record NOT carrying it is a second
# owner, and a second owner is a defect (the 2026-08-20 fleet audit, F4).
HEAL_OWNER = "dispatcher"

# ── T538: provider-level refusal detection ─────────────────────────────────
#
# A worker killed by an account-level 429/401/403 never reached the model, so
# it must not be recorded as that model failing its task (the 2026-08-20
# Ollama session-usage-limit incident: ~80 keeper dispatches died in ~22 s
# each before the worker read its brief, and all 80 were misattributed as
# glm-5.2 failures in docs/infra/model-perf.md).  The worker log
# (untracked/log/t<id>.log, written by bin/dispatch's nohup redirect) carries
# the refusal block.
#
# T625/D021 (2026-08-22): the classifier was a grep over a multi-megabyte
# stream containing everything the worker read — including its own quoted
# sources — and both failure directions were observed on real rows:
#   * FALSE NEGATIVE: T615/T616/T617/T621/T622 died of the Claude 5-hour
#     session limit ("hit your session limit", emitted 12:47Z) and were
#     recorded verified=fail — the signature list had "session usage limit"
#     and "reached your (session )?usage limit" but Claude says "hit your
#     session limit".  Misses by one word; five false model failures.
#   * FALSE POSITIVE: T526 died of the runner's OWN progress-timeout
#     watchdog (run record: killed='progress timeout 600s', signal 9) but
#     was recorded verified=unreached reason=provider-429 because the model
#     was QUOTING an old Ollama 429 out of a document.  T601 likewise: the
#     bare word 'quota' inside the prose "provider quota/appetite 7" of a
#     run that actually succeeded.
#
# The fix, per D021: the unit of classification is the RUNNER'S OWN terminal
# record, not a grep over worker output.
#   1. run record first (untracked/runs/<task>.json): a runner-initiated
#      kill (killed=wall/RSS/host/progress/directive/startup) is a harness
#      decision — NEVER a provider refusal, whatever the log quotes.
#   2. worker stdout is UNTRUSTED for this purpose: the log scan is
#      restricted to a bounded refusal WINDOW — the first 8 KiB of worker
#      output (a connect-time refusal lands there) and the last 8 KiB (a
#      mid-turn session limit kills the run at the end).  Quoted content
#      from mid-run documents lands in neither window (T526's quote sat at
#      665 KiB into an 18 MiB log; T601's at 6.7 MiB of 9.5 MiB).
#   3. the runner's OWN claude-envelope refusal line (T521 capture:
#      "tokens: no reading — claude api error", is_error=true with zero
#      usage) is a first-class unreached signal.
#
# Only STRONG refusal signatures match, and the classifier is conservative by
# construction — a bare HTTP status code is not enough, and incidental digits
# must never match: `[runner] pid 42994` is ruled out by the \b word
# boundary, 401/403 require an auth keyword nearby, and the status-code
# signatures anchor to the START of a line (the refusal is emitted as
# `429: {"message":...}`), which a mention inside a prompt never is.  The
# distinction must not become an excuse that launders genuine failures.
PROVIDER_REFUSAL_SIGNATURES = (
    # An HTTP status code at the start of a line is the refusal block the
    # provider client emits, e.g. 429: {"message":"...","type":"api_error",...}.
    (re.compile(r"^\s*429\b", re.M), "provider-429"),
    (re.compile(r"^\s*401\b", re.M), "provider-auth"),
    (re.compile(r"^\s*403\b", re.M), "provider-auth"),
    # Billing / rate-limit prose (the api_error message body).
    (re.compile(r"session usage limit", re.I), "provider-429"),
    (re.compile(r"reached your (?:session )?usage limit", re.I), "provider-429"),
    # D021: the Claude 5-hour session limit says "hit your session limit"
    # — one word off from the Ollama phrasing that killed the 2026-08-20
    # fleet.  T615/T616/T617/T621/T622 died of this and were recorded
    # verified=fail because the phrase was missing.
    (re.compile(r"hit your session limit", re.I), "provider-429"),
    (re.compile(r"\brate limit\b", re.I), "provider-429"),
    (re.compile(r"\bquota\b", re.I), "provider-429"),
    (re.compile(r"too many requests", re.I), "provider-429"),
    # Auth refusals.
    (re.compile(r"invalid api key", re.I), "provider-auth"),
    (re.compile(r"\bunauthorized\b", re.I), "provider-auth"),
    (re.compile(r"\bforbidden\b", re.I), "provider-auth"),
    # Connection failures.
    (re.compile(r"connection refused", re.I), "provider-connection"),
    (re.compile(r"connection reset", re.I), "provider-connection"),
    (re.compile(r"could not connect", re.I), "provider-connection"),
    (re.compile(r"name or service not known", re.I), "provider-connection"),
    (re.compile(r"temporary failure in name resolution", re.I), "provider-connection"),
)

# D021: the refusal window — the first and last bytes of WORKER output the
# classifier will scan.  A connect-time refusal lands in the head; a mid-turn
# session limit kills the run and lands in the tail.  Quoted content from
# mid-run documents lands in neither (measured: T526's quote at 665 KiB of an
# 18 MiB log, T601's at 6.7 MiB of 9.5 MiB).
REFUSAL_WINDOW_BYTES = 8192

# D021: the runner's OWN claude-envelope refusal signal (T521 capture).  This
# is a runner diagnostic line, not worker content: is_error=true with zero
# usage means the model never produced a token.
RUNNER_CLAUDE_API_REFUSAL_RX = re.compile(r"tokens: no reading[^\n]*claude api error", re.I)


def provider_refusal_reason(root, task_id):
    """Return the provider-refusal reason ('provider-429' / 'provider-auth' /
    'provider-connection') when the model was never reached, else None.

    Evidence, in order (D021):
      1. the run record (untracked/runs/<task>.json): a runner-initiated
         kill (`killed` set — wall / RSS / host pressure / progress watchdog
         / directive / startup) is a harness decision, NEVER a provider
         refusal.  This is the T526 fix: the worker quoted an old 429 while
         the watchdog killed it, and the old classifier blamed the provider.
      2. the worker log, scanned ONLY inside the refusal window (first and
         last REFUSAL_WINDOW_BYTES of worker output, [runner]-prefixed lines
         excluded — they are the runner's own diagnostics, and the argv echo
         carries the whole prompt, which must never be scored).
      3. the runner's own claude-envelope refusal line (is_error=true, zero
         usage — the model was never reached).

    A missing/unreadable log or record is a non-match, never an error — the
    absence of a refusal signature means the failure is attributed normally.
    """
    if not root or not task_id or not re.fullmatch(r"T\d+", task_id):
        return None
    # 1. Run record first: a runner-initiated kill is a harness decision,
    #    not a provider refusal — UNLESS a refusal signature sits in the
    #    TAIL window of the worker output.  A genuine provider limit can
    #    CAUSE a harness kill (T616: the Claude session limit blocked the
    #    lane, the runner's startup-liveness watchdog then killed the
    #    silent lane at 600 s — the record says startup timeout, the log's
    #    tail says "You've hit your session limit"); a quoted 429 that
    #    merely passed through the worker's text (T526) lands mid-log and
    #    never reaches the tail, so the harness kill stands.  The head
    #    window is NOT consulted for the killed case: an accumulated log
    #    may carry an older run's connect-time refusal, and the harness
    #    kill is about THIS run's terminal output.
    rr = read_run_record(root, task_id)
    if rr and rr.get("killed"):
        return _refusal_in_tail_window(root, task_id)
    p = os.path.join(root, "untracked", "log", task_id.lower() + ".log")
    try:
        with open(p, errors="replace") as f:
            text = f.read()
    except OSError:
        return None
    # 3. The runner's own unreached signal (checked on the raw text — it is
    #    a [runner] line, which the window scan below excludes).
    if RUNNER_CLAUDE_API_REFUSAL_RX.search(text):
        return "provider-429"
    # 2. The refusal window over WORKER output only: strip the runner's own
    #    diagnostics (the argv echo is the prompt — never scoreable).
    worker = "\n".join(l for l in text.splitlines() if not l.startswith("[runner]"))
    head = worker[:REFUSAL_WINDOW_BYTES]
    tail = worker[-REFUSAL_WINDOW_BYTES:] if len(worker) > REFUSAL_WINDOW_BYTES else ""
    window = head + "\n" + tail
    for rx, reason in PROVIDER_REFUSAL_SIGNATURES:
        if rx.search(window):
            return reason
    return None


def _refusal_in_tail_window(root, task_id):
    """Refusal signature in the LAST REFUSAL_WINDOW_BYTES of the worker's
    own output (the terminal window of THIS run), or None.

    Consulted when the run record names a harness kill (D021): the refusal
    could be the CAUSE of the kill (T616 — session limit blocked the lane,
    the watchdog then killed the silence) or an incidental quotation
    (T526 — mid-log document quote, excluded by the window).  Only the
    tail is scanned: a killed run's refusal is terminal."""
    p = os.path.join(root, "untracked", "log", task_id.lower() + ".log")
    try:
        with open(p, errors="replace") as f:
            text = f.read()
    except OSError:
        return None
    worker = "\n".join(l for l in text.splitlines() if not l.startswith("[runner]"))
    tail = worker[-REFUSAL_WINDOW_BYTES:] if len(worker) > REFUSAL_WINDOW_BYTES else worker
    for rx, reason in PROVIDER_REFUSAL_SIGNATURES:
        if rx.search(tail):
            return reason
    return None


def _fail_perf(task_id, model, report, fail_check, unreached, directive_kill=None):
    """The perf tuple for a failed dispatch.  `unreached` (a provider-refusal
    reason) turns a model failure into a lane-availability event: the ledger
    line records verified=unreached reason=<reason>, not verified=fail.  A
    directive_kill (T625) turns it into a harness-initiated stop: the ledger
    records verified=directive-kill reason=<id>/<type>, never verified=fail
    — the model did nothing wrong and did not choose to stop."""
    if directive_kill:
        return (task_id, model, report, "directive-kill", directive_kill)
    if unreached:
        return (task_id, model, report, "unreached", unreached)
    return (task_id, model, report, "fail", fail_check)


def generate_nonce():
    """A fresh 128-bit echo token."""
    return "NONCE-" + secrets.token_hex(8)


def nonce_prompt_lines(nonce):
    """The prompt fragment that makes the nonce unmissable."""
    return ("VERIFY-NONCE: {nonce}\n"
            "Begin your final reply with exactly the line: {nonce}\n".format(nonce=nonce))


def parse_deliverables(bundle_abs, fallback=None):
    """Parse `deliverables=` from a bundle's `<!--managent ...-->` meta header.

    Returns the declared list, or [fallback] when the header declares
    nothing and a fallback was given (the pre-T317 filename-derived findings
    path), or [] when nothing is declared and no fallback exists (a bare
    file dispatch with no manifest).
    """
    try:
        with open(bundle_abs) as f:
            for line in f:
                line = line.strip()
                if line.startswith("<!--managent "):
                    # Non-greedy, stopping at the first whitespace (the
                    # `acceptance=` key follows with a space) or at the
                    # `-->` comment close.  A greedy [^\s>]+ absorbed the
                    # close when deliverables= was the last key with no
                    # trailing space (latent since T317; exposed by the T411
                    # regression, whose bundles use the no-space form).
                    m = re.search(r"deliverables=(.*?)(?:\s|-->)", line)
                    if m:
                        val = m.group(1).rstrip(",")
                        return [p.strip() for p in val.split(",") if p.strip()]
                    break
    except Exception:
        pass
    return [fallback] if fallback else []


# Required top-level keys of a findings record (findings/README.md schema).
FINDINGS_REQUIRED_KEYS = ("task_id", "date", "model", "claims")


def is_findings_deliverable(d):
    """True when the repo-relative deliverable path `d` is under findings/."""
    reld = os.path.normpath(d)
    return reld == "findings" or reld.startswith("findings" + os.sep)


def verify_findings_file(path):
    """Validate one findings deliverable against the findings/README.md schema.

    Returns a list of error strings; empty means the file is a well-formed
    findings record.  Checks, per T488 (absorption-spec.md §6.4): the file
    JSON-loads, is an object, and carries the required keys (task_id, date,
    model, claims) with claims an array.  This is the cheap worker-side early
    warning; the authoritative conformance check remains claimlint + the
    done gate (T485).
    """
    errors = []
    try:
        with open(path) as f:
            data = json.load(f)
    except ValueError as e:
        return ["invalid JSON: %s" % e]
    except OSError as e:
        return ["unreadable: %s" % e]
    if not isinstance(data, dict):
        return ["not a JSON object"]
    missing = [k for k in FINDINGS_REQUIRED_KEYS if k not in data]
    if missing:
        errors.append("missing required key(s): %s" % ", ".join(missing))
    if "claims" in data and not isinstance(data["claims"], list):
        errors.append("claims must be an array")
    return errors


def store_path(root, store_env=None):
    """MANAGENT_STORE overrides the default state path (A3: substrate isolation)."""
    if store_env:
        return store_env
    return os.path.join(root, "docs", "infra", "managent", "tasks.json")


def read_store(root, store_env=None):
    try:
        with open(store_path(root, store_env)) as f:
            return json.load(f)
    except Exception:
        return None


def task_state(data, task_id):
    """(status, verdict) for a task, or (None, None) when unknown."""
    if not data or task_id not in data:
        return (None, None)
    t = data[task_id]
    return (t.get("status"), t.get("verdict"))


# ── T520: per-task-class wall guidance + wall-kill telemetry ─────────────────
#
# F8: 16/25 heals were exit-124 wall-kills — briefs too big for their wall.
# The epidemic was anecdotal: nothing recorded the brief's size at dispatch,
# and nothing compared the chosen wall against the task class's observed
# need.  This block ships the other half of T520 (tools/runner records
# brief_bytes/prompt_bytes/wall_budget in the run record); here we carry the
# per-task-class recommendation and the advisory that turns the measurement
# into an actionable `[verify] wall-low:` line at dispatch time.
#
# The recommendation is sourced from the DELEGATOR wall table
# (docs/infra/delegation/DELEGATOR.md §Choosing a wall) — the chosen wall is
# tools/runner's *fallback* ceiling for silent children, and the 600 s
# progress watchdog catches stuck runs first, so the backstop is generous.
# Task classes reuse model-profiles.py's ordered keyword rule
# (battery > verification > spec > infra; specific beats general).  battery
# runs (suite sweeps, retrograde builds) are the longest; verification
# (audits) is audit-heavy; spec is the standard mode; infra (tooling +
# regression) is mid.
#
# DELEGATOR rows:
#   1800  tiny bounded edit
#   2700  standard task — the mode
#   3600  mid task, tooling + regression
#   4500-5400  analysis- or audit-heavy
#   7200  audits, suite runs
WALL_GUIDANCE = {
    "spec": 2700,          # standard task — the mode
    "infra": 3600,         # mid task, tooling + regression
    "verification": 5400,  # audit-heavy
    "battery": 7200,       # suite runs / retrograde builds — the longest
}

# A brief at or above this many bytes is "large" for its class and the
# recommended wall escalates one DELEGATOR row — a 20 kB battery brief is
# not sent out under a 30 min wall.  8 kiB is roughly where a brief stops
# being a one-screen edit and starts being a document the model must read
# end to end.
LARGE_BRIEF_BYTES = 8192

# Ordered keyword rule, mirroring tools/model-profiles.py TYPE_KEYWORDS
# (battery > verification > spec > infra).  Kept inline so dispatch_verify
# stays stdlib-only (model-profiles imports claimlint binaries).  Drift is
# one-directional: add a keyword here AND in model-profiles.py when a new
# class signal appears.
_TYPE_KEYWORDS = {
    "battery": [
        "battery", "mutant", "vb_", "bellman", "scc", "movegen", "closure",
        "smd1", "batt-health", "golden-master", "baseline",
    ],
    "verification": [
        "audit", "verify", "verif", "race", "probe", "falsif", "confirm",
        "grade", "grading", "re-audit", "reaudit", "second-auditor",
        "third-auditor", "cross-check", "independent",
    ],
    "spec": [
        "spec", "design", "strategy", "architecture", "plan", "blueprint",
        "proposal", "draft",
    ],
    "infra": [],
}


def _glob_bundles(root, task_id):
    """The bundle file(s) for a T-id task, or [] when not a T-id."""
    if not root or not task_id or not re.fullmatch(r"T\d+", task_id):
        return []
    import glob as _glob
    return _glob.glob(os.path.join(root, "untracked", task_id + "-*.md"))


def classify_task_type(root, task_id, store_env=None):
    """Classify a dispatched task into one of spec/infra/verification/battery.

    Reuses model-profiles.py's ordered keyword rule (battery > verification
    > spec > infra; specific beats general).  The text blob is the lowercased
    bundle basename plus the task's note/verdict_note from the store (so a
    task classified at registration is not re-classified differently here).
    Returns "infra" (the default) when no keyword matches, when task_id is
    not a T-id, or when no single bundle resolves.
    """
    if not task_id or not re.fullmatch(r"T\d+", task_id):
        return "infra"
    hits = _glob_bundles(root, task_id)
    if len(hits) != 1:
        return "infra"
    base = os.path.basename(hits[0])
    if base.endswith(".md"):
        base = base[:-3]
    blob = base.lower()
    data = read_store(root, store_env) or {}
    t = data.get(task_id, {})
    blob = " ".join([blob, t.get("note") or "", t.get("verdict_note") or ""]).lower()
    for typ in ("battery", "verification", "spec", "infra"):
        for kw in _TYPE_KEYWORDS.get(typ, ()):
            if kw in blob:
                return typ
    return "infra"


def recommended_wall(task_type, brief_bytes=None):
    """Recommended fallback wall (s) for a task class, scaling up when the
    brief is large.

    The base is WALL_GUIDANCE[task_type] (infra is the default for an
    unknown class).  A brief at or above LARGE_BRIEF_BYTES escalates one
    DELEGATOR row — the next-larger class's wall — so a large spec brief is
    not sent out under the standard 45 min wall.  Caps at the longest row
    (7200 s) so battery, already at the top, stays there.
    """
    base = WALL_GUIDANCE.get(task_type, WALL_GUIDANCE["infra"])
    if brief_bytes is not None and brief_bytes >= LARGE_BRIEF_BYTES:
        rows = sorted(set(WALL_GUIDANCE.values()))
        larger = [r for r in rows if r > base]
        if larger:
            base = min(larger)
    return base


def _run_record_path(root, task_id):
    """Path to the runner's per-task run record, or None when not a T-id."""
    if not root or not task_id or not re.fullmatch(r"T\d+", task_id):
        return None
    return os.path.join(root, "untracked", "runs", task_id + ".json")


# ── T625: directive-kill classification ────────────────────────────────────
#
# A worker stopped because a `pause`/`kill` directive was in force was NOT a
# model failure: the harness killed it at the directive's behest.  Before
# T625 the termination surfaced as rc=124 + verified=fail — the exact
# signature of a wall-kill and of the Claude-window failures D048 had to
# annotate DO NOT SCORE by hand — so every directive kill wrote a false
# negative into the ladder (T544, 2026-08-22: two rows, pro and flash).
#
# Classification is mechanical and conservative:
#   1. the run record (untracked/runs/<task>.json): kill_class ==
#      "directive" (T625), or a `killed` string starting with "directive"
#      (the mid-run poll already wrote that shape pre-T625);
#   2. the worker log fallback (untracked/log/t<id>.log): the launch-time
#      signature `[runner] exit 124 (directive: ...)` — pre-T625 launch
#      refusals wrote NO run record at all.
# A genuine wall/RSS/host kill matches neither (D048's standing warning:
# the fix must not become a laundry for real failures).
_DIRECTIVE_KILL_RX = re.compile(r"^directive (D\d+) ([A-Z]+)", re.I)
_DIRECTIVE_LOG_RX = re.compile(r"exit 124 \(directive(?::\s*([a-z]+))?", re.I)


def directive_kill_reason(root, task_id):
    """→ "D<id>/<type>" (e.g. "D6257/pause") when the worker's death was a
    directive kill, else None.

    Evidence order: the run record first (kill_class or the killed string
    naming the directive), then the worker log (pre-T625 launch refusals,
    which wrote no run record — the log line is all that exists).  The
    log fallback is conservative: the exact launch-refusal signature must
    match, and a run that started at all has a run record, so a stray old
    line in an accumulated log cannot reclassify a wall-kill (which always
    writes a record)."""
    if not root or not task_id or not re.fullmatch(r"T\d+", task_id):
        return None
    rr = read_run_record(root, task_id)
    if rr:
        killed = rr.get("killed") or ""
        if rr.get("kill_class") == "directive" or killed.lower().startswith("directive"):
            m = _DIRECTIVE_KILL_RX.match(killed)
            if m:
                return "%s/%s" % (m.group(1), m.group(2).lower())
            return "unknown/directive"
    p = os.path.join(root, "untracked", "log", task_id.lower() + ".log")
    try:
        with open(p, errors="replace") as f:
            text = f.read()
    except OSError:
        return None
    m = _DIRECTIVE_LOG_RX.search(text)
    if m:
        typ = m.group(1) or "pause/kill"
        return "unknown/%s" % typ
    return None


def read_run_record(root, task_id):
    """Load the runner's run record for `task_id`, or None when absent/unreadable.

    The record (tools/runner, T364) carries brief_bytes, prompt_bytes,
    wall_budget and the kill reason — the join key for the wall-kill census.
    """
    p = _run_record_path(root, task_id)
    if not p or not os.path.isfile(p):
        return None
    try:
        with open(p) as f:
            return json.load(f)
    except (ValueError, OSError):
        return None


# ── T629: killed_by — the enumerated censoring vocabulary ─────────────────
#
# Ruling 32 (2026-08-22): a measured ladder, tier, or matrix cell is
# publishable only when its denominator is a census — every scored row has
# killed_by = none, guard-killed rows are present and labeled *censored*
# (never dropped, never scored), and skip counts print alongside every
# published number.  The verification record (the dispatch-verify ledger
# line) carries the one enumerated value below, written from the RUNNER'S
# OWN terminal record (untracked/runs/<task>.json: killed, signal, exit,
# or the runner's own killed_by stamp) — never inferred from a broad grep
# over worker output, which is untrusted for this purpose (that grep is
# what produced the T526/T601 false positives).
KILLED_BY_VALUES = (
    "none",
    "provider-limit",
    "provider-auth",
    "provider-connection",
    "directive",
    "wall",
    "cpu",
    "rss",
    "liveness",
    "watchdog",
    "harness-error",
)

# D021 classifier reasons → killed_by enum.  provider-429 (the classifier's
# name for every rate/session-limit refusal) is the brief's provider-limit.
_PROVIDER_REASON_TO_KILLED_BY = {
    "provider-429": "provider-limit",
    "provider-auth": "provider-auth",
    "provider-connection": "provider-connection",
}


def _classify_killed(killed, kill_class=None):
    """Map a runner-initiated kill (the record's `killed` string + optional
    kill_class) to the killed_by enum.  A kill we cannot classify is
    harness-error — an unknown runner decision is censored, never scored
    (the conservative direction)."""
    kl = killed.lower()
    if kill_class == "directive" or kl.startswith("directive"):
        return "directive"
    if kill_class == "liveness" or "liveness" in kl:
        return "liveness"
    if "progress timeout" in kl:
        return "watchdog"
    if "wall ceiling" in kl:
        return "wall"
    if "cpu ceiling" in kl:
        return "cpu"
    if "rss cap" in kl or "host memory pressure" in kl:
        return "rss"
    return "harness-error"


def killed_by_reason(root, task_id, unreached=None, directive_kill=None):
    """The enumerated killed_by for a task's terminal dispatch, or None when
    the task is not a T-id.

    Authority order (T629) — the RUNNER'S OWN terminal record is the source:
      1. the runner's killed_by stamp in the run record (the runner knows
         which guard fired; written on every kill path);
      2. the record's killed / kill_class / signal / exit fields (records
         written before the runner stamped the enum);
      3. the D021 refusal/directive classifications, ONLY in the cases the
         record cannot answer: a harness kill whose TAIL window shows the
         refusal that CAUSED it (T616 — session limit blocked the lane, the
         watchdog killed the silence), a non-zero exit with no harness kill
         (T617 — claude exit 1, zero usage: reached-and-failed, or never
         reached), and no record at all (pre-record launch refusals).
    The classifier is window-constrained (first+last 8 KiB of worker
    output) — the broad grep that produced the T526/T601 false positives is
    structurally impossible (their quotes sat mid-log).
    """
    if not root or not task_id or not re.fullmatch(r"T\d+", task_id):
        return None
    rr = read_run_record(root, task_id)
    if rr is not None:
        kb = rr.get("killed_by")
        if kb in KILLED_BY_VALUES:
            return kb
        killed = rr.get("killed") or ""
        if killed:
            # A harness kill — unless a provider refusal in the TAIL window
            # was its CAUSE (T616).  `unreached` (when passed) is exactly
            # the D021 tail-window result for a killed record; recompute it
            # when the caller did not (record_perf does not).
            if unreached is None:
                unreached = provider_refusal_reason(root, task_id)
            if unreached:
                return _PROVIDER_REASON_TO_KILLED_BY.get(unreached, "provider-limit")
            return _classify_killed(killed, rr.get("kill_class"))
        # No harness kill: the child ended by itself.
        if rr.get("exit") is None and rr.get("signal") is not None:
            return "harness-error"  # killed from outside the runner — unknown stop
        if rr.get("exit") not in (None, 0):
            # Non-zero exit with no harness kill: reached-and-failed, or
            # never reached (T617).  The D021 classifier is the only way
            # to tell them apart — a refusal censors, a plain failure
            # scores as fail.
            if unreached is None:
                unreached = provider_refusal_reason(root, task_id)
            if unreached:
                return _PROVIDER_REASON_TO_KILLED_BY.get(unreached, "provider-limit")
        return "none"
    # No run record at all (pre-record launch refusals, stub harnesses).
    if directive_kill:
        return "directive"
    if unreached is None:
        unreached = provider_refusal_reason(root, task_id)
    if unreached:
        return _PROVIDER_REASON_TO_KILLED_BY.get(unreached, "provider-limit")
    return "none"



def wall_advisory(root, task_id, wall_budget, brief_bytes=None, store_env=None):
    """Compare a dispatch's wall budget against the class recommendation.

    Returns (task_type, recommended, adequate, line):
      task_type   the classified class (spec/infra/verification/battery)
      recommended the recommended wall (s) for the class+brief
      adequate    True iff wall_budget is None/<=0 (unknown) or >= recommended
      line        a single `[verify]`-style advisory, or "" when adequate

    The advisory is the epidemic made actionable: a wall too low for the
    brief it carried is named at dispatch time, not only in a post-mortem
    heal census.  It is never a hard fail — a wall-low is a risk, not a lie.
    """
    typ = classify_task_type(root, task_id, store_env=store_env)
    rec = recommended_wall(typ, brief_bytes)
    if wall_budget is None or wall_budget <= 0:
        return typ, rec, True, ""
    adequate = wall_budget >= rec
    if adequate:
        return typ, rec, True, ""
    bb = "" if brief_bytes is None else " brief=%dB" % brief_bytes
    line = ("wall-low: %s class=%s wall_budget=%ss < recommended %ss%s — "
            "a wall-kill risk (brief too big for its wall; T520)"
            % (task_id, typ, wall_budget, rec, bb))
    return typ, rec, False, line


def verify_dispatch(*, root, task_id, model, nonce, stdout, rc,
                    store_env=None, deliverables=None):
    """Run the post-dispatch checks.

    Returns (exit_code, summary, details, perf):
      exit_code  0 = verification passed, 2 = verification FAILED
      summary    one line, printed with a [verify] prefix by the caller
      details    detail lines, printed indented under the summary
      perf       (task_id, model, report, verified, fail_check) for the model ledger
    """
    details = []
    nonce_ok = nonce in stdout

    # T538: a provider refusal (HTTP 429/401/403, quota/auth, connection
    # failure) means the model was never reached — an infrastructure fact, not
    # a task failure.  It applies only when the worker died (rc != 0) before
    # the work landed; a clean exit that did nothing is still a genuine model
    # failure, and a worker that closed the row before a non-zero exit was
    # clearly reached, so both stay 'fail'.
    unreached = provider_refusal_reason(root, task_id) if rc != 0 else None
    if unreached:
        details.append(
            "NOTE provider refusal (reason=%s): the model was never reached — "
            "recorded as unreached, not a task failure" % unreached)

    # T625: a directive-caused termination is a harness-initiated stop, not a
    # model failure.  Classified from the run record (kill_class=directive /
    # killed="directive ...") or the worker log (pre-fix launch refusals),
    # and it must NEVER produce a verified=fail row.
    directive_kill = directive_kill_reason(root, task_id) if rc != 0 else None
    if directive_kill:
        details.append(
            "NOTE directive kill (%s): the harness stopped the worker at a "
            "directive's behest — recorded as directive-kill, not a model "
            "failure" % directive_kill)

    dl_missing = []
    findings_bad = []  # [(deliverable, error), ...] — malformed findings records
    for d in (deliverables or []):
        p = d if os.path.isabs(d) else os.path.join(root, d)
        if not os.path.exists(p):
            dl_missing.append(d)
            continue
        if is_findings_deliverable(d):
            for err in verify_findings_file(p):
                findings_bad.append((d, err))

    if not nonce_ok:
        details.append(
            "FAIL nonce: the reply does not contain the injected token %s — "
            "the worker did not read (or echo) the instruction bundle" % nonce)

    # ── bare file dispatch: no kanban row — the nonce is the whole guard ──
    if task_id is None:
        if rc != 0:
            return (2,
                    "worker exited rc=%d — verification FAILED" % rc,
                    details + ["FAIL exit: worker did not exit cleanly (rc=%d)" % rc],
                    _fail_perf(task_id, model, "crash", "exit", unreached, directive_kill))
        if not nonce_ok:
            return (2,
                    "worker reported success; verification FAILED: nonce echo missing",
                    details, (task_id, model, "bare", "fail", "nonce"))
        if dl_missing:
            return (2,
                    "worker reported success; verification FAILED: deliverable(s) missing: %s"
                    % ", ".join(dl_missing),
                    details + ["FAIL deliverables: missing: %s" % ", ".join(dl_missing)],
                    (task_id, model, "bare", "fail", "deliverables"))
        if findings_bad:
            for d, err in findings_bad:
                details.append("FAIL findings: %s — %s" % (d, err))
            return (2,
                    "worker reported success; verification FAILED: malformed findings deliverable(s): %s"
                    % ", ".join(d for d, _ in findings_bad),
                    details, (task_id, model, "bare", "fail", "findings"))
        return (0,
                "verification PASSED (bare-file dispatch: nonce echoed; no kanban row to verify)",
                details, (task_id, model, "bare", "pass", None))

    # ── T-ID dispatch: the kanban row is the ground truth ────────────────
    status, verdict = task_state(read_store(root, store_env), task_id)
    if status is None:
        return (2,
                "worker reported success; verification FAILED: task %s not found in store %s"
                % (task_id, store_path(root, store_env)),
                details + ["FAIL kanban: task %s not found" % task_id],
                _fail_perf(task_id, model, "unknown", "row", unreached, directive_kill))

    if status != "done":
        # The row never closed.  rc==0 with an open row is the kimi incident.
        if rc == 0:
            return (2,
                    "worker exited 0 but the task never left %s — verification FAILED"
                    % status,
                    details + ["FAIL kanban: task %s is still %s (no claim/done recorded)"
                               % (task_id, status)],
                    (task_id, model, "incomplete", "fail", "row"))
        if directive_kill:
            summary = ("worker stopped by directive %s — verification FAILED "
                       "(directive kill, not a model failure)" % directive_kill)
        else:
            summary = "worker exited rc=%d and the task never left %s — verification FAILED" \
                % (rc, status)
        return (2,
                summary,
                details + ["FAIL exit: rc=%d; FAIL kanban: task %s is still %s"
                           % (rc, task_id, status)],
                _fail_perf(task_id, model, "incomplete", "row", unreached, directive_kill))

    # Row is closed.  What did the worker report — and did the work happen?
    verdict = verdict or "pass"
    if verdict in SUCCESS_VERDICTS:
        worker_report = "success"
    elif verdict in FAILURE_VERDICTS:
        worker_report = "failure-%s" % verdict
    else:
        worker_report = "unknown-%s" % verdict

    if rc != 0:
        return (2,
                "worker closed the row but exited rc=%d — verification FAILED" % rc,
                details + ["FAIL exit: worker exited rc=%d after closing the row" % rc],
                (task_id, model, worker_report, "fail", "exit"))

    # fail-found's definition is "task executed correctly, its subject
    # failed" — the deliverables ARE the executed work, so they are hard for
    # it too.  blocked/abandoned may legitimately produce nothing.
    deliverables_required = verdict in SUCCESS_VERDICTS or verdict == "fail-found"
    if dl_missing and deliverables_required:
        return (2,
                "worker reported %s; verification FAILED: deliverable(s) missing: %s"
                % (worker_report, ", ".join(dl_missing)),
                details + ["FAIL deliverables: missing: %s" % ", ".join(dl_missing)],
                (task_id, model, worker_report, "fail", "deliverables"))

    # T488: a findings deliverable that exists but does not parse (or lacks the
    # required keys) is broken work regardless of the verdict — report it
    # before the close, not after (absorption-spec.md §6.4).
    if findings_bad:
        for d, err in findings_bad:
            details.append("FAIL findings: %s — %s" % (d, err))
        return (2,
                "worker reported %s; verification FAILED: malformed findings deliverable(s): %s"
                % (worker_report, ", ".join(d for d, _ in findings_bad)),
                details, (task_id, model, worker_report, "fail", "findings"))

    if not nonce_ok:
        return (2,
                "worker reported %s; verification FAILED: nonce echo missing" % worker_report,
                details, (task_id, model, worker_report, "fail", "nonce"))

    if dl_missing:
        details.append("NOTE deliverables absent (expected for %s)" % verdict)

    # T520: wall-kill telemetry — flag a wall too low for the brief's class.
    # The run record (untracked/runs/<task_id>.json) carries brief_bytes +
    # wall_budget + the kill reason.  When the dispatch's wall budget was
    # below the class recommendation for that brief, surface it as a detail —
    # never a hard fail (a wall-low is a risk, not a lie).  This is the
    # epidemic made actionable at dispatch time.
    rr = read_run_record(root, task_id)
    if rr:
        wb = rr.get("wall_budget")
        bb = rr.get("brief_bytes")
        if bb is None:
            bb = rr.get("prompt_bytes")
        _typ, _rec, _ok, adv = wall_advisory(root, task_id, wb, bb, store_env=store_env)
        if adv:
            details.append(adv)

    if worker_report == "success":
        return (0,
                "worker reported success; side effects verified — verification PASSED",
                details, (task_id, model, "success", "pass", None))
    return (0,
            "worker reported failure (verdict %s); side effects verified — verification PASSED "
            "(believing the work, not the text)" % verdict,
            details, (task_id, model, worker_report, "pass", None))


def heal_dispatch(*, root, real_root, task_id, model, rc, wall_seconds,
                    store_env=None, mg_path=None, assert_path_env="WEIZIGO_DISPATCH_HEALS",
                    directive_kill=None):
    """Heal the one wound the dispatcher can heal: the worker it just watched
    die (rc != 0) left the kanban row in_progress.

    T477 (2026-08-19): T448/T450/T452/T466/T475 each sat claimed by a console
    that no longer existed until a human noticed and relayed a `reopen`. The
    process that watched the worker die is still running and already knows —
    so the heal lives here, in the dispatcher, not in a monitor.

    Heal ONLY this case. A worker that reported success and failed verification
    for a missing deliverable must stay exactly as it is: that is a claim to
    investigate, not a mess to tidy, and reopening it would erase the evidence.
    A worker that never claimed (row still dispatchable) needs no reopen. A
    worker that exited 0 but left the row open is the kimi incident, not a
    death — leave it for the Orchestrator.

    Returns (healed, line):
      healed  True iff the dispatcher reopened the row
      line    a single human-readable line printed by the caller under [verify]

    Side effects on heal:
      1. `managent reopen <task_id>` — row returns to dispatchable.
      2. an assertion record (JSON, one line) appended to the heals log:
         {task_id, model, exit_code, wall_seconds, healed_by, timestamp}.
      3. the returned line, so the operator sees the heal rather than the wound.
    The tree is never touched (a heal that cleaned the working tree would
    destroy a dead worker's uncommitted edits — three consoles died that way
    this week).

    F4/T513 — sole owner: this function is the ONLY automatic heal-reopen in
    any shipped script.  The `healed_by` field is `HEAL_OWNER` ("dispatcher"),
    so the heals log is a census of reopeners: any record NOT carrying it is a
    second owner and a defect.  See `tools/regression-dispatch-verification.sh`
    arm 10 for the invariant test.

    T631 (2026-08-22): this module is imported from HEAD (pinned), never the
    working tree, so a mid-edit file cannot crash the heal (the T616
    incident).  If this function STILL raises — a committed bug — the caller
    (bin/subagent) catches the exception and appends a marker to this same
    heals log: {task_id, model, exit_code, wall_seconds, healed_by:
    "dispatcher", healed: false, needs_manual_heal: true, error, timestamp}.
    The row is then left in_progress but LOUDLY flagged — a crashed heal is
    an unknown state, and auto-reopening it could relaunch a directive-kill
    stand-down or erase a kimi-incident investigation.  The marker is the
    census record that makes the zombie discoverable.
    """
    if task_id is None:
        return (False, "")
    # T625: re-derive the directive kill (the caller may not have one) so a
    # kill-directive death is never auto-reopened: `kill` is a STAND DOWN —
    # the operator ordered this run stopped, and making the row dispatchable
    # again would immediately re-launch the very run (the D048
    # duplicate-dispatch risk, and the D047 pause-forever defect class).  A
    # pause-directive kill heals normally — the next dispatch re-runs the
    # directive gate (bin/dispatch refuses until the pause discharges).
    if directive_kill is None:
        directive_kill = directive_kill_reason(root, task_id)
    if directive_kill and directive_kill.endswith("/kill"):
        return (False,
                "not healed: worker killed by directive %s (kill) — row left "
                "in_progress for the Orchestrator" % directive_kill)
    # Re-read the store at heal time: the row could have closed between the
    # verify read and now (rare, but a reopen of a done row would refuse and
    # we want to report that cleanly, not crash).
    status, _verdict = task_state(read_store(root, store_env), task_id)
    if status != "in_progress":
        return (False, "")
    if rc == 0:
        # A clean exit that left the row open is not a "watched die". The
        # kimi incident (rc=0, did nothing) is investigated, not auto-healed.
        return (False, "")

    mg = mg_path or os.path.join(real_root, "bin", "managent")
    r = subprocess.run([mg, "reopen", task_id],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return (False,
                "heal FAILED: managent reopen %s exited %d: %s"
                % (task_id, r.returncode, (r.stderr or r.stdout).strip()))

    rec = {
        "task_id": task_id,
        "model": model,
        "exit_code": rc,
        "wall_seconds": round(wall_seconds, 1),
        "healed_by": HEAL_OWNER,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    # T538: a heal caused by an unreached provider is a DIFFERENT event from an
    # ordinary dispatcher heal — the worker died of a lane-down refusal, not a
    # task failure.  Record the reason so T536's keeper backoff (and any lane
    # availability reader) can tell them apart.  The historical correction
    # record ({"correction": true, ...}) stays the precedent for retroactive
    # annotation; this field is the forward-looking classification.
    unreached = provider_refusal_reason(root, task_id)
    if unreached:
        rec["unreached"] = unreached
    # T625: same for a directive kill — the heal is an annotation of a
    # harness-initiated stop, never a model failure, and the directive id
    # names why the dispatcher re-opened the row.
    if directive_kill:
        rec["directive_kill"] = directive_kill
    path = (os.environ.get(assert_path_env)
            or os.path.join(real_root, "docs", "infra", "dispatch-heals.jsonl"))
    wrote = True
    try:
        with open(path, "a") as f:
            f.write(json.dumps(rec) + "\n")
    except OSError as e:
        wrote = False
        err = str(e)
    line = ("healed: dispatcher reopened %s (model=%s rc=%d wall=%.1fs) — "
            "assertion written"
            % (task_id, model, rc, wall_seconds))
    # T520: on a wall-kill (rc==124, the runner's timeout convention) name the
    # mis-sized dispatch in the heal line — the brief that was too big for its
    # wall.  The run record carries brief_bytes + wall_budget; the advisory
    # turns the reopen from a tidy into a measurement.
    if rc == 124:
        rr = read_run_record(root, task_id)
        if rr:
            wb = rr.get("wall_budget")
            bb = rr.get("brief_bytes")
            if bb is None:
                bb = rr.get("prompt_bytes")
            _typ, _rec, _ok, adv = wall_advisory(root, task_id, wb, bb, store_env=store_env)
            if adv:
                line = line + " | " + adv
    if not wrote:
        line = ("healed: dispatcher reopened %s (model=%s rc=%d wall=%.1fs) — "
                "ASSERTION WRITE FAILED: %s"
                % (task_id, model, rc, wall_seconds, err))
    elif directive_kill:
        line = line + " | directive-kill %s" % directive_kill
    return (True, line)


def record_perf(root, perf):
    """Append one line to the per-model dispatch ledger (best-effort).

    perf is the 5-tuple (task_id, model, report, verified, fail) returned by
    verify_dispatch.  Default target: docs/infra/model-perf.md.  Overridable
    via WEIZIGO_MODEL_PERF — the T411 regression points it at a scratch file
    so the live ledger is never touched by a test.  A failure to record is a
    loud warning, never a failed dispatch: verification is the gate, the
    ledger is data collection.

    T629: every line carries killed_by=<enum> — the verification record's
    censoring field, derived from the RUNNER'S OWN terminal record (see
    killed_by_reason).  A reader refuses any row with killed_by != none
    (Ruling 32: present, labeled censored, never scored).  The derived value
    is appended at the END of the line so every pre-existing substring
    assertion (verified=..., fail=..., reason=...) still matches.
    """
    task_id, model, report, verified, reason = perf
    date = time.strftime("%Y-%m-%d")
    path = os.environ.get("WEIZIGO_MODEL_PERF") or os.path.join(
        root, "docs", "infra", "model-perf.md")
    killed_by = killed_by_reason(root, task_id) or "none"
    if verified == "unreached":
        suffix = " reason=%s" % reason
    elif verified == "directive-kill":
        # T625: a directive-caused stop is a harness decision, never a model
        # failure — recorded with the directive id so the ladder can tell it
        # from every other termination (and so the count is verifiable).
        suffix = " reason=%s" % reason
    elif verified == "fail":
        suffix = " fail=%s" % reason
    else:
        suffix = ""
    line = "dispatch-verify %s %s %s report=%s verified=%s%s killed_by=%s\n" % (
        date, task_id or "-", model, report, verified, suffix, killed_by)
    try:
        with open(path, "a") as f:
            f.write(line)
        return True
    except OSError as e:
        print("[verify] WARNING: could not record dispatch perf at %s: %s"
              % (path, e), file=sys.stderr)
        return False


def scan_findings(root):
    """Yield (relpath, errors) for every findings/*.json under root.

    Skips rejections.json — it is the rejection ledger, not a findings record
    (the same skip claimlint's C7 scan applies at src/claimlint.zig:3022).  A
    missing findings/ directory yields nothing (a task may run before any
    findings file has been produced).
    """
    findings_dir = os.path.join(root, "findings")
    try:
        names = sorted(os.listdir(findings_dir))
    except OSError:
        return
    for name in names:
        if not name.endswith(".json") or name == "rejections.json":
            continue
        rel = os.path.join("findings", name)
        yield rel, verify_findings_file(os.path.join(findings_dir, name))


def main(argv):
    """`tools/dispatch_verify.py --dry-run` — the T488 acceptance gate.

    Runs the same findings parse verify_dispatch applies to declared findings
    deliverables, but over the live findings/ directory: a cheap early warning
    that every findings file JSON-loads and carries the required keys.  Exit 0
    when clean; exit 2 when any file is malformed (naming each), so a broken
    findings file fails the gate loudly rather than silently.

    --root <dir> overrides the repo root (default: current directory).
    """
    root = "."
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--root":
            if i + 1 < len(args):
                i += 1
                root = args[i]
        elif a.startswith("--root="):
            root = a.split("=", 1)[1]
        # --dry-run is the (only) mode; unknown flags are ignored so the
        # acceptance line can evolve without breaking this gate.
        i += 1

    bad = [(rel, err) for rel, errs in scan_findings(root) for err in errs]
    if bad:
        for rel, err in bad:
            print("FAIL findings: %s — %s" % (rel, err))
        print("dispatch-verify --dry-run: %d malformed findings file(s)" % len(bad))
        return 2
    print("dispatch-verify --dry-run: findings parse clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
