#!/usr/bin/env bash
# regression-claim-lifecycle.sh — T424 controls for the five claim/close lifecycle flakes
#
# Five defects surfaced the week of 2026-08-08, all in the same lifecycle, all
# with the same symptom: the kanban disagrees with reality.
#
#   1. worked-without-claiming — T392/T395/T400/T404/T419 were worked and
#      committed while still reading `dispatchable`. An unclaimed row is
#      invisible to holdsConflict, so nothing protects its files from a second
#      writer. Fix: git-commit-mine refuses a commit whose named task is not
#      in_progress (--explicit is the loud, deliberate escape).
#   2. reopen refuses done rows — a post-close correction must be recordable
#      against the row. Fix: `amend --post-close <text>` records the follow-up
#      commit against the row (verdict untouched), and reopen's refusal on a
#      done row names amend instead of dead-ending.
#   3. add --note documented but ignored — the note was stored null. Fix:
#      cmdAdd captures --note (≤4 KiB), round-trips into the store and show.
#   4. claim-at-close — T390 added the 10s refusal, but --force remains the
#      silent routine escape (3 of 34 rows closed inside the window after the
#      gate landed; the store records no trace of the force). Fix: a forced
#      close records a FORCED amendment so the kanban tells the truth.
#   5. C10 VOLATILE over-counts paths inside fenced code blocks — build-command
#      illustrations (zig --cache-dir /tmp/...) are not evidence citations
#      (Orchestrator ruling on T422, D064). Fix: C10 skips fenced blocks.
#
# Arms (all exercised against a scratch store / scratch repo — never the live
# kanban; the claimlint arm uses a fixture doc created and removed in place):
#   0. null control: claim → work → close cycle succeeds, no added friction
#   1. seeded: commit under a dispatchable row REFUSED; in_progress PASSES;
#      done-row commit REFUSED naming amend; --explicit still commits (escape)
#   2. seeded: amend --post-close round-trips into the store + show; reopen on
#      a done row refuses naming amend; audit WARNs amended rows
#   3. seeded: add --note round-trips into the store + show; >4 KiB rejected
#   4. seeded: done --force inside the claim window records a FORCED amendment;
#      the same close WITHOUT --force is refused (T390 gate regression)
#   5. seeded: a /tmp path inside a fenced block NOT counted by C10 while the
#      same path in prose IS; fixture removed → output byte-identical baseline
#
# Task: T424 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-08
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19). The
# C10 fixture doc ($FIXTURE) was previously removed only in the EXIT
# trap; a SIGKILLed run left it in the live tree. T448 adds INT/TERM/HUP
# to the trap (safety net) and a start-up check that REFUSES to run if
# the fixture from a previous (killed) run is still present. SIGKILL
# bypasses traps, so the start-up check is the load-bearing half.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/zig-out/bin/managent"
CLAIMLINT="$PROJECT/zig-out/bin/weizigo-claimlint"
WRAP="$PROJECT/tools/git-commit-mine"
AGENT="deepseek-v4-flash"   # canonical model label (claim/done validate against the list)

FAIL=0

if ! test -x "$MG"; then
    echo "SKIP: $MG not found — build with 'zig build' first (same convention as the"
    echo "      claimlint and resume regressions)."
    exit 0
fi
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first."
    exit 0
