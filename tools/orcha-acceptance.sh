#!/bin/sh
# orcha-acceptance.sh — the Orchestrator seat, tested mechanically.
#
# The incoming seat runs this on itself, daily and before declaring any landmark.
# No human judgement: every check is a command whose output decides.
#   sh tools/orcha-acceptance.sh          human-readable
#   sh tools/orcha-acceptance.sh --json   machine-readable
#
# Verdict contract (T537 — the summary line tells the truth; a WARN no longer
# hides, and a gauge that only ever goes up is no longer labelled "today"):
#   every check PASS   ->  ACCEPTANCE PASS                      exit 0
#   >=1 FAIL           ->  ACCEPTANCE FAIL — N check(s) ...     exit 1
#   no FAIL, >=1 WARN  ->  ACCEPTANCE PASS WITH N WARNING(S)…   exit 2
#   (a pre-check hard error — no status snapshot — exits 2 with no ACCEPTANCE
#    line; the operator reads the last line, so no line can be a lie)
# The warning/failure ids are always on the summary line.
#
# Env overrides (the regression sets these; the seat never does):
#   ORCHA_ROOT        project root (default: this script's parent dir)
#   ORCHA_STATUS      path to a `managent status --json` snapshot (default: run it)
#   ORCHA_MANAGENT    managent binary for AC5 (default bin/managent)
#   ORCHA_CLAIMLINT   path to a `weizigo-claimlint` text snapshot (default: run it)
#   ORCHA_NOW         epoch seconds used as AC7's "now" (test determinism)
#   ORCHA_AC7_WINDOW  AC7 window in seconds (default 86400 = 24 h)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -n "${ORCHA_ROOT:-}" ] && ROOT="$(cd "$ORCHA_ROOT" 2>/dev/null && pwd)"
cd "$ROOT" || exit 1

FAIL=0; WARN=0; JSON=0
[ "$1" = "--json" ] && JSON=1
OUT=""
FAILIDS=""; WARNIDS=""

mkdir -p /tmp/weizigo 2>/dev/null
S="$(mktemp /tmp/weizigo/.acc.XXXXXX 2>/dev/null)" || S=/tmp/weizigo/.acc.$$
trap 'rm -f "$S"' EXIT

esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

say() { # id, verdict, detail
    case "$2" in
        FAIL) FAIL=$((FAIL+1)); FAILIDS="$FAILIDS $1" ;;
        WARN) WARN=$((WARN+1)); WARNIDS="$WARNIDS $1" ;;
    esac
    if [ "$JSON" = 1 ]; then
        OUT="$OUT{\"ac\":\"$1\",\"verdict\":\"$2\",\"detail\":\"$(esc "$3")\"},"
    else
        printf '  %-5s %-4s %s\n' "$1" "$2" "$3"
    fi
}

# ── state snapshot ─────────────────────────────────────────────────────
if [ -n "${ORCHA_STATUS:-}" ]; then
    STATE=$(cat "$ORCHA_STATUS" 2>/dev/null)
else
    STATE=$(bin/managent status --json 2>/dev/null)
fi
[ -z "$STATE" ] && { echo "orcha-acceptance: no status snapshot (managent status --json produced nothing)" >&2; exit 2; }
printf '%s\n' "$STATE" > "$S"

# ── claimlint snapshot ─────────────────────────────────────────────────
if [ -n "${ORCHA_CLAIMLINT:-}" ]; then
    CL=$(cat "$ORCHA_CLAIMLINT" 2>/dev/null)
else
    CL=$(bin/weizigo-claimlint 2>&1)
fi

MGM="${ORCHA_MANAGENT:-bin/managent}"

