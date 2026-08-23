#!/bin/bash
# T774 cost-repeatability drive — 4 cells (model x brief shape) x 5 repeats,
# interleaved so no cell's repeats cluster in one load/time band.
#
# Each repeat: reset the frozen worktree to a byte-identical tree at 2ec4f93,
# launch the provider under tools/runner with a fresh context, capture the run
# record (wall/cpu/rss_mb/tokens) into the main repo.
#
# Identity: MANAGENT_TASK_ID=T774-<cell>-r<i> per repeat (env var, NOT the
# --task-id flag, so the runner never auto-claims/auto-dones a kanban row).
# Run records land in the WORKTREE's untracked/runs (repo_root resolves to the
# worktree) and are copied into the main repo after each run.
set -u
ROOT="/Users/alex/Project/Zig/weizigo"
RUN="$ROOT/untracked/bakeoff/t774-cost-repeatability"
WT="/tmp/weizigo/t774-frozen"
COMMIT="2ec4f93"
RUNNER="$ROOT/tools/runner"
BRIEF_M="$(cat "$ROOT/docs/evidence/T774-cost-repeatability/brief-m.txt")"
BRIEF_A="$(cat "$ROOT/docs/evidence/T774-cost-repeatability/brief-a.txt")"
CLAUDE_TOOLS="Read,Write,Edit,Bash,Grep,Glob"
LOG="$RUN/drive.log"

export WEIZIGO_tools=1      # claude gate (grand-race.md roster authorization)
unset PI_SESSION_FILE       # pi writes to the explicit --session path

: > "$LOG"

cell_run() {
  local cell="$1" model="$2" harness="$3" brief="$4" wall="$5" i="$6"
  local d="$RUN/$cell/r$i"
  mkdir -p "$d"
  # byte-identical tree for every repeat
  ( cd "$WT" && git reset --hard "$COMMIT" >/dev/null 2>&1 && git clean -fdq )
  export MANAGENT_TASK_ID="T774-$cell-r$i"
  local rc
  if [ "$harness" = "pi" ]; then
    ( cd "$WT" && "$RUNNER" --max-wall "$wall" -- \
        pi --provider deepseek --model "$model" --mode json \
           --session "$d/session.jsonl" -p "$brief" \
        > "$d/out.json" 2> "$d/trailer.log" )
    rc=$?
  else
    ( cd "$WT" && "$RUNNER" --max-wall "$wall" -- \
        claude -p "$brief" --model "$model" \
        --allowedTools "$CLAUDE_TOOLS" --output-format json \
        > "$d/out.json" 2> "$d/trailer.log" )
    rc=$?
  fi
  # copy the finalized run record into the main repo
  local rec="$WT/untracked/runs/T774-$cell-r$i.json"
  if [ -f "$rec" ]; then
    cp "$rec" "$d/run-record.json"
  else
    echo "NO-RECORD $cell r$i" >> "$LOG"
  fi
  local bytes=0; [ -f "$d/out.json" ] && bytes=$(wc -c < "$d/out.json")
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) cell=$cell r$i exit=$rc bytes=$bytes" >> "$LOG"
}

for i in 1 2 3 4 5; do
  cell_run ds-m deepseek-v4-flash pi    "$BRIEF_M" 1800 "$i"
  cell_run op-m claude-opus-5     claude "$BRIEF_M" 1800 "$i"
  cell_run ds-a deepseek-v4-flash pi    "$BRIEF_A" 5400 "$i"
  cell_run op-a claude-opus-5     claude "$BRIEF_A" 5400 "$i"
done
echo "ALL DONE $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