fi

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/claim-lifecycle-XXXXXX)" || { echo "regression-claim-lifecycle.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
FIXTURE="$PROJECT/docs/evidence/C10-FENCE-SEEDED.md"
TMPDIR="$(mktemp -d /tmp/weizigo/claim-lifecycle-tmp-XXXXXX)" || { echo "regression-claim-lifecycle.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }

# T448 (kill-survival recursion guard): the arm below re-invokes
# `sh "$0"` to exercise the start-up check against a planted stale
# fixture. Without this guard the recursive invocation would run arm 5,
# plant the same fixture, and recurse until the OS killed the test
# (T448.2 observed 120s timeout in the volatile script, 2026-08-19).
CLAIMLINT_SKIP_KILL_SURVIVAL="${CLAIMLINT_SKIP_KILL_SURVIVAL:-0}"

# T448: start-up check. If a previous run was killed mid-arm-5 (the only
# arm that creates $FIXTURE), the seeded doc would still be in the live
# tree. Refuse to run until the operator inspects and removes it by hand.
# The trap (set below) covers INT/TERM/HUP; SIGKILL bypasses traps, so
# this check is the load-bearing half.
if [ -e "$FIXTURE" ]; then
    echo "regression-claim-lifecycle.sh: REFUSED — stale fixture from a previous run:" >&2
    echo "    $FIXTURE" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
    echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
    echo "Remove the file by hand (after inspecting it is fixture-shaped and not yours)" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi

# T448: trap on EXIT/INT/TERM/HUP — previously EXIT only. The startup
# check is the load-bearing guard; this trap is the safety net.
cleanup() { rm -rf "$WORK" "$TMPDIR" 2>/dev/null || true; rm -f "$FIXTURE"; }
trap cleanup EXIT INT TERM HUP

# T448 (kill-survival recursion guard, continued): if re-entered by the
# kill-survival arm with CLAIMLINT_SKIP_KILL_SURVIVAL=1 set, the
# recursive invocation must NOT run the arms (including the kill-survival
# arm itself, which would re-plant the fixture and recurse). It already
# hit the start-up check (above) and the trap (above) on the way in —
# both are what we are testing. Exit cleanly so the caller sees RC=3
# from the start-up refusal (when the fixture is present) or RC=0 from
# a clean re-entry (when the cleanup removed it).
if [ "$CLAIMLINT_SKIP_KILL_SURVIVAL" = "1" ]; then
    exit 0
fi

# ── scratch git repo (isolated from the live repo, like the T278 regression) ─
cd "$WORK"
git init -q
git config user.email t424@test
git config user.name T424
mkdir -p docs docs/infra/managent
# T485: the absorption done-gate runs claimlint on every gated close; the
# scratch repo must carry a claimlint binary + a parseable (empty) register.
mkdir -p bin docs/epistemic
cp "$CLAIMLINT" bin/weizigo-claimlint
cat > docs/epistemic/CLAIMS.md <<'CLAIMS_EOF'
# scratch register — done-gate control (T485)

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF
echo base > README.md
git add README.md
git commit -qm base

# managent's default store resolves to $WORK/docs/infra/managent/tasks.json
# because the repo root is found by walking up from cwd; git-commit-mine uses
# the same default. Both operate on the scratch store — never the live kanban.

echo ""
echo "=== regression-claim-lifecycle ==="

# ── arm 0: null control — claim → work → close, no added friction ──────────
echo "  0. null control: claim → work → close cycle"
cat > arm0-bundle.md <<'EOF'
<!--managent set=A deliverables=docs/arm0.md-->
EOF
echo "  arm0 work" > docs/arm0.md
OUT=$("$MG" add TLC-ARM0 --bundle arm0-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
OUT=$("$MG" claim TLC-ARM0 --agent "$AGENT" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: claim: $OUT"; FAIL=1; fi
OUT=$(MANAGENT_TASK_ID=TLC-ARM0 "$WRAP" docs/arm0.md -m "TLC-ARM0 work" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: in_progress commit refused (RC=$RC): $OUT"
    FAIL=1
else
    echo "    PASS: commit while in_progress succeeds (no new friction)"
fi
sleep 11   # pass the T390 claim-at-close window so the null close is unforced
OUT=$("$MG" done TLC-ARM0 --status pass 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: done refused (RC=$RC): $OUT"
    FAIL=1
else
    echo "    PASS: done closes the row, verdict pass"
fi

# ── arm 1: seeded — commit under a dispatchable row is refused ─────────────
echo "  1. seeded: commit under a dispatchable row refused"
cat > arm1-bundle.md <<'EOF'
<!--managent set=A deliverables=docs/arm1.md-->
EOF
echo "  arm1 work" > docs/arm1.md
OUT=$("$MG" add TLC-ARM1 --bundle arm1-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
# row is dispatchable — the exact worked-without-claiming shape
COMMITS_BEFORE=$(git rev-list --count HEAD)
OUT=$(MANAGENT_TASK_ID=TLC-ARM1 "$WRAP" docs/arm1.md -m "worked without claiming" 2>&1)
RC=$?
COMMITS_AFTER=$(git rev-list --count HEAD)
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: commit under a dispatchable row succeeded (RC=0) — the worked-"
    echo "          without-claiming defect: $OUT"
    FAIL=1
elif echo "$OUT" | grep -qi "in_progress" && [ "$COMMITS_AFTER" -eq "$COMMITS_BEFORE" ]; then
    echo "    PASS: refused, names the claim requirement, no commit created"
else
    echo "    FAIL: refusal or message wrong (RC=$RC, commits $COMMITS_BEFORE->$COMMITS_AFTER): $OUT"
    FAIL=1
fi
# the refusal must leave the index untouched
if [ -z "$(git diff --cached --name-only)" ]; then
    echo "    PASS: nothing staged by the refused invocation"
else
    echo "    FAIL: refused invocation left staged paths"
    FAIL=1
fi
# positive control: claim first, then the same commit succeeds
OUT=$("$MG" claim TLC-ARM1 --agent "$AGENT" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: claim: $OUT"; FAIL=1; fi
OUT=$(MANAGENT_TASK_ID=TLC-ARM1 "$WRAP" docs/arm1.md -m "TLC-ARM1 after claim" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: in_progress commit refused (RC=$RC): $OUT"
    FAIL=1
else
    echo "    PASS: same commit succeeds once claimed (claim is the precondition)"
fi
sleep 11
OUT=$("$MG" done TLC-ARM1 --status pass 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: done: $OUT"; FAIL=1; fi
# done-row commit: refused, and the refusal names amend (the post-close path).
# The row's own deliverables are all committed by now, so this arm uses a
# second bundle whose deliverables are still uncommitted and a hand-written
# store entry (status=done) — the wrapper's claim check reads the store; the
# real managent close already proved the store format above.
cat > arm1d-bundle.md <<'EOF'
<!--managent set=A deliverables=docs/arm1.md,docs/arm1b.md-->
EOF
cp docs/infra/managent/tasks.json "$TMPDIR/arm1-store.json"
cat > docs/infra/managent/tasks.json <<'JSON'
{"TLC-ARMDONE": {"bundle": "arm1d-bundle.md", "status": "done", "verdict": "pass"}}
JSON
echo "  arm1b post-close" > docs/arm1b.md
OUT=$(MANAGENT_TASK_ID=TLC-ARMDONE "$WRAP" docs/arm1b.md -m "post-close follow-up" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: commit under a done row succeeded (RC=0): $OUT"
    FAIL=1
elif echo "$OUT" | grep -qi "amend"; then
    echo "    PASS: done-row commit refused, names amend as the post-close path"
else
    echo "    FAIL: done-row refusal does not name amend (RC=$RC): $OUT"
    FAIL=1
fi
# --explicit remains the loud, deliberate escape (Orchestrator/worker mode)
OUT=$(MANAGENT_TASK_ID=TLC-ARMDONE "$WRAP" --explicit docs/arm1b.md -m "TLC-ARMDONE explicit escape" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: --explicit commits anyway (documented escape, not silent)"
else
    echo "    FAIL: --explicit escape broken (RC=$RC): $OUT"
    FAIL=1
fi
# restore the real scratch store for the managent arms that follow
cp "$TMPDIR/arm1-store.json" docs/infra/managent/tasks.json
# the hand-written-store arms leave docs/arm1b.md committed under the explicit
# commit; it is the test's own file, and arm 2 reads only TLC-ARM1's row.

# ── arm 2: seeded — post-close correction recordable against the row ───────
echo "  2. seeded: amend --post-close records a follow-up against the row"
OUT=$("$MG" amend TLC-ARM1 --post-close "D064-style follow-up landed in abc123" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: amend --post-close refused (RC=$RC): $OUT"
    FAIL=1
else
    if python3 -c "
import json,sys
d=json.load(open('docs/infra/managent/tasks.json'))
ams=d['TLC-ARM1'].get('amendments',[])
sys.exit(0 if any('post-close' in a and 'abc123' in a for a in ams) else 1)"; then
        echo "    PASS: amendment recorded in the store (post-close + follow-up commit)"
    else
        echo "    FAIL: amendment not recorded in the store"
        FAIL=1
    fi
fi
OUT=$("$MG" show TLC-ARM1 2>/dev/null)
if echo "$OUT" | grep -q "abc123"; then
    echo "    PASS: show displays the post-close amendment"
else
    echo "    FAIL: show does not display the amendment: $OUT"
    FAIL=1
fi
# reopen on a done row must refuse AND name amend (the T422 dead-end)
OUT=$("$MG" reopen TLC-ARM1 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: reopen succeeded on a done row (RC=0): $OUT"
    FAIL=1
elif echo "$OUT" | grep -qi "amend"; then
    echo "    PASS: reopen refuses a done row and names amend (no dead-end)"
else
    echo "    FAIL: reopen refusal does not name amend (RC=$RC): $OUT"
    FAIL=1
fi
# audit flags amended rows (the kanban must surface the correction)
OUT=$("$MG" audit 2>/dev/null)
if echo "$OUT" | grep -qi "amend" && echo "$OUT" | grep -q "TLC-ARM1"; then
    echo "    PASS: audit surfaces the amended row"
else
    echo "    FAIL: audit does not flag the amended row: $OUT"
    FAIL=1
fi

# ── arm 3: seeded — add --note round-trips ─────────────────────────────────
echo "  3. seeded: add --note round-trips"
cat > arm3-bundle.md <<'EOF'
<!--managent set=A deliverables=docs/arm3.md-->
EOF
OUT=$("$MG" add TLC-ARM3 --bundle arm3-bundle.md --note "context for the row" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
if python3 -c "
import json,sys
d=json.load(open('docs/infra/managent/tasks.json'))
n=d['TLC-ARM3'].get('note')
sys.exit(0 if n=='context for the row' else 1)"; then
    echo "    PASS: note stored on the row"
else
    echo "    FAIL: note not stored (documented flag that silently does nothing)"
    FAIL=1
fi
OUT=$("$MG" show TLC-ARM3 2>/dev/null)
if echo "$OUT" | grep -q "context for the row"; then
    echo "    PASS: show displays the note"
else
    echo "    FAIL: show does not display the note"
    FAIL=1
fi
# >4 KiB note rejected (mirrors dispatch's limit)
BIG="$(head -c 5000 /dev/zero | tr '\0' 'x')"
OUT=$("$MG" add TLC-ARM3BIG --bundle arm3-bundle.md --note "$BIG" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "4 KiB"; then
    echo "    PASS: >4 KiB note rejected"
else
    echo "    FAIL: oversized note accepted (RC=$RC): $OUT"
    FAIL=1
fi

# ── arm 4: seeded — forced close leaves a record; unforced close refused ───
echo "  4. seeded: claim-at-close — refused without --force, recorded with it"
cat > arm4-bundle.md <<'EOF'
<!--managent set=A deliverables=docs/arm4.md-->
EOF
echo "  arm4 work" > docs/arm4.md
OUT=$("$MG" add TLC-ARM4 --bundle arm4-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
OUT=$("$MG" claim TLC-ARM4 --agent "$AGENT" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: claim: $OUT"; FAIL=1; fi
OUT=$(MANAGENT_TASK_ID=TLC-ARM4 "$WRAP" docs/arm4.md -m "TLC-ARM4 work" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: commit: $OUT"; FAIL=1; fi
# claim and done within 10s: refused WITHOUT --force (T390 gate regression)
OUT=$("$MG" done TLC-ARM4 --status pass 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: done within the 10s window succeeded without --force: $OUT"
    FAIL=1
elif echo "$OUT" | grep -qi "claim"; then
    echo "    PASS: unforced within-window close refused, names the claim"
else
    echo "    FAIL: refusal message does not mention the claim (RC=$RC): $OUT"
    FAIL=1
fi
# with --force: closes AND records the force in the store (fix 4)
OUT=$("$MG" done TLC-ARM4 --status pass --force 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: --force close refused (RC=$RC): $OUT"
    FAIL=1
else
    if python3 -c "
import json,sys
d=json.load(open('docs/infra/managent/tasks.json'))
ams=d['TLC-ARM4'].get('amendments',[])
sys.exit(0 if any('FORCED' in a for a in ams) else 1)"; then
        echo "    PASS: forced close recorded as an amendment (the kanban tells the truth)"
    else
        echo "    FAIL: forced close left no record — the silent escape"
        FAIL=1
    fi
fi

# ── arm 5: seeded — C10 does not count paths inside fenced blocks ─────────
echo "  5. seeded: C10 fence skip (fenced path not counted, prose path counted)"
RAND_SUFFIX="t424-$(date +%s)-$$"
PROSE_PATH="/tmp/weizigo/c10-$RAND_SUFFIX-prose.json"
FENCED_PATH="/tmp/weizigo/c10-$RAND_SUFFIX-fenced.json"
mkdir -p /tmp/weizigo
cat > "$FIXTURE" <<EOF
# C10 fence fixture (T424 regression control — do not commit)

A prose evidence citation — this is a real citation and MUST be counted:

$PROSE_PATH

A build-command illustration inside a fenced block — this is NOT evidence
and must NOT be counted (Orchestrator ruling on T422):

\`\`\`
zig build --cache-dir $FENCED_PATH --global-cache-dir /tmp/weizigo/c10-$RAND_SUFFIX-other --femit-bin=/tmp/weizigo/c10-$RAND_SUFFIX-bin
\`\`\`
EOF
cd "$PROJECT"   # claimlint scans the working tree from the repo root (its Index walks cwd)
"$CLAIMLINT" > "$TMPDIR/fence.out" 2>/dev/null
C10_SECTION="$(awk '/^== C10/{f=1} /^== A /{f=0} f' "$TMPDIR/fence.out")"
if echo "$C10_SECTION" | grep -Fq "$PROSE_PATH"; then
    echo "    PASS: prose /tmp citation counted"
else
    echo "    FAIL: prose /tmp citation not in the C10 section"
    FAIL=1
fi
if echo "$C10_SECTION" | grep -Fq "$FENCED_PATH"; then
    echo "    FAIL: fenced-block path counted by C10 — the over-count defect:"
    echo "$C10_SECTION" | grep -F "$FENCED_PATH" | head -3
    FAIL=1
else
    echo "    PASS: fenced-block path NOT counted"
fi
# null: fixture removed → the paths vanish from the output entirely
rm -f "$FIXTURE"
"$CLAIMLINT" > "$TMPDIR/null.out" 2>/dev/null
if grep -Fq "$FENCED_PATH" "$TMPDIR/null.out" || grep -Fq "$PROSE_PATH" "$TMPDIR/null.out"; then
    echo "    FAIL: fixture paths still reported after fixture removal"
    FAIL=1
else
    echo "    PASS: fixture paths absent once the fixture doc is gone"
fi

# ── T432: console liveness is an ASSERTION — UNKNOWN, never absence ───────
# T432 (2026-08-20): status is an assertion carrying an author and a
# timestamp; a later assertion supersedes an earlier one; ABSENCE of an
# assertion is UNKNOWN, never "none". No tool may derive non-existence from
# silence — no heartbeat means no instrumentation, not no console (D054).
# Arms:
#   6 seeded: an in_progress row with no heartbeat and no assertion reads
#     "UNKNOWN — no assertion" in liveness AND in the doctor's report; none
#     of liveness/status/doctor output carries an absence-implication phrase.
#   7 null: an asserted-idle row shows its assertion (never UNKNOWN) in
#     status and drops out of liveness; a heartbeat row reads [beating],
#     never UNKNOWN; the assertion records its actor.
#   8 seeded: argus checklist's stale-in-progress proposed brief must not
#     say "reopen if dead" — absence never grounds to presume death.

echo "  6. seeded: unasserted row renders UNKNOWN — no assertion"
cd "$WORK"   # arm 5 left us in the live repo; the T432 arms must run from scratch
cat > arm6-bundle.md <<'EOF'
<!--managent set=C deliverables=docs/arm6.md-->
EOF
OUT=$("$MG" add T432-ARM6 --bundle arm6-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
OUT=$("$MG" claim T432-ARM6 --agent "$AGENT" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: claim: $OUT"; FAIL=1; fi

LIVE_OUT=$("$MG" liveness 2>/dev/null)
if echo "$LIVE_OUT" | grep -q "T432-ARM6  UNKNOWN.*no assertion"; then
    echo "    PASS: liveness renders the unasserted row UNKNOWN — no assertion"
else
    echo "    FAIL: liveness does not render T432-ARM6 as UNKNOWN — no assertion:"
    echo "$LIVE_OUT" | grep "T432-ARM6" | sed 's/^/        /'
    FAIL=1
fi

STATUS_OUT=$("$MG" status 2>/dev/null)
if echo "$LIVE_OUT$STATUS_OUT" | grep -qiE "no console|not running|presumed dead|reopen if dead|console dead|is dead"; then
    echo "    FAIL: liveness/status output carries an absence-implication phrase:"
    echo "$LIVE_OUT$STATUS_OUT" | grep -iE "no console|not running|presumed dead|reopen if dead|console dead|is dead" | sed 's/^/        /'
    FAIL=1
else
    echo "    PASS: liveness/status output carries no absence phrase"
fi

# doctor arm: scratch tree with copied binaries + minimal register (T442 pattern)
mkdir -p "$WORK/bin" "$WORK/docs/epistemic" "$WORK/findings"
cp "$PROJECT/bin/managent" "$WORK/bin/managent"
cp "$PROJECT/bin/argus" "$WORK/bin/argus"
cp "$PROJECT/bin/weizigo-claimlint" "$WORK/bin/weizigo-claimlint" 2>/dev/null || true
cat > "$WORK/docs/epistemic/CLAIMS.md" <<'CLAIMS_EOF'
# CLAIMS — scratch register for T432 doctor testing

**Created:** 2026-08-20

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `t432.scratch-row` | — | all | scratch row for T432 doctor liveness testing | PROVEN | AGENTS.md:1 | — | — | 0 | ? | Z-TEST |
CLAIMS_EOF
cat > "$WORK/findings/rejections.json" <<'REJ_EOF'
{"description": "scratch rejections registry for T432 doctor testing","rejections": []}
REJ_EOF
(cd "$WORK" && "$PROJECT/bin/argus" --mode doctor --root "$WORK" --report "$WORK/doctor-report.md" >/dev/null 2>&1)
if [ -s "$WORK/doctor-report.md" ] && grep -q "T432-ARM6 in_progress, UNKNOWN.*no assertion" "$WORK/doctor-report.md"; then
    echo "    PASS: doctor renders the unasserted row UNKNOWN — no assertion"
else
    echo "    FAIL: doctor report does not render T432-ARM6 as UNKNOWN — no assertion:"
    [ -f "$WORK/doctor-report.md" ] && grep "T432-ARM6" "$WORK/doctor-report.md" | sed 's/^/        /'
    FAIL=1
fi
if [ -f "$WORK/doctor-report.md" ] && grep -qiE "no console|not running|presumed dead|reopen if dead|console dead" "$WORK/doctor-report.md"; then
    echo "    FAIL: doctor report carries an absence-implication phrase:"
    grep -iE "no console|not running|presumed dead|reopen if dead|console dead" "$WORK/doctor-report.md" | sed 's/^/        /'
    FAIL=1
else
    echo "    PASS: doctor report carries no absence phrase"
fi

# ── arm 7: null — asserted-idle and heartbeat rows never read UNKNOWN ────
echo "  7. null: asserted-idle and heartbeat rows never read UNKNOWN"
cat > arm7-bundle.md <<'EOF'
<!--managent set=C deliverables=docs/arm7.md-->
EOF
OUT=$("$MG" add T432-ARM7 --bundle arm7-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
OUT=$(MANAGENT_TASK_ID=T432-ARM7 "$MG" assert T432-ARM7 done --note "T432 null arm: console idle by assertion" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: assert T432-ARM7 done refused (RC=$RC): $OUT"
    FAIL=1
else
    echo "    PASS: assert done records the assertion"
fi
if python3 -c "
import json,sys
ok=False
try:
    for l in open('docs/infra/assertion-ledger/assertions.jsonl'):
        o=json.loads(l)
        if o.get('object')=='T432-ARM7' and o.get('actor')=='T432-ARM7':
            ok=True
except Exception:
    pass
sys.exit(0 if ok else 1)"; then
    echo "    PASS: assertion attributed (actor=T432-ARM7)"
else
    echo "    FAIL: assertion not attributed to the asserting actor"
    FAIL=1
fi
STATUS_OUT=$("$MG" status 2>/dev/null)
if echo "$STATUS_OUT" | grep "T432-ARM7" | grep -q "(asserted:"; then
    echo "    PASS: status shows the asserted-idle row with its assertion"
else
    echo "    FAIL: status does not show (asserted: ...) for T432-ARM7:"
    echo "$STATUS_OUT" | grep "T432-ARM7" | sed 's/^/        /'
    FAIL=1
fi
if echo "$STATUS_OUT" | grep "T432-ARM7" | grep -q "UNKNOWN"; then
    echo "    FAIL: asserted-idle row still reads UNKNOWN in status"
    FAIL=1
else
    echo "    PASS: asserted-idle row does NOT say UNKNOWN in status"
fi
LIVE_OUT=$("$MG" liveness 2>/dev/null)
if echo "$LIVE_OUT" | grep -q "T432-ARM7"; then
    echo "    FAIL: asserted-idle row still listed by liveness"
    FAIL=1
else
    echo "    PASS: asserted-idle row dropped from liveness (not in_progress)"
fi
# heartbeat row: an affirmative signal reads [beating], never UNKNOWN
cat > arm7b-bundle.md <<'EOF'
<!--managent set=C deliverables=docs/arm7b.md-->
EOF
OUT=$("$MG" add T432-ARM8 --bundle arm7b-bundle.md 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: add: $OUT"; FAIL=1; fi
OUT=$("$MG" claim T432-ARM8 --agent "$AGENT" 2>&1)
if [ $? -ne 0 ]; then echo "    FAIL: claim: $OUT"; FAIL=1; fi
mkdir -p untracked
HB_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '{"identifier":"t432-null-arm","task":"T432-ARM8","ts":"%s","command":"sleep 1"}\n' "$HB_TS" >> untracked/heartbeat.jsonl
LIVE_OUT=$("$MG" liveness 2>/dev/null)
if echo "$LIVE_OUT" | grep "T432-ARM8" | grep -q "\[beating\]"; then
    echo "    PASS: heartbeat row reads [beating] — an affirmative signal"
else
    echo "    FAIL: heartbeat row does not read [beating]:"
    echo "$LIVE_OUT" | grep "T432-ARM8" | sed 's/^/        /'
    FAIL=1
fi
if echo "$LIVE_OUT" | grep "T432-ARM8" | grep -q "UNKNOWN"; then
    echo "    FAIL: heartbeat row still reads UNKNOWN"
    FAIL=1
else
    echo "    PASS: heartbeat row does NOT say UNKNOWN"
fi

# ── arm 8: seeded — checklist proposed brief never presumes death ────────
echo "  8. seeded: stale-in-progress proposed brief never presumes death"
cat > "$WORK/registry-t432.md" <<'REG_EOF'
# Argus checklist registry (T432 scratch)

## Slugs

| slug | check | baseline | baseline_date | baseline_run | grade | first_seen | citations |
| --- | --- | --- | --- | --- | --- | --- | --- |
| stale-in-progress | `bin/managent liveness` + `bin/managent status` — count in_progress tasks | 0 tasks in_progress | 2026-08-20 | `20260820Z-checklist` | must | 2026-08-20 | T432 |
REG_EOF
(cd "$WORK" && "$PROJECT/bin/argus" --mode checklist --root "$WORK" --checklist "$WORK/registry-t432.md" --log "$WORK/ckl-watchdog.md" --summary "$WORK/ckl-summary.md" >/dev/null 2>&1)
if [ -f "$WORK/ckl-watchdog.md" ] && grep -q "reopen if dead" "$WORK/ckl-watchdog.md"; then
    echo "    FAIL: proposed brief presumes death ('reopen if dead'):"
    grep "reopen if dead" "$WORK/ckl-watchdog.md" | sed 's/^/        /'
    FAIL=1
else
    echo "    PASS: proposed brief never says 'reopen if dead'"
fi
if [ -f "$WORK/ckl-watchdog.md" ] && grep -q "UNKNOWN.*no assertion" "$WORK/ckl-watchdog.md"; then
    echo "    PASS: proposed brief carries the UNKNOWN framing"
else
    echo "    FAIL: proposed brief lacks the UNKNOWN framing:"
    [ -f "$WORK/ckl-watchdog.md" ] && grep "proposed_brief" "$WORK/ckl-watchdog.md" | sed 's/^/        /'
    FAIL=1
fi

# restore the live-repo cwd the T448 arm expects ($0 is relative there)
cd "$PROJECT"

# ── T448: kill-survival — start-up check refuses stale fixture ────────────
# Plant a stale fixture doc (mimics a SIGKILLed previous run leaving
# residue in the live tree) and re-invoke the script in a child shell.
# The script must refuse with the expected exit code and name the stale
# path. This is the load-bearing half of T448 — the trap is the safety
# net, but SIGKILL bypasses traps, so the start-up check is what
# actually catches residue.
#
# We re-invoke with CLAIMLINT_SKIP_KILL_SURVIVAL=1 so the recursive
# invocation runs only the start-up check (and the cleanup), not the
# whole suite — otherwise it would re-run arm 5, plant the same
# fixture, and recurse (T448.2 observed 120s timeout in volatile).
echo ""
echo "  T448: kill-survival — start-up check refuses stale fixture"
cat > "$FIXTURE" <<'EOF'
# stale fixture (T448 arm — do not commit)
EOF
OUT=$( CLAIMLINT_SKIP_KILL_SURVIVAL=1 sh "$0" 2>&1 )
RC=$?
# The stale fixture is itself a live-tree fixture — remove it via the
# same path the trap uses.
cleanup >/dev/null 2>&1 || true
# Re-invoke after cleanup: must succeed again (proves the refusal was
# strictly caused by the stale fixture, not some other state).
OUT_CLEAN=$( CLAIMLINT_SKIP_KILL_SURVIVAL=1 sh "$0" 2>&1 )
RC_CLEAN=$?
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q "REFUSED.*stale fixture" && echo "$OUT" | grep -q "$FIXTURE"; then
    echo "    PASS: stale-fixture refusal — start-up check named the path (RC=3)"
else
    echo "    FAIL: stale-fixture refusal (RC=$RC, expected 3):"
    echo "$OUT" | sed 's/^/        /' | head -5
    FAIL=1
fi
if [ "$RC_CLEAN" -eq 3 ]; then
    echo "    FAIL: clean re-run still refused with stale-fixture code — cleanup didn't remove the residue"
    FAIL=1
else
    echo "    PASS: clean re-run did not refuse on stale-fixture grounds (RC=$RC_CLEAN)"
fi

# ── T448: null — live tree byte-identical after the full run ───────────
# After the suite completes, the live tree must carry no residue. We
# assert against the FIXTURE path specifically (a git-status --porcelain
# would catch unrelated user edits; this script only owns $FIXTURE).
if [ ! -e "$FIXTURE" ]; then
    echo "    PASS: $FIXTURE absent after the run"
else
    echo "    FAIL: $FIXTURE still present after the run:"
    ls -la "$FIXTURE" | sed 's/^/        /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-claim-lifecycle: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-claim-lifecycle: FAILURES ==="
    exit 1
fi
