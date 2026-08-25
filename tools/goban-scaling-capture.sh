#!/bin/sh
# goban-scaling-capture.sh — append one measured row per goban solve to
# docs/infra/host/goban-scaling.jsonl.  Wraps the solve; never estimates.
#
# Usage: tools/goban-scaling-capture.sh <rows> <cols> <regime> <task> -- <command...>
#   regime: writes-off | memo-reuse | deps-guarded | history-exact
#
# Fields are MEASURED or absent.  A field we could not read is null, never a
# guess — the register has 85 PROSE-ONLY rows because guesses were written
# down as facts.  `nodes` is null unless the command prints `nodes=<n>`.
#
# T926 (2026-08-25) three fixes:
#   1. peak_rss_mb is now the sum of RSS across the WHOLE descendant set,
#      not the direct child only.  The T914 sampler read ps -axo pid=,rss=
#      for $CMDPID alone, so a multi-process solve under-reported by an
#      order of magnitude (3x2 live at 1,440 MB was recorded as 46 MB;
#      4x4 at 50x the same).  The fix mirrors the runner's walker: build
#      a ppid->[pid] map from a single ps snapshot per poll, BFS from the
#      child pid, and sum RSS over the whole set.  Peak is the max over
#      all polls.
#   2. A killed run writes a row.  The pre-T926 wrapper only appended
#      after `wait` returned; a wall kill, an RSS cap, a signal from the
#      lane, or a parent-trap fired in the wrong order left the row
#      unwritten.  The ledger dropped the entry, reading as "not
#      measured" when the work was measured-and-lost — the exact loss
#      shape the tractability question exists to surface.  The fix: an
#      EXIT trap appends the row with whatever was sampled up to the
#      kill, and stamps `killed_by` (wall | rss | signal | cap | none)
#      and `partial: true` so the reader knows.  A clean exit stamps
#      killed_by=none and partial=false.
#   3. The regime is OBSERVED, not trusted.  T924 invoked the wrapper
#      with `writes-off` for BOTH arms of its 4x4 comparison, so the
#      writes-on arm was recorded as writes-off (corrected by hand in
#      4a80255's successor; the same defect would re-fire the next
#      time).  The fix parses the command for `RETRO_SOUND` and stamps
#      regime_claimed (the arg), regime_observed (from the command),
#      and regime_mismatch (true when they disagree).  A disagreement
#      is reported on stderr so the operator sees it during the run;
#      the row still lands — losing it would be the worse failure.
#
# Env override: WEIZIGO_SCALING_LEDGER redirects the append target.  The
# regression uses this to exercise the script against a scratch ledger
# without touching the live docs/infra/host/goban-scaling.jsonl.
set -e
ROWS=$1; COLS=$2; REGIME=$3; TASK=$4
# T926: stash the FULL command line (including the leading env-var
# assignments like `RETRO_SOUND=1`) BEFORE we shift past the wrapper
# args.  The post-shift `$*` is missing those, which would silently
# break regime observation.  Save it once here, reuse everywhere.
CMDLINE_=$*
shift 4
[ "$1" = "--" ] && shift
LEDGER=${WEIZIGO_SCALING_LEDGER:-docs/infra/host/goban-scaling.jsonl}
OUT=$(mktemp -t goban-scaling); SAMP=$(mktemp -t goban-rss)
# Run-scoped shared state for the EXIT trap.  Each variable is set in
# the run path and read in the trap.  POSIX sh keeps them; `local`
# inside a function would be safer but sh-on-macOS lacks `local` in
# strict mode.  Names are CMDPID_/PEAK_/CAFF_/START_/RC_/KILLED_/etc
# to make the trap's "global write" visible at a glance.
START=$(date +%s)
# CMDLINE_ was stashed at the top of the script (before the shift) so
# env-var assignments like `RETRO_SOUND=1 cmd` survive — the post-shift
# $* would lose them.  Initialize the rest of the trap-shared state
# here; do NOT touch CMDLINE_ or the regime observation will collapse
# to "memo-reuse" on every run.
CMDPID_=; PEAK_=0; CAFF_=0; KILLED_=none; NODES_=; RC_=; PARTIAL_=false
# T926: idempotency guard.  The trap can fire more than once: a
# SIGTERM/SIGINT that the trap's `exit $RC_` doesn't fully suppress
# (POSIX sh is fuzzy here) will re-enter the trap on the way out, and
# each entry would write a row.  Set the flag at the start of
# _append_row; if a re-entrant call sees the flag, return without
# writing.  Single source of truth for "is the row already on disk".
APPENDED_=false
# T927: hold an idle-sleep assertion for the solve's lifetime so the wall
# figure cannot cross a host sleep. caffeinate -i -w $CMDPID auto-releases
# when the solve exits; a sidecar, so RSS polling still reads the solve.
if command -v caffeinate >/dev/null 2>&1; then CAFF_=1; fi
# Append the row on every exit path.  POSIX sh runs EXIT on `set -e`
# failures too, so the row lands even when the script itself explodes
# (mktemp ran out of space, python3 missing, etc.).  The trap is the
# ONE writer — duplicate appends would corrupt the ledger.
_append_row() {
  if [ "$APPENDED_" = "true" ]; then return; fi
  APPENDED_=true
  END=$(date +%s)
  WALL=$(( END - START ))
  # NODES and ART are best-effort reads; OUT may be missing on a kill
  # before the temp was created.  None when unreadable.
  if [ -f "$OUT" ]; then
    NODES_=$(grep -oE 'nodes=[0-9]+' "$OUT" | tail -1 | cut -d= -f2) || NODES_=
    ART=$(ls -l artifacts/oracle-${ROWS}x${COLS}.wzo 2>/dev/null | awk '{print $5}') || ART=
  fi
  # Regime observation: parses the command line for the env var that
  # actually drives memo_writes in src/retro.zig (RETRO_SOUND presence).
  # A leading "VAR=val cmd" form counts as "VAR is set".  CMDLINE_ is
  # captured before the wrapper's shift, so env-var assignments like
  # `RETRO_SOUND=1 cmd` survive — the post-shift $* would lose them.
  REGIME_OBS=
  case " $CMDLINE_ " in
    *" RETRO_SOUND "*) REGIME_OBS=writes-off ;;
    *" RETRO_SOUND="*) REGIME_OBS=writes-off ;;
    *" RETRO_DEPS "*)  REGIME_OBS=deps-guarded ;;
    *" RETRO_DEPS="*)  REGIME_OBS=deps-guarded ;;
    *) case " $CMDLINE_ " in
         *"history-exact"*) REGIME_OBS=history-exact ;;
         *) REGIME_OBS=memo-reuse ;; # default: no RETRO_SOUND, no RETRO_DEPS = reuse
       esac ;;
  esac
  if [ "$REGIME_OBS" != "$REGIME" ]; then
    MISMATCH=true
    echo "goban-scaling: REGIME MISMATCH claimed=$REGIME observed=$REGIME_OBS task=$TASK" >&2
  else
    MISMATCH=false
  fi
  # Exit code: the trap fires on a non-zero exit too, with $? = the
  # failing command's status.  Save it before the trap's own work can
  # clobber it.  137 = 128+9 (SIGKILL), 143 = 128+15 (SIGTERM); the
  # check is a heuristic for "killed by signal".
  RC_=${RC_:-0}
  if [ "$KILLED_" = "none" ]; then
    case $RC_ in
      137) KILLED_=signal; PARTIAL_=true ;;
      143) KILLED_=signal; PARTIAL_=true ;;
      124) KILLED_=wall; PARTIAL_=true ;;
    esac
  fi
  mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || true
  python3 - "$ROWS" "$COLS" "$REGIME" "$TASK" "$WALL" "$PEAK_" "$RC_" \
    "${NODES_:-}" "${ART:-}" "$LEDGER" "$CAFF_" "$START" "$END" \
    "$KILLED_" "$PARTIAL_" "$MISMATCH" "$REGIME_OBS" "$CMDLINE_" <<'PY'
