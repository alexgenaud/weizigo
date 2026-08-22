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
#   3. compute `eligible` (status dispatchable, id T\d+, NOT a duty, needs
#      all satisfied, exactly one bundle, model passes the gate), ordered by
#      the §5 key: waiting=1 first, then priority=N (0-99, 99 highest,
#      default 50), then `added` ascending.
#   4. run the logjam-PRESSURE state machine (§6–§8 of
#      docs/infra/fleet-keeper-design.md, T500): if the first eligible task
#      is conflict-blocked (its holds intersect a running task's holds), it
#      is the anchor — the fleet cap drops by one per running task that
#      completes while it stays blocked, until its holds free and it runs
#      solo.  Under pressure, only conflict-free candidates may be admitted.
#   5. fire `bin/dispatch <id> <model>` — model from the row's stored
#      `model`, else FLEET_DEFAULT_MODEL, gated by FLEET_MODEL_ALLOW /
#      FLEET_MODEL_DENY (D022).  One log line per firing.
#   6. never dispatches a duty row (DCLAIM/DRPLAY/DARGUS/DFLEET) or a
#      non-T seat (ORCHA-*); those run by their own mechanism.
#
# THE ONE-WRITER INVARIANT (T500, the operator's non-negotiable): the keeper
# NEVER dispatches a task whose holds intersect the holds of any in_progress
# task.  The pressure mechanism achieves progress by shrinking parallelism,
# never by preempting a holder or dispatching a conflict.  (D022's old
# "dispatch-anyway after a wait" escape was REJECTED by the operator on
# 2026-08-20 and is gone from this file.)
#
# The cooldown flag is the GRACEFUL stop (running workers finish, nothing
# new starts); a signal (q/^C) or killing the loop is the HARD stop.  Run
# detached under tools/runner, log at untracked/log/fleet-keeper.log.
#
# Env:
#   FLEET_INTERVAL       seconds between iterations (default 10)
#   FLEET_CAP            max in_progress workers (default 5)
#   FLEET_DEFAULT_MODEL  model for rows with no stored model.  NOT a free
#                        default: when unset, a model-less row gets the
#                        LEAST-DATA model (min per-model task count, ties by
#                        canonical order) so the exploration-first rule
#                        (T503) governs, not a fixed favourite.  Set it
#                        explicitly only to force a window.
#   FLEET_MODEL_ALLOW    comma list of canonical models allowed (D022); unset
#                        = all allowed.  e.g. "deepseek-v4-pro,deepseek-v4-flash"
#                        carves a DeepSeek-only window.
#   FLEET_MODEL_DENY     comma list of canonical models denied (D022); wins over
#                        ALLOW.  DURABLE DEFAULT (D036, 2026-08-20): when UNSET
#                        it denies glm-5.2,minimax-m3,kimi-k2.7 until the Ollama
#                        weekly quota refreshes — set FLEET_MODEL_DENY= (empty)
#                        to override for a forced window.  e.g. "glm-5.2,minimax-m3"
#                        turns an ollama cooldown into a config line.
#   FLEET_LOGJAM_FLAG    minutes after which a blocked anchor is flagged
#                        (T500 §10; telemetry only, default 60).
#   FLEET_HEAL_COOLDOWN  seconds a recently-healed row stays out of the
#                        dispatch pool (default 600 — 10 min; T504).  A row
#                        the dispatcher just healed (docs/infra/dispatch-heals.jsonl)
#                        or whose claim_count >= 2 needs investigation, not
#                        an instant re-fire (the T358 duplicate-dispatch class).
#   FLEET_DISPATCH_COOLDOWN seconds a row stays out after a firing (default
#                        300; T536).  Caps the keeper at ~1 fire per row per
#                        window, whatever the store says — the pre-claim-death
#                        rate limiter.
#   FLEET_MODEL_FAILURE_TRIP consecutive pre-claim deaths on one model, across
#                        different rows, that bench the model (default 3; T536).
#   FLEET_LANE_RETRY     seconds a benched model stays down before a re-probe
#                        (default 1800; T536).
#   FLEET_ROOT            working dir for untracked/ (cooldown, log, bundles);
#                        default = this repo.  Set to a scratch dir in tests.
#   FLEET_TEST_WORKER    forwarded to bin/dispatch as --test-worker (tests).
#   MANAGENT_STORE       scratch store (tests only; never set in production).
#   FLEET_APPETITE       family appetite map "family=LEVEL" (T651).  The loop
#                        auto-dispatches only SPEND/CONSERVE families; OFF,
#                        RESERVED (Fable) and PROBE (local) are refused.
#                        Default: claude=SPEND,deepseek=SPEND,ollama=SPEND,
#                        fable=RESERVED,local=PROBE.  ollama's §1 OFF→SPEND is
#                        the D036 default deny (model-level), not appetite.
#   FLEET_FAMILY_CAP     per-family concurrent-lane cap "family=N" (T651;
#                        §7c.33 enforcement at dispatch — T628 owns the meter
#                        that sizes it).  Default: claude=3,fable=1; unlisted
#                        = uncapped.
#
#   --once               run exactly one iteration and exit (test hook).
#
# Task: T496/T501/T504/T536/T651 · Model: glm-5.2 (T496/T501), deepseek-v4-pro (T504/T536/T651) · Date: 2026-08-19 (T496), 2026-08-20 (T501/T504/T536), 2026-08-22 (T651)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

