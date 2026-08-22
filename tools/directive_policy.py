"""tools/directive_policy.py — directive discharge + staleness policy (T625)

The directive ledger (docs/infra/managent/directives.jsonl) records a fact
once; whether that fact is still IN FORCE at apply time is a separate
question the record cannot answer by itself.  This module is the single
evaluation of that question, shared by the enforcement points:

  * tools/runner — the launch-time and mid-run directive checks: a pending
    `pause`/`kill` stops the run only while it is enforced;
  * bin/dispatch — the pre-launch check: refuse to spend a worker's tokens
    on a row a pending directive will kill.

Defect (T625, 2026-08-22): D047, a `pause` issued 2026-08-20T12:55:28Z,
carried its discharge condition ("T545 goes first") only in English prose
inside --note.  T545 closed `done`; nothing re-evaluated D047, so it kept
killing fresh T544 dispatches for two days, and every termination surfaced
as `verified=fail` — a false model-failure row in the ladder.

Two remedies, both machine-checkable:

  1. discharge-by-condition — `managent tell <t> pause --until-done <row>`:
     the pause is enforced only while <row> is not `done` in the kanban,
     re-evaluated at EVERY apply (D047 would have discharged itself the
     moment T545 closed).  Preferred over a timeout: a timeout on a
     still-valid pause is the opposite failure, so a pause WITH a
     condition is governed by the condition alone.
  2. staleness horizon — an unacked pause WITHOUT a condition, older than
     STALE_HOURS_DEFAULT (24 h; WEIZIGO_DIRECTIVE_STALE_HOURS override), is
     reported stale, not enforced.  `kill` is never stale and never
     conditional: it is an explicit halt, and treating it as expired could
     resume a run the operator ordered stopped.

The ledger's `read` flag is an ack, not a verdict: unacked means UNKNOWN
(has the worker seen it? is it still relevant?), and the point of this
module is that UNKNOWN must not default to "still in force" — the
project's oldest rule, broken by its own tooling.

Stdlib only (the consumers run standalone).  Task: T625 · 2026-08-22.
"""
import calendar
import json
import os
import re
import time

STALE_HOURS_DEFAULT = 24
STALE_HOURS_ENV = "WEIZIGO_DIRECTIVE_STALE_HOURS"
_ROW_RE = re.compile(r"^T\d+$")


def read_directives(repo_root):
    """The directive ledger as a list of dicts (empty on any failure).

    One JSON object per physical line; unparseable lines are skipped — the
    same parse-resilience the managent reader applies (T399).
    """
    path = os.path.join(repo_root, "docs", "infra", "managent", "directives.jsonl")
    out = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    except OSError:
        return []
    return out


def read_store(repo_root):
    """The kanban store dict, honoring MANAGENT_STORE (tests isolate).

    A missing/unreadable store is {} — a directive whose until_done row
    cannot be found is evaluated as "not done", and the staleness horizon
    is the backstop for the block-forever failure mode.
    """
    path = os.environ.get("MANAGENT_STORE") or os.path.join(
        repo_root, "docs", "infra", "managent", "tasks.json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}


def parse_ts(ts):
    """ISO timestamp (YYYY-MM-DDTHH:MM:SSZ, the ledger's format) → epoch
    seconds (UTC), or None when unparseable."""
    if not ts or len(ts) < 19:
        return None
    try:
        return calendar.timegm(time.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return None


def stale_hours():
    """The staleness horizon in hours (env override, else the default)."""
    v = os.environ.get(STALE_HOURS_ENV)
    if v:
        try:
            return float(v)
        except ValueError:
            pass
    return STALE_HOURS_DEFAULT


def evaluate(d, repo_root, store=None, now_epoch=None, stale_h=None):
    """One directive's status at apply time.

    Returns (enforced, reason):
      enforced  True  → the runner must stop on this directive
      reason    why   — "acked" / "not-a-stop:<type>" / a discharge or
                staleness reason (not enforced) / "enforced[: ...]"
    """
    if d.get("read"):
        return (False, "acked")
    dtype = d.get("directive")
    if dtype not in ("pause", "kill"):
        return (False, "not-a-stop:%s" % dtype)

    if dtype == "pause":
        until = d.get("until_done")
        if until:
            # Discharge-by-condition governs: re-evaluated at every apply.
            # A row absent from the store is NOT done — the condition is
            # unsatisfied, so the pause stays enforced until the staleness
            # backstop would... it has a condition, so it is condition-
            # governed only.  A typo'd row id blocks until a human fixes or
            # acks it — that is the honest reading of "until <row> is done".
            if store is None:
                store = read_store(repo_root)
            row = store.get(until)
            if row and isinstance(row, dict) and row.get("status") == "done":
                return (False, "discharged: until_done %s is done" % until)
            return (True, "enforced: until_done %s not done" % until)
        # No discharge condition → the staleness horizon applies.
        if now_epoch is None:
            now_epoch = int(time.time())
        ts_ep = parse_ts(d.get("ts"))
        if ts_ep is not None:
            h = stale_h if stale_h is not None else stale_hours()
            age_h = (now_epoch - ts_ep) / 3600.0
            if age_h > h:
                return (False, "stale: unacked > %.0fh (horizon %.0fh)" % (age_h, h))
    return (True, "enforced")


def evaluate_directives(task_id, repo_root, store=None, now_epoch=None,
                        stale_h=None):
    """Every ledger directive addressed to task_id, evaluated at apply time.

    Returns (enforced, not_enforced):
      enforced     [(directive_dict, reason)] — stop directives in force now
      not_enforced [(directive_dict, reason)] — directives that must NOT
                   stop the run, with the reason (acked / not-a-stop /
                   discharged / stale)
    """
    if store is None:
        store = read_store(repo_root)
    enforced = []
    not_enforced = []
    for d in read_directives(repo_root):
        if d.get("target") != task_id:
            continue
        en, reason = evaluate(d, repo_root, store=store,
                              now_epoch=now_epoch, stale_h=stale_h)
        if en:
            enforced.append((d, reason))
        else:
            not_enforced.append((d, reason))
    return enforced, not_enforced
