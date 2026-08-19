#!/bin/sh
# Fleet view — human console. Four sections: PROGRESS / CONCERNS / DONE / OPEN.
# Refresh 10 s. Read-only by default; WATCH_FLEET_HEAL=1 opts into auto-reopen.
#
# TIME FORMATS (operator rule 2026-08-19): a colon means an INSTANT, always
# (HH:MM:SS). A DURATION never contains a colon: 4h28 | 19'48 | 48s | 12.34.
# Instants are UTC-stored, shown local; the header shows both. CPU time is a
# duration, so it is rendered through dur() — never the colon form ps gives.
#
# T469 (2026-08-19): the old WORKING-NOW + KANBAN lists are merged and split
# by state into the four sections below, each elaborated once under the
# tables. Shell only — no daemon, no other file changed. Rationale:
# docs/infra/fleet-surface.md.
#
# Process detection uses `ps -axww` + substring grep, NOT pgrep -f: pgrep -f
# silently misses processes on macOS (proven 2026-08-19). A monitor that
# misses a process is the silent-wrong-answer class this project hates.
#
# Test hooks: WATCH_FLEET_ONCE=1 renders one frame and exits (no loop).
# WATCH_FLEET_SOURCE=1 defines helpers only (no cd, no loop) so a test can
# source the file without side effects.

if [ "${WATCH_FLEET_SOURCE:-0}" != "1" ]; then
    cd "$(dirname "$0")/.." || exit 1
    REPO=$(pwd)
fi
HEAL_MIN=${HEAL_MIN:-15}   # claim age (minutes) before a processless claim is healable

# ── duration formatter (operator rule: never a colon in a duration) ────
dur() {  # seconds (int or float) -> 4h28 | 19'48 | 48s | 12.34
    awk -v s="$1" 'BEGIN {
        if (s < 60) { if (s == int(s)) printf "%ds", s; else printf "%.2f", s }
        else if (s < 3600) printf "%d%c%02d", int(s/60), 39, s - int(s/60)*60
        else printf "%dh%02d", int(s/3600), int((s - int(s/3600)*3600)/60) }'; }
etime_secs() {  # ps etime (dd-hh:mm:ss | hh:mm:ss | mm:ss) -> whole seconds
    echo "$1" | awk -F'[:-]' '{
        if (NF==4) s=$1*86400+$2*3600+$3*60+$4
        else if (NF==3) s=$1*3600+$2*60+$3
        else if (NF==2) s=$1*60+$2
        else s=$1
        printf "%d", s }'; }
cpu_secs() {  # ps -o time= (mm:ss.cc | hh:mm:ss) -> seconds (float)
    echo "$1" | awk -F: '{
        if (NF==3) print $1*3600+$2*60+$3
        else if (NF==2) print $1*60+$2
        else print $1 }'; }

# ── kanban surface helpers ────────────────────────────────────────────
short() { case "$1" in *opus*) echo opus;; *fable*) echo fable;; *sonnet*) echo sonnet;;
    *v4-pro*) echo dspro;; *v4-flash*) echo flash;; *glm*) echo glm;; *minimax*) echo minimax;;
    *kimi*) echo kimi;; *qwen*) echo qwen;; *) echo "${1%%:*}";; esac; }
# bundle path -> one-line task description (from the brief's first heading)
shortname() { b="$1"; [ -f "$b" ] || { echo "?"; return; }
    line=$(grep -m1 '^# ' "$b" | sed 's/^# //; s/^T[0-9A-Za-z-]* //')
    line=$(echo "$line" | sed 's/^(\([^)]*\)).*/\1/; s/^— //; s/^- //')
    printf '%s' "$(echo "$line" | cut -c1-56)"
    [ "$(echo "$line" | wc -c | tr -d ' ')" -gt 57 ] && printf '…'; printf '\n'; }
