#!/bin/sh
# tools/model-matrix.sh — the model x task-type coverage matrix.
#
# Which model has done how much of which KIND of work. The point is the empty
# cells: a model with no data for a task type is an untested hypothesis, and
# every allocation belief we hold is one of those until a cell says otherwise.
#
# Reads the live store AND the archive. Counts only closed rows carrying a
# model. `·` is zero, and zero is the interesting value.
#
#   --min N   only show models with at least N closed rows (default 0)
set -e
cd "$(dirname "$0")/.." || exit 1
python3 - "${2:-0}" <<'PY'
import json,collections,sys
minn=int(sys.argv[1])
rows=[]
for p in ('docs/infra/managent/tasks.json','docs/infra/managent/archive.json'):
    try: d=json.load(open(p))
    except Exception: continue
    rows += [v for k,v in d.items() if isinstance(v,dict) and k!='_sys']
done=[r for r in rows if r.get('status')=='done' and r.get('model')]
cell=collections.Counter((r['model'], r.get('task_type') or 'UNKNOWN') for r in done)
tot=collections.Counter(r['model'] for r in done)
models=[m for m in sorted(tot) if tot[m]>=minn]
types=sorted({ty for _,ty in cell})
filled=sum(1 for m in models for ty in types if cell.get((m,ty)))
print("closed rows with a model: %d   cells filled: %d of %d" % (len(done), filled, len(models)*len(types)))
print()
w=max(len(m) for m in models)+1
hdr=" "*w
for ty in types: hdr += "%-7s" % ty[:6]
print(hdr+"  total")
for m in models:
    line = m.ljust(w)
    for ty in types:
        n=cell.get((m,ty),0)
        line += "%-7s" % (n if n else '·')
    print(line + "  %d" % tot[m])
print()
empt=[(m,ty) for m in models for ty in types if not cell.get((m,ty)) and ty!='UNKNOWN']
print("empty cells: %d" % len(empt))
byt=collections.Counter(ty for _,ty in empt)
print("emptiest task types: " + ", ".join("%s(%d)"%(k,v) for k,v in byt.most_common(5)))
PY
