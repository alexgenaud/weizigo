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
# section with zero rows prints NOTHING — no heading, no "(none)".
MAX_ROWS=20
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
if [ "${WATCH_FLEET_SOURCE:-0}" = "1" ]; then
    return 2>/dev/null || exit 0
fi
START=$(date +%s)

cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd); T=/tmp/weizigo/.fleet.$$; mkdir -p /tmp/weizigo
CONC_STATE=${FLEET_CONC_STATE:-/tmp/weizigo/fleet-concerns.tsv}   # CONCERNS first-seen, survives restarts (T591)
STTY_SAVE=""; [ -t 0 ] && STTY_SAVE=$(stty -g < /dev/tty 2>/dev/null)
[ -n "$STTY_SAVE" ] && stty -echo < /dev/tty 2>/dev/null      # keys never echo, even mid-redraw
cleanup() { rm -f "$T".* 2>/dev/null
            [ -n "$STTY_SAVE" ] && stty "$STTY_SAVE" < /dev/tty 2>/dev/null; }
trap 'cleanup' EXIT
trap 'cleanup; exit 130' INT      # ^C quits, immediately
trap 'cleanup; exit 143' TERM                  # kill quits, immediately
trap 'cleanup; printf "\n"; exit 0'  HUP

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
lm()   { grep -ho 'L[0-9]' untracked/"$1"-*.md 2>/dev/null | head -1; }
ctag() { awk -F'\t' -v k="$1" '$1==k{print $2; exit}' untracked/concern-tags.tsv 2>/dev/null; }
fit()  { cut -c1-"$COLS"; }                      # every row trimmed to the terminal width
show() { # $1 file  $2 slots — print up to $2 rows, then "(more)" if any remain
    tot=$(grep -c . "$1" 2>/dev/null); [ -z "$tot" ] && tot=0
    [ "$tot" = 0 ] && { printf ' (none)\n'; return; }
    printf '\n'; head -n "$2" "$1"
    [ "$tot" -gt "$2" ] && printf '  (more: %s)\n' "$((tot - $2))"; }

ONESHOT=0; [ -t 1 ] || ONESHOT=1        # piped or redirected: draw once, exit, hand the shell back
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
for k,r in auth.items(): r['done']=(raw.get(k) or {}).get('done','')
json.dump(auth,open(1,'w'))
PYX
    bin/managent liveness 2>/dev/null > "$T.liveness" || : > "$T.liveness"

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
        printf '%010d\t  %-5s %-3s %-8s  %-6s %-6s %s\n' "$esec" "$t" "$(lm "$t")" \
            "$(mdl "$(mflag "$cmd")")" \
            "$(dur "$(ps -o etime= -p $p|tr -d ' ')")" "$(ps -o time= -p $p|tr -d ' '|awk -F: '{print $NF}')" \
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
        [ -z "$lbl" ] && { case "$(desc "$t")" in *seat*|*owner*|*owns*|*successor*|*console*|*orchestrator*) lbl="console";; *) lbl="orphaned";; esac; }
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
        printf '  %-5s %-3s %-8s  %-6s %s\n' "$t" "$(lm "$t")" "$lbl" "$tm" "$(desc "$t")" | fit >> "$T.conc"
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
    # T739: reserve exactly what the frame prints — k headings + (k-1) separators,
    # the 2-line footer, one "(more)" per flexible section that can exceed its
    # MIN_ROWS floor, and 1 spare so the footer never scrolls off. The old 2k+6
    # kept the pre-T738 banner budget (3 lines), so a data-rich frame left blank
    # lines while DONE/OPEN still had rows to show; every line recovered here
    # becomes a visible row (arm K pins 32 vs the old 30).
    k=$(( (np>0) + (nc>0) + (nr>0) + (nd>0) + (no>0) ))
    reserve=$(( 2*k - 1 + 2 + 1 ))                 # headings+seps, footer, spare
    [ "$nd" -gt "$MIN_ROWS" ] && reserve=$(( reserve + 1 ))    # DONE "(more)"
    [ "$no" -gt "$MIN_ROWS" ] && reserve=$(( reserve + 1 ))    # OPEN "(more)"
    avail=$(( ROWS - reserve - np - nc - nr ))
    [ "$avail" -lt 0 ] && avail=0
    ds=$(( avail / 2 )); os=$(( avail - ds ))
    [ "$ds" -gt "$nd" ] && { os=$(( os + ds - nd )); ds=$nd; }
    [ "$os" -gt "$no" ] && { ds=$(( ds + os - no )); os=$no; }
    [ "$ds" -lt "$MIN_ROWS" ] && ds=$MIN_ROWS
    [ "$os" -lt "$MIN_ROWS" ] && os=$MIN_ROWS
    [ "$ds" -gt "$MAX_ROWS" ] && ds=$MAX_ROWS
    [ "$os" -gt "$MAX_ROWS" ] && os=$MAX_ROWS

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
    printf '\n  %s · q or ^C quits · another key to refresh %ss\n' "$(date '+%H:%M:%S')" "$nap"

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