import sys, json, subprocess
from datetime import datetime
r,c,regime,task,wall,peak,rc,nodes,art,ledger,caff,start,end,\
    killed_by,partial,mismatch,regime_obs,cmdline = sys.argv[1:19]
def num(x):
    try: return int(x)
    except: return None
def asbool(x):
    return x in ("true", "1", "True", "TRUE")
head = subprocess.run(['git','rev-parse','--short','HEAD'],
                      capture_output=True,text=True).stdout.strip() or None
# T927: count "Entering Sleep" entries from pmset whose timestamp falls in
# [start, end]. None when pmset is unavailable (cannot measure = cannot count).
sleeps = None
try:
    pm = subprocess.run(['pmset','-g','log'],
                        capture_output=True,text=True,timeout=3.0)
    if pm.returncode == 0:
        s, e = int(start), int(end)
        n = 0; saw = False
        for line in pm.stdout.splitlines():
            if 'Entering Sleep' not in line: continue
            saw = True
            parts = line.split(None, 3)
            if len(parts) < 3: continue
            try: dt = datetime.strptime(' '.join(parts[:3]), '%Y-%m-%d %H:%M:%S %z')
            except ValueError: continue
            ep = int(dt.timestamp())
            if s <= ep <= e: n += 1
        sleeps = n if saw else None
except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
    sleeps = None
row = {"rows":int(r),"cols":int(c),"points":int(r)*int(c),
       "regime":regime,"regime_claimed":regime,"regime_observed":regime_obs,
       "regime_mismatch":asbool(mismatch),
       "task":task,
       "wall_s":num(wall),"peak_rss_mb":num(peak),"exit":num(rc),
       "nodes":num(nodes),"artifact_bytes":num(art),"head":head,
       "host":{"cores":18,"ram_gb":48},"measured":True,
       # T926: every run lands a row, including killed ones.  killed_by is
       # the T629 enum (none | signal | wall | rss | cap); partial is true
       # when the row was written without a clean wait.  A reader can
       # filter partial out without losing the row.
       "killed_by":killed_by,
       "partial":asbool(partial),
       # T927: idle-sleep prevention for the run. sleep_prevented is whether
       # the caffeinate assertion was held; sleeps_during_run is the count
       # of host sleeps in the window (null when pmset is unavailable).
       "start_epoch":num(start),
       "sleep_prevented": bool(int(caff)),
       "sleeps_during_run": sleeps}
