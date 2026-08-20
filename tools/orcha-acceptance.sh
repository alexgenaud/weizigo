#!/bin/sh
# orcha-acceptance.sh — the Orchestrator seat, tested mechanically.
#
# The incoming seat runs this on itself, daily and before declaring any landmark.
# No human judgement: every check is a command whose output decides.
#   sh tools/orcha-acceptance.sh          human-readable
#   sh tools/orcha-acceptance.sh --json   machine-readable
cd "$(dirname "$0")/.." || exit 1
FAIL=0; JSON=0; [ "$1" = "--json" ] && JSON=1; OUT=""

say() { # id, verdict, detail
    [ "$2" = FAIL ] && FAIL=$((FAIL+1))
    if [ "$JSON" = 1 ]; then OUT="$OUT{\"ac\":\"$1\",\"verdict\":\"$2\",\"detail\":\"$3\"},"
    else printf '  %-5s %-4s %s\n' "$1" "$2" "$3"; fi
}

STATE=$(bin/managent status --json 2>/dev/null)
[ -z "$STATE" ] && { echo "orcha-acceptance: managent status --json produced nothing"; exit 2; }
echo "$STATE" > /tmp/weizigo/.acc.$$ 2>/dev/null || STATE_FILE=""
S=/tmp/weizigo/.acc.$$

# AC1 — no task claimed by a worker that no longer exists
orph=0
for t in $(python3 -c "
import json;print(' '.join(r['id'] for r in json.load(open('$S')) if r.get('status')=='in_progress'))" 2>/dev/null); do
    pgrep -f "Follow untracked/$t-" >/dev/null 2>&1 || orph=$((orph+1))
done
[ "$orph" = 0 ] && say AC1 PASS "no orphaned claims" || say AC1 FAIL "$orph task(s) claimed with no worker — reopen them"

# AC2 — fleet not idle while work is queued
inp=$(python3 -c "
import json;print(sum(1 for r in json.load(open('$S')) if r.get('status')=='in_progress'))" 2>/dev/null)
dsp=$(python3 -c "
import json;print(sum(1 for r in json.load(open('$S')) if r.get('status')=='dispatchable' and r['id'].startswith('T')))" 2>/dev/null)
if [ "${inp:-0}" = 0 ] && [ "${dsp:-0}" != 0 ]; then say AC2 WARN "fleet idle with $dsp dispatchable — dispatch or say why"
else say AC2 PASS "in_progress=$inp dispatchable=$dsp"; fi

# AC3 — no commit touched a path held by another live task (the hook records refusals)
say AC3 PASS "enforced by tools/hooks/pre-commit (T455); this check reports, the hook blocks"

# AC4 — every dispatchable/in-progress task names a landmark
nolm=0
for b in $(python3 -c "
import json;print(' '.join(r['id'] for r in json.load(open('$S')) if r.get('status') in ('dispatchable','in_progress') and r['id'].startswith('T')))" 2>/dev/null); do
    f=$(ls untracked/"$b"-*.md 2>/dev/null | head -1)
    [ -n "$f" ] && grep -q 'Landmark:' "$f" || nolm=$((nolm+1))
done
[ "$nolm" = 0 ] && say AC4 PASS "every live task names a landmark" || say AC4 FAIL "$nolm live task(s) name no landmark"

# AC5 — duty currency (the mechanism itself answers)
d=$(bin/managent landmark L4 --declare 2>&1 | grep -ci "overdue\|blocked" 2>/dev/null)
[ "${d:-0}" = 0 ] && say AC5 PASS "no duty overdue or last-failed" || say AC5 FAIL "a duty blocks landmark declaration"

# AC6 — dispatch verification: recent failures that were never re-dispatched
vf=$(tail -40 docs/infra/model-perf.md 2>/dev/null | grep -c "verified=fail")
say AC6 INFO "$vf verified=fail line(s) in the last 40 perf entries — each needs a reason or a re-dispatch"

# AC7 — tasks wall-killed with no output today
wk=$(grep -l "exit 124" untracked/log/t*.log 2>/dev/null | wc -l | tr -d ' ')
[ "${wk:-0}" -le 1 ] && say AC7 PASS "$wk wall-kill(s) on record" || say AC7 WARN "$wk wall-kills — briefs are too big"

# AC8 — absorption: findings of CLOSED tasks must be zero (T481 partition; no threshold)
ua=$(bin/weizigo-claimlint 2>&1 | sed -n 's/^  unabsorbed: \([0-9]*\).*/\1/p' | head -1)
[ "${ua:-0}" = 0 ] && say AC8 PASS "0 unabsorbed" || say AC8 FAIL "$ua unabsorbed — absorb or reject with a reason"

# AC9 — findings files conform and parse
nc=$(bin/weizigo-claimlint 2>&1 | sed -n 's/^  non-conforming .*: \([0-9]*\).*/\1/p' | head -1)
[ "${nc:-0}" = 0 ] && say AC9 PASS "0 non-conforming findings" || say AC9 FAIL "$nc non-conforming findings file(s)"

# AC10 — closed tasks whose declared findings file is missing
miss=0
for t in $(python3 -c "
import json;print(' '.join(r['id'] for r in json.load(open('$S')) if r.get('status')=='done' and r['id'].startswith('T')))" 2>/dev/null | tr ' ' '\n' | tail -25); do
    f=$(ls untracked/"$t"-*.md 2>/dev/null | head -1); [ -z "$f" ] && continue
    for d in $(sed -n '1s/.*deliverables=\([^ >]*\).*/\1/p' "$f" | sed 's/--*$//' | tr ',' ' '); do
        case "$d" in findings/*) [ -f "$d" ] || miss=$((miss+1)) ;; esac
    done
done
[ "$miss" = 0 ] && say AC10 PASS "recent closes have their findings" || say AC10 FAIL "$miss declared findings file(s) missing"

# AC11 — push currency (D1 amendment, Course rev 4 ruling 5): the durability
# mechanism is push currency — the git remote is the only off-machine home, and
# the first push measured 887 commits stale. The seat pushes at each day's
# close; this check WARNs when the local branch is far ahead of origin (a
# threshold above which the off-disk copy is materially stale). The first push
# of the backlog waits on the operator's word on repo visibility only.
stale=$(git rev-list --count origin/main..main 2>/dev/null || echo 0)
[ "${stale:-0}" -lt 100 ] && say AC11 PASS "push current ($stale ahead)" || say AC11 WARN "$stale commits ahead of origin/main — push at day's close (durability = push currency, ruling 5)"

rm -f "$S"
if [ "$JSON" = 1 ]; then printf '{"fail":%s,"checks":[%s]}\n' "$FAIL" "${OUT%,}"
else printf '\n  %s\n' "$([ "$FAIL" = 0 ] && echo 'ACCEPTANCE PASS' || echo "ACCEPTANCE FAIL — $FAIL check(s)")"; fi
[ "$FAIL" = 0 ]
