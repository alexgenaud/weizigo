#!/bin/bash
# T774 resume — complete the 7 missing repeats (T774.1 drove 13/20 before its
# runner wall killed the drive mid-flight). Same cell_run as drive.sh; runs the
# missing cells in interleaved order, rm -rf'ing each target dir first so every
# repeat gets a genuinely fresh context (session file + outputs).
# Identity: MANAGENT_TASK_ID=T774-<cell>-r<i> per repeat (env var, not --task-id).
set -u
ROOT="/Users/alex/Project/Zig/weizigo"
RUN="$ROOT/untracked/bakeoff/t774-cost-repeatability"
WT="/tmp/weizigo/t774-frozen"
COMMIT="2ec4f93"
RUNNER="$ROOT/tools/runner"
BRIEF_M="$(cat "$ROOT/docs/evidence/T774-cost-repeatability/brief-m.txt")"
BRIEF_A="$(cat "$ROOT/docs/evidence/T774-cost-repeatability/brief-a.txt")"
CLAUDE_TOOLS="Read,Write,Edit,Bash,Grep,Glob"
LOG="$RUN/resume.log"

export WEIZIGO_tools=1
unset PI_SESSION_FILE

: > "$LOG"

cell_run() {
  local cell="$1" model="$2" harness="$3" brief="$4" wall="$5" i="$6"
  local d="$RUN/$cell/r$i"
  rm -rf "$d"
  mkdir -p "$d"
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
  local rec="$WT/untracked/runs/T774-$cell-r$i.json"
  if [ -f "$rec" ]; then
    cp "$rec" "$d/run-record.json"
  else
    echo "NO-RECORD $cell r$i" >> "$LOG"
  fi
  local bytes=0; [ -f "$d/out.json" ] && bytes=$(wc -c < "$d/out.json")
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) cell=$cell r$i exit=$rc bytes=$bytes" >> "$LOG"
}

cell_run ds-m deepseek-v4-flash pi    "$BRIEF_M" 1800 5
cell_run op-m claude-opus-5     claude "$BRIEF_M" 1800 5
cell_run ds-a deepseek-v4-flash pi    "$BRIEF_A" 5400 4
cell_run op-a claude-opus-5     claude "$BRIEF_A" 5400 2
cell_run op-a claude-opus-5     claude "$BRIEF_A" 5400 4
cell_run ds-a deepseek-v4-flash pi    "$BRIEF_A" 5400 5
cell_run op-a claude-opus-5     claude "$BRIEF_A" 5400 5
echo "ALL DONE $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$LOG"
