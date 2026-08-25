#!/bin/sh
# goban-scaling-capture.sh — append one measured row per goban solve to
# docs/infra/host/goban-scaling.jsonl.  Wraps the solve; never estimates.
#
# Usage: tools/goban-scaling-capture.sh <rows> <cols> <regime> <task> -- <command...>
#   regime: writes-off | memo-reuse | deps-guarded | history-exact
#
# Fields are MEASURED or absent.  A field we could not read is null, never a
# guess — the register has 85 PROSE-ONLY rows because guesses were written
# down as facts.  `nodes` is null unless the command prints `nodes=<n>`.
set -e
ROWS=$1; COLS=$2; REGIME=$3; TASK=$4; shift 4
[ "$1" = "--" ] && shift
LEDGER=docs/infra/host/goban-scaling.jsonl
OUT=$(mktemp -t goban-scaling); SAMP=$(mktemp -t goban-rss)
START=$(date +%s)
# T927: hold an idle-sleep assertion for the solve's lifetime so the wall
# figure cannot cross a host sleep. caffeinate -i -w $CMDPID auto-releases
# when the solve exits; a sidecar, so RSS polling still reads the solve.
CAFF=0
if command -v caffeinate >/dev/null 2>&1; then CAFF=1; fi
"$@" > "$OUT" 2>&1 &
CMDPID=$!
if [ "$CAFF" = 1 ]; then
  caffeinate -i -w $CMDPID >/dev/null 2>&1 &
else
  : # sleep guard unavailable (non-darwin); recorded as sleep_prevented=false
fi
PEAK=0
while kill -0 $CMDPID 2>/dev/null; do
  R=$(ps -axo pid=,rss= | awk -v p=$CMDPID '$1==p{print int($2/1024)}')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] 2>/dev/null && PEAK=$R
  echo "$R" >> "$SAMP"
  sleep 1
done
wait $CMDPID; RC=$?
END=$(date +%s)
WALL=$(( END - START ))
NODES=$(grep -oE 'nodes=[0-9]+' "$OUT" | tail -1 | cut -d= -f2)
ART=$(ls -l artifacts/oracle-${ROWS}x${COLS}.wzo 2>/dev/null | awk '{print $5}')
python3 - "$ROWS" "$COLS" "$REGIME" "$TASK" "$WALL" "$PEAK" "$RC" "${NODES:-}" "${ART:-}" "$LEDGER" "$CAFF" "$START" "$END" <<'PY'
import sys, json, subprocess
from datetime import datetime
r,c,regime,task,wall,peak,rc,nodes,art,ledger,caff,start,end = sys.argv[1:14]
def num(x):
    try: return int(x)
    except: return None
head = subprocess.run(['git','rev-parse','--short','HEAD'],capture_output=True,text=True).stdout.strip() or None
# T927: count "Entering Sleep" entries from pmset whose timestamp falls in
# [start, end]. None when pmset is unavailable (cannot measure = cannot count).
sleeps = None
try:
    pm = subprocess.run(['pmset','-g','log'],capture_output=True,text=True,timeout=3.0)
    if pm.returncode == 0:
        s, e = int(start), int(end)
        n = 0; saw = False
        for line in pm.stdout.splitlines():
            if 'Entering Sleep' not in line: continue
            saw = True
            parts = line.split(None, 3)
            if len(parts) < 3: continue
            try: dt = datetime.strptime(' '.join(parts[:3]), '%Y-%m-%d %H:%M:%S %z')
            except ValueError: continue
            ep = int(dt.timestamp())
            if s <= ep <= e: n += 1
        sleeps = n if saw else None
except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
    sleeps = None
row = {"rows":int(r),"cols":int(c),"points":int(r)*int(c),"regime":regime,"task":task,
       "wall_s":num(wall),"peak_rss_mb":num(peak),"exit":num(rc),
       "nodes":num(nodes),"artifact_bytes":num(art),"head":head,
       "host":{"cores":18,"ram_gb":48},"measured":True,
       # T927: idle-sleep prevention for the run. sleep_prevented is whether
       # the caffeinate assertion was held; sleeps_during_run is the count
       # of host sleeps in the window (null when pmset is unavailable).
       "start_epoch":num(start),
       "sleep_prevented": bool(int(caff)),
       "sleeps_during_run": sleeps}
with open(ledger,'a') as f: f.write(json.dumps(row,sort_keys=True)+"\n")
print("goban-scaling: %sx%s %s wall=%ss peak=%sMB rc=%s sleep_prevented=%s sleeps=%s -> %s"%(r,c,regime,wall,peak,rc,row["sleep_prevented"],sleeps,ledger))
PY
cat "$OUT"; rm -f "$OUT" "$SAMP"
exit $RC
