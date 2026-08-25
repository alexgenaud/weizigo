#!/bin/sh
# Fleet view — operator console. Nothing reads this. Read-only. Refresh 10 s.
# Time: a colon is always an INSTANT (14:52:01); durations never contain one (4h28, 19'48, 12.345).
# Times column (T591): every row type carries an HH:MM at the same column as PROGRESS's elapsed —
#   CONCERNS = first seen (persists in $CONC_STATE across restarts), RECENT = the lane trailer's
#   mtime (last kill/resolve, 24 h window), DONE = the store's `done` field (shown local, like the
#   header and RECENT mtimes).
# Layout: PROGRESS, CONCERNS (current) and RECENT (resolved/killed) always show every row.
# DONE and OPEN show at least MIN_ROWS each (when they have that much data), expand into
# whatever height is left, and never exceed MAX_ROWS. T738: no banner header, and a
# section with zero rows prints NOTHING — no heading, no "(none)". T823: no "(more: N)"
# line either — the operator does not want it and the row is worth more as task data, so
# a truncated section simply shows fewer rows (its reserve is gone with its output).
# Columns (T823): PROGRESS is task, landmark, model-from-argv, elapsed, RATE (output
# tokens per wall second — not CPU), FRESH (age of the transcript's last write —
# the liveness signal, T839); CONCERNS is task, landmark, label, first-seen,
# HOLDER (the store's `agent`, never the brief's text), description.
# MAX_ROWS raised 20 -> 200 (T804): with exact fill the 50/50 split already bounds
# each flexible section at ~ROWS/2, so the cap only guards a pathological store
# (thousands of DONE rows on a giant terminal) — and a 20 cap left terminals
# taller than ~45 rows unfilled, the same blank-at-the-bottom family this file
# keeps fixing (T739 spare, T799 blank, T804 reserve/print mismatch, T823
# "(more)" reserve deleted with its line).
MAX_ROWS=200
MIN_ROWS=4
# Refresh escalates: every 10 s for the first minute, every minute for the first hour, hourly after.
# Any keypress refreshes immediately AND resets the escalation (T492); q or ^D quits; ^C quits.
#
# Schedule helpers (T492): nap_for_age maps seconds-since-START to the nap,
# reset_schedule restarts the escalation (called on any non-quit keypress).
# Self-contained and defined early so a regression harness can source them
# alone via WATCH_FLEET_SOURCE=1 (mirrors the HEAD contract's guard).
nap_for_age() {  # $1 = seconds since schedule start -> 10 | 60 | 3600
    [ -n "$1" ] && [ "$1" -ge 0 ] 2>/dev/null || return 1
    if   [ "$1" -lt 60 ];   then echo 10
    elif [ "$1" -lt 3600 ]; then echo 60
    else                        echo 3600; fi; }
reset_schedule() {  # restart the escalation: START := now
    START=$(date +%s); }
# Output tokens per wall second (T823) — the fifth PROGRESS column. It replaced
# `ps -o time= | awk -F: '{print $NF}'`, which kept only the LAST colon-separated
# field of cumulative CPU time: a real 1:20.93 rendered as 20.93, so 80.9 s
# displayed as 20.9 and two rows were not comparable. A correct CPU number would
# still be the wrong metric — these are API-driven workers whose measured CPU
# utilisation is 6.9% (T817), 9.7% (T801), 8.1% (T808), so ~92% of elapsed is
# spent waiting on the provider and local CPU tracks how a model chose to search,
# not how much work it did. Output tokens per wall second is the rate we do have.
# Missing reading or no elapsed yet -> UNKNOWN: never 0 (a 0 asserts the worker
# produced nothing) and never a stale value (see the meter join below).
# The "/s" suffix is the label: this column is a RATE, and nobody can read
# 103.6/s as CPU seconds. One decimal below 1000/s (real rates are 60-150),
# none at or above, so any plausible value fits the 8-char slot — a number is
# never truncated to fit a column, which is the exact defect this replaced.
rate_of() {  # $1 = tokens_out ('' = no reading)  $2 = elapsed wall seconds -> "N.N/s" | UNKNOWN
    case "${1:-x}" in ''|*[!0-9]*) echo UNKNOWN; return ;; esac
    case "${2:-x}" in ''|*[!0-9]*) echo UNKNOWN; return ;; esac
    [ "$2" -gt 0 ] || { echo UNKNOWN; return; }
    awk -v n="$1" -v s="$2" 'BEGIN{r=n/s; printf (r<1000 ? "%.1f/s" : "%.0f/s"), r}'; }
