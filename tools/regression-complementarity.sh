#!/usr/bin/env bash
# regression-complementarity.sh — controls for tools/complementarity.py (T637).
#
# The complementarity reduction turns race artifacts (per-lane finding sets
# plus a graded reference union) into the standing complementarity record
# T636's panel selection reads: per-lane unique-catch rates, the pairwise
# overlap matrix, and the best-subset-of-size-k table, per (task_type, epoch).
# The brief's four controls are the contract:
#
#   (a) seeded disjoint   lanes A,B with known disjoint finding sets ->
#                         overlap 0, both unique_catch_rate 1.0,
#                         best-subset-of-2 reaches the full union
#   (b) seeded subset     lane B's findings a strict subset of lane A's ->
#                         B's unique_catch_rate 0, best-subset-of-2 does not
#                         pick {A,B}
#   (c) null              a single-lane race -> overlap matrix undefined,
#                         reported as null with a note, never a 1x1 matrix
#                         of 1.0
#   (d) determinism       the same race fed twice -> byte-identical output
#
# These live in the tool's `check` mode (so they run wherever the tool does);
# this script additionally pins the OUT-OF-PROCESS determinism of the real
# committed inputs (tools/complementarity-inputs/race-{a,f}.json), the schema
# surface, and the load-bearing honesty fields (the disclaimer, n, and the
# prior label) on every `zig build test`.  Synthetic fixtures only — the
# tool is read-only; nothing here writes the live repo.
#
# Wired in build.zig (zig build test); see the T503 block for the pattern.

set -u
TOOL="tools/complementarity.py"
IN_A="tools/complementarity-inputs/race-a.json"
IN_F="tools/complementarity-inputs/race-f.json"
WORK="$(mktemp -d /tmp/weizigo/complementarity.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
FAIL=0

echo "=== regression-complementarity ==="
if [ ! -x "$TOOL" ] && ! python3 -c "import ast; ast.parse(open('$TOOL').read())" 2>/dev/null; then
    echo "  FAIL: $TOOL not readable"; exit 1
fi

# 1. the brief's four controls (seeded disjoint, seeded subset, null,
#    determinism) plus schema validation — all inside the tool
echo " 1. tool check mode (the brief's controls)"
if python3 "$TOOL" check > "$WORK/check.out" 2>&1; then
    echo "    PASS: check exits 0"
else
    echo "    FAIL: check exits non-zero"; cat "$WORK/check.out"; FAIL=1
fi
if grep -q "ALL CONTROLS PASSED" "$WORK/check.out"; then
    echo "    PASS: all controls reported passed"
else
    echo "    FAIL: controls did not all pass"; FAIL=1
fi

# 2. committed inputs are valid and reduce cleanly
echo " 2. committed race inputs reduce cleanly"
if python3 "$TOOL" reduce --input "$IN_A" --input "$IN_F" --out "$WORK/record.json" 2>"$WORK/reduce.err"; then
    echo "    PASS: reduce exits 0 on race-a + race-f"
else
    echo "    FAIL: reduce failed"; cat "$WORK/reduce.err"; FAIL=1
fi

# 3. out-of-process determinism: two separate invocations, byte-identical
echo " 3. out-of-process determinism on the real inputs"
python3 "$TOOL" reduce --input "$IN_A" --input "$IN_F" > "$WORK/rec1.json" 2>/dev/null
python3 "$TOOL" reduce --input "$IN_A" --input "$IN_F" > "$WORK/rec2.json" 2>/dev/null
if cmp -s "$WORK/rec1.json" "$WORK/rec2.json"; then
    echo "    PASS: two separate reduce runs are byte-identical"
else
    echo "    FAIL: reduce output differs across runs"; FAIL=1
fi

# 4. honesty fields are present: disclaimer, n, prior label, no clock
echo " 4. honesty fields (disclaimer, n, prior label, no timestamp)"
if grep -q "coverage of the union we found, never of the truth" "$WORK/record.json"; then
    echo "    PASS: disclaimer present"
else
    echo "    FAIL: disclaimer missing"; FAIL=1
fi
if python3 -c "
import json,sys
r = json.load(open('$WORK/record.json'))
for key, g in r['groups'].items():
    assert g['n'] == 26, (key, g['n'])
    assert g['prior_warning'] is True
    assert 'PRIOR' in g['sample_note'] or 'prior' in g['sample_note']
    assert 'rate_definitions' in r
assert r['generated_from'], 'generated_from must name the inputs'
print('    PASS: n=26 per group, prior_warning set, sample_note labels the prior, provenance named')
"; then
    :
else
    echo "    FAIL: honesty fields wrong"; FAIL=1
fi
if grep -qE '"date"|"timestamp"|"clock"' "$WORK/record.json"; then
    echo "    FAIL: record contains a clock field (determinism breach)"; FAIL=1
else
    echo "    PASS: no clock/timestamp field in the record"
fi

# 5. race-f (adjudication) headline: one entrant alone covers the full union
echo " 5. race-f headline (one entrant alone covers the union)"
if python3 -c "
import json
r = json.load(open('$WORK/record.json'))
g = r['groups']['adjudication/2026-08-22']
assert g['best_subsets']['1']['coverage'] == 1.0
assert len(g['best_subsets']['1']['best']) == 3  # entrants 2/3/4 all tie
assert all(p['unique_catches'] == 0 for p in g['per_lane'].values())
print('    PASS: k=1 coverage 1.0 (3 tied entrants), no unique catches')
"; then
    :
else
    echo "    FAIL: race-f headline wrong"; FAIL=1
fi

# 6. race-a (spec-audit) headline: opus alone 17/26; opus+dsflash 21/26
echo " 6. race-a headline (genuine complementarity across auditors)"
if python3 -c "
import json
r = json.load(open('$WORK/record.json'))
g = r['groups']['spec-audit/2026-08-22']
assert g['per_lane']['lane-3']['catches'] == 17
assert g['per_lane']['lane-3']['unique_catches'] == 10
assert g['best_subsets']['2']['coverage'] == round(21/26, 6)
assert g['merges']['merge_decisions'] == 18
assert g['merges']['split_decisions'] == 10
print('    PASS: opus 17/26 (10 unique); best pair 21/26; merges 18/10')
"; then
    :
else
    echo "    FAIL: race-a headline wrong"; FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-complementarity: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-complementarity: FAILURES ==="
    exit 1
fi
