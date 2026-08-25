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
    print("PICK\t%s\t%s"%(t,v.get('bundle') or ''))
    break
PYP
)
  echo "$choice" | grep '^SKIP' | while IFS="$(printf '\t')" read -r _ t f; do
    echo "pop-next: skip $t — held file busy: $f"
  done
  pick=$(echo "$choice" | grep '^PICK' | head -1 | cut -f2)
  [ -z "$pick" ] && { echo "pop-next: no AUTO row is dispatchable right now"; return 3; }
  model=$(bin/managent assign "$pick" --json 2>/dev/null | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('model') or '')
except Exception: print('')" 2>/dev/null)
  [ -z "$model" ] && model=dspro
  if [ "$DRY" = 1 ]; then
    echo "pop-next: WOULD dispatch $pick -> $model"
    return 0
  fi
  echo "pop-next: dispatching $pick -> $model"
  bin/dispatch "$pick" "$model" --wall=7200 2>&1 | tail -1
}

i=0
while [ "$i" -lt "$LOOPS" ]; do
  pop_once || true
  i=$((i+1))
  [ "$i" -lt "$LOOPS" ] && sleep 60
done
exit 0
