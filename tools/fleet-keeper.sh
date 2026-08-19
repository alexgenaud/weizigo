#!/usr/bin/env bash
# tools/fleet-keeper.sh — T496 fleet keeper: keep the fleet full, cool down on demand.
#
# A shell loop (NOT a managent engine change — src/managent/main.zig is
# serial-held by T485/T486/T487).  Everything it needs already exists:
# `bin/managent status --json` (read the queue), `bin/dispatch <id> <model>`
# (fire a worker), and a configurable fleet cap (default 5, the operator's
# ruling of 2026-08-19).  The graceful stop is a FILE flag
# (untracked/fleet-keeper.cooldown, set by tools/fleet-cooldown.sh) — no
# store change, no engine change; works for the human and the Orchestrator.
#
# Loop, every FLEET_INTERVAL seconds:
#   1. read `bin/managent status --json`.
#   2. if the cooldown flag is set → dispatch nothing.  (Fail-safe / dead-
#      man's switch: if the flag's directory cannot be read, treat it as
#      cooldown-set and dispatch nothing — a dead fleet is the safe
#      failure, not a free-for-all.)
#   3. if in_progress >= FLEET_CAP → dispatch nothing.
#   4. else pick the next dispatchable TASK (status dispatchable, id T\d+,
#      NOT a duty, needs all satisfied, exactly one bundle), ordered by
#      `added` ascending (oldest first — the queue's natural priority; do
#      not re-implement DO-NOW ranking, that is backlog policy, not fleet
#      policy).
#   5. fire `bin/dispatch <id> <model>` — model from the row's stored
#      `model`, else FLEET_DEFAULT_MODEL.  One log line per firing.
#   6. never dispatches a duty row (DCLAIM/DRPLAY/DARGUS/DFLEET) or a
#      non-T seat (ORCHA-*); those run by their own mechanism.
#
# The cooldown flag is the GRACEFUL stop (running workers finish, nothing
# new starts); a signal (q/^C) or killing the loop is the HARD stop.  Run
# detached under tools/runner, log at untracked/log/fleet-keeper.log.
#
# Env:
#   FLEET_INTERVAL       seconds between iterations (default 10)
#   FLEET_CAP            max in_progress workers (default 5)
#   FLEET_DEFAULT_MODEL  model for rows with no stored model (default glm-5.2)
#   FLEET_ROOT            working dir for untracked/ (cooldown, log, bundles);
#                        default = this repo.  Set to a scratch dir in tests.
#   FLEET_TEST_WORKER    forwarded to bin/dispatch as --test-worker (tests).
#   MANAGENT_STORE       scratch store (tests only; never set in production).
#
#   --once               run exactly one iteration and exit (test hook).
#
# Task: T496 · Model: glm-5.2 · Date: 2026-08-19

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

ONCE=0
[ "${1:-}" = "--once" ] && ONCE=1

export FLEET_INTERVAL="${FLEET_INTERVAL:-10}"
export FLEET_CAP="${FLEET_CAP:-5}"
export FLEET_DEFAULT_MODEL="${FLEET_DEFAULT_MODEL:-glm-5.2}"
# FLEET_ROOT defaults to ROOT inside the python (so production leaves it unset
# and bin/dispatch gets no --test-root, exactly as a real dispatch).

