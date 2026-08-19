#!/usr/bin/env bash
# regression-dispatch.sh — T476 controls for bin/dispatch (headless dispatch wrapper)
#
# T476's gap: the Orchestrator's dispatch procedure lived only in the
# incumbent's head — nohup detach, log path, wall choice, provider↔model
# pairing, claude's refusal to go through bin/subagent.  bin/dispatch wraps
# bin/subagent so the correct thing is the easy thing.  These controls pin
# the wrapper's contract:
#
#   dry-run    for every dispatchable canonical model: the constructed
#              bin/subagent command (provider flags + exact ollama tag),
#              the log path convention untracked/log/t<id>.log, the wall
#              default 2700 and --wall= override.  Nothing is spawned.
#   seeded     a dispatchable row claimed in a scratch store: bin/dispatch
#              MUST refuse and name `in_progress` (re-dispatch of a live
#              row is how the T350/T376/T389 duplicates happened).
#   seeded     a non-canonical model name: MUST refuse and name it.
#   seeded     a claude-* label: MUST refuse — claude seats run from a
#              claude console with `claude -p`, never via a non-Claude
#              harness (human rule, documented in bin/subagent).
#   seeded     a dispatchable row whose untracked/T<id>-*.md bundle is
#              absent: MUST refuse.
#   seeded     an unknown T-id: MUST refuse.
#   seeded     a manager at the delegation cap (WEIZIGO_AGENT_DEPTH=3):
#              MUST refuse (shared cap with bin/subagent).
#   sync       the model map in bin/dispatch must cover every canonical
#              model in src/managent/main.zig canonical_models[] (T317
#              single source of truth) — dispatchable ones by name, the
#              claude family by the claude- refusal branch.
#   e2e        a real dispatch through the wrapper with a stub worker
#              (bin/subagent --test-worker): nohup detach writes
#              untracked/log/t<id>.log, the row leaves dispatchable →
#              in_progress → done, the log ends with "verification
#              PASSED", the deliverable exists, and bin/dispatch prints
#              the one data line (dispatched T<id> … pid … log).
#
# All fixtures are synthetic and run in a scratch dir under /tmp/weizigo —
# never the live repo, never the live kanban (MANAGENT_STORE), never
# docs/infra/model-perf.md (WEIZIGO_MODEL_PERF).  bin/dispatch is invoked
# with --test-root=$WORK so the bundle and log land in scratch.
#
# Task: T476 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-19

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
DISPATCH="$ROOT/bin/dispatch"
SUBAGENT="$ROOT/bin/subagent"
MG="$ROOT/bin/managent"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t476-dispatch-XXXXXX)" || { echo "regression-dispatch.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# A stale depth stamp from a worker-run suite would trip the cap control.
unset WEIZIGO_AGENT_DEPTH || true

# ── scratch repo + store (the e2e stub commits its deliverable) ──────────
cd "$WORK"
git init -q
git config user.email t476@test
git config user.name T476
echo base > README.md
mkdir -p docs untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export REAL_MG="$MG"

# ── stub worker (honest): claims, writes+commits the deliverable, sleeps
# past the T390 claim-to-done window, closes the row.  Parses task/model/
# nonce/deliverable out of the prompt exactly as a real agent would.
cat > "$WORK/stub.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, re, subprocess, sys, time

prompt = sys.argv[-1]
mg = os.environ["REAL_MG"]

nonce = re.search(r"NONCE-[0-9a-f]{16}", prompt).group(0)
task = re.search(r"managent (?:claim|done) (T\d+)", prompt).group(1)
model = re.search(r"managent claim \S+ --agent (\S+)", prompt).group(1)
dl = re.search(r"^  - (\S+)$", prompt, re.M).group(1)

subprocess.run([mg, "claim", task, "--agent", model], check=True)
with open(dl, "w") as f:
    f.write("T476 stub deliverable\n")
subprocess.run(["git", "add", "--", dl], check=True)
subprocess.run(["git", "commit", "-qm", "T476 stub deliverable"], check=True)
# T390: done within 10s of claim is refused as claim-at-close.
time.sleep(11)
subprocess.run([mg, "done", task, "--agent", model, "--status", "pass"], check=True)
print(nonce + " task complete")
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub.py"