ONCE=0
[ "${1:-}" = "--once" ] && ONCE=1

export FLEET_INTERVAL="${FLEET_INTERVAL:-10}"
export FLEET_CAP="${FLEET_CAP:-5}"
export FLEET_DEFAULT_MODEL="${FLEET_DEFAULT_MODEL:-glm-5.2}"
export FLEET_ROOT="${FLEET_ROOT:-$ROOT}"
# FLEET_ROOT defaults to ROOT (so production leaves it unset and bin/dispatch
# gets no --test-root, exactly as a real dispatch).  It is now also the lease
# and state root in bash (T651), so export it for the python child too.

# ── T651/T511 single-instance lease ──────────────────────────────────────
# mkdir is the atomic lock (macOS ships no flock(1); the repo's commit mutex
# uses Python fcntl.flock, but that is per-process and cannot span the bash
# loop's iterations).  The lock DIR records the owner's pid; a SIGKILLed
# keeper leaves a stale dir whose pid is dead, and the next keeper takes it
# over.  The dir lives under untracked/ beside the cooldown flag, but we do
# NOT create untracked/ itself: a missing untracked/ must stay missing (the
# dead-man's switch below), so an unavailable lease degrades to no-guard and
# lets cooldown_set() refuse.
LOCK_DIR="$FLEET_ROOT/untracked/fleet-keeper.lock"
if [ -d "$FLEET_ROOT/untracked" ]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    HOLDER="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo unknown)"
    if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then
      echo "lease-held: another keeper holds the lease (pid $HOLDER)"
      exit 3
    fi
    # stale lease (holder dead) — take it over
    rm -rf "$LOCK_DIR" 2>/dev/null || true
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "lease-held: could not take over the lease dir $LOCK_DIR"
      exit 3
    fi
  fi
  printf '%s\n' "$$" > "$LOCK_DIR/pid" 2>/dev/null || true
  trap 'rm -rf "$LOCK_DIR" 2>/dev/null || true' EXIT
fi