iterate() {
python3 - "$ROOT" "$ONCE" <<'PY'
import glob, json, os, re, subprocess, sys, time

REAL_ROOT = sys.argv[1]
ONCE = sys.argv[2] == "1"
CAP = int(os.environ.get("FLEET_CAP", "5"))
DEFAULT_MODEL = os.environ.get("FLEET_DEFAULT_MODEL", "glm-5.2")
FLEET_ROOT = os.environ.get("FLEET_ROOT") or REAL_ROOT
TEST_WORKER = os.environ.get("FLEET_TEST_WORKER")
FLEET_ROOT_SET = os.environ.get("FLEET_ROOT") is not None

COOLDOWN = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.cooldown")
LOGDIR = os.path.join(FLEET_ROOT, "untracked", "log")
LOG = os.path.join(LOGDIR, "fleet-keeper.log")
MG = os.path.join(REAL_ROOT, "bin", "managent")
DISPATCH = os.path.join(REAL_ROOT, "bin", "dispatch")

def ts():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def log(msg):
    # Lazy dir creation: we must NOT create untracked/ before the cooldown
    # check, or the dead-man's switch (missing untracked/ → cooldown) could
    # never trigger.  Create the log dir only when we actually log.
    try:
        os.makedirs(LOGDIR, exist_ok=True)
        with open(LOG, "a") as f:
            f.write(f"{ts()} {msg}\n")
    except OSError:
        pass  # logging must never kill the keeper.

def cooldown_set():
    # Dead-man's switch: if the flag's directory cannot be listed (missing
    # dir, permission denied), treat it as cooldown-set and dispatch
    # nothing.  A clean negative (dir readable, flag absent) → clear.
    d = os.path.dirname(COOLDOWN) or "."
    try:
        names = os.listdir(d)
    except OSError:
        return True
    return os.path.basename(COOLDOWN) in names

def read_rows():
    env = dict(os.environ)
    try:
        r = subprocess.run([MG, "status", "--json"], capture_output=True,
                           text=True, env=env, timeout=30)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        log(f"ERROR cannot read status --json: {e}")
        return None
    if r.returncode != 0:
        log(f"ERROR managent status --json rc={r.returncode}: {r.stderr.strip()}")
        return None
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        log("ERROR status --json was not JSON")
        return None

def needs_met(row, by_id):
    for n in (row.get("needs") or []):
        dep = by_id.get(n)
        if dep is None or dep.get("status") != "done":
            return False
    return True

def has_bundle(tid):
    return len(glob.glob(os.path.join(FLEET_ROOT, "untracked", f"{tid}-*.md"))) == 1

def added_of(tid):
    # `managent status --json` omits `added`; `managent show <id>` prints it
    # on a "    added:    <iso>" line.  This is the public CLI contract, not
    # the store schema (T485-T487 may reshape the store; show is stable).
    try:
        r = subprocess.run([MG, "show", tid], capture_output=True,
                           text=True, env=dict(os.environ), timeout=15)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""
    for line in (r.stdout or "").splitlines():
        if line.strip().startswith("added:"):
            return line.split("added:", 1)[1].strip()
    return ""

def main():
    if cooldown_set():
        log("cooldown flag set — no new dispatches")
        print("cooldown")
        return 0
    rows = read_rows()
    if rows is None:
        print("error")
        return 0
    by_id = {r.get("id"): r for r in rows}
    in_prog = sum(1 for r in rows if r.get("status") == "in_progress")
    if in_prog >= CAP:
        log(f"at cap ({in_prog}/{CAP}) — no dispatch")
        print("cap")
        return 0
    elig = []
    for r in rows:
        rid = r.get("id") or ""
        if r.get("status") != "dispatchable":
            continue
        if r.get("duty"):
            continue  # duties run by their own mechanism
        if not re.fullmatch(r"T\d+", rid):
            continue  # non-T seats (ORCHA-*, STANDING-*) stay manual
        if not needs_met(r, by_id):
            continue
        if not has_bundle(rid):
            continue
        elig.append(r)
    if not elig:
        log("nothing eligible")
        print("none")
        return 0
    elig.sort(key=lambda r: added_of(r["id"]) or "")
    pick = elig[0]
    model = pick.get("model") or DEFAULT_MODEL
    cmd = [DISPATCH, pick["id"], model]
    if FLEET_ROOT_SET:
        cmd.append(f"--test-root={FLEET_ROOT}")
    if TEST_WORKER:
        cmd.append(f"--test-worker={TEST_WORKER}")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              env=dict(os.environ), timeout=60)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        log(f"ERROR dispatch {pick['id']} → {model}: {e}")
        print("error")
        return 0
    out = proc.stdout.strip()
    err = proc.stderr.strip()
    if proc.returncode == 0 and out.startswith("dispatched "):
        log(f"dispatched {pick['id']} → {model} (in_progress was {in_prog}/{CAP}) — {out}")
        print(f"dispatched {pick['id']} {model}")
    else:
        log(f"dispatch REFUSED {pick['id']} → {model} (rc={proc.returncode}) — {err or out}")
        print(f"refused {pick['id']}")
    return 0

sys.exit(main())
PY
}

# ── loop ──────────────────────────────────────────────────────────────────
while :; do
  iterate
  [ "$ONCE" -eq 1 ] && break
  sleep "$FLEET_INTERVAL"
done