seed_task() {  # $1=id  $2=deliverable
    printf '<!--managent set=C deliverables=%s-->\n# %s — T476 regression bundle\n' "$2" "$1" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

row_status() {  # $1=id — status word from `managent show`'s "<id>  <status>" line
    "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
}

echo "=== bin/dispatch regression ==="

# T991 is the dry-run row: dispatchable, with a bundle.  A dry-run previews
# a real dispatch, so it must validate the row exactly as the real path does.
seed_task T991 findings/T991-result.json

# ── dry-run: provider/model pairing per family, log path, wall ───────────
echo "  1. dry-run deepseek-v4-flash → --dsflash, log path, wall default 2700"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q -- "--provider deepseek --dsflash T991 --wall=2700" \
   && echo "$OUT" | grep -q "untracked/log/t991.log"; then
    echo "    PASS: deepseek-flash command + log path correct"
else
    echo "    FAIL: rc=$RC; output:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/log/t991.log" ]; then
    echo "    FAIL: --dry-run spawned something (log exists)"
    FAIL=1
else
    echo "    PASS: --dry-run spawned nothing"
fi

echo "  2. dry-run deepseek-v4-pro → --dspro"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 deepseek-v4-pro --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider deepseek --dspro T991 --wall=2700"; then
    echo "    PASS: deepseek-pro command correct"
else
    echo "    FAIL: missing --provider deepseek --dspro"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  3. dry-run glm-5.2 → ollama --model glm-5.2:cloud"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 glm-5.2 --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider ollama --model glm-5.2:cloud T991 --wall=2700"; then
    echo "    PASS: glm-5.2 command correct"
else
    echo "    FAIL: missing --model glm-5.2:cloud"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  4. dry-run kimi-k2.7 → ollama --model kimi-k2.7-code:cloud (tag alias too)"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 kimi-k2.7 --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider ollama --model kimi-k2.7-code:cloud T991 --wall=2700"; then
    echo "    PASS: kimi-k2.7 command correct"
