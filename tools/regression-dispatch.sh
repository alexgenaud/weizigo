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
#              single source of truth) — dispatchable ones by name,
#              including the claude family via the claude provider (T494).
#   e2e        a real dispatch through the wrapper with a stub worker
#              (bin/subagent --test-worker): nohup detach writes
#              untracked/log/t<id>.log, the row leaves dispatchable →
#              in_progress → done, the log ends with "verification
#              PASSED", the deliverable exists, and bin/dispatch prints
#              the one data line (dispatched T<id> … pid … log).
#
# All fixtures are synthetic and run in a scratch dir under /tmp/weizigo —
# never the live repo, never the live kanban (MANAGENT_STORE), never
# docs/infra/model-perf.md (WEIZIGO_MODEL_PERF), never
# docs/infra/dispatch-heals.jsonl (WEIZIGO_DISPATCH_HEALS).  bin/dispatch
# is invoked with --test-root=$WORK so the bundle and log land in scratch.
#
# Telemetry isolation (audit F3, 2026-08-20; T512): the suite must PROVE it
# writes only to scratch — the F3 defect was fixture T989/T990 heal records
# appended to the LIVE dispatch-heals.jsonl because WEIZIGO_DISPATCH_HEALS
# was not exported.  Arm 15a is the positive control (a real heal must land
# in the scratch log) and the closing isolation assertion scans the lines
# appended to the live logs during the run for fixture markers.
#
# Task: T476 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-19
# T512 isolation arms: 2026-08-20

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
# T477: the dispatcher's heal writes to a scratch file during tests, never the
# live heal log (2026-08-20 audit F3: the suite was appending T989/T990 heals
# to docs/infra/dispatch-heals.jsonl).
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"
export REAL_MG="$MG"

# ── live-telemetry baselines (T512, audit F3) ─────────────────────────────
# The live logs are append-only and the live fleet legitimately appends to
# them while this suite runs, so the closing isolation check cannot be a
# byte-identity compare.  It snapshots the line counts now and scans the
# lines appended DURING the run for the suite's fixture markers: any fixture
# record in the live logs is the F3 defect returning.
LIVE_HEALS="$ROOT/docs/infra/dispatch-heals.jsonl"
LIVE_PERF="$ROOT/docs/infra/model-perf.md"
LIVE_HEALS_BASE=$(wc -l < "$LIVE_HEALS" 2>/dev/null || echo 0)
LIVE_PERF_BASE=$(wc -l < "$LIVE_PERF" 2>/dev/null || echo 0)

# ── T485 done-gate substrate in scratch ───────────────────────────────────
# bin/managent done runs `bin/weizigo-claimlint c7 --json` from the repo
# root it walks from CWD — the scratch repo — so the e2e stub's close needs
# a claimlint binary + a minimal register there, exactly as
# regression-dispatch-verification.sh provisions them.  Without it the
# stub's done is refused ("cannot run bin/weizigo-claimlint") and the e2e
# arms fail with rc=1 (observed 2026-08-20).
CLAIMLINT="$ROOT/bin/weizigo-claimlint"
[ -x "$CLAIMLINT" ] || CLAIMLINT="$ROOT/zig-out/bin/weizigo-claimlint"
if [ -x "$CLAIMLINT" ]; then
    mkdir -p "$WORK/bin" "$WORK/docs/epistemic"
    ln -s "$CLAIMLINT" "$WORK/bin/weizigo-claimlint"
    printf '# minimal scratch claims register (T476 regression)\n' > "$WORK/docs/epistemic/CLAIMS.md"
else
    echo "regression-dispatch.sh: WARNING — weizigo-claimlint not built (zig build); the e2e done-gate arms will fail" >&2
fi

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
subprocess.run([mg, "done", task, "--agent", model, "--status", "pass",
                "--impression-waiver", "stub worker — no model ran (T476 regression)"], check=True)
print(nonce + " task complete")
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub.py"