with open(ledger,'a') as f: f.write(json.dumps(row,sort_keys=True)+"\n")
print("goban-scaling: %sx%s %s wall=%ss peak=%sMB rc=%s killed_by=%s partial=%s regime_mismatch=%s sleep_prevented=%s sleeps=%s -> %s"%(r,c,regime,wall,peak,rc,killed_by,partial,mismatch,row["sleep_prevented"],sleeps,ledger))
PY
}
# Install the trap BEFORE spawning the child, so a launch failure (env
# hang, etc.) still gets a row.  Stash $? at trap entry as RC_; the
# trap's own commands don't read $? until the end.
trap '
  # macOS /bin/sh clears $? on trap entry (the bash/dash convention of
  # leaving the signal status in $? is NOT honored here), so we cannot
  # read the signal from $? alone.  Instead, the trap inspects whether
  # the child is still alive: if it is, the WRAPPER was killed, not
  # the child, and the row is honestly marked killed_by=signal.  If
  # the child has already exited, the wait that followed it (or its
  # absence) drives rc.  killed_by is the truth source, rc is best-
  # effort on this shell.
  if [ -n "$CMDPID_" ] && kill -0 $CMDPID_ 2>/dev/null; then
    KILLED_=signal; PARTIAL_=true
    RC_=143
  fi
  # T926: ALWAYS attempt to append the row, even when something else in
  # the trap path failed.  The python heredoc inside _append_row may
  # itself fail (e.g. WEIZIGO_SCALING_LEDGER points at a directory or
  # an unwritable path).  In that case the row is LOST — unacceptable
  # for the kill path.  As a degraded-mode recovery, dump the row text
  # to stderr so a human can recover it by hand; the data is not gone,
  # just unappended.  This is a backstop, not a substitute for fixing
  # the ledger path.
  if ! _append_row; then
    echo "goban-scaling: ROW APPEND FAILED task=$TASK rows=${ROWS}x${COLS} regime=$REGIME wall=$(($(date +%s) - START))s killed_by=$KILLED_ partial=$PARTIAL_ rc=$RC_ — recover by hand from stderr" >&2
  fi
  cat "$OUT" 2>/dev/null
  rm -f "$OUT" "$SAMP"
  exit $RC_
' EXIT INT TERM

# T927: hold an idle-sleep assertion for the solve's lifetime so the wall
# figure cannot cross a host sleep. caffeinate -i -w $CMDPID auto-releases
# when the solve exits; a sidecar, so RSS polling still reads the solve.
"$@" > "$OUT" 2>&1 &
CMDPID_=$!
if [ "$CAFF_" = 1 ]; then
  caffeinate -i -w $CMDPID_ >/dev/null 2>&1 &
else
  : # sleep guard unavailable (non-darwin); recorded as sleep_prevented=false
fi
# T926: sample the WHOLE descendant set, not just CMDPID.  A child that
# forks (a zig solve typically has thread-pool workers) would otherwise
# under-report by 1-2 orders of magnitude.  The walker is the same shape
# tools/runner uses (_descendant_pids_ps): one `ps -axo pid=,ppid=,rss=`
# call per poll, BFS from $CMDPID_ over the ppid->[pid] map, sum RSS
# across the set.  Peak across the run is the metric.
while kill -0 $CMDPID_ 2>/dev/null; do
  # One ps call, awk to BFS the tree and sum RSS.  The walker is small
  # enough to inline; a separate script would only hide the cost.
  R=$(ps -axo pid=,ppid=,rss= 2>/dev/null | awk -v root="$CMDPID_" '
    BEGIN { split("", kids); split("", rss) }
    { kids[$2] = kids[$2] " " $1; rss[$1] = $3 }
    function sum_tree(node,   s, c, i) {
      s = rss[node] + 0
      n = split(kids[node], c, " ")
      for (i = 1; i <= n; i++) if (c[i] != "") s += sum_tree(c[i])
      return s
    }
    END { print int(sum_tree(root) / 1024) }
  ')
  if [ -n "$R" ] && [ "$R" -gt "$PEAK_" ] 2>/dev/null; then
    PEAK_=$R
  fi
  echo "$R" >> "$SAMP"
  sleep 1
done
# Clean exit path: wait the child and record its exit normally.  The
# trap's RC_=... will already have caught signal-kill children; the
# 137/143/124 heuristic covers the most common shapes (wall=124 from
# `timeout`, signal=137 from SIGKILL, signal=143 from SIGTERM).
#
# The `|| RC_=$? || true` is load-bearing under `set -e`: a child
# killed by a signal makes `wait` return 137, which set -e would treat
# as a script failure, aborting BEFORE the RC_=$? assignment runs
# and the EXIT trap fires with an unset RC_ (defaults to 0 — exactly
# the data loss the kill path exists to prevent).  The first `||`
# keeps the exit code in $?; the second swallows set -e for this line.
wait $CMDPID_ || RC_=$? || true
exit $RC_
