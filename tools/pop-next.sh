#!/bin/sh
# tools/pop-next.sh — pop ONE well-specified task off the stack and dispatch it.
#
# Operator, 2026-08-25: "I would like the backlog of well-specified, obviously
# beneficial tasks to methodically execute. Not in haste, perhaps serially, but
# automatically pop off the stack and run."
#
# Deliberately small.  It does not supervise, does not close rows, does not
# judge.  It picks the highest-ranked AUTO row that is dispatchable and whose
# held files are free, assigns a model, and calls bin/dispatch — which already
# enforces caps, admission, holds and the delegation depth.  Everything else
# that exists keeps doing its job.
#
#   --dry-run   print the choice, dispatch nothing
#   --loop N    pop, then wait until the fleet has room again, up to N times
#   MAX_LANES   how many lanes may run at once (default 1 — serial, as asked)
#
# It STOPS, loudly, rather than guessing:
#   * no AUTO row is dispatchable            -> exit 0, says so
#   * the next AUTO row's file is held       -> skips it, names the holder
#   * untracked/pop-next.stop exists         -> exit 0, the graceful brake
#
# DISCUSS rows are never popped.  That is the point: they need a conversation,
# and a loop cannot have one.
set -e
cd "$(dirname "$0")/.." || exit 1
QUEUE=docs/infra/dispatch-queue.tsv
STOP=untracked/pop-next.stop
MAX_LANES="${MAX_LANES:-1}"
DRY=0; LOOPS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --loop) shift; LOOPS="${1:-1}" ;;
    *) echo "pop-next: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

lanes_now() { pgrep -f -- '--arbiter-id T[0-9]' 2>/dev/null | wc -l | tr -d ' '; }