seed_task() {  # $1=id  $2=deliverable
    printf '<!--managent set=C deliverables=%s-->\n# %s — T476 regression bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$2" "$1" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

# T505: seed a task with an exact-length title (the brief's `# T<id> — <title>`
# line).  The title is the text after ` — `; the 40-char limit (DELEGATOR.md
# §Task titles) applies to that portion, not the whole `# T<id> —` line.
seed_task_titled() {  # $1=id  $2=deliverable  $3=title
    printf '<!--managent set=C deliverables=%s-->\n# %s — %s\n**Landmark:** none directly; unblocks regression fixture\n' "$2" "$1" "$3" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

title_of_len() {  # $1=N → N-char title (repeated 't')
    printf 't%.0s' $(seq 1 "$1")
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

# T494 (2026-08-19): the claude-seat refusal is RETIRED.  The cited rule was
# mis-stated — the prohibition is about the *harness*, not the dispatcher
# (docs/infra/agents/subdelegation.md:152-156): Claude must never run *inside*
# a pi/Ollama harness driving the Anthropic API, but a headless `claude -p`
# session launched by a non-Claude worker is explicitly acceptable.  claude
# labels now route to bin/subagent's claude provider.  This arm was RED
# against the pre-T494 code (claude was refused); it goes GREEN once the
# claude branch lands.
echo "  9. claude-* label routes to --provider claude (T494: rule corrected —"
echo "     headless claude -p from a non-Claude worker is allowed)"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 claude-opus-5 --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q -- "--provider claude --model claude-opus-5 T991 --wall=2700"; then
    echo "    PASS: claude-opus-5 routes to --provider claude (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected claude routing"; echo "$OUT" | sed 's/^/    | /'
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
        echo "    FAIL: canonical model '$m' not resolved in bin/dispatch"
        SYNC_FAIL=1
    fi
done
if [ "$SYNC_FAIL" -eq 0 ]; then
    echo "    PASS: all canonical models resolved (incl. claude via the claude provider)"
else
    FAIL=1
fi

# ── T494: claude-provider arms (red against the pre-T494 code) ───────────
# The claude branch must (a) render the exact `claude -p` line of the T481/
# t490 precedent shape in --dry-run, (b) route every canonical claude label,
# and (c) inherit the row-state refusal — a claude dispatch of an
# in_progress row is still refused, the same fence that caught T350/T376.
echo " 13a. dry-run claude-fable-5 prints the exact claude -p line (T481 shape)"
OUT=$(cd "$ROOT" && "$DISPATCH" T991 claude-fable-5 --dry-run --test-root="$WORK" 2>&1)
RC=$?
# The resolved claude -p command must carry the nonce, the model, the
# allowedTools set, and the json output format — the T481/t490 precedent
# (json since T521: the usage envelope is the token-capture source; the
# runner unwraps the text for verification).
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q "claude -p" \
   && echo "$OUT" | grep -q -- "--model claude-fable-5" \
   && echo "$OUT" | grep -q -- "--allowedTools Read,Write,Edit,Bash,Grep,Glob" \
   && echo "$OUT" | grep -q -- "--output-format json" \
   && echo "$OUT" | grep -qE "NONCE-[0-9a-f]{16}"; then
    echo "    PASS: claude -p line carries model, allowedTools, output-format, nonce"
else
    echo "    FAIL: claude -p shape incomplete (rc=$RC)"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 13b. dry-run all four canonical claude labels route to --provider claude"
CLAUDE_FAIL=0
for lbl in claude-fable-5 claude-opus-5 claude-sonnet-5 claude-haiku-4-5-20251001; do
    OUT=$(cd "$ROOT" && "$DISPATCH" T991 "$lbl" --dry-run --test-root="$WORK" 2>&1)
    if ! echo "$OUT" | grep -q -- "--provider claude --model $lbl T991"; then
        echo "    FAIL: $lbl did not route to --provider claude --model $lbl"
        echo "$OUT" | sed 's/^/    | /'
        CLAUDE_FAIL=1
    fi
done
if [ "$CLAUDE_FAIL" -eq 0 ]; then
    echo "    PASS: all four claude labels route to the claude provider"
else
    FAIL=1
fi

echo " 13c. seeded: claude dispatch of an in_progress row refuses (row-state"
echo "      guard inherited by the claude branch — the T350/T376 fence holds)"
seed_task T994 findings/T994-result.json
"$MG" claim T994 --agent claude-fable-5 >/dev/null 2>&1
OUT=$(cd "$ROOT" && "$DISPATCH" T994 claude-fable-5 --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "in_progress"; then
    echo "    PASS: refused in_progress claude dispatch (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected in_progress refusal for claude"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/log/t994.log" ]; then
    echo "    FAIL: claude refusal spawned a dispatch (log exists)"; FAIL=1
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

# ── T494 e2e: a claude dispatch through the wrapper (stub worker) ─────────
# Proves the claude branch inherits the full dispatch+verify path: nohup
# detach, claim → in_progress → done, verification PASSED, deliverable
# written, and a perf-ledger line attributed to claude-fable-5.  RED
# against the pre-T494 code (claude refused at resolve_model).
echo " 15. e2e: claude dispatch T989 with stub worker → done → perf-ledger line"
seed_task T989 docs/T989-result.txt
OUT=$(cd "$ROOT" && "$DISPATCH" T989 claude-fable-5 \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] || ! echo "$OUT" | grep -q "^dispatched T989"; then
    echo "    FAIL: claude dispatch rc=$RC; expected 'dispatched T989' data line"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
else
    echo "    PASS: claude dispatch returned and printed the data line"
fi
SEEN_DONE=0
for i in $(seq 1 60); do
    S=$(row_status T989)
    [ "$S" = "done" ] && { SEEN_DONE=1; break; }
    sleep 0.5
done
if [ "$SEEN_DONE" -eq 1 ]; then
    echo "    PASS: claude row reached done"
else
    echo "    FAIL: claude row did not reach done in 30s (status=$(row_status T989))"
    FAIL=1
fi
CLOG="$WORK/untracked/log/t989.log"
if [ -f "$CLOG" ] && grep -q "verification PASSED" "$CLOG"; then
    echo "    PASS: untracked/log/t989.log exists and ends verification PASSED"
else
    echo "    FAIL: claude log missing or verification not PASSED ($CLOG)"
    [ -f "$CLOG" ] && tail -5 "$CLOG" | sed 's/^/    | /'
    FAIL=1
fi
if [ -f "$WORK/docs/T989-result.txt" ]; then
    echo "    PASS: claude deliverable written by the worker"
else
    echo "    FAIL: claude deliverable docs/T989-result.txt missing"
    FAIL=1
fi
if grep -q "dispatch-verify .* T989 claude-fable-5 report=.* verified=pass" "$WORK/perf-ledger.txt"; then
    echo "    PASS: perf-ledger line written for claude-fable-5 (verified=pass)"
else
    echo "    FAIL: perf-ledger line for claude-fable-5 missing"
    [ -f "$WORK/perf-ledger.txt" ] && cat "$WORK/perf-ledger.txt" | sed 's/^/    | /'
    FAIL=1
fi

# ── F3 isolation positive control (T512): a real heal lands in scratch ──
# The audit F3 defect: the suite's e2e arms appended T989/T990 fixture heal
# records to the LIVE docs/infra/dispatch-heals.jsonl because
# WEIZIGO_DISPATCH_HEALS was not exported.  This arm forces the exact T477
# heal signature — worker claims, then dies rc=1 leaving the row
# in_progress, so verification fails and heal_dispatch reopens it — and
# asserts the heal record lands in the SCRATCH log.  RED against the
# pre-fix code (the record would land in the live log instead; the closing
# isolation assertion below then fails).
echo " 15a. F3 positive control: claim-then-die worker → heal record in scratch, row reopened"
seed_task T987 findings/T987-result.json
cat > "$WORK/stub_die.py" <<'STUBDIEEOF'
#!/usr/bin/env python3
import os, re, subprocess, sys
# Claim, then die rc=1 without closing: rc!=0 + row in_progress is the
# exact T477 signature the dispatcher heals (verify fails → heal_dispatch).
prompt = sys.argv[-1]
mg = os.environ["REAL_MG"]
task = re.search(r"managent claim (T\d+)", prompt).group(1)
model = re.search(r"managent claim \S+ --agent (\S+)", prompt).group(1)
subprocess.run([mg, "claim", task, "--agent", model], check=True)
sys.exit(1)
STUBDIEEOF
chmod +x "$WORK/stub_die.py"
: > "$WORK/dispatch-heals.jsonl"   # fresh scratch heal log for this arm
OUT=$(cd "$ROOT" && "$DISPATCH" T987 deepseek-v4-flash \
        --test-root="$WORK" --test-worker="$WORK/stub_die.py" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "^dispatched T987"; then
    echo "    PASS: dispatch returned and printed the data line"
else
    echo "    FAIL: dispatch rc=$RC; expected 'dispatched T987' data line"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
HEAL_SEEN=0
REOPEN_SEEN=0
for i in $(seq 1 60); do
    if grep -q '"task_id": "T987"' "$WORK/dispatch-heals.jsonl" 2>/dev/null; then HEAL_SEEN=1; fi
    [ "$(row_status T987)" = "dispatchable" ] && REOPEN_SEEN=1
    [ "$HEAL_SEEN" -eq 1 ] && [ "$REOPEN_SEEN" -eq 1 ] && break
    sleep 0.5
done
if [ "$HEAL_SEEN" -eq 1 ]; then
    echo "    PASS: heal record landed in the SCRATCH heal log (WEIZIGO_DISPATCH_HEALS)"
else
    echo "    FAIL: no heal record in the scratch heal log"
    cat "$WORK/dispatch-heals.jsonl" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
if [ "$REOPEN_SEEN" -eq 1 ]; then
    echo "    PASS: row reopened to dispatchable by the heal"
else
    echo "    FAIL: row not reopened (status=$(row_status T987))"
    FAIL=1
fi
if grep -q "healed: dispatcher reopened T987" "$WORK/untracked/log/t987.log" 2>/dev/null; then
    echo "    PASS: dispatch log carries the heal line"
else
    echo "    FAIL: heal line missing from untracked/log/t987.log"
    [ -f "$WORK/untracked/log/t987.log" ] && tail -5 "$WORK/untracked/log/t987.log" | sed 's/^/    | /'
    FAIL=1
fi

# ── T505 arms: brief-title length gate (≤40 chars) at dispatch ──────────
# The 40-char title rule (DELEGATOR.md §Task titles) was violated three
# times in one session.  The gate lives in bin/dispatch (not src/managent,
# which is serial-held by T485/486/487/497; not bin/dispatch's claude
# logic, which T494 owns).  A brief whose `# T<id> — <title>` title
# portion exceeds 40 chars refuses dispatch, naming the title and limit.
echo " 16. T505 null: 39-char title dispatches (dry-run)"
seed_task_titled T995 findings/T995-result.json "$(title_of_len 39)"
OUT=$(cd "$ROOT" && "$DISPATCH" T995 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "dry-run T995"; then
    echo "    PASS: 39-char title dispatched (rc=$RC)"
else
    echo "    FAIL: rc=$RC; 39-char title should dispatch"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 17. T505 seeded: 41-char title refuses dispatch, naming title + limit"
seed_task_titled T996 findings/T996-result.json "$(title_of_len 41)"
OUT=$(cd "$ROOT" && "$DISPATCH" T996 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "40" && echo "$OUT" | grep -qi "title"; then
    echo "    PASS: refused 41-char title, named the 40-char limit (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected title-length refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if [ -e "$WORK/untracked/log/t996.log" ]; then
    echo "    FAIL: title refusal spawned a dispatch (log exists)"; FAIL=1
fi

echo " 18. T505 seeded: brief with no `# T<id> — title` line refuses dispatch"
printf '<!--managent set=C deliverables=docs/T997-x.txt-->\nno title line here\n**Landmark:** none directly; unblocks regression fixture\n' \
    > "$WORK/untracked/T997-bundle.md"
"$MG" add T997 >/dev/null 2>&1
OUT=$(cd "$ROOT" && "$DISPATCH" T997 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "title"; then
    echo "    PASS: refused brief with no title line (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected no-title-line refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── F3 isolation assertion (T512): nothing of the suite reached live telemetry ─
# The live logs are append-only; the live fleet may legitimately append while
# this suite runs.  The invariant under test is: lines appended during the
# run carry NO fixture marker (T987/T989/T990 — the ids this suite's
# dispatched arms use).  The F3 defect was exactly these fixture records in
# the live heal log.
echo " 19. isolation: live dispatch-heals + model-perf gained no fixture data"
ISO_FAIL=0
APPENDED=$(tail -n +$((LIVE_HEALS_BASE + 1)) "$LIVE_HEALS" 2>/dev/null)
if [ -z "$APPENDED" ]; then
    echo "    PASS: docs/infra/dispatch-heals.jsonl — no lines appended during the run"
elif echo "$APPENDED" | grep -qE '"task_id": "T(987|989|990)"'; then
    echo "    FAIL: fixture heal record(s) appended to the LIVE heal log (F3 regression)"
    echo "$APPENDED" | grep -nE '"task_id": "T(987|989|990)"' | sed 's/^/    | /'
    ISO_FAIL=1
else
    echo "    PASS: docs/infra/dispatch-heals.jsonl — appended lines carry no fixture data"
fi
APPENDED=$(tail -n +$((LIVE_PERF_BASE + 1)) "$LIVE_PERF" 2>/dev/null)
if [ -z "$APPENDED" ]; then
    echo "    PASS: docs/infra/model-perf.md — no lines appended during the run"
elif echo "$APPENDED" | grep -qE ' T(987|989|990) '; then
    echo "    FAIL: fixture perf line(s) appended to the LIVE model-perf.md"
    echo "$APPENDED" | grep -nE ' T(987|989|990) ' | sed 's/^/    | /'
    ISO_FAIL=1
else
    echo "    PASS: docs/infra/model-perf.md — appended lines carry no fixture data"
fi
[ "$ISO_FAIL" -eq 0 ] || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-dispatch: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-dispatch: FAILURES ==="
    exit 1
fi