iterate() {
python3 - "$ROOT" "$ONCE" <<'PY'
import calendar, glob, json, os, re, subprocess, sys, time

REAL_ROOT = sys.argv[1]
ONCE = sys.argv[2] == "1"
CAP = int(os.environ.get("FLEET_CAP", "5"))
DEFAULT_MODEL = os.environ.get("FLEET_DEFAULT_MODEL", "glm-5.2")
FLEET_ROOT = os.environ.get("FLEET_ROOT") or REAL_ROOT
TEST_WORKER = os.environ.get("FLEET_TEST_WORKER")
FLEET_ROOT_SET = os.environ.get("FLEET_ROOT") is not None
# D022 (1) model-allowlist: FLEET_MODEL_ALLOW / FLEET_MODEL_DENY (comma lists of
# canonical model labels).  Lets an operator carve a model-cooldown window
# (e.g. "no ollama until 02:00") as a config line, not a code edit.
# D036 (operator, 2026-08-20): the Ollama weekly token allowance is exhausted
# (the 429 wall).  The three ollama models are DENIED BY DEFAULT until credits
# refresh, so the knowledge outlives any one shell.  REVIEW: restore the empty
# default when the quota clears.  An explicitly-set FLEET_MODEL_DENY — even the
# empty string (`FLEET_MODEL_DENY=`) — overrides the default for a forced
# window; a non-empty list carves a different one.
ALLOW = {m for m in os.environ.get("FLEET_MODEL_ALLOW", "").split(",") if m}
DEFAULT_DENY = "glm-5.2,minimax-m3,kimi-k2.7"
_deny_env = os.environ.get("FLEET_MODEL_DENY")
DENY = {m for m in (_deny_env if _deny_env is not None else DEFAULT_DENY).split(",") if m}
# T651: family appetite + fan-out cap (the loop's dispatch-time enforcement of
# §1 and §7c.33).  T628 owns the *when* — the reset watcher, token meter and
# the meter that re-sizes the cap — this loop owns the *loop*: it refuses a
# family whose appetite is not SPEND/CONSERVE and a family already at its
# concurrent-lane cap.  ollama's §1 "OFF→SPEND" is expressed by the D036
# default deny above (model-level), not here, so the appetite default is SPEND
# and the deny still refuses the three ollama models while the quota is out.
FAMILY = {
    "claude-opus-5": "claude", "claude-sonnet-5": "claude",
    "claude-haiku-4-5-20251001": "claude", "claude-fable-5": "fable",
    "deepseek-v4-pro": "deepseek", "deepseek-v4-flash": "deepseek",
    "glm-5.2": "ollama", "minimax-m3": "ollama", "kimi-k2.7": "ollama",
    "qwen3.8:27b-mlx": "local",
}

def _kv_map(env, default):
    m = dict(default)
    for kv in (os.environ.get(env) or "").split(","):
        kv = kv.strip()
        if "=" in kv:
            k, v = kv.split("=", 1)
            m[k.strip()] = v.strip()
    return m

DEFAULT_APPETITE = {"claude": "SPEND", "fable": "RESERVED", "deepseek": "SPEND",
                    "ollama": "SPEND", "local": "PROBE"}
APPETITE = _kv_map("FLEET_APPETITE", DEFAULT_APPETITE)
DEFAULT_FAMILY_CAP = {"claude": 3, "fable": 1}  # §7c.33: one race's worth; Fable alone
FAMILY_CAP = _kv_map("FLEET_FAMILY_CAP", DEFAULT_FAMILY_CAP)

def family_of(model):
    return FAMILY.get((model or "").split(":")[0], "other")

def family_cap(family):
    v = FAMILY_CAP.get(family)
    if v in (None, ""):
        return None  # uncapped
    try:
        return int(v)
    except ValueError:
        return None

def appetite_allows(model):
    fam = family_of(model)
    return APPETITE.get(fam, "SPEND") in ("SPEND", "CONSERVE")

# T500 §10: minutes after which a blocked anchor is flagged (telemetry only).
LOGJAM_FLAG_MIN = int(os.environ.get("FLEET_LOGJAM_FLAG", "60"))
# T536: pre-claim-death backoff + circuit breaker knobs.  A row fired within
# DISPATCH_COOLDOWN is never eligible (whatever the store says); consecutive
# pre-claim deaths back off 300→600→1200→3600; MODEL_FAILURE_TRIP distinct
# rows dying on one model bench that model for LANE_RETRY seconds.
DISPATCH_COOLDOWN = int(os.environ.get("FLEET_DISPATCH_COOLDOWN", "300"))
MODEL_FAILURE_TRIP = int(os.environ.get("FLEET_MODEL_FAILURE_TRIP", "3"))
LANE_RETRY = int(os.environ.get("FLEET_LANE_RETRY", "1800"))
BACKOFF_BASE = 300
BACKOFF_CAP = 3600

COOLDOWN = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.cooldown")
LOGDIR = os.path.join(FLEET_ROOT, "untracked", "log")
LOG = os.path.join(LOGDIR, "fleet-keeper.log")
PRESSURE = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.pressure.json")
LOGJAM_FLAG = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.logjam.flag")
# T651: orchestrator-wake flag — the loop's signal (NOT a console spawn) that
# the seat is owed work a leaf cannot do (a due duty, a sequencing decision).
WAKE = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.wake")
# T504: per-row heal cooldown.  HEAL_STATE is the keeper's own memory
# (untracked/, alongside the pressure file); HEAL_LOG is T477's dispatcher
# heal record (docs/infra/dispatch-heals.jsonl); STORE is the kanban, read
# directly for claim_count (status --json omits it).
HEAL_STATE = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.heal.json")
HEAL_LOG = os.path.join(FLEET_ROOT, "docs", "infra", "dispatch-heals.jsonl")
STORE = os.environ.get("MANAGENT_STORE") or os.path.join(REAL_ROOT, "docs", "infra", "managent", "tasks.json")
HEAL_COOLDOWN = int(os.environ.get("FLEET_HEAL_COOLDOWN", "600"))
ATTEMPTS = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.attempts.json")
LANE_DOWN = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.lane-down.json")
# T536 in-memory state (loaded fresh each iteration).  BENCHED_UNTIL is
# published by reconcile() so model_allowed()/least_data_model() refuse a
# benched lane.
ATTEMPTS_STATE = {"rows": {}, "models": {}}
BENCHED_UNTIL = {}
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

def bundle_path(tid):
    hits = glob.glob(os.path.join(FLEET_ROOT, "untracked", f"{tid}-*.md"))
    return hits[0] if len(hits) == 1 else None

def priority_of(tid):
    # D022 (2): priority lives in the bundle's `<!--managent ... priority=N-->
    # header — the single simplest source (co-located with the brief, no
    # engine/store change, no extra file).  0-99, 99 highest, default 50.
    bp = bundle_path(tid)
    if not bp:
        return 50
    try:
        with open(bp, "r", errors="replace") as f:
            head = f.read(2048)
    except OSError:
        return 50
    m = re.search(r"priority\s*=\s*(\d+)", head)
    if not m:
        return 50
    p = int(m.group(1))
    return p if 0 <= p <= 99 else 50

def waiting_of(tid):
    # T500 §5: `waiting=1` in the bundle header is the operator's "bump" — a
    # task marked waiting outranks every priority number as "next".  Boolean.
    bp = bundle_path(tid)
    if not bp:
        return 0
    try:
        with open(bp, "r", errors="replace") as f:
            head = f.read(2048)
    except OSError:
        return 0
    return 1 if re.search(r"waiting\s*=\s*1\b", head) else 0

def model_allowed(model):
    # D022 (1): allowlist/denylist gate the resolved model.  Both unset →
    # everything allowed (the row's stored model as today).  T536 adds the
    # per-model circuit breaker: a benched model (consecutive pre-claim deaths
    # tripped the lane) is refused until its FLEET_LANE_RETRY re-probe window.
    if model in DENY:
        return False
    if ALLOW and model not in ALLOW:
        return False
    bu = BENCHED_UNTIL.get(model)
    if bu and bu > time.time():
        return False
    return True

def least_data_model(by_id):
    # T503 exploration-first: a model-less row gets the model with the FEWEST
    # tasks in the ledger (ties by canonical order), so the under-measured are
    # sampled and an over-measured favourite is not silently handed everything.
    # The deny/allow gate still applies: the chosen model must be allowed.
    # T629/Ruling 32: a guard-killed row (killed_by != none in the perf
    # ledger) is present and labeled censored, NEVER counted as the model's
    # data — the guard stopped the lane, so no measurement happened.  The
    # census line prints the skip counts alongside the choice.
    censored = _read_censored_tasks()
    counts = {}
    unattributed = 0
    for r in by_id.values():
        rid = r.get("id") or ""
        m = (r.get("model") or "").split(":")[0]
        if not m:
            unattributed += 1
            continue
        if rid in censored:
            continue
        counts[m] = counts.get(m, 0) + 1
    print("least-data census: counted=%d censored=%d unattributed=%d"
          % (sum(counts.values()), len(censored), unattributed), file=sys.stderr)
    # Known canonical set (T317) so ties and missing models resolve stably.
    canon = ["kimi-k2.7", "minimax-m3", "deepseek-v4-flash",
             "deepseek-v4-pro", "glm-5.2"]
    best = None
    for m in canon:
        if not model_allowed(m):
            continue
        if best is None or counts.get(m, 0) < counts.get(best, 0):
            best = m
    return best or DEFAULT_MODEL  # all gated: fall back to the explicit default


def _read_censored_tasks():
    """Task ids whose latest dispatch-verify ledger line carries killed_by != none.

    T629: the perf ledger (WEIZIGO_MODEL_PERF, else the live model-perf.md)
    is the verification record — a killed_by value names a guard stop, and
    such rows are censored (never counted as model data).  Rows without the
    field predate the schema and stay counted (legacy); a task with both a
    censored line and a later genuine line is not censored (the latest line
    wins).  Missing/unreadable ledger → empty set (nothing censored)."""
    path = os.environ.get("WEIZIGO_MODEL_PERF") or os.path.join(
        FLEET_ROOT, "docs", "infra", "model-perf.md")
    censored = set()
    try:
        with open(path, errors="replace") as f:
            for line in f:
                if not line.startswith("dispatch-verify "):
                    continue
                parts = line.split()
                if len(parts) < 5:
                    continue
                task = parts[2]
                if not re.fullmatch(r"T\d+", task):
                    continue
                kb = None
                for kv in parts[4:]:
                    if kv.startswith("killed_by="):
                        kb = kv.split("=", 1)[1]
                if kb is not None and kb != "none":
                    censored.add(task)
                elif kb == "none":
                    censored.discard(task)  # a later genuine line un-censors
    except OSError:
        pass
    return censored

def parse_iso(s):
    # UTC epoch seconds for an ISO-8601 "…Z" timestamp (calendar.timegm treats
    # the tuple as UTC, matching time.time()).
    try:
        return calendar.timegm(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ"))
    except (TypeError, ValueError):
        return None

def load_pressure():
    try:
        with open(PRESSURE, "r") as f:
            return json.load(f) or {}
    except (OSError, ValueError):
        return {}

def save_pressure(state):
    # Never create untracked/ here — the dead-man's switch depends on its
    # absence being detectable.  In production (and in the scratch repo)
    # untracked/ already exists; a missing dir is a cooldown, not a chance
    # to silently recreate it.
    try:
        with open(PRESSURE, "w") as f:
            json.dump(state, f)
    except OSError:
        pass  # pressure tracking is advisory; never fatal.

def read_heal_log():
    # T504: T477's dispatcher heal record log (tools/dispatch_verify.py) —
    # one JSON line per heal: {task_id, model, exit_code, wall_seconds,
    # healed_by, timestamp}.  Append-only; the latest timestamp per task
    # wins.  Missing/unreadable file → no heals (null arm).
    out = {}
    try:
        with open(HEAL_LOG, "r", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                tid = rec.get("task_id")
                tstr = rec.get("timestamp")
                if not tid or not tstr:
                    continue
                e = parse_iso(tstr)
                if e is None:
                    continue
                if tid not in out or e > out[tid][0]:
                    out[tid] = (e, tstr)
    except OSError:
        pass
    return out

def read_claim_counts():
    # T504: claim_count lives in the kanban store, not in `status --json`
    # (printStatusJson omits it).  Read the store directly — the same file
    # watch-fleet.sh reads.  Missing/unreadable → empty (null arm).
    try:
        with open(STORE, "r", errors="replace") as f:
            doc = json.load(f)
    except (OSError, ValueError):
        return {}
    out = {}
    for k, v in doc.items():
        if k == "_sys" or not isinstance(v, dict):
            continue
        try:
            out[k] = int(v.get("claim_count") or 0)
        except (TypeError, ValueError):
            out[k] = 0
    return out

def load_heal_state():
    try:
        with open(HEAL_STATE, "r") as f:
            d = json.load(f) or {}
            return {"healed": d.get("healed") or {},
                    "seen_hl": d.get("seen_hl") or {},
                    "seen_cc": d.get("seen_cc") or {}}
    except (OSError, ValueError):
        return {"healed": {}, "seen_hl": {}, "seen_cc": {}}

def save_heal_state(state):
    # Like save_pressure: never create untracked/ here (dead-man's switch).
    try:
        with open(HEAL_STATE, "w") as f:
            json.dump(state, f)
    except OSError:
        pass  # heal cooldown is advisory; never fatal.

def pid_alive(pid):
    # T536: a pre-claim death is "the recorded pid is gone".  kill(pid, 0)
    # probes existence without signalling.  A recycled pid is a known limit;
    # acceptable for a backoff heuristic (the test scratch dir has no recycling).
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True  # exists, not ours — treat as alive
    except (OSError, ValueError):
        return False
    return True

def _seat_owed(rows):
    # T651: "owed work" a leaf cannot do, evaluated cheaply from the kanban
    # and the keeper's own state.  Concretely: a duty row that is due (duties
    # are the seat's work — absorption/sequencing/claim-verify/falsification —
    # and the loop deliberately never dispatches a duty), or a blocked anchor
    # that has waited past FLEET_LOGJAM_FLAG (a sequencing/dispatch decision
    # only a human makes).  Deliberately EXCLUDED: normal T-rows (the loop
    # dispatches those itself), anything under the logjam threshold (pressure
    # handles it), provider cooldowns (T628 re-probes), and an empty queue
    # (nothing owed — no wake, no console).
    owed = []
    for r in rows:
        if r.get("status") == "duty" and r.get("due"):
            owed.append(f"duty-due:{r.get('id')}")
    if os.path.exists(LOGJAM_FLAG):
        owed.append("logjam:blocked anchor past threshold")
    return owed

def _reconcile_wake(owed):
    # The wake is a flag, never a console spawn: the loop is not qualified to
    # decide what the seat should do, and a fresh seat console is expensive
    # (seat succession exists to avoid a permanently-live one).  Reconciled
    # every iteration so it is never left stale (same discipline as the
    # logjam flag, T514).
    if owed:
        try:
            with open(WAKE, "w") as f:
                f.write("\n".join(owed) + "\n")
        except OSError:
            pass
        log(f"orchestrator-wake: {'; '.join(owed)}")
    elif os.path.exists(WAKE):
        try:
            os.remove(WAKE)
        except OSError:
            pass

def load_attempts():
    try:
        with open(ATTEMPTS, "r") as f:
            d = json.load(f) or {}
            return {"rows": d.get("rows") or {}, "models": d.get("models") or {}}
    except (OSError, ValueError):
        return {"rows": {}, "models": {}}

def save_attempts():
    # Like save_pressure: never create untracked/ here (dead-man's switch).
    try:
        with open(ATTEMPTS, "w") as f:
            json.dump(ATTEMPTS_STATE, f)
    except OSError:
        pass  # backoff memory is advisory; never fatal.

def backoff_seconds(failures):
    # T536 layer 2: 300 s → 600 s → 1200 s, cap 3600 s, per consecutive
    # pre-claim death of the same row.
    n = max(0, int(failures) - 1)
    return min(BACKOFF_BASE * (2 ** n), BACKOFF_CAP)

def reconcile(rows):
    # T536: adjudicate the keeper's own firings.  A row whose recorded pid is
    # gone AND that never left `dispatchable` is one pre-claim death: bump its
    # backoff (300→600→1200→3600) and the model's failure streak; bench the
    # model's lane at MODEL_FAILURE_TRIP distinct rows.  A real claim
    # (in_progress/done) by a row the keeper fired resets that model's streak.
    global BENCHED_UNTIL
    now = time.time()
    rrows = ATTEMPTS_STATE.get("rows")
    mmodels = ATTEMPTS_STATE.get("models")
    for r in rows:
        rid = r.get("id") or ""
        st = r.get("status")
        rec = rrows.get(rid)
        if rec is None:
            continue
        model = rec.get("model")
        if st in ("in_progress", "done"):
            pending = rec.get("last_pid") is not None
            rec["failures"] = 0
            rec["backoff_until"] = None
            rec["last_pid"] = None
            rec["last_ts"] = None  # the attempt succeeded; no pending pre-claim cooldown
            # A firing the keeper made just claimed — that model's streak breaks.
            if pending and model and model in mmodels:
                mm = mmodels[model]
                mm["failed_rows"] = []
                mm["benched_until"] = None
                mm["benched_since"] = None
            continue
        if st != "dispatchable":
            continue  # blocked/failed/… — not a firing this keeper must judge
        pid = rec.get("last_pid")
        if pid is None:
            continue  # already adjudicated (or pidless firing)
        if pid_alive(pid):
            continue  # worker still running — no death yet
        # Pre-claim death: pid gone, row never left dispatchable.
        rec["failures"] = int(rec.get("failures") or 0) + 1
        backoff = backoff_seconds(rec["failures"])
        rec["backoff_until"] = now + backoff
        rec["last_pid"] = None
        log(f"backoff: {rid} pre-claim death #{rec['failures']} — parked {backoff}s")
        if model:
            mm = mmodels.setdefault(model, {"failed_rows": [], "benched_until": None,
                                            "benched_since": None})
            fr = mm.setdefault("failed_rows", [])
            if rid not in fr:
                fr.append(rid)
            if len(fr) >= MODEL_FAILURE_TRIP:
                if (mm.get("benched_until") or 0) <= now:
                    mm["benched_until"] = now + LANE_RETRY
                    mm["benched_since"] = now
                    log(f"LANE-DOWN {model} — {len(fr)} consecutive pre-claim deaths")
    # Drop entries for rows that left the store entirely (purged/retired).
    live = {r.get("id") for r in rows}
    for rid in list(rrows):
        if rid not in live:
            del rrows[rid]
    # Publish the benched set for model_allowed()/least_data_model().
    BENCHED_UNTIL = {m: v.get("benched_until") for m, v in mmodels.items()
                     if v.get("benched_until")}
    # lane-down.json — the operator-visible census of benched lanes (telemetry).
    try:
        down = {}
        for m, v in mmodels.items():
            bu = v.get("benched_until")
            if bu and bu > now:
                down[m] = {"consecutive_failures": len(v.get("failed_rows") or []),
                           "benched_since": v.get("benched_since"),
                           "benched_until": bu}
        if down:
            with open(LANE_DOWN, "w") as f:
                json.dump(down, f)
        elif os.path.exists(LANE_DOWN):
            os.remove(LANE_DOWN)
    except OSError:
        pass  # the lane-down census is telemetry; never fatal.

def fire(pick, in_prog, c_eff):
    rid = pick["row"]["id"]
    model = pick["model"]
    cmd = [DISPATCH, rid, model]
    if FLEET_ROOT_SET:
        cmd.append(f"--test-root={FLEET_ROOT}")
    if TEST_WORKER:
        cmd.append(f"--test-worker={TEST_WORKER}")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True,
                              env=dict(os.environ), timeout=60)
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        log(f"ERROR dispatch {rid} → {model}: {e}")
        print("error")
        return
    out = proc.stdout.strip()
    err = proc.stderr.strip()
    if proc.returncode == 0 and out.startswith("dispatched "):
        # T536 layer 1: record the firing (pid + time) so the next iteration
        # knows this row was just fired.  A pre-claim death is adjudicated on
        # a later iteration; the cooldown holds until then.
        m = re.search(r"pid (\d+)", out)
        pid = int(m.group(1)) if m else None
        prev = ATTEMPTS_STATE.get("rows", {}).get(rid) or {}
        ATTEMPTS_STATE.setdefault("rows", {})[rid] = {
            "model": model,
            "last_ts": time.time(),
            "last_pid": pid,
            "failures": int(prev.get("failures") or 0),
            "backoff_until": None,
        }
        save_attempts()
        log(f"dispatched {rid} → {model} (in_progress {in_prog}/{c_eff}) — {out}")
        print(f"dispatched {rid} {model}")
    else:
        log(f"dispatch REFUSED {rid} → {model} (rc={proc.returncode}) — {err or out}")
        print(f"refused {rid}")

def main():
    if cooldown_set():
        # T500 §6/§8: cooldown dispatches nothing but still advances the
        # `running` snapshot (so `completed` stays an honest diff).  Never
        # touch anchor/drops/waiting_since — cooldown pauses pressure, it
        # does not reset it.
        rows = read_rows()
        if rows is not None:
            prev = load_pressure()
            running = {r.get("id") for r in rows if r.get("status") == "in_progress"}
            save_pressure({
                "anchor": prev.get("anchor"),
                "drops": prev.get("drops") or 0,
                "waiting_since": prev.get("waiting_since"),
                "running": sorted(running),
            })
        log("cooldown flag set — no new dispatches")
        print("cooldown")
        return 0
    rows = read_rows()
    if rows is None:
        print("error")
        return 0
    by_id = {r.get("id"): r for r in rows}

    # ── T504 heal cooldown: observe fresh heals, park healed rows ────────
    now = time.time()
    now_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now))
    heal_log = read_heal_log()
    claim_counts = read_claim_counts()
    heal_state = load_heal_state()
    healed = heal_state.get("healed") or {}
    seen_hl = heal_state.get("seen_hl") or {}
    seen_cc = heal_state.get("seen_cc") or {}
    for r in rows:
        rid = r.get("id") or ""
        st = r.get("status")
        if st == "done":
            # step 4: a real close ends the row's story — clear the cooldown.
            healed.pop(rid, None)
            seen_hl.pop(rid, None)
            seen_cc.pop(rid, None)
            continue
        if st != "dispatchable":
            continue
        marked = False
        # signal 1: a fresh T477 heal record (the dispatcher's own ledger).
        if rid in heal_log:
            epoch, tstr = heal_log[rid]
            if seen_hl.get(rid) != tstr:
                seen_hl[rid] = tstr
                healed[rid] = epoch if epoch <= now else now
                marked = True
        # signal 2: claim_count >= 2 (kanban fallback — a row claimed and
        # returned without a heal record, e.g. a manual reopen).
        cc = claim_counts.get(rid, 0)
        if cc >= 2 and seen_cc.get(rid, 0) != cc:
            seen_cc[rid] = cc
            if not marked:
                healed[rid] = now
                marked = True
    # step 4: the window expiring also ends the cooldown (prune stale entries).
    for rid in list(healed):
        if now - float(healed[rid]) >= HEAL_COOLDOWN:
            healed.pop(rid, None)
    save_heal_state({"healed": healed, "seen_hl": seen_hl, "seen_cc": seen_cc})

    # ── T536 pre-claim-death memory: adjudicate firings, back off, trip lanes ─
    global ATTEMPTS_STATE
    ATTEMPTS_STATE = load_attempts()
    reconcile(rows)
    save_attempts()
    attempts_rows = ATTEMPTS_STATE.get("rows") or {}

    in_prog_rows = [r for r in rows if r.get("status") == "in_progress"]
    running = {r.get("id") for r in in_prog_rows}

    # ── T651 orchestrator wake + idle exit ───────────────────────────────
    # Wake the seat (flag + log) only when owed work exists; then, if nothing
    # is running AND no dispatchable leaf row remains, exit so no keeper idles
    # (launchd StartInterval wakes a fresh keeper when work appears).  A queue
    # holding only gated rows (denied/benched/OFF) is NOT empty — the keeper
    # stays alive to re-check when a gate lifts; it launches no console and
    # consumes no tokens while it waits.
    _reconcile_wake(_seat_owed(rows))
    leaf_pool = [r for r in rows
                 if r.get("status") == "dispatchable"
                 and not r.get("duty")
                 and re.fullmatch(r"T\d+", r.get("id") or "")]
    if not running and not leaf_pool:
        save_pressure({"anchor": None, "drops": 0, "waiting_since": None,
                       "running": []})
        if os.path.exists(LOGJAM_FLAG):
            try:
                os.remove(LOGJAM_FLAG)
            except OSError:
                pass
        if ONCE:
            print("none")
            return 0
        log("idle: queue empty — exiting (launchd wakes a fresh keeper)")
        print("idle")
        return 1

    # The set of holds currently held by a RUNNING task (the only holds that
    # block — a done holder is no holder).  managent's own holdsConflict
    # (src/managent/main.zig) enforces this at claim time too.
    inprog_holds = set()
    for r in in_prog_rows:
        for h in (r.get("holds") or []):
            inprog_holds.add(h)
    elig = []
    for r in rows:
        rid = r.get("id") or ""
        if r.get("status") != "dispatchable":
            continue
        if r.get("duty"):
            continue  # duties run by their own mechanism
        if not re.fullmatch(r"T\d+", rid):
            continue  # non-T seats (ORCHA-*, STANDING-*) stay manual
        # T504: a recently-healed row is parked — the worker that exited
        # without closing needs investigation, not an instant re-fire.
        if rid in healed:
            age = now - float(healed[rid])
            if age < HEAL_COOLDOWN:
                log(f"heal-cooldown: {rid} (healed {int(age)}s ago, waiting)")
                continue
        if not needs_met(r, by_id):
            continue
        if not has_bundle(rid):
            continue
        # T536: dispatch-attempt memory + per-row backoff.  A row just fired
        # (or whose worker is still running, or whose consecutive pre-claim
        # deaths back off) is parked — the keeper never re-fires it.
        rec = attempts_rows.get(rid)
        if rec is not None:
            bu = rec.get("backoff_until")
            if bu and now < float(bu):
                log(f"backoff: {rid} parked {int(float(bu) - now)}s more "
                    f"({rec.get('failures') or 0} consecutive pre-claim deaths)")
                continue
            pid = rec.get("last_pid")
            if pid is not None and pid_alive(pid):
                log(f"attempt-cooldown: {rid} worker pid {pid} still running — not re-fired")
                continue
            last_ts = rec.get("last_ts") or 0
            if now - float(last_ts) < DISPATCH_COOLDOWN:
                log(f"attempt-cooldown: {rid} fired {int(now - float(last_ts))}s ago "
                    f"(< {DISPATCH_COOLDOWN}s) — not re-fired")
                continue
        model = r.get("model") or least_data_model(by_id)
        if not model_allowed(model):
            continue  # D022 (1) model window / T536 benched lane
        if not appetite_allows(model):
            log(f"appetite: {rid} family {family_of(model)} appetite "
                f"{APPETITE.get(family_of(model), 'SPEND')} — not auto-dispatched")
            continue  # T651 §1: OFF/RESERVED/PROBE families never auto-launch
        holds = set(r.get("holds") or [])
        elig.append({"row": r, "model": model,
                     "priority": priority_of(rid),
                     "waiting": waiting_of(rid),
                     "added": added_of(rid) or "",
                     "holds": holds,
                     "conflict_blocked": bool(holds & inprog_holds)})
    # §5 ordering: waiting=1 first, then priority desc (99 highest), then
    # added ascending (oldest first).
    elig.sort(key=lambda e: (-e["waiting"], -e["priority"], e["added"]))

    # ── §6 pressure bookkeeping ──────────────────────────────────────────
    prev = load_pressure()
    prev_running = set(prev.get("running") or [])
    completed = prev_running - running  # ids that left in_progress this iter

    anchor = None
    drops = 0
    waiting_since = None
    if elig and elig[0]["conflict_blocked"]:
        top = elig[0]
        if prev.get("anchor") == top["row"]["id"]:
            # Same anchor still the blocked next → drop rule (§7).
            anchor = top["row"]["id"]
            drops = int(prev.get("drops") or 0) + len(completed)
            waiting_since = prev.get("waiting_since") or now_iso
        else:
            # Entry or re-anchor: a fresh pressure epoch from drops = 0.
            anchor = top["row"]["id"]
            drops = 0
            waiting_since = now_iso
    # else: no blocked next → NORMAL (anchor null, drops 0).

    c_eff = CAP if anchor is None else max(1, CAP - drops)

    save_pressure({
        "anchor": anchor,
        "drops": drops,
        "waiting_since": waiting_since,
        "running": sorted(running),
    })

    anchor_holds = set()
    flagged = False
    if anchor is not None:
        for e in elig:
            if e["row"]["id"] == anchor:
                anchor_holds = e["holds"]
                break
        # §10 signal 2: every pressured iteration logs the state.
        holder_of = {}
        for r in in_prog_rows:
            for h in (r.get("holds") or []):
                holder_of.setdefault(h, r.get("id"))
        held = "{" + ",".join(sorted(anchor_holds)) + "}"
        holders = ", ".join(f"{h}←{holder_of.get(h, '?')}" for h in sorted(anchor_holds))
        log(f"pressure: {anchor} blocked on {held} — drops={drops} cap={c_eff} ({holders})")

        # §10 flag telemetry: after FLEET_LOGJAM_FLAG minutes, write the flag
        # (one line per anchor) and log a LOGJAM: line every iteration.
        waited = now - (parse_iso(waiting_since) or now)
        if waited >= LOGJAM_FLAG_MIN * 60:
            flagged = True
            held_files = ",".join(sorted(anchor_holds))
            per_file = ",".join(f"{h}:{holder_of.get(h, '?')}" for h in sorted(anchor_holds))
            try:
                with open(LOGJAM_FLAG, "w") as f:
                    f.write(f"{anchor} held={held_files} holders={per_file} waited={int(waited // 60)}min\n")
            except OSError:
                pass
            log(f"LOGJAM: {anchor} waited {int(waited // 60)}min (>= {LOGJAM_FLAG_MIN}min) — "
                f"held {held_files}, holders {per_file}")
    # T514: logjam-flag lifecycle — the flag is created ONLY by the pressure
    # state machine (a blocked anchor past FLEET_LOGJAM_FLAG minutes) and is
    # removed the iteration that condition no longer holds: pressure exit
    # (anchor null), re-anchor to a different id (fresh waiting_since, below
    # threshold), or — defensively — the same anchor dropping below threshold
    # (cannot happen while the anchor stays, since waited only grows, but the
    # branch is correct regardless).  A loud artifact that outlives its
    # condition (F5: a flag naming a task that is now running while
    # pressure.json says NORMAL) trains readers to ignore it, so the flag is
    # always reconciled to the current pressure state — never hand-planted,
    # never left stale.  A flag the keeper did not write (hand-planted, or a
    # leftover from a crashed previous run) is swept on the next iteration the
    # condition is false: the keeper's own cleanup, not a manual `rm`.
    # Telemetry only: clearing the flag dispatches nothing and never preempts a
    # holder (the one-writer invariant, §3).  Under cooldown the flag is left
    # untouched (the early return above) — cooldown pauses pressure, it does
    # not reset it; the flag is reconciled when cooldown lifts.
    if not flagged and os.path.exists(LOGJAM_FLAG):
        try:
            os.remove(LOGJAM_FLAG)
        except OSError:
            pass  # removing the flag is telemetry hygiene; never fatal.

    # ── §8 step 3: cap ───────────────────────────────────────────────────
    if len(running) >= c_eff:
        log(f"at cap ({len(running)}/{c_eff}) — no dispatch")
        print("cap")
        return 0

    # ── §8 step 4: candidate filter ─────────────────────────────────────
    # T651 adds two gates before the one-writer holds test: the per-family
    # fan-out cap (§7c.33 — refuse a family already at its concurrent-lane
    # cap) and an explicit hold-conflict log (the reason must be recorded,
    # not silently skipped).  The one-writer invariant (§3) still binds.
    holder_of = {}
    for r in in_prog_rows:
        for h in (r.get("holds") or []):
            holder_of.setdefault(h, r.get("id"))
    family_inprog = {}
    for r in in_prog_rows:
        m = r.get("model") or (r.get("identifier") or "").split("/")[0] or ""
        fam = family_of(m)
        family_inprog[fam] = family_inprog.get(fam, 0) + 1
    candidates = []
    for e in elig:
        fam = family_of(e["model"])
        cap = family_cap(fam)
        if cap is not None and family_inprog.get(fam, 0) >= cap:
            log(f"family-cap: {e['row']['id']} family {fam} at cap "
                f"{family_inprog.get(fam, 0)}/{cap} — not dispatched")
            continue
        if e["holds"] & inprog_holds:
            held = sorted(e["holds"] & inprog_holds)
            holders = ", ".join(f"{h}←{holder_of.get(h, '?')}" for h in held)
            log(f"hold-conflict: {e['row']['id']} holds {{{','.join(held)}}} "
                f"held by running ({holders}) — not dispatched")
            continue  # the one-writer invariant (§3), always
        if anchor is not None and (e["holds"] & anchor_holds):
            continue  # compatibility with the blocked task, under pressure
        candidates.append(e)
    if not candidates:
        log("logjam: no conflict-free eligible task")
        print("none")
        return 0
    pick = candidates[0]  # elig is sorted; the first survivor is the best key
    fire(pick, len(running), c_eff)
    return 0

sys.exit(main())
PY
}

# ── loop ──────────────────────────────────────────────────────────────────
# T651: exit when idle (no running worker and no dispatchable leaf row), so
# no keeper process holds a seat while the queue is empty; launchd
# StartInterval wakes a fresh keeper when work appears.  `iterate` returns 1
# on idle (loop mode only); --once always returns 0.
while :; do
  iterate
  rc=$?
  [ "$ONCE" -eq 1 ] && break
  [ "$rc" -eq 1 ] && break
  sleep "$FLEET_INTERVAL"
done