pop_once() {
  [ -f "$STOP" ] && { echo "pop-next: STOPPED — $STOP exists (remove it to resume)"; return 1; }
  n=$(lanes_now)
  if [ "$n" -ge "$MAX_LANES" ]; then
    echo "pop-next: $n lane(s) running, MAX_LANES=$MAX_LANES — nothing popped"
    return 2
  fi
  choice=$(python3 - "$QUEUE" <<'PYP'
import json,sys,os
q=sys.argv[1]
store=json.load(open('docs/infra/managent/tasks.json'))
# A dispatched row reads `dispatchable` until its worker claims itself, which is a
# window wide enough to dispatch it twice (the T350/T376/T389 duplicate class). So
# a row with a LIVE runner is not a candidate, whatever the store says. Process
# table first, store second.
import subprocess,re
live=set()
try:
    ps=subprocess.run(['ps','-axo','command='],capture_output=True,text=True).stdout
    live={m for m in re.findall(r'--arbiter-id (T\d+)', ps)}
except Exception: pass
held=set()
for k,v in store.items():
    if isinstance(v,dict) and v.get('status')=='in_progress':
        for h in (v.get('holds') or []): held.add(h)
rows=[]
for ln in open(q):
    if ln.startswith('#') or not ln.strip(): continue
    f=ln.rstrip('\n').split('\t')
    if len(f)>=4 and f[3]=='AUTO': rows.append((int(f[1]),f[0]))
rows.sort()
for _,t in rows:
    v=store.get(t)
    if not v or v.get('status')!='dispatchable': continue
    if t in live:
        print("SKIP\t%s\tlive runner already (store not yet claimed)"%t); continue
    clash=[h for h in (v.get('holds') or []) if h in held]
    if clash:
        print("SKIP\t%s\t%s"%(t,','.join(clash))); continue
    # unspec is a BLOCKER (operator, 2026-08-25): "If we wonder why such-or-such
    # task is not running, we should be able to reliably see and declare. 'oh,
    # it's unspecified, let's specify now'." A row with no acceptance= in its
    # bundle header has no bar to be judged against, so it is not dispatchable
    # work -- it is work waiting to be specified. Same test watch-fleet uses.
    b=v.get('bundle') or ''
    try: head=open(b).read()[:400]
    except Exception: head=''
    if 'acceptance=' not in head:
        print("UNSPEC\t%s\t%s"%(t,b)); continue
    print("PICK\t%s\t%s"%(t,v.get('bundle') or ''))
    break
PYP
)
  echo "$choice" | grep '^SKIP' | while IFS="$(printf '\t')" read -r _ t f; do
    echo "pop-next: skip $t — held file busy: $f"
  done
  echo "$choice" | grep '^UNSPEC' | while IFS="$(printf '\t')" read -r _ t f; do
    echo "pop-next: skip $t — UNSPEC (no acceptance= in $f); specify it to make it runnable"
  done
  pick=$(echo "$choice" | grep '^PICK' | head -1 | cut -f2)
  [ -z "$pick" ] && { echo "pop-next: no AUTO row is dispatchable right now"; return 3; }
  # ── no ollama-cloud for single-model work (operator, 2026-08-25) ────────
  # "Do not dispatch single model tasks to Ollama. We will soon run out of
  #  Ollama weekly token credits. I would prefer to accumulate comparative
  #  race data than use Ollama models for singular task work."
  # The family name managent knows is `ollama-cloud`; bin/dispatch and
  # fleet_caps call the same family `ollama`. Passing the WRONG name here is
  # silent -- `--exclude ollama` is accepted and ignored, and the popper would
  # go on assigning kimi/glm/minimax while looking configured. Verified live:
  # --exclude ollama-cloud drops all three with "excluded by row (family
  # ollama-cloud)". Local mlx (family `local`) is unaffected and is
  # PROBE-gated anyway; it spends no cloud credit.
  EXCLUDE_FAMILIES="${EXCLUDE_FAMILIES:-ollama-cloud}"

  # ── a pinned model wins over the mechanized draw ────────────────────────
  # A race arm is only a race arm if it runs on the model it is an arm FOR.
  # Race J pins oxalpha / dsflash / dspro / kimi / sonnet / gemini-flash onto
  # T916-T920 and T939; letting `assign` redraw them would silently turn six
  # sealed lanes into six lanes of whatever was cheapest, and the judge would
  # never know. `managent agent <id> <model>` is how a row gets pinned, and
  # the pin also carries kimi past EXCLUDE_FAMILIES on purpose: the operator's
  # rule is no ollama for SINGULAR task work, and comparative race data is the
  # stated exception ("I would prefer to accumulate comparative race data than
  # use Ollama models for singular task work", 2026-08-25).
  model=$(python3 -c "
import json,sys
v=json.load(open('docs/infra/managent/tasks.json')).get('$pick') or {}
print(v.get('model') or '')" 2>/dev/null)
  if [ -n "$model" ]; then
    echo "pop-next: $pick is pinned to $model (not redrawn)"
  else
  # --dry-run must not RECORD an assignment. It did: the first dry run of this
  # script pinned claude-haiku onto T931 as a side effect, because the DRY
  # check sat after the assign call. A preview that mutates the store is not a
  # preview. `assign --dry-run` prints the same choice and writes nothing.
  assign_dry=""; [ "$DRY" = 1 ] && assign_dry="--dry-run"
  model=$(bin/managent assign "$pick" --json --exclude "$EXCLUDE_FAMILIES" $assign_dry 2>/dev/null | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('model') or '')
except Exception: print('')" 2>/dev/null)
  fi
  [ -z "$model" ] && model=dspro
  if [ "$DRY" = 1 ]; then
    echo "pop-next: WOULD dispatch $pick -> $model"
    return 0
  fi
  echo "pop-next: dispatching $pick -> $model"
  bin/dispatch "$pick" "$model" --wall=7200 2>&1 | tail -1
}

# ── the loop runs a FRESH child each tick ────────────────────────────────
# It used to call pop_once in-process. A `--loop 240` therefore ran for hours
# against the copy of this file that `sh` had already parsed, so editing the
# script did nothing to the loop that was running. That is not theoretical:
# on 2026-08-25 the ollama-cloud exclusion above was added while a loop was
# live, and the next pop still drew minimax-m3 -- the operator's instruction
# was in the file and not in the running process. The lane was killed and the
# row reopened.
#
# So the loop is now a supervisor: each tick re-execs this script for exactly
# one pop, which re-reads the file, the queue, and the stop-file every time.
# A single pop (`--loop 1`, the default) still runs in-process -- that is the
# child the supervisor spawns, and it must not recurse.
i=0
while [ "$i" -lt "$LOOPS" ]; do
  if [ "$LOOPS" -eq 1 ]; then
    pop_once || true
  else
    if [ "$DRY" = 1 ]; then sh "$0" --dry-run || true; else sh "$0" || true; fi
  fi
  i=$((i+1))
  [ "$i" -lt "$LOOPS" ] && sleep 60
done
exit 0