# bundle path -> landmark id (L<n>) or -
landmark() { b="$1"; [ -f "$b" ] || { echo "-"; return; }
    lm=$(grep -m1 -i 'landmark' "$b" | grep -oE 'L[0-9]+' | head -1)
    [ -n "$lm" ] || lm=$(head -3 "$b" | grep -oE 'L[0-9]+' | head -1)
    [ -n "$lm" ] && echo "$lm" || echo "-"; }
landmark_name() { case "$1" in
    L0) echo "the table and the instruments exist";; L1) echo "the dashboard tells the truth";;
    L2) echo "proven 4×4 values";; L3) echo "the new engine outplays the old one";;
    L4) echo "the ledger is clean";; L5) echo "one rulebook";;
    L6) echo "small Go solved, certifiably";; L7) echo "the 5×5 decision, costed";; *) echo "?";; esac; }

# rows_tsv <status-json>: merge managent's resolved status (T464 resolver:
# assertion ledger authoritative) with tasks.json claim/done timestamps.
# Emits: id|status|bundle|identifier|claimed|done|verdict  (one line per row)
rows_tsv() { python3 -c '
import json, os, sys
rows = json.loads(sys.argv[1]) if sys.argv[1].strip().startswith("[") else []
claimed={}; dones={}
store = os.environ.get("MANAGENT_STORE") or "docs/infra/managent/tasks.json"
try:
    d = json.load(open(store))
    for k, r in (d.items() if isinstance(d, dict) else []):
        if isinstance(r, dict):
            if r.get("claimed"): claimed[k]=r["claimed"]
            if r.get("done"): dones[k]=r["done"]
except Exception: pass
for r in rows:
    rid=r.get("id","")
    print("%s|%s|%s|%s|%s|%s|%s" % (rid, r.get("status",""), r.get("bundle",""),
        r.get("identifier",""), claimed.get(rid,""), dones.get(rid,""), r.get("verdict","")))
' "$1"; }

# deliverables from the brief's <!--managent ... deliverables=...--> line
deliverables() { b="$1"; [ -f "$b" ] || return
    grep -m1 -oE 'deliverables=[^>"*]*' "$b" | sed 's/deliverables=//' | tr ',' '\n'; }
dels_ok() { b="$1"; ok=1
    for f in $(deliverables "$b"); do [ -n "$f" ] && [ -e "$f" ] || ok=0; done
    [ "$ok" = 1 ]; }

# task_proc <id>: the worker process for a claimed task. Prefers the model
# process over its runner wrapper. Emits pid|elapsed|cpu (empty if none).
task_proc() { echo "$PS" | awk -v id="Follow untracked/$1-" '
    index($0, id) && !chosen {
        if ($0 ~ /pi --provider|ollama launch|claude -p/) { chosen=1; ep=$1"|"$3"|"$4 }
        else if (!first) { first=$1"|"$3"|"$4 } }
    END { if (chosen) print ep; else if (first) print first }'; }

# OPEN: the DO NOW table from the backlog if it parses, else dispatchable.
# Emits task ids (one per line), capped at 8.
parse_open() {
    f="docs/status/backlog-2026-08-19.md"
    [ -f "$f" ] || return 0
    awk -F'|' '/^## DO NOW/{d=1;next} /^## /&&d{d=0}
        d && /^\| [0-9]+ \| T[0-9]/ { id=$3; gsub(/ /,"",id); print id }' "$f" | head -8
}

# ── the one frame ─────────────────────────────────────────────────────
frame() {
    NOW=$(date +%s)
    printf '=== weizigo fleet — %s local / %s UTC ===\n' "$(date '+%H:%M:%S')" "$(date -u '+%H:%M:%S')"
    STATUS=$(bin/managent status --json 2>/dev/null)
    LIVENESS=$(bin/managent liveness 2>/dev/null)
    PS=$(ps -axww -o pid=,ppid=,etime=,time=,command= 2>/dev/null)
    ROWS=$(rows_tsv "$STATUS")

    # ── heal (opt-in): claimed + no process + old claim → reopen (assert first)
    if [ "${WATCH_FLEET_HEAL:-0}" = "1" ]; then
        echo "$ROWS" | while IFS='|' read -r id status bundle ident claimed dts verdict; do
            [ "$status" = "in_progress" ] || continue; [ -n "$claimed" ] || continue
            cs=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$claimed" +%s 2>/dev/null) || continue
            age=$((NOW - cs)); [ "$age" -gt $((HEAL_MIN * 60)) ] || continue
            [ -n "$(task_proc "$id")" ] && continue
            printf '  ** HEAL: %s claimed %s, no process — asserting + reopening **\n' "$id" "$(dur "$age")"
            bin/managent assert "$id" dispatchable --note \
                "watch-fleet auto-reopen: no process after $(dur "$age"), claimed $claimed" 2>/dev/null
            bin/managent reopen "$id" 2>/dev/null
        done
        STATUS=$(bin/managent status --json 2>/dev/null); ROWS=$(rows_tsv "$STATUS")
    fi

    # ── PROGRESS: in_progress with a live worker process ───────────────
    PROG=$(echo "$ROWS" | while IFS='|' read -r id status bundle ident claimed dts verdict; do
        [ "$status" = "in_progress" ] || continue
        p=$(task_proc "$id"); [ -n "$p" ] || continue
        pid=$(echo "$p" | cut -d'|' -f1)
        el=$(dur "$(etime_secs "$(echo "$p" | cut -d'|' -f2)")")
        cp=$(dur "$(cpu_secs "$(echo "$p" | cut -d'|' -f3)")")
        printf '  %-6s %-2s %-7s %-7s %-6s %s\n' "$id" "$(landmark "$bundle")" "$el" "$cp" "$pid" "$(short "$ident")"
    done)
    printf '\nPROGRESS\n  %-6s %-2s %-7s %-7s %-6s %s\n' TASK L ELAPSED CPU PID MODEL
    [ -n "$PROG" ] && printf '%s\n' "$PROG" || printf '  (none)\n'

    # ── CONCERNS: in_progress with no process (dead/wall-killed/RSS-killed lane)
    # Each line ends with the exact command that resolves it.
    CONC=$(echo "$ROWS" | while IFS='|' read -r id status bundle ident claimed dts verdict; do
        [ "$status" = "in_progress" ] || continue
        p=$(task_proc "$id"); [ -n "$p" ] && continue
        if dels_ok "$bundle"; then dl="deliverables present"; else dl="deliverables missing"; fi
        printf '  %-6s claimed, no process (%s)  ->  bin/managent reopen %s\n' "$id" "$dl" "$id"
    done)
    printf '\nCONCERNS\n'
    [ -n "$CONC" ] && printf '%s\n' "$CONC" || printf '  (none)\n'

    # ── DONE: closed in the last 12 hours, with verdict ────────────────
    CUTOFF=$((NOW - 43200))
    DONELIST=$(echo "$ROWS" | while IFS='|' read -r id status bundle ident claimed dts verdict; do
        [ "$status" = "done" ] || continue; [ -n "$dts" ] || continue
        ds=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$dts" +%s 2>/dev/null) || continue
        [ "$ds" -ge "$CUTOFF" ] || continue
        printf '  %-6s %s\n' "$id" "${verdict:-?}"
    done)
    printf '\nDONE (last 12h)\n'
    [ -n "$DONELIST" ] && printf '%s\n' "$DONELIST" || printf '  (none)\n'

    # ── OPEN: dispatchable soon — backlog DO NOW if it parses, else the queue
    OPEN_IDS=$(parse_open)
    [ -n "$OPEN_IDS" ] || OPEN_IDS=$(echo "$ROWS" | awk -F'|' '$2=="dispatchable"{print $1}' | head -8)
    printf '\nOPEN\n'
    if [ -n "$OPEN_IDS" ]; then
        echo "$OPEN_IDS" | while read -r id; do printf '  %s\n' "$id"; done
    else printf '  (none)\n'; fi

    # ── elaboration: one line per landmark and per task that appeared ──
    printf '\nLANDMARK\n'
    lms=$(echo "$ROWS" | awk -F'|' '$2=="in_progress"{print $3}' \
        | while read -r b; do landmark "$b"; done | sort -u | grep -vE '^-|^$')
    if [ -n "$lms" ]; then
        echo "$lms" | while read -r lm; do printf '  %-3s %s\n' "$lm" "$(landmark_name "$lm")"; done
    else printf '  (none)\n'; fi

    printf '\nTASK\n'
    # ids that appeared: in_progress + done(12h) + OPEN, deduped
    appeared=$(
        echo "$ROWS" | awk -F'|' '$2=="in_progress"{print $1}'
        echo "$ROWS" | while IFS='|' read -r id status bundle ident claimed dts verdict; do
            [ "$status" = "done" ] || continue; [ -n "$dts" ] || continue
            ds=$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$dts" +%s 2>/dev/null) || continue
            [ "$ds" -ge "$CUTOFF" ] && echo "$id"
        done
        printf '%s\n' "$OPEN_IDS"
    )
    elab=$(printf '%s\n' "$appeared" | sed '/^$/d' | sort -u | while read -r id; do
        b=$(echo "$ROWS" | awk -F'|' -v t="$id" '$1==t{print $3; exit}')
        printf '  %-6s %s\n' "$id" "$(shortname "$b")"
    done)
    [ -n "$elab" ] && printf '%s\n' "$elab" || printf '  (none)\n'

    # ── footer: processes not on the kanban (operator console, race lanes) ─
    printf '\nNOT ON THE KANBAN\n'
    exclude=$(echo "$ROWS" | awk -F'|' '$2=="in_progress"{ ids = ids (n++ ? "|" : "") $1 }
        END { if (n) print "Follow untracked/(" ids ")-"; else print "Follow untracked/()-zz" }')
    tmp=$(mktemp /tmp/weizigo/fleet-footer-XXXXXX 2>/dev/null) || tmp=/tmp/weizigo/fleet-footer
    echo "$PS" | awk '/^[0-9]+ /{ if (rec != "") print rec; rec = $0; next }
                       { rec = rec " " $0 } END { if (rec != "") print rec }' \
        | grep -v -E "$exclude" | while read -r pid ppid el tm cmd; do
        case "$cmd" in
            *"bake-off"*|*bakeoff*|*untracked/race*) kind="race";;
            *bin/subagent*) kind="dispatcher";;
            *tools/runner*) kind="runner";;
            *"pi --provider"*|*"ollama launch"*|*"claude -p"*)
                case "$cmd" in *"Follow untracked/"*) kind="unclaimed worker?";; *) kind="console";; esac;;
            *)
                if [ "$ppid" = "1" ] && \
                   [ "$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-)" = "$REPO" ]; then
                    kind="ORPHAN? (in-repo)"
                else continue; fi;;
        esac
        printf '  %-7s %-7s %-6s %-18s %s\n' \
            "$(dur "$(etime_secs "$el")")" "$(dur "$(cpu_secs "$tm")")" "$pid" "$kind" "$(echo "$cmd" | cut -c1-50)…"
    done > "$tmp"
    if [ -s "$tmp" ]; then cat "$tmp"; else printf '  (none)\n'; fi
    rm -f "$tmp"
    printf '\n'
}

if [ "${WATCH_FLEET_ONCE:-0}" = "1" ]; then frame; exit 0; fi
if [ "${WATCH_FLEET_SOURCE:-0}" = "1" ]; then return 2>/dev/null || exit 0; fi
while true; do clear; frame; sleep 10; done