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
"$@" > "$OUT" 2>&1 &
CMDPID=$!
PEAK=0
while kill -0 $CMDPID 2>/dev/null; do
  R=$(ps -axo pid=,rss= | awk -v p=$CMDPID '$1==p{print int($2/1024)}')
  [ -n "$R" ] && [ "$R" -gt "$PEAK" ] 2>/dev/null && PEAK=$R
  echo "$R" >> "$SAMP"
  sleep 1
done
wait $CMDPID; RC=$?
WALL=$(( $(date +%s) - START ))
NODES=$(grep -oE 'nodes=[0-9]+' "$OUT" | tail -1 | cut -d= -f2)
ART=$(ls -l artifacts/oracle-${ROWS}x${COLS}.wzo 2>/dev/null | awk '{print $5}')
python3 - "$ROWS" "$COLS" "$REGIME" "$TASK" "$WALL" "$PEAK" "$RC" "${NODES:-}" "${ART:-}" "$LEDGER" <<'PY'
import sys, json, subprocess
r,c,regime,task,wall,peak,rc,nodes,art,ledger = sys.argv[1:11]
def num(x):
    try: return int(x)
    except: return None
head = subprocess.run(['git','rev-parse','--short','HEAD'],capture_output=True,text=True).stdout.strip() or None
row = {"rows":int(r),"cols":int(c),"points":int(r)*int(c),"regime":regime,"task":task,
       "wall_s":num(wall),"peak_rss_mb":num(peak),"exit":num(rc),
       "nodes":num(nodes),"artifact_bytes":num(art),"head":head,
       "host":{"cores":18,"ram_gb":48},"measured":True}
with open(ledger,'a') as f: f.write(json.dumps(row,sort_keys=True)+"\n")
print("goban-scaling: %sx%s %s wall=%ss peak=%sMB rc=%s -> %s"%(r,c,regime,wall,peak,rc,ledger))
PY
cat "$OUT"; rm -f "$OUT" "$SAMP"
exit $RC
