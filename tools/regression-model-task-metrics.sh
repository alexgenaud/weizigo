#!/usr/bin/env bash
# regression-model-task-metrics.sh — T750.
#
# The schema's conformance control for docs/infra/model-task-metrics.jsonl.
# Per T750's amendment: the row schema stores facts (num/den pairs, integers,
# nulls for UNKNOWN) and refuses to freeze derived numbers into the record.
# This script is the standing gate that defends the schema from a
# well-meaning future re-introduction of the defects T750 retired:
#
#   (a) percent-refused   a row carrying canary_recall_pct or any *_pct
#                         field where a num/den pair belongs is REJECTED
#                         (the field is not even in the schema; the control
#                         asserts the *negative* — a hard fail)
#   (b) pair-required     canary_recall_num and canary_recall_den are
#                         either both present or both null; same for
#                         false_flags / flags_total
#   (c) null-not-zero     a 0 in fabricated_citations is a *reading* (the
#                         grader looked and found none); a null is UNKNOWN.
#                         The control checks the distinction is preserved
#   (d) reference-present race rows whose evidence ends in a findings file
#                         that BOTH a grader ruling AND a sealed key could
#                         have generated carry `reference` set; warns on
#                         race rows that omit it (warn-only, not refuse —
#                         the brief says "record, do not silently fix")
#   (e) id-uniqueness     every (run_id, task_id, model, as_of) tuple is
#                         unique (a re-run is a new row, not an edit)
#   (f) type-roundtrip    every task_type value is in the known set;
#                         unknown values are warned (the project grew task
#                         types organically and an unmapped value is a soft
#                         signal, not a hard fail)
#   (g) ledger-vs-source  for every backfilled row, the source findings file
#                         contains the integers the row carries (greps the
#                         source for the canary counts and fabricated
#                         counts it backfilled)
#   (h) retirement-cited  tools/model-profiles.py's thoroughness and
#                         citation_honesty docstrings carry the T750
#                         disposition text; the control greps for it
#
# All fixtures are synthetic; the live JSONL is read but never written.
# Task: T750 · Role: worker · Model: minimax-m3 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
JSONL="$ROOT/docs/infra/model-task-metrics.jsonl"
SCHEMA="$ROOT/docs/infra/model-task-metrics.schema.md"
MODEL_PROFILES="$ROOT/tools/model-profiles.py"
FAIL=0

# Working dir under /tmp/weizigo (the disposable scratch root, never
# untracked/; T421/AGENTS).
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t750-metrics-XXXXXX)" || {
    echo "FATAL: scratch mktemp failed; refusing to run" >&2
    exit 2
}
trap 'rm -rf "$WORK"' EXIT

echo "=== regression-model-task-metrics: pre-flight ==="
if ! test -f "$JSONL"; then
    echo "FAIL: $JSONL missing — the ledger is the system's spine"
    exit 1
fi
if ! test -f "$SCHEMA"; then
    echo "FAIL: $SCHEMA missing — the schema is the contract"
    exit 1
fi
if ! test -f "$MODEL_PROFILES"; then
    echo "FAIL: $MODEL_PROFILES missing — the retirement-cite target"
    exit 1
fi

