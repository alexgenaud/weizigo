#!/bin/sh
# tools/backlog-table.sh — the daily open-backlog trend.
#
# Operator, 2026-08-25: "I would like to see this again at the end of the day,
# and tomorrow, and every day for the week."
#
# Reads the live store AND the archive, because a retired row was still added
# and still closed — dropping the archive would understate both columns and
# silently flatter the trend.
#
#   --days N   how many days to show (default 7)
set -e
cd "$(dirname "$0")/.." || exit 1
DAYS="${1:-7}"
[ "$DAYS" = "--days" ] && DAYS="${2:-7}"
python3 - "$DAYS" <<'PY'
import json,sys,collections
days=int(sys.argv[1])
rows=[]
for p in ('docs/infra/managent/tasks.json','docs/infra/managent/archive.json'):
    try: d=json.load(open(p))
    except Exception: continue
    rows += [v for k,v in d.items() if isinstance(v,dict) and k!='_sys']
add=collections.Counter(); done=collections.Counter()
for r in rows:
    if r.get('added'): add[r['added'][:10]]+=1
    if r.get('done'):  done[r['done'][:10]]+=1
alldays=sorted(set(list(add)+list(done)))
# open-at-end is cumulative over ALL history, not just the window shown
openn=0; series={}
for d in alldays:
    openn += add[d]-done[d]; series[d]=openn
show=alldays[-days:]
w=("day","added","closed","net","open at end")
print("%-8s %6s %7s %6s %13s" % w)
print("-"*44)
prev=None
for d in show:
    net=add[d]-done[d]
    delta=""
    if prev is not None:
        # deceleration marker: is the net addition smaller than yesterday's?
        delta = "  v" if net < prev else ("  ^" if net > prev else "  =")
    print("%-8s %6d %7d %+6d %13d%s" % (d[5:], add[d], done[d], net, series[d], delta))
    prev=net
print()
print("open at end = every row ever added minus every row ever closed, to that date.")
print("v = net additions fell vs the previous shown day (deceleration), ^ = rose.")
PY
