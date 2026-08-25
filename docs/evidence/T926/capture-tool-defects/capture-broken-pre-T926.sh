#!/bin/sh
# Pre-T926 broken version: under-reports RSS, drops killed rows, trusts regime arg
set -e
ROWS=$1; COLS=$2; REGIME=$3; TASK=$4; shift 4
[ "$1" = "--" ] && shift
LEDGER=${WEIZIGO_SCALING_LEDGER:-docs/infra/host/goban-scaling.jsonl}
OUT=$(mktemp -t goban-scaling); SAMP=$(mktemp -t goban-rss)
START=$(date +%s)
CAFF=0
if command -v caffeinate >/dev/null 2>&1; then CAFF=1; fi
"$@" > "$OUT" 2>&1 &
CMDPID=$!
if [ "$CAFF" = 1 ]; then
  caffeinate -i -w $CMDPID >/dev/null 2>&1 &
else
  :
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
       "start_epoch":num(start),
       "sleep_prevented": bool(int(caff)),
       "sleeps_during_run": sleeps}
with open(ledger,'a') as f: f.write(json.dumps(row,sort_keys=True)+"\n")
print("goban-scaling: %sx%s %s wall=%ss peak=%sMB rc=%s sleep_prevented=%s sleeps=%s -> %s"%(r,c,regime,wall,peak,rc,row["sleep_prevented"],sleeps,ledger))
PY
cat "$OUT"; rm -f "$OUT" "$SAMP"
exit $RC