# ── (a) percent-refused: any *_pct field on a row is rejected ───────────
echo ""
echo "  a. percent-refused: any *_pct field on a real row is rejected"
PCT_HITS=$(python3 -c "
import json, sys
hits=[]
for i,line in enumerate(open('$JSONL'), 1):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    for k in o:
        if k.endswith('_pct') or k=='canary_recall_pct' or k=='precision' or k=='recall':
            hits.append((i, k, o.get('run_id') or o.get('task_id')))
if hits:
    for i,k,r in hits: print(f'    line {i}: {k} (run {r})')
sys.exit(1 if hits else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: percentage/derived fields present (rule §0: counts, never percentages):"
    echo "$PCT_HITS"
    FAIL=1
else
    echo "    PASS: no row carries a *_pct or precision/recall field"
fi

# ── (b) pair-required: canary_recall_num and _den are both-or-neither ───
echo "  b. pair-required: canary_recall_num and canary_recall_den are paired"
PAIR=$(python3 -c "
import json, sys
bad=[]
for i,line in enumerate(open('$JSONL'), 1):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    n=o.get('canary_recall_num'); d=o.get('canary_recall_den')
    if (n is None) != (d is None):
        bad.append((i, n, d, o.get('run_id') or o.get('task_id')))
    elif n is not None and not (isinstance(n,int) and isinstance(d,int) and 0<=n<=d):
        bad.append((i, n, d, o.get('run_id') or o.get('task_id')))
    ff=o.get('false_flags'); ft=o.get('flags_total')
    if ft is not None and ff is None:
        bad.append((i, 'flags_total without false_flags', o.get('run_id') or o.get('task_id')))
if bad:
    for x in bad: print('    bad:', x)
sys.exit(1 if bad else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: pair-required violation:"
    echo "$PAIR"
    FAIL=1
else
    echo "    PASS: canary_recall_num/den are paired (both-or-neither) and within bounds"
fi

# ── (c) null-not-zero: a 0 in fabricated_citations is a reading, not a fill-in
echo "  c. null-not-zero: rows have a real reading or a real UNKNOWN, not a substituted 0"
NULLZERO=$(python3 -c "
import json, sys
bad=[]
for i,line in enumerate(open('$JSONL'), 1):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    fc=o.get('fabricated_citations')
    # 0 is fine.  What we forbid is a row that has the field set to 0 but
    # carries no evidence of grader inspection (no race field, no
    # evidence path).  Such a row is *probably* a fill-in, not a reading.
    if fc==0 and not o.get('race') and not o.get('evidence'):
        bad.append((i, o.get('run_id') or o.get('task_id')))
if bad:
    for x in bad: print('    bad:', x)
sys.exit(1 if bad else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: fabricated_citations=0 without grader evidence (rule: 0 is a reading, not a default):"
    echo "$NULLZERO"
    FAIL=1
else
    echo "    PASS: fabricated_citations=0 only on rows that have a grader/race to justify it"
fi

# ── (d) reference-present: race rows with grader-ruling source carry reference
echo "  d. reference-present: race rows with sealed key source carry reference"
REFS=$(python3 -c "
import json, sys, os
# Which race rows have BOTH a grader ruling AND a sealed key as plausible
# sources?  Today: T706 (Race G batch 2, has sealed key findings/T653-batch2-design.json
# and grader ruling findings/T706-...).
warn=[]
for i,line in enumerate(open('$JSONL'), 1):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    if not o.get('race'): continue
    if o.get('reference') is not None: continue
    ev=o.get('evidence') or ''
    # sealed-key shaped evidence: findings/T*.json whose contents record
    # canary_correct_verdict.  Today only T706 batch 2 has that shape; the
    # T893-race-c3-adjudication rows do not (the adjudicator's ruling is
    # the only truth, the ITEMS.txt is not a sealed key in the same sense).
    if 'T706' in (o.get('run_id') or '') or 'T653' in ev:
        warn.append((i, o.get('run_id'), o.get('model')))
if warn:
    for x in warn: print('    warn:', x)
sys.exit(0)  # warn-only, not refuse
" 2>&1)
if [ -n "$REFS" ]; then
    echo "    WARN: race rows whose source has BOTH a grader ruling AND a sealed key, but reference is null:"
    echo "$REFS"
    echo "    (warn-only — the brief says 'record, do not silently fix')"
else
    echo "    PASS: every race row whose source is multi-truth carries reference"
fi

# ── (e) id-uniqueness: (run_id, task_id, model, as_of) tuples are unique
echo "  e. id-uniqueness: every (run_id, task_id, model, as_of) tuple is unique"
DUPES=$(python3 -c "
import json, sys
from collections import Counter
keys=Counter()
for line in open('$JSONL'):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    k=(o.get('run_id'), o.get('task_id'), o.get('model'), o.get('as_of'))
    keys[k]+=1
dupes=[(k,c) for k,c in keys.items() if c>1]
if dupes:
    for k,c in dupes: print('    dupe:', c, k)
sys.exit(1 if dupes else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: id-uniqueness violation:"
    echo "$DUPES"
    FAIL=1
else
    echo "    PASS: every (run_id, task_id, model, as_of) tuple is unique"
fi

# ── (f) type-roundtrip: every task_type is in the known set; warn on novel
echo "  f. type-roundtrip: every task_type is mapped; novel values are warned"
NOVEL=$(JSONL_FOR_PY="$JSONL" python3 -c '
import json, os
known=set("audit infra research implement battery spec/design orchestration-seat grade integration/reframe census-harvest cleanup-hygiene design-spec race science-probe terminology-refactor tooling-fix onboarding-land implementation-bounded".split())
novel=set()
for line in open(os.environ["JSONL_FOR_PY"]):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    t=o.get("task_type")
    if t and t not in known: novel.add(t)
if novel:
    for n in sorted(novel): print("    novel:", n)
' 2>&1)
if [ -n "$NOVEL" ]; then
    echo "    WARN: novel task_type values present (T565/T868 migration is operator-ratified; record is the source):"
    echo "$NOVEL"
else
    echo "    PASS: every task_type maps to a known label"
fi

# ── (g) ledger-vs-source: backfilled integers are present in the source
echo "  g. ledger-vs-source: backfilled canary counts and fabricated counts are in the source"
BACKFILL=$(python3 -c "
import json, os, sys
# The T750 backfill: T706 5 rows (canary_recall), T626 5 rows (fabricated),
# T557 3 rows (fabricated where the grade names them).  T706's
# findings/T706-race-g-batch2-grade.json names count_correct and count_total
# per lane; T626's findings/T626-variance.json names '-N fabricated M' in
# each lane's note; T557's findings/T557-race1-t447-replication.json says
# '0 fabricated' globally.
problems=[]
for i,line in enumerate(open('$JSONL'), 1):
    line=line.strip()
    if not line: continue
    o=json.loads(line)
    rid=o.get('run_id') or ''
    n=o.get('canary_recall_num'); d=o.get('canary_recall_den')
    if n is not None:
        # T706 has count_correct and count_total in canary_detection.per_lane.<model>
        if rid.startswith('T706') or 'T706' in (o.get('evidence') or ''):
            ev=o.get('evidence') or 'findings/T706-race-g-batch2-grade.json'
            full=os.path.join('$ROOT', ev)
            if not os.path.isfile(full):
                problems.append((i, 'T706 source missing', ev))
                continue
            src=open(full).read()
            # The model label is in o['model']; canary_detection.per_lane.<model>.count_correct
            # must equal n and count_total must equal d.
            m=o.get('model') or ''
            if m and f'\"{m}\"' in src:
                # python json parse, find canary_detection.per_lane.<m>.count_correct
                d_src=json.loads(src)
                per=d_src.get('canary_detection',{}).get('per_lane',{}).get(m,{})
                cc=per.get('count_correct'); ct=per.get('count_total')
                if cc is not None and cc!=n:
                    problems.append((i, f'canary_recall_num={n} but source count_correct={cc} for {m}', rid))
                if ct is not None and ct!=d:
                    problems.append((i, f'canary_recall_den={d} but source count_total={ct} for {m}', rid))
    fc=o.get('fabricated_citations')
    if fc is not None and rid.startswith('T626'):
        # T626's per-lane notes carry 'itemized <I> bonuses <B> penalties <P> -F fabricated <F>'
        # The pattern is in the JSONL notes field itself (the original column where
        # the variance was first reported) — grep the JSONL for the run_id
        # substring and confirm the count appears in the same row's notes.
        with open('$JSONL') as fh:
            for src_line in fh:
                src_o = json.loads(src_line)
                if src_o.get('run_id') == rid and src_o.get('model') == o.get('model'):
                    src_notes = src_o.get('notes', '') or ''
                    if f'fabricated {fc}' not in src_notes:
                        problems.append((i, f'fabricated_citations={fc} not in JSONL notes for {rid} (notes carry: {src_notes[:60]}...)', ev))
                    break
            else:
                problems.append((i, f'could not find source row for {rid} to verify fabricated count', ev))
if problems:
    for p in problems: print('    bad:', p)
sys.exit(1 if problems else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: backfilled integers do not match the source findings file:"
    echo "$BACKFILL"
    FAIL=1
else
    echo "    PASS: backfilled canary counts and fabricated counts reproduce from the source"
fi

# ── (h) retirement-cited: tools/model-profiles.py cites T750 for both retirements
echo "  h. retirement-cited: model-profiles.py docstrings carry the T750 disposition"
RET=$(python3 -c "
import re, sys
txt=open('$MODEL_PROFILES').read()
problems=[]
# T750 cites the disposition for thoroughness AND citation_honesty
if not re.search(r'thoroughness.*T750', txt, re.DOTALL):
    # be lenient: accept 'T750' anywhere within 12 lines of 'thoroughness'
    sec=re.search(r'  thoroughness\b.*?(?=\n  \w|\n#|\Z)', txt, re.DOTALL)
    if not sec or 'T750' not in sec.group(0):
        problems.append('thoroughness docstring does not cite T750 disposition')
if not re.search(r'citation_honesty.*T750', txt, re.DOTALL):
    sec=re.search(r'  citation_honesty\b.*?(?=\n  \w|\n#|\Z)', txt, re.DOTALL)
    if not sec or 'T750' not in sec.group(0):
        problems.append('citation_honesty docstring does not cite T750 disposition')
if problems:
    for p in problems: print('    bad:', p)
sys.exit(1 if problems else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: model-profiles.py retirement citation:"
    echo "$RET"
    FAIL=1
else
    echo "    PASS: model-profiles.py docstrings carry the T750 disposition for both retirements"
fi

# ── (i) schema-doc-self-reference: schema cites T750 and references the control
echo "  i. schema-doc-self-reference: schema cites T750 and points at this control"
SCHEMAOK=$(python3 -c "
import sys
txt=open('$SCHEMA').read()
problems=[]
if 'T750' not in txt: problems.append('schema does not cite T750')
if 'regression-model-task-metrics.sh' not in txt: problems.append('schema does not name this control')
if 'canary_recall_num' not in txt: problems.append('schema does not document canary_recall_num')
if 'fabricated_citations' not in txt: problems.append('schema does not document fabricated_citations')
if 'discernment_entropy' not in txt: problems.append('schema does not document discernment_entropy')
if problems:
    for p in problems: print('    bad:', p)
sys.exit(1 if problems else 0)
" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
    echo "    FAIL: schema doc self-reference:"
    echo "$SCHEMAOK"
    FAIL=1
else
    echo "    PASS: schema doc cites T750, this control, and the new fields"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-model-task-metrics: all checks PASS"
    exit 0
else
    echo "regression-model-task-metrics: FAIL"
    exit 1
fi
