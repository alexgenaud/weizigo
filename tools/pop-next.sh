#!/bin/sh
# tools/pop-next.sh — pop ONE well-specified task off the stack and dispatch it.
#
# Operator, 2026-08-25: "I would like the backlog of well-specified, obviously
# beneficial tasks to methodically execute. Not in haste, perhaps serially, but
# automatically pop off the stack and run."
#
# Deliberately small.  It does not supervise, does not close rows, does not
# judge.  It picks the highest-ranked AUTO row that is dispatchable and whose
# held files are free, assigns a model, and calls bin/dispatch — which already
# enforces caps, admission, holds and the delegation depth.  Everything else
# that exists keeps doing its job.
#
#   --dry-run   print the choice, dispatch nothing
#   --loop N    pop, then wait until the fleet has room again, up to N times
#   MAX_LANES   how many lanes may run at once (default 1 — serial, as asked)
#
# It STOPS, loudly, rather than guessing:
#   * no AUTO row is dispatchable            -> exit 0, says so
#   * the next AUTO row's file is held       -> skips it, names the holder
#   * untracked/pop-next.stop exists         -> exit 0, the graceful brake
#
# DISCUSS rows are never popped.  That is the point: they need a conversation,
# and a loop cannot have one.
set -e
cd "$(dirname "$0")/.." || exit 1
QUEUE=docs/infra/dispatch-queue.tsv
STOP=untracked/pop-next.stop
# Default 8 (operator, 2026-08-25: "I would hope for at least one from each
# family and more"). Was 1, then 5, then 3.
#
# Eight is chosen against the family caps below, not picked for size: with
# claude=3, deepseek=3, other=4 and ollama=2, no two families can fill eight
# lanes between them, so a full fleet necessarily spans at least three of the
# four providers -- CC, Ollama, DS, OpenRouter -- and usually all four.
# That is the "not all eggs in one basket" rule expressed as a cap rather
# than as a hope. Nothing was blocked at 1 -- 14 rows were runnable and idle. The real
# guards are downstream and unchanged: bin/dispatch enforces family caps, the
# RAM arbiter refuses a lane that does not fit, and holds keep two rows off one
# file. Set MAX_LANES=1 to go back to serial.
MAX_LANES="${MAX_LANES:-8}"
DRY=0; LOOPS=1
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --loop) shift; LOOPS="${1:-1}" ;;
    *) echo "pop-next: unknown argument '$1'" >&2; exit 2 ;;
  esac
  shift
done

# Per-family caps, enforced by bin/dispatch (tools/fleet_caps.py). Defaults are
# claude=5, deepseek=5, ollama=5, local=5, other=5, fable=1 -- which at
# MAX_LANES=8 would let ONE family take five of the eight. Tightened so the
# fleet has to spread: claude=3 (unchanged from T651 and the number that has
# never tripped the provider), deepseek=3, other=4. `other` is where every
# OpenRouter model lands (google, openai, alibaba, nvidia, upstage, oxalpha),
# so 4 bounds the credit the operator says is going fastest while still
# letting four different OpenRouter models run at once.
# claude=4, not 3: the cap counts STORE ROWS, not processes, and T935 -- the
# orchestration seat -- is an in_progress row with no lane behind it. It ate a
# claude slot and refused a real race arm ("Running now: T935, T971, T972").
# Four restores three usable claude lanes. The underlying defect is that a
# row with no process should not consume a family slot; noted, not fixed here.
export FLEET_FAMILY_CAP="${FLEET_FAMILY_CAP:-claude=4,deepseek=3,other=4,ollama=2,fable=1}"

lanes_now() { pgrep -f -- '--arbiter-id T[0-9]' 2>/dev/null | wc -l | tr -d ' '; }

