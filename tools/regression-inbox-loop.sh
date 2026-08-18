#!/usr/bin/env bash
# regression-inbox-loop.sh — T352 controls for the worker inbox loop
#
# T352 closes the four-hour 0% CPU stall: the relay between consoles used to
# be a human pasting text.  man-agent has had `tell` and `inbox` for a
# while, but two things were missing: workers did not poll, and the
# Orchestrator's view of unread directives lived only in `managent inbox`
# — not where the operator already looks (resume).  T352 makes both
# halfs work and proves them with four controls.
#
#   null control       a worker with an empty inbox proceeds unchanged:
#                      the dispatch prompt carries the inbox-loop paragraph,
#                      but the inbox command is a no-op when there is
#                      nothing to ack.
#   seeded (the point) `managent tell` to a live temp-store row, and the
#                      worker (a deterministic stub we drive from the test)
#                      reads, acks, records the directive ID, and reports
#                      done — with NO human action in between.  The
#                      timeline (write, read, ack, record) is printed.
#   seeded             an unread directive older than 5 min surfaces in
#                      `managent resume` with a STALL marker and an age
#                      string.  The resume surface is the operator's
#                      single read point, so the visibility lives there.
#   cross-check        the `INBOX LOOP` paragraph is in BOTH the
#                      bin/subagent and bin/ollama-subagent dispatch
#                      prompts — the prompt is the only thing the worker
#                      sees at the start, so the rule has to be there.
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and
# live repo are never touched.  MANAGENT_STORE points at a scratch kanban
# and the command is invoked from the scratch repo, so findRepoRoot
# resolves there.  directives.jsonl lives under the scratch repo's
# docs/infra/managent/, so the temp store carries its own directive
# history (the live one is never read or written by this test).
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent (built, not yet
# deployed) → bin/managent.  SKIP loudly when none carries the inbox or
# resume commands, same convention as regression-managent-resume.sh.
#
# Task: T352 · Role: worker · Model: minimax-m3 · Date: 2026-08-04

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/.."
FAIL=0

# ── binary resolution ────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy (zig build deploy-managent)"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "inbox \[<target>\] \[--ack\]"; then
    echo "SKIP: $MG does not carry 'inbox --ack' — rebuild from src/managent/main.zig"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent resume"; then
    echo "SKIP: $MG does not carry 'resume' — rebuild from src/managent/main.zig"
    exit 0
fi

# ── scratch repo + kanban store ──────────────────────────────────────────
# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/inbox-loop-XXXXXX)" || { echo "regression-inbox-loop.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t352@test
git config user.name T352
echo base > README.md
mkdir -p docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
DIRECTIVES="$WORK/docs/infra/managent/directives.jsonl"
export MANAGENT_STORE="$STORE"
# The regression is itself a worker-tier script — it would not dispatch
# further — so we explicitly clear WEIZIGO_AGENT_DEPTH to depth-0 so the
# dry-run of bin/ollama-subagent / bin/subagent inside the test renders
# the prompt.  (When run from a manager console, the env already carries
# depth 2 and the dry-run would refuse with the depth-cap message.)
unset WEIZIGO_AGENT_DEPTH

# Seed a task so we have something to `tell` to.
cat > "$STORE" <<'JSONEOF'
{
  "TSEED": {"status":"in_progress","agent":"t352","model":"minimax-m3","bundle":"untracked/TSEED-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-04T16:00:00Z","claimed":"2026-08-04T16:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF

echo "=== inbox-loop regression ==="

# ── 1. null control: empty inbox is a no-op for the worker ──────────────
# The dispatch prompt carries the inbox-loop paragraph.  A worker that runs
# the inbox command on an empty store sees `-- no pending directives --`
# and acks zero.  The pre-fix code path (no inbox-loop paragraph in the
# prompt) is what the brief calls out; this control does not re-test that
# the paragraph is present (cross-check 4 does), only that an empty
# inbox does not error or block.
echo "  1. null control: empty inbox → no pending directives, ack=0, RC=0"
OUT=$("$MG" inbox TSEED --ack 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "no pending directives" && \
   echo "$OUT" | grep -q "acked 0 directive"; then
    echo "    PASS: empty inbox → -- no pending directives, acked 0, RC=0"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── 2. seeded: tell → worker reads → worker acks → worker records D0NN ──
# The whole point of T352.  The "worker" is a deterministic stub we
# drive from the test (the test is the harness, not a real agent
# console — that would cost a worker + minutes).  The stub performs the
# four steps a real worker would: tell (orchestrator side), read, ack,
# record the directive ID in a findings-equivalent file.  No human in
# the loop.  Timeline is printed so a reviewer can see the sequence.
echo ""
echo "  2. seeded: tell → read → ack → record, no human action between"
TIMELINE="$(mktemp)"
echo "T+0.000s orchestrator: managent tell TSEED amend --note 'use clamp(TIE,[L,H])' --from T352-test" >> "$TIMELINE"
T_TELL_START=$(date +%s.%N)
TELL_OUT=$("$MG" tell TSEED amend --note "use clamp(TIE,[L,H])" --from T352-test 2>&1)
T_TELL_END=$(date +%s.%N)
TELL_DID=$(echo "$TELL_OUT" | grep -oE 'directive D[0-9]+' | head -1 | awk '{print $2}')
printf 'T+%.3fs directive stored: %s\n' "$(echo "$T_TELL_END - $T_TELL_START" | bc -l)" "${TELL_DID:-NONE}" >> "$TIMELINE"

# Worker-side: read the inbox (no ack yet — read first, decide, then ack)
T_READ_START=$(date +%s.%N)
READ_OUT=$("$MG" inbox TSEED 2>/dev/null)
T_READ_END=$(date +%s.%N)
if echo "$READ_OUT" | grep -q "$TELL_DID" && echo "$READ_OUT" | grep -q "use clamp(TIE,\\[L,H\\])"; then
    printf 'T+%.3fs worker read: %s present, note text present\n' "$(echo "$T_READ_END - $T_READ_START" | bc -l)" "$TELL_DID" >> "$TIMELINE"
else
    printf 'T+%.3fs worker read: %s MISSING from inbox — FAIL\n' "$(echo "$T_READ_END - $T_READ_START" | bc -l)" "$TELL_DID" >> "$TIMELINE"
    echo "$READ_OUT" | sed 's/^/      /' >> "$TIMELINE"
    FAIL=1
fi

# Worker-side: act on the amend by recording the directive ID in a
# worker-side note file (proxy for "I read it and acted").  The
# Orchestrator will see this in `managent status`/`resume`.
WORKER_NOTE="$WORK/worker-act-on-${TELL_DID}.log"
printf 'worker TSEED acted on %s: amended clamp(TIE,[L,H]) handling.\n' "$TELL_DID" > "$WORKER_NOTE"
printf 'T+%.3fs worker wrote: %s\n' "$(echo "$T_READ_END - $T_READ_START" | bc -l)" "$WORKER_NOTE" >> "$TIMELINE"

# Worker-side: ack the directive so the resume surface stops flagging it.
T_ACK_START=$(date +%s.%N)
ACK_OUT=$("$MG" inbox TSEED --ack 2>/dev/null)
T_ACK_END=$(date +%s.%N)
if echo "$ACK_OUT" | grep -q "acked 1 directive"; then
    printf 'T+%.3fs worker acked: 1 directive marked read\n' "$(echo "$T_ACK_END - $T_ACK_START" | bc -l)" >> "$TIMELINE"
else
    printf 'T+%.3fs worker acked: acked 1 directive MISSING from output\n' "$(echo "$T_ACK_END - $T_ACK_START" | bc -l)" >> "$TIMELINE"
    echo "$ACK_OUT" | sed 's/^/      /' >> "$TIMELINE"
    FAIL=1
fi

# Verify the directive file is on disk with read=true
if grep -q "\"id\":\"$TELL_DID\".*\"read\":true" "$DIRECTIVES"; then
    printf 'T+%.3fs disk state: %s carries read:true for %s\n' "$(echo "$T_ACK_END - $T_ACK_START" | bc -l)" "$DIRECTIVES" "$TELL_DID" >> "$TIMELINE"
else
    printf 'T+%.3fs disk state: %s does NOT carry read:true for %s — FAIL\n' "$(echo "$T_ACK_END - $T_ACK_START" | bc -l)" "$DIRECTIVES" "$TELL_DID" >> "$TIMELINE"
    grep -o "{\"id\":\"$TELL_DID\"[^}]*}" "$DIRECTIVES" | sed 's/^/      /' >> "$TIMELINE"
    FAIL=1
fi

# Print the timeline
sed 's/^/    /' "$TIMELINE"
echo "    timeline saved to: $TIMELINE"

# ── 3. seeded: an unread directive surfaces in `managent resume` ────────
# Plant a second directive with a backdated timestamp so the resume
# surface flags it as STALL.  Then run resume and check the surface
# names the directive ID and shows the STALL marker.
echo ""
echo '  3. seeded: an unread directive surfaces in `managent resume` with STALL marker'
# Plant a backdated directive by hand (so we don't need to wait N minutes
# for real time to pass — the stall threshold is 5 min, default).
NOW_BACK=$(date -u -v-2H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "2 hours ago" +"%Y-%m-%dT%H:%M:%SZ")
printf '{"id":"D042","target":"TSEED","directive":"amend","note":"backdated stall fixture","from":"t352-fixture","ts":"%s","read":false}\n' "$NOW_BACK" >> "$DIRECTIVES"

# Resume must show D042 and a `!` marker, with an age of ~120 min and
# the "STALL" count ≥ 1.  Use --threshold 0 to make this deterministic
# in any timezone without changing the source — we just check the surface
# surfaces a stall-shaped line, not the exact count.
RESUME_OUT=$(RESUME_STALL_MIN=0 "$MG" resume 2>/dev/null)
if echo "$RESUME_OUT" | grep -q "D042" && \
   echo "$RESUME_OUT" | grep -q "pending directives" && \
   echo "$RESUME_OUT" | grep -qE "STALL"; then
    echo "    PASS: D042 appears in resume with STALL marker"
    echo "$RESUME_OUT" | grep -A 1 "pending directives" | head -4 | sed 's/^/      /'
else
    echo "    FAIL: D042 / STALL not in resume output:"
    echo "$RESUME_OUT" | sed 's/^/      /'
    FAIL=1
fi

# Sanity: an acked directive is NOT shown in the resume (the acked
# D<TELL_DID> from control 2 is filtered).  Resume says "none" if all
# directives are read.
if echo "$RESUME_OUT" | grep -q "$TELL_DID"; then
    echo "    FAIL: acked directive $TELL_DID still appears in resume — read flag not honoured"
    FAIL=1
else
    echo "    PASS: acked directive $TELL_DID is filtered out of resume"
fi

# ── 4. cross-check: the INBOX LOOP paragraph is in both dispatch prompts ─
# The prompt is the only thing a worker reads at the start; if the rule
# is not there, the worker has no way to know to poll.  Both
# bin/subagent and bin/ollama-subagent MUST carry the paragraph, AND
# the paragraph MUST mention the worker-instruction command
# (managent inbox <id> --ack).  A regression in either script is the
# exact failure mode T352 names: the worker is silent, the human
# relay returns by default.
echo ""
echo "  4. cross-check: INBOX LOOP paragraph in the dispatch prompt"
# T440/T441: T437 merged the subagent pair behind `--provider`, so the injected
# prompt lives in bin/subagent alone; bin/ollama-subagent is now a thin
# backward-compat wrapper that carries no prompt text. Assert against the
# script that actually builds the prompt — checking the wrapper tested nothing
# and was red for that reason, not because the paragraph had regressed.
SUBAGENT="$PROJECT/bin/subagent"
# Still needed by arm 5, which dry-runs the wrapper end-to-end: the
# wrapper carries no prompt text of its own but must still RENDER it by
# delegating to bin/subagent.
OLLAMA_SUBAGENT="$PROJECT/bin/ollama-subagent"
for s in "$SUBAGENT"; do
    if [ ! -f "$s" ]; then
        echo "    FAIL: $s missing"
        FAIL=1
        continue
    fi
    HAS_PARA=0
    HAS_INBOX_CMD=0
    HAS_CHECKPOINTS=0
    if grep -q "INBOX LOOP" "$s"; then HAS_PARA=1; fi
    if grep -q "managent inbox" "$s"; then HAS_INBOX_CMD=1; fi
    if grep -q "natural checkpoint\|after a commit\|before reporting done" "$s"; then HAS_CHECKPOINTS=1; fi
    if [ "$HAS_PARA" -eq 1 ] && [ "$HAS_INBOX_CMD" -eq 1 ] && [ "$HAS_CHECKPOINTS" -eq 1 ]; then
        echo "    PASS $s: INBOX LOOP paragraph present, mentions 'managent inbox', names natural checkpoints"
    else
        echo "    FAIL $s: paragraph=$HAS_PARA inbox-cmd=$HAS_INBOX_CMD checkpoints=$HAS_CHECKPOINTS"
        FAIL=1
    fi
done

# ── 5. dry-run shows the prompt carries the paragraph (worker would see it) ─
# A worker console does not run --dry-run, but the prompt content is
# what they receive.  Verify the rendered dispatch prompt includes the
# INBOX LOOP paragraph so a console that follows the documented protocol
# sees the instruction.
echo ""
echo "  5. dry-run renders the inbox-loop paragraph in the dispatch prompt"
# Synthetic bundle for the dry-run (re-create it for the duration of the test)
BUNDLE="$PROJECT/untracked/T997-inbox-loop-dryrun.md"
rm -f "$BUNDLE"
printf '<!--managent set=G deliverables=findings/T997-test.json-->\n# T997 — dry-run\n' > "$BUNDLE"
trap 'rm -f "$BUNDLE" "$WORK/worker-act-on-D"*.log; rm -rf "$WORK"' EXIT
OUT=$("$OLLAMA_SUBAGENT" T997 --model minimax-m3 --dry-run 2>&1)
if echo "$OUT" | grep -q "INBOX LOOP" && \
   echo "$OUT" | grep -q "managent inbox T997 --ack"; then
    echo "    PASS: dry-run prompt includes 'INBOX LOOP' and 'managent inbox T997 --ack'"
else
    echo "    FAIL: dry-run prompt missing inbox-loop paragraph"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── 6. T441: targetless --ack is REFUSED ────────────────────────────
# The pre-T441 code path matched target.len==0 to every row. The fix
# refuses targetless ack unless --all is given.
echo ""
echo "  6. seeded: targetless --ack is REFUSED (T441 ack scope)"
OUT=$("$MG" inbox --ack 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "would mark every row"; then
    echo "    PASS: targetless --ack refused (RC=$RC), message names the risk"
else
    echo "    FAIL: expected refusal with 'would mark every row', got RC=$RC:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── 7. T441: --all --ack acks across all targets ─────────────────────
# Plant a directive for TSEED, then ack it with --all.echo ""
echo "  7. seeded: --all --ack acks all targets (T441 ack scope)"
"$MG" tell TSEED amend --note "test-for-all-ack" --from T441-test 2>/dev/null
ALL_ACK_OUT=$("$MG" inbox --all --ack 2>/dev/null)
ALL_RC=$?
if [ "$ALL_RC" -eq 0 ] && echo "$ALL_ACK_OUT" | grep -q "acked"; then
    ACKED_COUNT=$(echo "$ALL_ACK_OUT" | grep -oE 'acked [0-9]+ directive' | grep -oE '[0-9]+')
    if [ "$ACKED_COUNT" -gt 0 ]; then
        echo "    PASS: --all --ack succeeded, acked $ACKED_COUNT directive(s)"
    else
        echo "    FAIL: --all --ack reported 0 directives acked (expected > 0)"
        FAIL=1
    fi
else
    echo "    FAIL: --all --ack failed (RC=$ALL_RC):"
    echo "$ALL_ACK_OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── 8. T441: read_by + read_at attribution on acked directives ───────
# Plant a fresh directive, ack it with MANAGENT_TASK_ID set, and verify
# the directive record carries read_by and read_at.
echo ""
echo "  8. seeded: ack records read_by + read_at (T441 read attribution)"
"$MG" tell TSEED amend --note "test-read-attribution" --from T441-test 2>/dev/null
export MANAGENT_TASK_ID=T441
"$MG" inbox TSEED --ack 2>/dev/null
unset MANAGENT_TASK_ID
if grep -q "read_by.*T441" "$DIRECTIVES" && grep -q "read_at" "$DIRECTIVES"; then
    echo "    PASS: directives.jsonl carries read_by:T441 and read_at timestamp"
else
    echo "    FAIL: read_by or read_at missing from directives.jsonl"
    grep "test-read-attribution" "$DIRECTIVES" | head -1 | sed 's/^/      /'
    FAIL=1
fi

# ── 9. T441: liveness shows UNKNOWN — no assertion for never-beat rows ─
# Verify that the liveness output uses "UNKNOWN — no assertion" not "never beat".
echo ""
echo "  9. seeded: liveness shows UNKNOWN — no assertion (T441 unasserted status)"
LIVE_OUT=$("$MG" liveness 2>/dev/null)
if echo "$LIVE_OUT" | grep -q "UNKNOWN.*no assertion"; then
    echo "    PASS: liveness uses 'UNKNOWN — no assertion' for rows without heartbeats"
else
    echo "    FAIL: liveness output missing 'UNKNOWN — no assertion'"
    echo "$LIVE_OUT" | grep -i "never beat" | sed 's/^/      /'
    FAIL=1
fi
if echo "$LIVE_OUT" | grep -q "never beat"; then
    echo "    FAIL: liveness still uses 'never beat' (must be 'UNKNOWN — no assertion')"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-inbox-loop: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-inbox-loop: FAILURES ==="
    exit 1
fi