# Freshness of a live transcript (T839) — the SIXTH PROGRESS column, next to
# the rate. Both harnesses append a transcript while the run is in flight (pi
# at untracked/tokens/sessions/<task>.<ts>.<pid>.<n>.jsonl, claude under
# $WEIZIGO_CLAUDE_TRANSCRIPT_DIR), so the age of the transcript's last write
# is the liveness signal the completion-time ledger cannot give: it is the
# number that would have shown qwen/T824 alive while its log sat at 2,951
# bytes for 33 minutes. The meter join (below) emits the transcript file's
# mtime; this renders it as an age, right-aligned into a 5-char slot.
# Buckets: seconds under a minute, minutes up to the 15-min heal horizon,
# STALE across the 15-min-to-1h band (the ambiguity window the heal uses),
# hours up to a day, days beyond. STALE is a verdict, not an age — it is
# what the operator must act on; past an hour the age itself is the honest
# signal and a bare STALE would shout at every long-lived lane.
freshness_of() {  # $1 = mtime (epoch s) -> "N(s|m|h|d)" | "STALE" | "-"
    case "${1:-x}" in ''|*[!0-9]*) printf '%s' '-'; return ;; esac
    [ "$1" -gt 0 ] || { printf '%s' '-'; return; }
    now=$(date +%s)
    age=$(( now - $1 ))
    [ "$age" -lt 0 ] && age=0
    if   [ "$age" -lt 60 ];    then printf '%2ds' "$age"
    elif [ "$age" -le 900 ];   then printf '%2dm' "$((age/60))"
    elif [ "$age" -le 3600 ];  then printf 'STALE'
    elif [ "$age" -lt 86400 ]; then printf '%2dh' "$((age/3600))"
    else                            printf '%2dd' "$((age/86400))"
    fi; }
if [ "${WATCH_FLEET_SOURCE:-0}" = "1" ]; then
    return 2>/dev/null || exit 0
fi
START=$(date +%s)

cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd); T=/tmp/weizigo/.fleet.$$; mkdir -p /tmp/weizigo
CONC_STATE=${FLEET_CONC_STATE:-/tmp/weizigo/fleet-concerns.tsv}   # CONCERNS first-seen, survives restarts (T591)
STTY_SAVE=""; [ -t 0 ] && STTY_SAVE=$(stty -g < /dev/tty 2>/dev/null)
[ -n "$STTY_SAVE" ] && stty -echo < /dev/tty 2>/dev/null      # keys never echo, even mid-redraw
CLEANED=0
cleanup() { [ "$CLEANED" = 1 ] && return; CLEANED=1   # idempotent: q/^C/TERM/HUP call cleanup, then the EXIT trap calls it again
            rm -f "$T".* 2>/dev/null
            [ -t 1 ] && { printf '\n'; printf '\033[?25h'; }   # T799: fresh prompt line, then restore the cursor (the tput cnorm sequence)
            [ -n "$STTY_SAVE" ] && stty "$STTY_SAVE" < /dev/tty 2>/dev/null; }
trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT      # ^C quits, immediately
trap 'cleanup; exit 143' TERM                  # kill quits, immediately
trap 'cleanup; exit 0'  HUP                     # HUP quits, immediately (cleanup prints the exit newline)

