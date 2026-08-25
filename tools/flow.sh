#!/bin/sh
# tools/flow.sh — arrival vs completion, and the queue depth that follows.
#
# Called the FLOW TABLE, not a burndown: a burndown assumes the queue only
# falls. This one is honest in both directions and stays correctly named when
# the backlog grows, which is what it has been doing.
#
# Operator, 2026-08-25: "I would like to see this again at the end of the day,
# and tomorrow, and every day for the week."
#
# Reads the live store AND the archive, because a retired row was still added
# and still closed — dropping the archive would understate both columns and
# silently flatter the trend.
#
#   --days N    daily rows, N days (default 7)
#   --blocks    four-hour blocks for today (00-04, 04-08, 08-12, 12-16, 16-20, 20-24)
#   --blocks N  four-hour blocks for the last N days
set -e
cd "$(dirname "$0")/.." || exit 1
MODE=days; DAYS=7
case "$1" in
  --blocks) MODE=blocks; DAYS="${2:-1}" ;;
  --days)   DAYS="${2:-7}" ;;
  [0-9]*)   DAYS="$1" ;;
esac
python3 - "$MODE" "$DAYS" <<'PY'
import json,sys,collections
mode=sys.argv[1]; days=int(sys.argv[2])
rows=[]
for p in ('docs/infra/managent/tasks.json','docs/infra/managent/archive.json'):
    try: d=json.load(open(p))
    except Exception: continue
    rows += [v for k,v in d.items() if isinstance(v,dict) and k!='_sys']
add=collections.Counter(); done=collections.Counter()
for r in rows:
    if r.get('added'): add[r['added'][:10]]+=1
    if r.get('done'):  done[r['done'][:10]]+=1
if mode=='blocks':
    # re-key by (date, four-hour block) instead of by date
    add=collections.Counter(); done=collections.Counter()
    def blk(ts):
        return ts[:10]+" "+"%02d-%02d" % ((int(ts[11:13])//4)*4, (int(ts[11:13])//4)*4+4)
    for r in rows:
        if r.get('added'): add[blk(r['added'])]+=1
        if r.get('done'):  done[blk(r['done'])]+=1
    days=days*6   # six blocks per day
alldays=sorted(set(list(add)+list(done)))
# open-at-end is cumulative over ALL history, not just the window shown
openn=0; series={}
for d in alldays:
    openn += add[d]-done[d]; series[d]=openn
show=alldays[-days:]
w=(("day" if mode=="days" else "block"),"added","closed","net","open at end")
print("%-14s %6s %7s %6s %13s" % w)
print("-"*50)
prev=None
for d in show:
    net=add[d]-done[d]
    delta=""
    if prev is not None:
        # deceleration marker: is the net addition smaller than yesterday's?
        delta = "  v" if net < prev else ("  ^" if net > prev else "  =")
    label = d[5:] if mode=='days' else d[5:]
    print("%-14s %6d %7d %+6d %13d%s" % (label, add[d], done[d], net, series[d], delta))
    prev=net
print()
print("open at end = every row ever added minus every row ever closed, to that date.")
print("v = net additions fell vs the previous shown day (deceleration), ^ = rose.")
PY