else
    echo "    FAIL: missing --model kimi-k2.7-code:cloud"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT2=$(cd "$ROOT" && "$DISPATCH" T991 kimi-k2.7-code:cloud --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT2" | grep -q -- "--model kimi-k2.7-code:cloud T991"; then
    echo "    PASS: raw tag kimi-k2.7-code:cloud canonicalizes to the same command"
else
    echo "    FAIL: tag alias did not canonicalize"; echo "$OUT2" | sed 's/^/    | /'
    FAIL=1
fi

echo "  5. dry-run minimax-m3 → --model minimax-m3:cloud; qwen3.8:27b-mlx → --model qwen3.8:27b-mlx"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 minimax-m3 --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--model minimax-m3:cloud T991"; then
    echo "    PASS: minimax-m3 command correct"
else
    echo "    FAIL: missing --model minimax-m3:cloud"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
OUT=$(cd "$ROOT" && "$DISPATCH" T991 qwen3.8:27b-mlx --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--model qwen3.8:27b-mlx T991"; then
    echo "    PASS: qwen command correct (no :cloud tag)"
else
    echo "    FAIL: missing --model qwen3.8:27b-mlx"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  6. dry-run --wall=5400 override lands in the command"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 deepseek-v4-flash --wall=5400 --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--wall=5400"; then
    echo "    PASS: wall override present"
else
    echo "    FAIL: --wall=5400 missing"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── seeded: refusals ──────────────────────────────────────────────────────
echo "  7. seeded: dispatchable row already claimed → refuse, name in_progress"
seed_task T992 findings/T992-result.json
"$MG" claim T992 --agent deepseek-v4-flash >/dev/null 2>&1
OUT=$(cd "$ROOT" && "$DISPATCH" T992 deepseek-v4-flash --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "in_progress"; then
    echo "    PASS: refused in_progress row (rc=$RC, message names the state)"
else
    echo "    FAIL: rc=$RC; expected refusal naming in_progress"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/log/t992.log" ]; then
    echo "    FAIL: refusal spawned a dispatch (log exists)"
    FAIL=1
else
    echo "    PASS: nothing spawned on refusal"
fi

echo "  8. seeded: non-canonical model → refuse, name the model"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 gpt-4o --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "gpt-4o"; then
    echo "    PASS: refused gpt-4o naming it (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected refusal naming gpt-4o"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  9. seeded: claude-* label → refuse with the claude-seat guidance"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 claude-opus-5 --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "claude"; then
    echo "    PASS: refused claude-opus-5 (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected claude refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 10. seeded: dispatchable row with no bundle → refuse"
seed_task T993 findings/T993-result.json
rm -f "$WORK/untracked/T993-bundle.md"
OUT=$(cd "$ROOT" && "$DISPATCH" T993 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "T993"; then
    echo "    PASS: refused missing-bundle row naming T993 (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected missing-bundle refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 11. seeded: unknown T-id → refuse"
OUT=$(cd "$ROOT" && "$DISPATCH" T9998 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "T9998"; then
    echo "    PASS: refused unknown task naming T9998 (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected unknown-task refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 12. seeded: manager at delegation cap refuses"
OUT=$(cd "$ROOT" && WEIZIGO_AGENT_DEPTH=3 "$DISPATCH" T991 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: refused at cap depth (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected cap refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── sync: bin/dispatch covers every canonical model (T317 single source) ──
echo " 13. sync: model map covers src/managent/main.zig canonical_models[]"
CANON=$(sed -n '/const canonical_models/,/^};/p' "$ROOT/src/managent/main.zig" \
        | grep -oE '"[a-z0-9.:-]+"' | tr -d '"' | sort)
SYNC_FAIL=0
for m in $CANON; do
    if grep -q "\"$m\"" "$DISPATCH"; then
        :
    elif echo "$m" | grep -q "^claude-" && grep -q "claude-" "$DISPATCH"; then
        :
    else
        echo "    FAIL: canonical model '$m' not resolved (and not claude-refused) in bin/dispatch"
        SYNC_FAIL=1
    fi
done
if [ "$SYNC_FAIL" -eq 0 ]; then
    echo "    PASS: all canonical models resolved or claude-refused"
else
    FAIL=1
fi

# ── e2e: one real dispatch through the wrapper (stub worker) ──────────────
echo " 14. e2e: dispatch T990 with stub worker; detach → log → in_progress → done"
seed_task T990 docs/T990-result.txt
OUT=$(cd "$ROOT" && "$DISPATCH" T990 deepseek-v4-flash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] || ! echo "$OUT" | grep -q "^dispatched T990"; then
    echo "    FAIL: dispatch rc=$RC; expected 'dispatched T990' data line"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
else
    echo "    PASS: dispatch returned and printed the data line"
fi
PID_LINE=$(echo "$OUT" | grep "^dispatched T990" | grep -oE "pid [0-9]+" || true)

SEEN_INPROG=0
SEEN_DONE=0
for i in $(seq 1 60); do
    S=$(row_status T990)
    if [ "$S" = "in_progress" ]; then SEEN_INPROG=1; fi
    if [ "$S" = "done" ]; then SEEN_DONE=1; break; fi
    sleep 0.5
done
if [ "$SEEN_INPROG" -eq 1 ]; then
    echo "    PASS: row passed through in_progress (claim happened)"
else
    echo "    FAIL: row never left dispatchable"
    FAIL=1
fi
if [ "$SEEN_DONE" -eq 1 ]; then
    echo "    PASS: row reached done"
else
    echo "    FAIL: row did not reach done in 30s (status=$(row_status T990))"
    FAIL=1
fi

LOG="$WORK/untracked/log/t990.log"
if [ -f "$LOG" ] && grep -q "verification PASSED" "$LOG"; then
    echo "    PASS: untracked/log/t990.log exists and ends verification PASSED"
else
    echo "    FAIL: log missing or verification not PASSED ($LOG)"
    [ -f "$LOG" ] && tail -5 "$LOG" | sed 's/^/    | /'
    FAIL=1
fi
if [ -f "$WORK/docs/T990-result.txt" ]; then
    echo "    PASS: deliverable written by the worker"
else
    echo "    FAIL: deliverable docs/T990-result.txt missing"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-dispatch: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-dispatch: FAILURES ==="
    exit 1
fi
