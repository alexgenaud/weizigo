#!/usr/bin/env python3
"""Shared dispatch verification for bin/subagent and bin/ollama-subagent (T411).

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

    dl_missing = []
    for d in (deliverables or []):
        p = d if os.path.isabs(d) else os.path.join(root, d)
        if not os.path.exists(p):
            dl_missing.append(d)

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
                    (task_id, model, "crash", "fail", "exit"))
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
                (task_id, model, "unknown", "fail", "row"))

    if status != "done":
        # The row never closed.  rc==0 with an open row is the kimi incident.
        if rc == 0:
            return (2,
                    "worker exited 0 but the task never left %s — verification FAILED"
                    % status,
                    details + ["FAIL kanban: task %s is still %s (no claim/done recorded)"
                               % (task_id, status)],
                    (task_id, model, "incomplete", "fail", "row"))
        return (2,
                "worker exited rc=%d and the task never left %s — verification FAILED"
                % (rc, status),
                details + ["FAIL exit: rc=%d; FAIL kanban: task %s is still %s"
                           % (rc, task_id, status)],
                (task_id, model, "incomplete", "fail", "row"))

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

    if not nonce_ok:
        return (2,
                "worker reported %s; verification FAILED: nonce echo missing" % worker_report,
                details, (task_id, model, worker_report, "fail", "nonce"))

    if dl_missing:
        details.append("NOTE deliverables absent (expected for %s)" % verdict)

    if worker_report == "success":
        return (0,
                "worker reported success; side effects verified — verification PASSED",
                details, (task_id, model, "success", "pass", None))
    return (0,
            "worker reported failure (verdict %s); side effects verified — verification PASSED "
            "(believing the work, not the text)" % verdict,
            details, (task_id, model, worker_report, "pass", None))


def heal_dispatch(*, root, real_root, task_id, model, rc, wall_seconds,
                    store_env=None, mg_path=None, assert_path_env="WEIZIGO_DISPATCH_HEALS"):
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
    """
    if task_id is None:
        return (False, "")
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
        "healed_by": "dispatcher",
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
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
    if not wrote:
        line = ("healed: dispatcher reopened %s (model=%s rc=%d wall=%.1fs) — "
                "ASSERTION WRITE FAILED: %s"
                % (task_id, model, rc, wall_seconds, err))
    return (True, line)


def record_perf(root, perf):
    """Append one line to the per-model dispatch ledger (best-effort).

    perf is the 5-tuple (task_id, model, report, verified, fail) returned by
    verify_dispatch.  Default target: docs/infra/model-perf.md.  Overridable
    via WEIZIGO_MODEL_PERF — the T411 regression points it at a scratch file
    so the live ledger is never touched by a test.  A failure to record is a
    loud warning, never a failed dispatch: verification is the gate, the
    ledger is data collection.
    """
    task_id, model, report, verified, fail = perf
    date = time.strftime("%Y-%m-%d")
    path = os.environ.get("WEIZIGO_MODEL_PERF") or os.path.join(
        root, "docs", "infra", "model-perf.md")
    line = "dispatch-verify %s %s %s report=%s verified=%s%s\n" % (
        date, task_id or "-", model, report, verified,
        (" fail=%s" % fail) if fail else "")
    try:
        with open(path, "a") as f:
            f.write(line)
        return True
    except OSError as e:
        print("[verify] WARNING: could not record dispatch perf at %s: %s"
              % (path, e), file=sys.stderr)
        return False
