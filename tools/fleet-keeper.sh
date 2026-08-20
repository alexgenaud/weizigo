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
#                        ALLOW.  e.g. "glm-5.2,minimax-m3,kimi-k2.7,qwen3.8"
#                        turns an ollama cooldown into a config line.
#   FLEET_LOGJAM_FLAG    minutes after which a blocked anchor is flagged
#                        (T500 §10; telemetry only, default 60).
#   FLEET_HEAL_COOLDOWN  seconds a recently-healed row stays out of the
#                        dispatch pool (default 600 — 10 min; T504).  A row
#                        the dispatcher just healed (docs/infra/dispatch-heals.jsonl)
#                        or whose claim_count >= 2 needs investigation, not
#                        an instant re-fire (the T358 duplicate-dispatch class).
#   FLEET_ROOT            working dir for untracked/ (cooldown, log, bundles);
#                        default = this repo.  Set to a scratch dir in tests.
#   FLEET_TEST_WORKER    forwarded to bin/dispatch as --test-worker (tests).
#   MANAGENT_STORE       scratch store (tests only; never set in production).
#
#   --once               run exactly one iteration and exit (test hook).
#
# Task: T496/T501/T504 · Model: glm-5.2 (T496/T501), deepseek-v4-pro (T504) · Date: 2026-08-19 (T496), 2026-08-20 (T501/T504)

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
# (e.g. "no ollama until 02:00") as a config line, not a code edit.  Default
# (both unset): the row's stored model as today.
ALLOW = {m for m in os.environ.get("FLEET_MODEL_ALLOW", "").split(",") if m}
DENY = {m for m in os.environ.get("FLEET_MODEL_DENY", "").split(",") if m}
# T500 §10: minutes after which a blocked anchor is flagged (telemetry only).
LOGJAM_FLAG_MIN = int(os.environ.get("FLEET_LOGJAM_FLAG", "60"))

COOLDOWN = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.cooldown")
LOGDIR = os.path.join(FLEET_ROOT, "untracked", "log")
LOG = os.path.join(LOGDIR, "fleet-keeper.log")
PRESSURE = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.pressure.json")
LOGJAM_FLAG = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.logjam.flag")
# T504: per-row heal cooldown.  HEAL_STATE is the keeper's own memory
# (untracked/, alongside the pressure file); HEAL_LOG is T477's dispatcher
# heal record (docs/infra/dispatch-heals.jsonl); STORE is the kanban, read
# directly for claim_count (status --json omits it).
HEAL_STATE = os.path.join(FLEET_ROOT, "untracked", "fleet-keeper.heal.json")
HEAL_LOG = os.path.join(FLEET_ROOT, "docs", "infra", "dispatch-heals.jsonl")
STORE = os.environ.get("MANAGENT_STORE") or os.path.join(REAL_ROOT, "docs", "infra", "managent", "tasks.json")
HEAL_COOLDOWN = int(os.environ.get("FLEET_HEAL_COOLDOWN", "600"))
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
    # everything allowed (the row's stored model as today).
    if model in DENY:
        return False
    if ALLOW and model not in ALLOW:
        return False
    return True

def least_data_model(by_id):
    # T503 exploration-first: a model-less row gets the model with the FEWEST
    # tasks in the ledger (ties by canonical order), so the under-measured are
    # sampled and an over-measured favourite is not silently handed everything.
    # The deny/allow gate still applies: the chosen model must be allowed.
    counts = {}
    for r in by_id.values():
        m = (r.get("model") or "").split(":")[0]
        if not m:
            continue
        counts[m] = counts.get(m, 0) + 1
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

    in_prog_rows = [r for r in rows if r.get("status") == "in_progress"]
    running = {r.get("id") for r in in_prog_rows}
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
        model = r.get("model") or least_data_model(by_id)
        if not model_allowed(model):
            continue  # D022 (1): model cooldown window
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
            try:
                held_files = ",".join(sorted(anchor_holds))
                per_file = ",".join(f"{h}:{holder_of.get(h, '?')}" for h in sorted(anchor_holds))
                with open(LOGJAM_FLAG, "w") as f:
                    f.write(f"{anchor} held={held_files} holders={per_file} waited={int(waited // 60)}min\n")
            except OSError:
                pass
            log(f"LOGJAM: {anchor} waited {int(waited // 60)}min (>= {LOGJAM_FLAG_MIN}min) — "
                f"held {held_files}, holders {per_file}")

    # ── §8 step 3: cap ───────────────────────────────────────────────────
    if len(running) >= c_eff:
        log(f"at cap ({len(running)}/{c_eff}) — no dispatch")
        print("cap")
        return 0

    # ── §8 step 4: two-test candidate filter ─────────────────────────────
    candidates = []
    for e in elig:
        if e["holds"] & inprog_holds:
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
while :; do
  iterate
  [ "$ONCE" -eq 1 ] && break
  sleep "$FLEET_INTERVAL"
done