# AC1 — no task claimed by a worker that no longer exists
orph=0
for t in $(python3 -c "
import json;print(' '.join(r['id'] for r in json.load(open('$S')) if r.get('status')=='in_progress'))" 2>/dev/null); do
    pgrep -f "Follow untracked/$t-" >/dev/null 2>&1 || orph=$((orph+1))
done
[ "$orph" = 0 ] && say AC1 PASS "no orphaned claims" || say AC1 FAIL "$orph task(s) claimed with no worker — reopen them"

# AC2 — fleet not idle while work is queued. T537: WARN -> FAIL — the handover
# names "fleet idle" the seat's recurring failure and the keeper exists to
# dispatch, so idle-with-queued is a broken fleet, not a warning.
inp=$(python3 -c "
import json;print(sum(1 for r in json.load(open('$S')) if r.get('status')=='in_progress'))" 2>/dev/null)
dsp=$(python3 -c "
import json;print(sum(1 for r in json.load(open('$S')) if r.get('status')=='dispatchable' and r['id'].startswith('T')))" 2>/dev/null)
if [ "${inp:-0}" = 0 ] && [ "${dsp:-0}" != 0 ]; then say AC2 FAIL "fleet idle with $dsp dispatchable — dispatch or say why"
else say AC2 PASS "in_progress=$inp dispatchable=$dsp"; fi

# AC3 removed (T872 green-up): it was an unconditional PASS. The T455
# holder-collision refusal it pointed at is really covered by
# regression-precommit.sh and regression-git-commit-mine-hook.sh. The
# remaining checks keep their original ids (AC4..AC11) so the T537
# regression (which filters AC6/AC7 by exact id) stays green.

# AC4 — every dispatchable/in-progress task names a landmark
nolm=0
for b in $(python3 -c "
import json;print(' '.join(r['id'] for r in json.load(open('$S')) if r.get('status') in ('dispatchable','in_progress') and r['id'].startswith('T')))" 2>/dev/null); do
    f=$(ls untracked/"$b"-*.md 2>/dev/null | head -1)
    [ -n "$f" ] && grep -q 'Landmark:' "$f" || nolm=$((nolm+1))
done
[ "$nolm" = 0 ] && say AC4 PASS "every live task names a landmark" || say AC4 FAIL "$nolm live task(s) name no landmark"

# AC5 — duty currency (the mechanism itself answers)
d=$("$MGM" landmark L4 --declare 2>&1 | grep -ci "overdue\|blocked" 2>/dev/null)
[ "${d:-0}" = 0 ] && say AC5 PASS "no duty overdue or last-failed" || say AC5 FAIL "a duty blocks landmark declaration"

# AC6 — dispatch verification: recent failures that were never re-dispatched.
# T537: INFO -> WARN. A non-zero count must surface (it now blocks a clean PASS)
# because each line needs a reason or a re-dispatch (handover §3). NOT FAIL: the
# check measures presence, not unexplained-ness — the ledger line may itself be
# the explanation — and FAIL-on-presence needs the operator's ruling.
# T629/Ruling 32: a verified=fail line carrying killed_by != none is a
# GUARD-KILLED row — present and labeled censored, never scored.  AC6 counts
# only the uncensored (killed_by absent or none) failures and prints the
# censored skip count next to the figure.
perf40=$(tail -40 docs/infra/model-perf.md 2>/dev/null)
CENSORED_RX='killed_by=(provider-limit|provider-auth|provider-connection|directive|wall|cpu|rss|liveness|watchdog|harness-error)'
vf=$(printf '%s\n' "$perf40" | grep "verified=fail" | grep -Ev "$CENSORED_RX" | grep -c . || true)
cens=$(printf '%s\n' "$perf40" | grep "verified=fail" | grep -Ec "$CENSORED_RX" || true)
cens=${cens:-0}
if [ "${vf:-0}" = 0 ]; then say AC6 PASS "0 verified=fail in the last 40 perf entries ($cens censored, skipped)"
else say AC6 WARN "$vf verified=fail line(s) in the last 40 perf entries ($cens censored, skipped) — each needs a reason or a re-dispatch"; fi

# AC7 — tasks wall-killed in the last 24 h. T537: was a cumulative-ever counter
# (grep -l "exit 124" over every t*.log the project ever produced), which was
# monotonic — it could never return to PASS and the number described history,
# not today. Now: a 24 h rolling window over run records (untracked/runs/*.json),
# whose `killed` field carries the kill reason directly (T520). Bar: <=1/day
# (handover §3, "wall-kills ≤1/day"). Over the bar is a FAIL.
now=${ORCHA_NOW:-$(date +%s)}
win=${ORCHA_AC7_WINDOW:-86400}
cutoff=$((now - win))
wk=$(python3 - "$cutoff" <<'PY'
import json, os, sys, datetime
cutoff = int(sys.argv[1])
d = "untracked/runs"
n = 0
if os.path.isdir(d):
    for f in os.listdir(d):
        if not f.endswith(".json"):
            continue
        p = os.path.join(d, f)
        try:
            r = json.load(open(p))
        except Exception:
            continue
        killed = (r.get("killed") or "")
        if "wall" not in killed.lower() and r.get("exit") != 124:
            continue
        end = r.get("end") or ""
        ts = 0
        if end:
            try:
                ts = int(datetime.datetime.fromisoformat(end.replace("Z", "+00:00")).timestamp())
            except Exception:
                ts = 0
        if ts == 0:
            try:
                ts = int(os.path.getmtime(p))
            except Exception:
                ts = 0
        if ts >= cutoff:
            n += 1
print(n)
PY
)
wk=${wk:-0}
if [ "${wk:-0}" -le 1 ]; then say AC7 PASS "$wk wall-kill(s) in the last 24 h (run records; bar <=1/day)"
else say AC7 FAIL "$wk wall-kills in the last 24 h (bar <=1/day) — briefs are too big"; fi

# AC8 — absorption: findings of CLOSED tasks must be zero (T481 partition; no threshold)
ua=$(printf '%s\n' "$CL" | sed -n 's/^  unabsorbed: \([0-9]*\).*/\1/p' | head -1)
[ "${ua:-0}" = 0 ] && say AC8 PASS "0 unabsorbed" || say AC8 FAIL "$ua unabsorbed — absorb or reject with a reason"

# AC9 — findings files conform and parse
nc=$(printf '%s\n' "$CL" | sed -n 's/^  non-conforming .*: \([0-9]*\).*/\1/p' | head -1)
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

# AC11 — push currency (D1 amendment, Course rev 5 ruling 5): the durability
# mechanism is push currency — the git remote is the only off-machine home, and
# the first push measured 887 commits stale (now archived to
# origin/archive/pre-squash-2026-08-20). The daily-close push goes to the
# archive branch until Stage 4 lands a cleaned main. Count commits on no
# remote ref: origin/main is deliberately stale until Stage 4's squash, so the
# yardstick is commits not reachable from ANY remote (rev-list --not
# --remotes=origin). A threshold above which the off-disk copy is materially
# stale = WARN (a gauge — it returns to PASS when the daily push lands, so the
# WARN is honest, not a monotonic counter).
stale=$(git rev-list --count main --not --remotes=origin 2>/dev/null || echo 0)
[ "${stale:-0}" -lt 100 ] && say AC11 PASS "push current ($stale unpushed)" || say AC11 WARN "$stale commits unpushed — daily close pushes to origin/archive/pre-squash-2026-08-20 until Stage 4 (durability = push currency, ruling 5)"

# ── summary ────────────────────────────────────────────────────────────
failids=$(printf '%s' "$FAILIDS" | sed 's/^ *//; s/ *$//' | tr ' ' ',')
warnids=$(printf '%s' "$WARNIDS" | sed 's/^ *//; s/ *$//' | tr ' ' ',')

if [ "$FAIL" -gt 0 ]; then
    line="ACCEPTANCE FAIL — $FAIL check(s) — $failids"
    [ "$WARN" -gt 0 ] && line="$line ; WARN — $warnids"
    exitcode=1
elif [ "$WARN" -gt 0 ]; then
    line="ACCEPTANCE PASS WITH $WARN WARNING(S) — $warnids"
    exitcode=2
else
    line="ACCEPTANCE PASS"
    exitcode=0
fi

if [ "$JSON" = 1 ]; then
    printf '{"fail":%s,"warn":%s,"summary":"%s","exit":%s,"checks":[%s]}\n' \
        "$FAIL" "$WARN" "$(esc "$line")" "$exitcode" "${OUT%,}"
else
    printf '\n  %s\n' "$line"
fi
exit "$exitcode"