dur() { echo "$1" | awk -F: '{if(NF==3)printf"%dh%02d",$1,$2; else if(NF==2)printf"%d'\''%02d",$1,$2; else print $1}'; }
# Short model names (T739): the single mapping is the "Short names → canonical"
# table in docs/infra/model-registry.md — watch-fleet holds no second mapping.
# A worker's argv can carry the short name (the --dsflash startup alias), a
# canonical label (--model deepseek-v4-flash) or a serving tag (--model
# glm-5.2:cloud, stealth/ox-alpha); a model string matches a row when it
# equals, prefixes, or is prefixed by the row's short/canonical/serving-tag.
# Unknown models fall back to the pre-colon prefix (a rendering fallback, not
# a map).
mdl() { awk -F'|' -v m="$1" '
        /^\| *`[a-zA-Z0-9]+` *\|/ {
            short=$2; canon=$3; tag=$4
            gsub(/[` ]/,"",short); gsub(/[` ]/,"",canon); gsub(/[` ]/,"",tag)
            if (m != "" && (m == short || index(canon,m)==1 || index(m,canon)==1 \
                || (tag != "" && tag != "—" && (index(tag,m)==1 || index(m,tag)==1)))) { print short; found=1; exit }
        }
        END { if (!found) { sub(/:.*/,"",m); print m } }' docs/infra/model-registry.md; }
mflag() { # $1 = argv; model = the --model arg, else the --dsflash/--dspro startup alias (T591)
    m=$(echo "$1" | sed -n 's/.*--model \([^ ]*\).*/\1/p' | head -1)
    [ -n "$m" ] && { printf '%s' "$m"; return; }
    case "$1" in *--dsflash*) printf 'dsflash';; *--dspro*) printf 'dspro';; esac; }
desc() { d=$(awk -F'\t' -v t="$1" '$1==t{print $2}' untracked/task-desc.tsv 2>/dev/null)
         b=$(ls untracked/"$1"-*.md 2>/dev/null | head -1)          # one brief, never a glob of several
         [ -z "$d" ] && [ -n "$b" ] && d=$(sed -n '2s/^# *//p' "$b" | sed 's/^T[0-9]* *//;s/^(\([^)]*\)).*/\1/;s/^— *//')
         [ -z "$d" ] && [ -n "$b" ] && d=$(basename "$b" .md | sed "s/^$1-//;s/-/ /g")
         [ -z "$d" ] && d="(no brief on disk)"
         printf '%s' "$d" | tr -s ' \t' ' ' | sed 's/ *$//'; }
# The HOLDER is the store's `agent`, never the brief's text (T823): T771
# rendered as "orchestration oversight seat (fable)" while its agent field said
# claude-opus-5 — the seat was handed over and the brief was written for the
# previous holder. desc() is stale by design (it describes WHAT the task is);
# the WHO can only come from the store. Rendered through mdl() so it is a short
# name from the one registry table; no agent -> "-", never an invented one.
holder() { a=$(awk -F'\t' -v t="$1" '$1==t{print $2; exit}' "$T.agent" 2>/dev/null)
           [ -z "$a" ] && { printf '%s' '-'; return; }
           mdl "$a"; }
lm()   { grep -ho 'L[0-9]' untracked/"$1"-*.md 2>/dev/null | head -1; }
ctag() { awk -F'\t' -v k="$1" '$1==k{print $2; exit}' untracked/concern-tags.tsv 2>/dev/null; }
fit()  { cut -c1-"$COLS"; }                      # every row trimmed to the terminal width
show() { # $1 file  $2 slots — print up to $2 rows; T823: no "(more: N)" trailer
    # The operator's ruling: "(more: 187)" cost a row and told him nothing he
    # wanted. The line AND its reserve are gone together — T804 had already
    # found the reservation and the print condition disagreeing, so deleting
    # one without the other is how that family of blank-at-the-bottom bugs
    # recurs. A truncated section now just shows fewer rows.
    tot=$(grep -c . "$1" 2>/dev/null); [ -z "$tot" ] && tot=0
    [ "$tot" = 0 ] && { printf ' (none)\n'; return; }
    printf '\n'; head -n "$2" "$1"; }

ONESHOT=0; [ -t 1 ] || ONESHOT=1        # piped or redirected: draw once, exit, hand the shell back
[ -t 1 ] && printf '\033[?25l'          # T799: hide the cursor while the watcher runs; cleanup restores it (the tput civis sequence)
while true; do
    SZ=""; [ -r /dev/tty ] && SZ=$( (stty size < /dev/tty) 2>/dev/null )
    ROWS=${FLEET_LINES:-$(echo "$SZ" | cut -d' ' -f1)}; COLS=${FLEET_COLS:-$(echo "$SZ" | cut -d' ' -f2)}
    [ -z "$ROWS" ] && ROWS=40; [ -z "$COLS" ] && COLS=100

    bin/managent status --json 2>/dev/null > "$T.list" || echo '[]' > "$T.list"
    python3 - "$T.list" docs/infra/managent/tasks.json > "$T.json" <<'PYX'
import json,sys
auth={r['id']:r for r in json.load(open(sys.argv[1])) if isinstance(r,dict) and 'id' in r}
try: raw=json.load(open(sys.argv[2]))
except Exception: raw={}
# `managent status --json` carries neither `agent` nor `claimed`; both come
# from the store (T823 needs agent for the holder column and claimed to date
# the meter's readings).
for k,r in auth.items():
    src=raw.get(k) or {}
    r['done']=src.get('done','')
    r['agent']=src.get('agent') or ''
    r['claimed']=src.get('claimed') or ''
json.dump(auth,open(1,'w'))
PYX
    bin/managent liveness 2>/dev/null > "$T.liveness" || : > "$T.liveness"
    # T908: live worker task ids, collected ONCE per frame before the meter
    # join so the reading set (want below) covers every PROGRESS row. The row
    # list (live processes) and the reading set must share one source of
    # truth: a row shown in PROGRESS must always have its transcript read, or
    # be shown with a stated reason — never a bare UNKNOWN that means “I was
    # not asked”. The T786 incident: store status `done` while the worker was
    # still alive and writing 170k readable tokens; the reading set was
    # store-in_progress only, so the closed-but-alive row was listed by the
    # process scan but never read, and the rate column said UNKNOWN about a
    # lane that had the most readable data of any in the fleet. The per-row
    # PROGRESS loop below re-runs the same scan for the per-process fields;
    # the duplication is deliberate (collecting ids early for the meter join
    # without disturbing the per-row loop the existing arms pin).
    : > "$T.live"
    for p in $(pgrep -f "Follow untracked/T[0-9]+" 2>/dev/null); do
        cmd=$(ps -o command= -p "$p" 2>/dev/null)
        case "$cmd" in
            sh*"$0"|bash*"$0"|*" /bin/sh "*"$0"*) continue ;;
        esac
        t=$(echo "$cmd" | sed -n 's/.*Follow untracked\/\(T[0-9]*\).*/\1/p' | head -1)
        [ -z "$t" ] && continue
        printf '%s\n' "$t" >> "$T.live"
    done
    # Meter join (T823 + T839): task -> its latest output-token reading, and
    # task -> its holder. A reading written BEFORE the task's current claim
    # belongs to a previous run of the same id, so it is dropped rather than
    # divided by this run's elapsed — that is the "never a stale value" half
    # of the rule; the "never 0" half is rate_of's. T839 adds a SECOND source:
    # the in-flight transcript. tokens.jsonl is written at completion, so a
    # running task has no ledger reading and rendered UNKNOWN forever; the
    # transcript (pi session jsonl under untracked/tokens/sessions/<task>.*,
    # claude under $WEIZIGO_CLAUDE_TRANSCRIPT_DIR/<task>.*) is appended
    # continuously and carries the SAME number the completion ledger will
    # eventually record — summed per-turn usage.output across assistant turns
    # (verified: T533's transcript sum 49956 == its ledger tokens_out 49956).
    # The ledger wins when both are post-claim; the transcript's file mtime
    # is emitted unconditionally so the freshness column shows the liveness
    # even when the rate itself is UNKNOWN (transcript present, no usage yet
    # — never 0). Staleness for the transcript is NOT the claim date: a
    # worker claims AFTER pi launches (the bundle's first instruction), so a
    # live run's session start routinely PRECEDES its claim (T822: session
    # 06:44:25Z, claim 07:12:03Z — the same file, one run). The row instead
    # correlates the session start against the PROCESS start (field 4 vs
    # now-esec) and drops a file that began more than 2 min before the
    # process — that shape only exists for a previous run's leftover.
    # Output shape: <task> \t <tokens|''> \t <mtime|''> \t <session-start|''>.
    python3 - "$T.json" untracked/tokens/tokens.jsonl untracked/tokens/sessions "${WEIZIGO_CLAUDE_TRANSCRIPT_DIR:-}" "$T.live" "$T.agent" "$T.status" > "$T.tok" <<'PYT'
import json,sys,os,re,time,calendar
try: store=json.load(open(sys.argv[1]))
except Exception: store={}
def epo(s):
    if not s: return 0
    try: return int(calendar.timegm(time.strptime(s[:19],'%Y-%m-%dT%H:%M:%S')))
    except Exception: return 0
# completion-time ledger: task -> (ts, tokens); pre-claim readings belong to
# a previous run of the same id and are dropped (the T823 rule).
led={}
try: fh=open(sys.argv[2])
except Exception: fh=[]
for line in fh:
    line=line.strip()
    if not line: continue
    try: r=json.loads(line)
    except Exception: continue
    t=r.get('task'); n=r.get('tokens_out'); ts=r.get('ts') or ''
    if not t or n is None: continue
    claimed=(store.get(t) or {}).get('claimed') or ''
    if claimed and ts and ts < claimed: continue      # a previous run of this id
    prev=led.get(t)
    if prev is None or ts >= prev[0]: led[t]=(ts,n)
# in-flight transcripts: newest file per in_progress task. No claim filter
# here — a live run's session legitimately starts before its claim; the
# process-correlation drop happens per row where the process start is known.
def read_tx(path):
    toks=0; start=0
    try: fh=open(path,errors='replace')
    except Exception: return 0,0
    with fh:
        for line in fh:
            line=line.strip()
            if not line: continue
            try: d=json.loads(line)
            except Exception: continue
            if not isinstance(d,dict): continue
            tt=d.get('type')
            if tt=='session' and not start and isinstance(d.get('timestamp'),str):
                start=epo(d.get('timestamp') or '')
            elif tt=='message' and isinstance(d.get('message'),dict):
                m=d.get('message')
                if m.get('role')=='assistant' and isinstance(m.get('usage'),dict):
                    toks += int(m.get('usage').get('output') or 0)
            elif tt in ('summary','compaction') and isinstance(d.get('usage'),dict):
                toks += int(d.get('usage').get('output') or 0)
            elif isinstance(d.get('output_tokens'),(int,float)):  # claude envelope
                toks += int(d['output_tokens'])
    return toks,start
fresh={}; tx={}; ss={}
# T908: the reading set is store-in_progress UNION the live process set, so
# every PROGRESS row (a live process) has its transcript read — the row list
# and the reading set share one source. A closed-but-alive row (store `done`,
# process alive — the T786 incident) is therefore read for freshness (the
# worker IS still writing, which is the incident signal); the PROGRESS loop
# renders its rate as the stated reason `closed` rather than a number, so the
# rate column never fabricates a live-progress figure for a run the store has
# closed. The store status drives rate-vs-reason; the process scan drives
# listed-vs-hidden.
live=set()
try:
    for line in open(sys.argv[5]):
        line=line.strip()
        if line: live.add(line)
except Exception: pass
want={t for t,v in store.items() if (v or {}).get('status')=='in_progress'} | live
for base in (sys.argv[3],sys.argv[4] or ''):
    if not base or not os.path.isdir(base): continue
    try: names=os.listdir(base)
    except Exception: continue
    groups={}
    for name in names:
        mm=re.match(r'^(T\d+)\.',name)
        if not mm: continue
        t=mm.group(1)
        if t in want: groups.setdefault(t,[]).append(os.path.join(base,name))
    for t,paths in groups.items():
        newest=None; nmt=0
        for p in paths:
            try: st=os.stat(p)
            except Exception: continue
            if int(st.st_mtime) > nmt: newest,nmt=p,int(st.st_mtime)
        if newest is None: continue
        toks,start=read_tx(newest)
        fresh[t]=nmt
        if start>0: ss[t]=start
        if toks>0: tx[t]=toks
with open(sys.argv[6],'w') as f:
    for t,v in store.items():
        a=(v or {}).get('agent') or ''
        if a: f.write('%s\t%s\n' % (t,a))
with open(sys.argv[7],'w') as f:   # T908: task -> store status, for rate-vs-reason
    for t,v in store.items():
        st=(v or {}).get('status') or ''
        if st: f.write('%s\t%s\n' % (t,st))
for t in sorted(set(led) | set(fresh)):
    n=led[t][1] if t in led else (tx.get(t,'') if t in tx else '')
    print('%s\t%s\t%s\t%s' % (t,n,fresh.get(t,''),ss.get(t,'')))
PYT

    : > "$T.prog"; : > "$T.conc"; : > "$T.recent"; : > "$T.done"; : > "$T.open"

    # Detect live workers by the brief path in their argv, not by provider:
    # deepseek chains are subagent -> runner -> pi (the pi child's argv is
    # bare "pi"); ollama carries "ollama launch pi"; claude carries "claude -p".
    # The one thing every chain shares is the runner/subagent argv containing
    # "Follow untracked/T<id>-*.md". Match that, skip only the fleet script's
    # own process, and dedupe by task id (a chain yields several matches).
    for p in $(pgrep -f "Follow untracked/T[0-9]+" 2>/dev/null); do
        cmd=$(ps -o command= -p "$p" 2>/dev/null)
        # Skip only the fleet script's OWN process (argv IS the script
        # invocation). A mere mention of watch-fleet.sh in an argv is not the
        # script — T493's own worker argv lists the deliverable path and must
        # not be hidden.
        case "$cmd" in
            sh*"$0"|bash*"$0"|*" /bin/sh "*"$0"*) continue ;;
        esac
        t=$(echo "$cmd" | sed -n 's/.*Follow untracked\/\(T[0-9]*\).*/\1/p' | head -1)
        [ -z "$t" ] && continue
        printf '%s\n' "$t" >> "$T.prog.ids"
    done
    sort -u "$T.prog.ids" 2>/dev/null | while read -r t; do
        p=$(pgrep -f "Follow untracked/$t-" 2>/dev/null | sort -n | tail -1)
        [ -z "$p" ] && continue
        cmd=$(ps -o command= -p "$p" 2>/dev/null)
        [ "$(lsof -a -p "$p" -d cwd -Fn 2>/dev/null|grep '^n'|cut -c2-)" = "$REPO" ] || continue
        esec=$(ps -o etime= -p $p 2>/dev/null | tr -d ' ' | awk -F'[-:]' '
            {if(NF==4) print $1*86400+$2*3600+$3*60+$4;
             else if(NF==3) print $1*3600+$2*60+$3;
             else if(NF==2) print $1*60+$2; else print 0}')
        case "$esec" in ''|*[!0-9]*) esec=0 ;; esac
        # T839: rate from the in-flight transcript (field 2), dropped when
        # the transcript's session STARTED more than 2 min before the process
        # (a previous run's leftover — its tokens divided by this run's
        # elapsed would be the stale reading the rule forbids); freshness
        # (field 3) is the age of the transcript's last write, from the file
        # mtime. Rate (col 30-37, 8 wide) then freshness (right-aligned 5
        # wide, unit letters line up; STALE fills the slot exactly so no row
        # pushes the description — no jitter as ages cross bucket boundaries).
        tok=$(awk -F'\t' -v k="$t" '$1==k{print $2; exit}' "$T.tok" 2>/dev/null)
        mt=$(awk -F'\t' -v k="$t" '$1==k{print $3; exit}' "$T.tok" 2>/dev/null)
        ss=$(awk -F'\t' -v k="$t" '$1==k{print $4; exit}' "$T.tok" 2>/dev/null)
        pstart=$(( $(date +%s) - esec ))
        if [ -n "$ss" ] && [ "$ss" -gt 0 ] 2>/dev/null && \
           [ $(( ss + 120 )) -lt "$pstart" ] 2>/dev/null; then
            tok=""; mt=""                  # a previous run's transcript: not this run's rate OR liveness
        fi
        # T908: a live process whose store row is NOT in_progress is the
        # closed-but-alive state (the T786 incident: worker closed its own
        # row and kept working). The reading set already opened its
        # transcript (want = in_progress ∪ live), so freshness shows the
        # worker is still writing — the incident signal. The rate column
        # renders the stated reason `closed` instead of a number, because the
        # store says this run is over and quoting its tokens/s as live
        # progress would be the fabricated figure the S11 contract forbids.
        # `closed` is neither a bare blank nor a number; it surfaces the
        # disagreement between the two sources instead of hiding it as
        # UNKNOWN. rate_of's “never 0” still holds for in_progress rows.
        st=$(awk -F'\t' -v k="$t" '$1==k{print $2; exit}' "$T.status" 2>/dev/null)
        if [ -n "$st" ] && [ "$st" != "in_progress" ]; then
            rate_disp="closed"
        else
            rate_disp=$(rate_of "$tok" "$esec")
        fi
        printf '%010d\t  %-5s %-3s %-8s  %-6s %-8s %5s %s\n' "$esec" "$t" "$(lm "$t")" \
            "$(mdl "$(mflag "$cmd")")" \
            "$(dur "$(ps -o etime= -p $p|tr -d ' ')")" \
            "$rate_disp" \
            "$(freshness_of "$mt")" \
            "$(desc "$t")" >> "$T.prog.raw"
    done
    rm -f "$T.prog.ids"

    sort -rn "$T.prog.raw" 2>/dev/null | cut -f2- | fit > "$T.prog"; rm -f "$T.prog.raw"

    : > "$T.conc.raw"
    for t in $(python3 -c "
import json;d=json.load(open('$T.json'))
o=[((v.get('claimed') or ''),k) for k,v in d.items() if v.get('status')=='in_progress']
print(' '.join(k for _,k in sorted(o,reverse=True)))" 2>/dev/null); do
        pgrep -f "Follow untracked/$t-" >/dev/null 2>&1 && continue
        grep -q "    $t  \[beating\]" "$T.liveness" 2>/dev/null && continue
        lbl=$(ctag "$t")
        if [ -z "$lbl" ]; then
            case "$(desc "$t")" in
                *seat*|*owner*|*owns*|*successor*|*console*|*orchestrator*) lbl="console";;
                *)  # T839: never accuse work that is alive or finished. A
                    # transcript written within the last 15 min (the heal
                    # horizon) proves the console is healthy even when pgrep
                    # cannot see it (qwen/T824: 573 KB across 25 bash calls,
                    # killed as "produced no output since launch"); a run
                    # record with a clean exit proves the lane COMPLETED
                    # (T818: 12 of 12 chunks committed, failed only the nonce
                    # echo — calling that orphaned trained the reader to
                    # ignore the section). Only a genuinely dead, unclosed
                    # task is an orphan.
                    m=$(awk -F'\t' -v k="$t" '$1==k{print $3; exit}' "$T.tok" 2>/dev/null)
                    if [ -n "$m" ] && [ "$m" -gt 0 ] 2>/dev/null && \
                       [ $(( $(date +%s) - m )) -le 900 ] 2>/dev/null; then
                        lbl="lived"
                    elif [ -f "untracked/runs/$t.json" ] && \
                         grep -Eq '"exit": ?0' "untracked/runs/$t.json" 2>/dev/null; then
                        lbl="finished"
                    else
                        lbl="orphaned"
                    fi;;
            esac
        fi
        printf '%s\t%s\n' "$t" "$lbl" >> "$T.conc.raw"
    done
    # CONCERNS time = first seen. State persists across refreshes AND restarts
    # (CONC_STATE); a concern that clears and reappears gets a fresh first-seen.
    python3 - "$T.conc.raw" "$CONC_STATE" > "$T.conc.rows" <<'PY'
import sys,os,time
cur=[]
for line in open(sys.argv[1]):
    t,lbl=line.rstrip('\n').split('\t',1)
    cur.append((t,lbl))
now=str(int(time.time()))
old={}
if os.path.exists(sys.argv[2]):
    for line in open(sys.argv[2]):
        k,v=line.rstrip('\n').split('\t',1)
        if any(k==t for t,_ in cur): old[k]=v
out=[]
for t,lbl in cur:
    fs=old.get(t,now); old[t]=fs
    try: tm=time.strftime('%H:%M',time.localtime(int(fs)))
    except Exception: tm='--:--'
    out.append('%s\t%s\t%s' % (t,lbl,tm))
with open(sys.argv[2],'w') as f:
    for x in out:
        t,_,_=x.split('\t'); f.write('%s\t%s\n' % (t,old[t]))
print('\n'.join(out))
PY
    while IFS=$(printf '\t') read -r t lbl tm; do
        [ -z "$t" ] && continue
        printf '  %-5s %-3s %-8s  %-6s %-8s %s\n' "$t" "$(lm "$t")" "$lbl" "$tm" "$(holder "$t")" "$(desc "$t")" | fit >> "$T.conc"
    done < "$T.conc.rows"
    for f in untracked/bakeoff/*/*/out.md; do
        [ -f "$f" ] && [ ! -s "$f" ] || continue
        d=$(dirname "$f")
        [ -f "$d/trailer.log" ] || continue
        # RECENT only: age out killed lanes whose trailer is older than 24 h
        # (HH:MM is unambiguous within a day)
        [ -z "$(find "$d/trailer.log" -mtime -1 2>/dev/null)" ] && continue
        grep -qa "exit 12[0-9]" "$d/trailer.log" 2>/dev/null || continue
        tm=$(date -r "$d/trailer.log" +%H:%M 2>/dev/null); [ -z "$tm" ] && tm="--:--"
        printf '  %-5s %-3s %-8s  %-6s %s\n' "race" "" "killed" "$tm" "lane $(basename "$d")" | fit >> "$T.recent"
    done

    # DONE rows: completed time (store `done`, UTC ISO -> local HH:MM) + verdict
    python3 - "$T.json" "$MAX_ROWS" > "$T.done.rows" <<'PY'
import json,sys,time,calendar
d=json.load(open(sys.argv[1]))
rows=[((v.get('done') or ''),k) for k,v in d.items() if v.get('status')=='done']
rows.sort(reverse=True)
def hm(ts):
    if not ts: return '--:--'
    try:
        utc=time.strptime(ts[:19],'%Y-%m-%dT%H:%M:%S')
        return time.strftime('%H:%M',time.localtime(calendar.timegm(utc)))
    except Exception: return '--:--'
for done,k in rows[:int(sys.argv[2])]:
    v=(d.get(k) or {}).get('verdict','') or '?'
    if v=='pass-with-findings': v='findings'
    elif v=='fail-found': v='fail'
    print('%s\t%s\t%s' % (k,v,hm(done)))
PY
    while IFS=$(printf '\t') read -r t v tm; do
        [ -z "$t" ] && continue
        printf '  %-5s %-3s %-9s %-6s %s\n' "$t" "$(lm "$t")" "$v" "$tm" "$(desc "$t")" | fit >> "$T.done"
    done < "$T.done.rows"
    python3 - "$T.json" > "$T.openstat" <<'PYS'
import json,sys,os,re
d=json.load(open(sys.argv[1]))
try:
    seg=open('docs/status/backlog-2026-08-19.md').read().split('## DO NOW')[1].split('##')[0]
    donow=set(re.findall(r'\bT\d+\b', seg))
except Exception: donow=set()
for k,v in d.items():
    if v.get('status')!='dispatchable': continue
    needs=[n for n in (v.get('needs') or []) if (d.get(n) or {}).get('status')!='done']
    import glob
    br=glob.glob(f'untracked/{k}-*.md')
    if needs:                       st='dep-wait'
    elif not br:                    st='no-brief'
    elif 'acceptance=' not in open(br[0]).read()[:400]: st='unspec'
    elif k in donow:                st='next'
    else:                           st='low-prio'
    print(f'{k}\t{st}')
PYS

    for t in $(python3 -c "
import json;d=json.load(open('$T.json'))
import re,os
disp=[k for k,v in d.items() if v.get('status')=='dispatchable' and k.startswith('T')]
prio=[]
try:
    b=open('docs/status/backlog-2026-08-19.md').read()
    seg=b.split('## DO NOW')[1].split('##')[0]
    prio=[m for m in re.findall(r'\bT\d+\b', seg)]
except Exception: pass
head=[k for k in prio if k in disp]
tail=sorted([k for k in disp if k not in head], key=lambda x:int(x[1:]))
print(' '.join((head+tail)[:$MAX_ROWS]))" 2>/dev/null); do
        st=$(awk -F'\t' -v t="$t" '$1==t{print $2}' "$T.openstat" 2>/dev/null)
        printf '  %-5s %-3s %-8s  %s\n' "$t" "$(lm "$t")" "${st:-open}" "$(desc "$t")" | fit >> "$T.open"
    done

    np=$(grep -c . "$T.prog" 2>/dev/null); nc=$(grep -c . "$T.conc" 2>/dev/null); nr=$(grep -c . "$T.recent" 2>/dev/null)
    nd=$(grep -c . "$T.done" 2>/dev/null); no=$(grep -c . "$T.open" 2>/dev/null)
    for v in np nc nr nd no; do eval "[ -z \"\$$v\" ] && $v=0"; done
    # T739/T799/T804/T823: reserve exactly what the frame prints — k headings
    # + (k-1) separators, 1 blank above the footer (T804, restored: the footer
    # is a separator from the data) and the 1-line footer. Nothing else: T823
    # deleted the "(more: N)" line, so there is no "(more)" row to reserve
    # either. T799 dropped the footer's leading blank and trailing newline, so
    # T739's "+1 spare" is gone: it existed to park the trailing-newline
    # cursor row, which no longer exists. The footer is the terminal's last
    # line and needs no spare to stay on screen (arm K pins 35 rows / 38
    # one-shot lines vs T804's 33/38, T799's 34/39, T739's 32/37).
    # Every version of this bug has been the same bug: a reserve constant that
    # no longer matched what the frame prints. T804's instance was a reserve
    # that charged a "(more)" row when nd/no > MIN_ROWS while show() printed
    # it on tot > slots, which needed a settle loop to resolve (the split
    # depended on the reserve and the reserve on the split). With the line
    # gone that circularity is gone with it: the reserve is a constant, the
    # split is one pass, and each section is floored at MIN_ROWS but never
    # given more than it holds. Invariant, pinned by arm N at three heights
    # and two section mixes: printed lines == ROWS exactly for data-rich
    # frames.
    k=$(( (np>0) + (nc>0) + (nr>0) + (nd>0) + (no>0) ))
    base=$(( 2*k - 1 + 2 ))                 # headings+seps, blank above footer, footer
    capd=$nd; capo=$no
    [ "$capd" -gt "$MAX_ROWS" ] && capd=$MAX_ROWS
    [ "$capo" -gt "$MAX_ROWS" ] && capo=$MAX_ROWS
    avail=$(( ROWS - base - np - nc - nr ))
    [ "$avail" -lt 0 ] && avail=0
    ds=0; os=0
    [ "$capd" -ge "$MIN_ROWS" ] && ds=$MIN_ROWS   # floors: MIN_ROWS each,
    [ "$capo" -ge "$MIN_ROWS" ] && os=$MIN_ROWS   # never more than the section holds
    rem=$(( avail - ds - os )); [ "$rem" -lt 0 ] && rem=0
    ds=$(( ds + rem / 2 )); os=$(( os + rem - rem / 2 ))
    [ "$ds" -gt "$capd" ] && { os=$(( os + ds - capd )); ds=$capd; }
    [ "$os" -gt "$capo" ] && { ds=$(( ds + os - capo )); os=$capo; }
    [ "$ds" -gt "$capd" ] && ds=$capd   # both over: excess is unprintable data, let it go
    [ "$os" -gt "$capo" ] && os=$capo

    # T738: clear only on a real terminal — in one-shot/pipe mode the ESC
    # sequence would land on the same line as the first heading and break
    # line-anchored parsing of the frame (banner used to absorb it).
    [ -t 1 ] && clear
    # T738: a section with zero rows prints nothing — no heading, no "(none)";
    # a blank line separates sections only when a section actually follows.
    # `%b` (not `%s`) so sep='\n' renders as a newline, not two literal chars.
    sep=""
    [ "$np" -gt 0 ] && { printf '%bPROGRESS\n' "$sep"; cat "$T.prog"; sep='\n'; }
    [ "$nc" -gt 0 ] && { printf '%bCONCERNS\n' "$sep"; cat "$T.conc"; sep='\n'; }
    [ "$nr" -gt 0 ] && { printf '%bRECENT\n' "$sep"; cat "$T.recent"; sep='\n'; }
    [ "$nd" -gt 0 ] && { printf '%bDONE' "$sep"; show "$T.done" "$ds"; sep='\n'; }
    [ "$no" -gt 0 ] && { printf '%bOPEN' "$sep"; show "$T.open" "$os"; sep='\n'; }
    [ "$ONESHOT" = 1 ] && { cleanup; exit 0; }

    # how long have we been watching? refresh rate follows that, not the clock
    age=$(( $(date +%s) - START ))
    nap=$(nap_for_age "$age")
    # T799/T804: the footer is the terminal's last line — no trailing newline
    # (which parked the visible cursor on the line below); the leading blank
    # (restored by T804) separates the footer from the data. The reserve above
    # counts the blank line, so the frame still fills the terminal exactly.
    printf '\n  %s · q or ^C quits · another key to refresh %ss' "$(date '+%H:%M:%S')" "$nap"

    # macOS ships bash 3.2, whose `read -t` returns 1 on TIMEOUT — the same status as EOF.
    # A timeout and a ^D are therefore indistinguishable here, so ^D cannot be a quit key
    # without the refresh killing the program. ^C (trapped) and `q` are the quit paths.
    if [ -t 0 ]; then          # stdin is a real terminal: wait on a key, not on the clock
        if read -t "$nap" -n 1 -r -s key < /dev/tty 2>/dev/null; then
            case "$key" in q|Q) cleanup; exit 0 ;; esac
            reset_schedule         # any other key: refresh now AND restart the escalation (T492)
        fi                                           # non-zero: timeout — redraw
    else
        sleep "$nap"
    fi
done
cleanup