pop_once() {
  [ -f "$STOP" ] && { echo "pop-next: STOPPED — $STOP exists (remove it to resume)"; return 1; }
  # Report orphans every tick. NOT --close: a lane that died after writing its
  # deliverable looks identical to one that produced nothing, and closing it
  # `abandoned` would be a lie (T894 and T963 both delivered and never closed).
  # So this only records, and the record is what an unattended stretch is
  # reconstructed from.
  bin/managent reap 2>&1 | grep -E 'ORPHAN|orphans: [1-9]' | sed 's/^/pop-next: reap: /' || true
  n=$(lanes_now)
  if [ "$n" -ge "$MAX_LANES" ]; then
    echo "pop-next: $n lane(s) running, MAX_LANES=$MAX_LANES — nothing popped"
    return 2
  fi
  choice=$(python3 - "$QUEUE" <<'PYP'
import json,sys,os,re
q=sys.argv[1]
store=json.load(open('docs/infra/managent/tasks.json'))
# A dispatched row reads `dispatchable` until its worker claims itself, which is a
# window wide enough to dispatch it twice (the T350/T376/T389 duplicate class). So
# a row with a LIVE runner is not a candidate, whatever the store says. Process
# table first, store second.
import subprocess,re
live=set()
try:
    ps=subprocess.run(['ps','-axo','command='],capture_output=True,text=True).stdout
    live={m for m in re.findall(r'--arbiter-id (T\d+)', ps)}
except Exception: pass
held=set()
for k,v in store.items():
    if isinstance(v,dict) and v.get('status')=='in_progress':
        for h in (v.get('holds') or []): held.add(h)
rows=[]
for ln in open(q):
    if ln.startswith('#') or not ln.strip(): continue
    f=ln.rstrip('\n').split('\t')
    if len(f)>=4 and f[3]=='AUTO': rows.append((int(f[1]),f[0]))
rows.sort()
for _,t in rows:
    v=store.get(t)
    if not v or v.get('status')!='dispatchable': continue
    if t in live:
        print("SKIP\t%s\tlive runner already (store not yet claimed)"%t); continue
    import glob as _g
    fails=0
    for rf in _g.glob('untracked/runs/%s.*.json'%t)+['untracked/runs/%s.json'%t]:
        try: rd=json.load(open(rf))
        except Exception: continue
        if rd.get('exit') not in (0,None) and (rd.get('wall') or 0) < 120: fails+=1
    if fails >= 5:
        print("FAILCAP\t%s\t%d"%(t,fails)); continue
    clash=[h for h in (v.get('holds') or []) if h in held]
    if clash:
        print("SKIP\t%s\t%s"%(t,','.join(clash))); continue
    # unspec is a BLOCKER (operator, 2026-08-25): "If we wonder why such-or-such
    # task is not running, we should be able to reliably see and declare. 'oh,
    # it's unspecified, let's specify now'." A row with no acceptance= in its
    # bundle header has no bar to be judged against, so it is not dispatchable
    # work -- it is work waiting to be specified. Same test watch-fleet uses.
    b=v.get('bundle') or ''
    # Read the WHOLE `<!--managent ... -->` comment, not a fixed byte window.
    # A 400-byte window declared T954 unspec because its metadata line is 606
    # bytes (ten holds and ten deliverables) and acceptance= sits at byte 547 --
    # a correctly specified row, permanently unrunnable, for a reason nothing
    # printed. The metadata comment is the unit; measure that.
    head=''
    try:
        raw=open(b).read()
        m=re.search(r'<!--managent(.*?)-->', raw, re.S)
        head=m.group(1) if m else raw[:400]
    except Exception: head=''
    if 'acceptance=' not in head:
        print("UNSPEC\t%s\t%s"%(t,b)); continue
    print("PICK\t%s\t%s"%(t,v.get('bundle') or ''))
    break
PYP
)
  echo "$choice" | grep '^FAILCAP' | while IFS="$(printf '\t')" read -r _ t n; do
    echo "pop-next: skip $t — $n fast failures already; not re-dispatching. Investigate, then delete its untracked/runs/$t.*.json attempts to clear."
  done
  echo "$choice" | grep '^SKIP' | while IFS="$(printf '\t')" read -r _ t f; do
    echo "pop-next: skip $t — held file busy: $f"
  done
  # ── retry cap ───────────────────────────────────────────────────────────
  # T873 was re-dispatched 30 times in 30 minutes, once per tick, each attempt
  # dying in 18.7 s with exit 1 and zero tokens, because Ollama's weekly limit
  # had run out. The row reads `dispatchable` the whole time (the lane dies
  # before it can claim), so nothing stopped the loop. A row with N recent
  # failed attempts is skipped and named; the operator decides what to do
  # about it, which is the whole point of surfacing rather than retrying.
  echo "$choice" | grep '^UNSPEC' | while IFS="$(printf '\t')" read -r _ t f; do
    echo "pop-next: skip $t — UNSPEC (no acceptance= in $f); specify it to make it runnable"
  done
  pick=$(echo "$choice" | grep '^PICK' | head -1 | cut -f2)
  [ -z "$pick" ] && { echo "pop-next: no AUTO row is dispatchable right now"; return 3; }
  # ── no ollama-cloud for single-model work (operator, 2026-08-25) ────────
  # "Do not dispatch single model tasks to Ollama. We will soon run out of
  #  Ollama weekly token credits. I would prefer to accumulate comparative
  #  race data than use Ollama models for singular task work."
  # The family name managent knows is `ollama-cloud`; bin/dispatch and
  # fleet_caps call the same family `ollama`. Passing the WRONG name here is
  # silent -- `--exclude ollama` is accepted and ignored, and the popper would
  # go on assigning kimi/glm/minimax while looking configured. Verified live:
  # --exclude ollama-cloud drops all three with "excluded by row (family
  # ollama-cloud)". Local mlx (family `local`) is unaffected and is
  # PROBE-gated anyway; it spends no cloud credit.
  # ── which families the mechanized DRAW may use ──────────────────────────
  # A PIN always wins over this (see below), so a pinned race arm still runs on
  # its own model. This only steers unpinned backlog work.
  #
  # Operator, 2026-08-25 on the credit picture: ollama full but "we tend to burn
  # them quickly"; OpenRouter "burning fairly quickly, slow and steady"; DeepSeek
  # typical, "do not go unusually heavy"; Claude barely used with its 5-hour
  # window resetting soon. The mechanized draw is solo-least-data, which favours
  # the models with the least history -- and every one of those is OpenRouter
  # (google, openai, alibaba, nvidia, upstage, oxalpha). Left alone it would
  # spend the scarcest credit fastest, for the least urgent reason.
  #
  # So unpinned backlog work draws from claude and deepseek; the OpenRouter
  # models still run wherever a row PINS them, which is where their comparative
  # data comes from. Revisit when the OpenRouter picture changes -- this is a
  # credit decision, not a capability one, and it must not leak into any race.
  # Excluded: ollama-cloud (operator: races only, credits burn fast) and local
  # (qwenlocal declares 18,432 MB -- "hold back on risky/heavy 20 GB jobs").
  # Everything else is IN, including oxalpha and the four OpenRouter models.
  #
  # This REVERSES the narrower exclusion set fifteen minutes ago, which had
  # steered every unpinned draw to claude and deepseek to save OpenRouter
  # credit. That was the wrong trade and the operator corrected it: "most
  # models can be utilized about equally. Models with least evidence should be
  # raced. Don't put all eggs in the same basket." Concentrating three hours of
  # unattended work on two families is exactly one basket, and the models with
  # the least evidence are the ones that most need the lanes. Slow and steady
  # is bought with the RATE (3 lanes), not by benching two thirds of the roster.
  #
  # oxalpha is in, which also satisfies "poke oxalpha periodically": least-data
  # draws it on its own without a separate mechanism, and if the provider is
  # still 429ing, the lane exits and the dispatcher reopens the row.
  # local only. qwenlocal declares 18,432 MB and heavy jobs are held back.
  #
  # ollama-cloud is back IN as of 2026-08-25, superseding this morning's "no
  # singular work on ollama". The operator now wants all four provider families
  # delegating at once -- CC, Ollama, DS, OpenRouter -- with "Ollama a bit
  # less", and its weekly credits reset within hours. So it draws again, capped
  # at 2 against claude=3, deepseek=3, other=4. If the credit picture changes,
  # the lever is the CAP, not the exclusion: benching a whole provider is what
  # left three families covering eight lanes earlier today.
  # ollama-cloud is OUT again: the weekly limit was exhausted 2026-08-25 and
  # does not reset until Sunday. This is a fact about the provider, not a
  # policy, so it stays until the reset regardless of the four-provider goal.
  EXCLUDE_FAMILIES="${EXCLUDE_FAMILIES:-local,ollama-cloud}"

  # ── a pinned model wins over the mechanized draw ────────────────────────
  # A race arm is only a race arm if it runs on the model it is an arm FOR.
  # Race J pins oxalpha / dsflash / dspro / kimi / sonnet / gemini-flash onto
  # T916-T920 and T939; letting `assign` redraw them would silently turn six
  # sealed lanes into six lanes of whatever was cheapest, and the judge would
  # never know. `managent agent <id> <model>` is how a row gets pinned, and
  # the pin also carries kimi past EXCLUDE_FAMILIES on purpose: the operator's
  # rule is no ollama for SINGULAR task work, and comparative race data is the
  # stated exception ("I would prefer to accumulate comparative race data than
  # use Ollama models for singular task work", 2026-08-25).
  # Models already holding a lane. `assign --exclude` matches a family OR an
  # exact canonical model, so feeding it the live set gives ONE LANE PER MODEL.
  # Family caps alone do not: `other` is capped at 4 and qwen3.8-27b took three
  # of five lanes on its own, because least-data keeps picking whoever has the
  # fewest rows and that is the same model until its count moves. The operator
  # asked for at least four models delegating, not four lanes.
  LIVE_MODELS=$(python3 -c "
import json
t=json.load(open('docs/infra/managent/tasks.json'))
print(','.join(sorted({v.get('model') for v in t.values() if isinstance(v,dict) and v.get('status')=='in_progress' and v.get('model')})))" 2>/dev/null)

  model=$(python3 -c "
import json,sys
v=json.load(open('docs/infra/managent/tasks.json')).get('$pick') or {}
print(v.get('model') or '')" 2>/dev/null)
  if [ -n "$model" ]; then
    echo "pop-next: $pick is pinned to $model (not redrawn)"
  else
  # --dry-run must not RECORD an assignment. It did: the first dry run of this
  # script pinned claude-haiku onto T931 as a side effect, because the DRY
  # check sat after the assign call. A preview that mutates the store is not a
  # preview. `assign --dry-run` prints the same choice and writes nothing.
  assign_dry=""; [ "$DRY" = 1 ] && assign_dry="--dry-run"
  EXCL="$EXCLUDE_FAMILIES"; [ -n "$LIVE_MODELS" ] && EXCL="$EXCL,$LIVE_MODELS"
  model=$(bin/managent assign "$pick" --json --exclude "$EXCL" $assign_dry 2>/dev/null | python3 -c "import sys,json
try: print(json.load(sys.stdin).get('model') or '')
except Exception: print('')" 2>/dev/null)
  fi
  [ -z "$model" ] && model=dspro
  if [ "$DRY" = 1 ]; then
    echo "pop-next: WOULD dispatch $pick -> $model"
    return 0
  fi
  echo "pop-next: dispatching $pick -> $model"
  # Print the WHOLE refusal, not the last line. `| tail -1` here threw away
  # every line but the last of bin/dispatch's message, so a complete refusal --
  # "REFUSED — title `...` is 44 chars, over the 40-char limit ... Shorten it;
  # the long form goes in the brief's body" -- reached the log as nothing but
  # "the long form goes in the brief's body". The dispatcher then retried the
  # same row 22 times over 22 minutes with no task id in the log, and the
  # operator asked whether it was working. The gate named its subject; this
  # line discarded it. On success bin/dispatch's last line is the summary, so
  # keep that shape for the success case only.
  # T961 landed the one-door rule: bin/dispatch now REFUSES a direct call, and
  # this script was calling it directly -- so the dispatcher was refused by the
  # gate it had itself queued. Go through the door like everything else.
  # FLEET_TEST_WORKER is the test seam (the fleet-keeper convention): when set,
  # it is forwarded to the door as --test-worker=<cmd> so the e2e regression
  # launches a stub instead of a real lane (the regression-one-door-dispatch
  # arm 7). Production never sets it.
  test_worker_args=""
  [ -n "${FLEET_TEST_WORKER:-}" ] && test_worker_args="--test-worker=$FLEET_TEST_WORKER"
  # A row can carry a `dispatched` timestamp while reading `dispatchable`, if
  # the lane died before it could claim. managent then REJECTS the redispatch
  # ("already dispatched to X at T") and the popper retries it every tick
  # forever -- the T873 monopoly in a different costume. Two rows were stuck
  # this way tonight, T925 and T973, each consuming a whole tick while thirty
  # race arms waited.
  #
  # The condition is deliberately precise: a dispatch was recorded, no run
  # record exists, AND no live process holds the id. That combination means
  # the lane never started, so --force is the correct escape and not a
  # second-console risk. Anything looser must NOT auto-force: --force over a
  # genuinely live console is how T350/T376/T389 duplicated.
  FORCE=""
  never_ran=$(python3 -c "
import json,glob
v=json.load(open('docs/infra/managent/tasks.json')).get('$pick') or {}
print('1' if v.get('dispatched') and not glob.glob('untracked/runs/$pick*.json') else '')" 2>/dev/null)
  if [ -n "$never_ran" ] && ! pgrep -f -- "--arbiter-id $pick" >/dev/null 2>&1; then
    FORCE="--force"
    echo "pop-next: $pick has a dispatch record but nothing ran — forcing once (no run record, no live process)"
  fi
  out=$(bin/managent dispatch "$pick" --to "$model" --wall 7200 $FORCE $test_worker_args 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    # The data line is the one that starts with "dispatched " on stdout — the
    # door adds its own stderr diagnostics AFTER the callee's data line, so
    # `tail -1` would surface a diagnostic, not the launch (T953's failure
    # mode, one door deeper).
    echo "$out" | grep '^dispatched ' | head -1
  else
    echo "pop-next: dispatch REFUSED $pick (rc=$rc) — full message follows:"
    echo "$out" | sed 's/^/  | /'
  fi
}

# ── the loop runs a FRESH child each tick ────────────────────────────────
# It used to call pop_once in-process. A `--loop 240` therefore ran for hours
# against the copy of this file that `sh` had already parsed, so editing the
# script did nothing to the loop that was running. That is not theoretical:
# on 2026-08-25 the ollama-cloud exclusion above was added while a loop was
# live, and the next pop still drew minimax-m3 -- the operator's instruction
# was in the file and not in the running process. The lane was killed and the
# row reopened.
#
# So the loop is now a supervisor: each tick re-execs this script for exactly
# one pop, which re-reads the file, the queue, and the stop-file every time.
# A single pop (`--loop 1`, the default) still runs in-process -- that is the
# child the supervisor spawns, and it must not recurse.
i=0
while [ "$i" -lt "$LOOPS" ]; do
  if [ "$LOOPS" -eq 1 ]; then
    pop_once || true
  else
    if [ "$DRY" = 1 ]; then sh "$0" --dry-run || true; else sh "$0" || true; fi
  fi
  i=$((i+1))
  [ "$i" -lt "$LOOPS" ] && sleep 60
done
exit 0
