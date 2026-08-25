#!/bin/sh
# tools/audit-arm-check.sh <arm> — acceptance check for one DONE-audit arm.
#
# Checks only what is mechanically checkable: the arm's records.json parses,
# is a non-empty list, every object carries the schema's required fields, and
# every judgement field carries a reason. It cannot check whether a judgement
# is CORRECT — that is T951's job, against the sealed answer key.
set -e
ARM="$1"
[ -z "$ARM" ] && { echo "usage: audit-arm-check.sh <arm>" >&2; exit 2; }
cd "$(dirname "$0")/.." || exit 1
DIR="docs/audits/done-audit-2026-08-25/$ARM"
python3 - "$DIR" <<'PY'
import json,os,sys
d=sys.argv[1]
rp=os.path.join(d,'records.json'); ap=os.path.join(d,'analysis.md')
fail=[]
if not os.path.exists(rp): fail.append("missing %s"%rp)
if not os.path.exists(ap): fail.append("missing %s"%ap)
if fail:
    print("audit-arm-check: FAIL\n  "+"\n  ".join(fail)); sys.exit(1)
try: recs=json.load(open(rp))
except Exception as e:
    print("audit-arm-check: FAIL — records.json does not parse: %s"%e); sys.exit(1)
if not isinstance(recs,list) or not recs:
    print("audit-arm-check: FAIL — records.json is not a non-empty list"); sys.exit(1)
mech=["task_id","model","verdict","deliverables_declared","deliverables_present_in_git",
      "findings_file_exists","acceptance_declared","run_record_exists"]
judg=["work_actually_done","verdict_accurate","absorbed","self_reported_or_verified","useful"]
bad=[]
for i,r in enumerate(recs):
    if not isinstance(r,dict): bad.append("record %d is not an object"%i); continue
    for f in mech+judg:
        if f not in r: bad.append("%s: missing %s"%(r.get('task_id','#%d'%i),f))
    for f in judg:
        rk=f+"_reason"
        if r.get(f) is not None and not (r.get(rk) or "").strip():
            bad.append("%s: %s has no %s"%(r.get('task_id','#%d'%i),f,rk))
if bad:
    print("audit-arm-check: FAIL — %d problem(s)"%len(bad))
    for b in bad[:15]: print("  "+b)
    sys.exit(1)
print("audit-arm-check: PASS — %d records, all required fields present, every judgement reasoned"%len(recs))
PY
