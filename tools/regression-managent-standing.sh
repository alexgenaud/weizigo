#!/usr/bin/env bash
# regression-managent-standing.sh — T294 controls for `managent standing`'s
# STANDING-ABSORB trigger; T368 extends: marker re-pointing, the loud-failure
# class kill, the C3 (STANDING-REEVIDENCE) reading + growth control, and the
# archive absorption refusal (same claimlint C7 parse family).
#
# Before T294 the standing mechanism had NO controls at all: the four
# pre-existing triggers ran in production with nothing proving they fire when
# they should or stay silent when they should. STANDING-ABSORB (the C7
# unabsorbed-findings trigger) ships with the pair the brief demands:
#
#   null control     C7 at/below the threshold (here: empty findings/ → C7=0)
#                    → the trigger does NOT fire, and `managent standing` SAYS
#                    so ("at/below threshold, no trigger") rather than silence
#   seeded control   a synthetic unabsorbed finding pushes C7 over (6 claims
#                    not in the register → C7=6 > threshold 5) → the trigger
#                    FIRES, names the count, and registers STANDING-ABSORB as
#                    a dispatchable kanban task
#
# T368 adds the controls the marker-rotting incident class needs:
#
#   marker presence  a fresh claimlint run must carry every string managent's
#                    parser matches (C3/C7 summary labels, C7 detail item
#                    marker) — the next rename breaks THIS test, not the
#                    mechanism (the T356 incident: C7 read 0 for a day)
#   loud failure     a claimlint whose summary drifted away (stubbed) makes
#                    `managent standing` exit nonzero with UNRELIABLE readings
#                    — a missing marker is never a silent 0
#   C3 reading       the repointed C3 marker reads claimlint's own count
#   C3 growth        C3 debt growth fires STANDING-REEVIDENCE
#   archive refusal  `managent archive --dry-run` refuses a done task whose
#                    findings are unabsorbed (T319's parser was silently dead)
#
# The count is exercised against claimlint's OWN summary (the same binary and
# the same parse the real command uses) — the control never reimplements the
# count, it asserts the trigger reacts to it.
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban, live
# findings/, and live CLAIMS.md are never touched. MANAGENT_STORE points at a
# scratch kanban and the command is invoked from the scratch repo, so
# findRepoRoot resolves there. bin/weizigo-claimlint is copied in so
# `managent standing`'s internal claimlint run works against the scratch
# findings/ and register.
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent (built, not yet
# deployed — same convention as regression-managent-resume.sh) → bin/managent.
# SKIP (loudly) when no binary carries the standing command, or when the real
# repo's bin/weizigo-claimlint is absent (the control cannot run without it) —
# a fresh clone without a build cannot run the control.
#
# Task: T294 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03
# T368: 2026-08-05 (marker re-point + loud-failure class kill)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# ── binary resolution ─────────────────────────────────────────────────────
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
if ! "$MG" help 2>&1 | grep -q "managent standing"; then
    echo "SKIP: $MG does not carry the standing command — rebuild from src/managent/main.zig"
    exit 0
fi
if [ ! -x "$PROJECT/bin/weizigo-claimlint" ]; then
    echo "SKIP: $PROJECT/bin/weizigo-claimlint not found — build with 'zig build' first (the standing control runs claimlint for real)"
    exit 0
fi

WORK="$(mktemp -d /tmp/weizigo/managent-standing-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t294@test
git config user.name T294
mkdir -p docs/infra/managent docs/infra/dispatch docs/epistemic findings untracked/msg bin

# claimlint must run against the scratch repo's own findings/ and register
cp "$PROJECT/bin/weizigo-claimlint" bin/

# Minimal register — 3 rows so claimlint's parse/index paths have content
# AND the C3 reading is nonzero (T368: the 11-column schema; every row is
# tierB — committed evidence, none under docs/evidence/ — so claimlint's
# C3 count is exactly the row count). None of the seeded claim IDs below
# exists in it, so every seeded claim is unabsorbed ("NO SUCH ID").
# Evidence file present so C2 stays quiet.
cat > docs/epistemic/CLAIMS.md <<'MDEOF'
# scratch register — T294/T368 standing control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `GLOBAL.SCRATCH1` | S1 | all | scratch row one | PROVEN | `scratch.md:1` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH2` | S2 | all | scratch row two | PROVEN | `scratch.md:2` | — | — | 0 | ? | Z- |
| `GLOBAL.SCRATCH3` | S3 | all | scratch row three | PROVEN | `scratch.md:3` | — | — | 0 | ? | Z- |
MDEOF
echo "scratch evidence" > scratch.md

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

git add -A
git commit -qm base

echo "=== managent standing regression (STANDING-ABSORB) ==="

# ── null control: C7 at/below threshold → no trigger, and it says so ────────
echo "  1. null control: empty findings/ → C7=0 ≤ threshold 5, no trigger, stated"
OUT=$("$MG" standing 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && \
   echo "$OUT" | grep -q "C7 unabsorbed: 0 (threshold 5)" && \
   echo "$OUT" | grep -q "at/below threshold, no trigger" && \
   ! echo "$OUT" | grep -q "TRIGGERED — absorption backlog" && \
   ! echo "$OUT" | grep -q "registered STANDING-ABSORB"; then
    echo "    PASS: count 0, explicit at/below-threshold statement, no registration, RC=0"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── null control 2: nothing may be registered in the scratch kanban ─────────
echo "  2. null control: STANDING-ABSORB not registered in the kanban"
if [ -f "$STORE" ] && grep -q "STANDING-ABSORB" "$STORE"; then
    echo "    FAIL: null control registered STANDING-ABSORB anyway:"
    grep -o "STANDING-ABSORB[^,}]*" "$STORE" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: kanban untouched by a below-threshold C7"
fi

# ── seeded control: 6 unabsorbed claims → C7=6 > 5, trigger fires, names it ─
echo "  3. seeded control: synthetic unabsorbed finding pushes C7 over the threshold"
cat > findings/T294SEED-absorb.json <<'JSONEOF'
{
  "task_id": "T294SEED",
  "date": "2026-08-03",
  "model": "deepseek-v4-flash",
  "claims": [
    "GLOBAL.SEED-ABSORB-1",
    "GLOBAL.SEED-ABSORB-2",
    "GLOBAL.SEED-ABSORB-3",
    "GLOBAL.SEED-ABSORB-4",
    "GLOBAL.SEED-ABSORB-5",
    "GLOBAL.SEED-ABSORB-6"
  ]
}
JSONEOF
OUT=$("$MG" standing 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && \
   echo "$OUT" | grep -q "C7 unabsorbed: 6 (threshold 5)" && \
   echo "$OUT" | grep -q "TRIGGERED — absorption backlog above threshold" && \
   echo "$OUT" | grep -q "registered STANDING-ABSORB" && \
   echo "$OUT" | grep -q "T294SEED-absorb.json: 6"; then
    echo "    PASS: count named (6), trigger fired, task registered, per-file composition surfaced"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── seeded control 2: the kanban actually carries the dispatchable task ─────
echo "  4. seeded control: STANDING-ABSORB is a registered dispatchable task"
if [ -f "$STORE" ] && grep -q '"STANDING-ABSORB"' "$STORE"; then
    echo "    PASS: STANDING-ABSORB present in the scratch kanban"
else
    echo "    FAIL: trigger said registered but the kanban does not carry it:"
    [ -f "$STORE" ] && sed 's/^/      /' "$STORE" || echo "      (no store file)"
    FAIL=1
fi

# ── seeded control 3: the auto-registered brief exists in the scratch repo ──
echo "  5. seeded control: brief file created next to the other standing briefs"
if [ -f "docs/infra/dispatch/STANDING-ABSORB.md" ]; then
    echo "    PASS: docs/infra/dispatch/STANDING-ABSORB.md created"
else
    echo "    FAIL: brief file missing"
    FAIL=1
fi

# ── T368 control 6: the markers managent parses exist in a real claimlint ──
# run. A claimlint output rename breaks THIS test before it can break the
# standing mechanism again (the T356 incident class: the rename passed
# because nothing asserted the exact strings). The strings must match
# src/managent/main.zig's parseSummaryCount labels and the C7 detail item
# marker exactly.
echo "  6. T368: markers managent parses are present in a real claimlint run"
CL_OUT=$("$PWD/bin/weizigo-claimlint" 2>/dev/null)
MARKER_OK=1
echo "$CL_OUT" | grep -q "== SUMMARY ==" || { echo "    FAIL: '== SUMMARY ==' block missing from claimlint output"; MARKER_OK=0; }
echo "$CL_OUT" | grep -q "C3 PROVEN w/o committed evid." || { echo "    FAIL: C3 summary marker 'C3 PROVEN w/o committed evid.' missing — repoint parseSummaryCount in src/managent/main.zig"; MARKER_OK=0; }
echo "$CL_OUT" | grep -q "C7 unabsorbed findings" || { echo "    FAIL: C7 summary marker 'C7 unabsorbed findings' missing"; MARKER_OK=0; }
echo "$CL_OUT" | grep -q "  C7 UNABSORBED  \`" || { echo "    FAIL: C7 detail item marker '  C7 UNABSORBED  \`' missing"; MARKER_OK=0; }
if [ "$MARKER_OK" -eq 1 ]; then
    echo "    PASS: all four markers present in claimlint output"
else
    FAIL=1
fi

# ── T368 control 7: a drifted claimlint format is a LOUD failure, never a ──
# silent 0. Stub claimlint with a summary that drifted away from the markers
# (the pre-T356 colon style, which killed C7 for a day) — standing must exit
# nonzero, print UNRELIABLE readings on stdout, and print a FATAL diagnostic
# on stderr. The real claimlint is restored immediately after.
echo "  7. T368: drifted claimlint format → standing exits nonzero with UNRELIABLE readings"
cp bin/weizigo-claimlint bin/weizigo-claimlint.real
cat > bin/weizigo-claimlint <<'STUBEOF'
#!/bin/sh
# T368 stub: claimlint whose summary format drifted away from managent's markers
echo "== C7  UNABSORBED FINDINGS (fails the run) =="
echo "  C7 unabsorbed findings: 6"
echo "== SUMMARY =="
echo "  C3: 3"
echo "  C7 unabsorbed findings: 6   (FAILS)"
exit 1
STUBEOF
chmod +x bin/weizigo-claimlint
OUT7=$("$MG" standing 2>/dev/null)
RC7=$?
ERR7=$("$MG" standing 2>&1 >/dev/null)
if [ "$RC7" -ne 0 ] && echo "$OUT7" | grep -q "UNRELIABLE" && echo "$ERR7" | grep -q "FATAL"; then
    echo "    PASS: RC=$RC7, UNRELIABLE readings on stdout, FATAL diagnostic on stderr"
else
    echo "    FAIL: RC=$RC7, stdout:"; echo "$OUT7" | sed 's/^/      /'
    FAIL=1
fi
cp bin/weizigo-claimlint.real bin/weizigo-claimlint
chmod +x bin/weizigo-claimlint

# ── T368 control 8: the C3 reading is claimlint's own (repointed marker) ────
# The 3-row register is all tierB → claimlint C3 = 3. The seeded run above
# persisted prior=3, so this run must read 3 (was 3) and NOT fire (no growth).
echo "  8. T368: C3 reading equals claimlint's own count (3) and does not fire without growth"
OUT8=$("$MG" standing 2>/dev/null)
if [ $? -eq 0 ] && echo "$OUT8" | grep -q "C3 debt: 3 (was 3)" && ! echo "$OUT8" | grep -q "TRIGGERED — C3 debt grew"; then
    echo "    PASS: C3 debt read as 3 (was 3), no trigger without growth"
else
    echo "    FAIL: output:"; echo "$OUT8" | sed 's/^/      /'
    FAIL=1
fi

# ── T368 control 9: C3 debt growth fires STANDING-REEVIDENCE ───────────────
# (the C3 analog of the seeded C7 control: the trigger must FIRE on a seeded
# above-threshold input — here growth 3→4 with prior>0)
echo "  9. T368: C3 debt growth triggers STANDING-REEVIDENCE"
cat >> docs/epistemic/CLAIMS.md <<'MDEOF'
| `GLOBAL.SCRATCH4` | S4 | all | scratch row four | PROVEN | `scratch.md:4` | — | — | 0 | ? | Z- |
MDEOF
OUT9=$("$MG" standing 2>/dev/null)
if [ $? -eq 0 ] && \
   echo "$OUT9" | grep -q "C3 debt: 4 (was 3)" && \
   echo "$OUT9" | grep -q "TRIGGERED — C3 debt grew" && \
   echo "$OUT9" | grep -q "registered STANDING-REEVIDENCE"; then
    echo "    PASS: C3 3→4 fired and registered STANDING-REEVIDENCE"
else
    echo "    FAIL: output:"; echo "$OUT9" | sed 's/^/      /'
    FAIL=1
fi

# ── T368 controls 10/11: archive absorption refusal reads the same C7 ──────
# detail section. T319's parser looked for a task-ID token format that never
# existed in any claimlint output, so the refusal was silently dead; the new
# parse derives task IDs from the UNABSORBED items' "in <file>" lines per
# findings/README.md's <TASKID>-<slug>.json convention. The controls live
# here (not a new script) because wiring a new script would touch build.zig,
# which T369 owns; this script is already the claimlint-parse family.
# A separate scratch store isolates the archive run from the standing kanban.
echo " 10. T368: archive --dry-run refuses a done task with unabsorbed findings"
STORE2="$WORK/docs/infra/managent/tasks-archive.json"
cat > "$STORE2" <<'JSONEOF'
{"TARCH1":{"status":"done","agent":"test","bundle":"untracked/TARCH1.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:00:02Z","dispatched":null,"dispatched_to":null,"note":"archive control","acceptance":null,"claim_count":1}}
JSONEOF
cat > findings/TARCH1-test.json <<'JSONEOF'
{"task_id": "TARCH1", "date": "2026-08-05", "model": "deepseek-v4-flash", "claims": ["GLOBAL.SEED-NOT-ABSORBED"]}
JSONEOF
OUT10=$(MANAGENT_STORE="$STORE2" "$MG" archive --dry-run 2>&1)
if echo "$OUT10" | grep -q "1 unabsorbed findings" && ! echo "$OUT10" | grep -q "archivable: 1 row"; then
    echo "    PASS: TARCH1 refused (1 unabsorbed findings)"
else
    echo "    FAIL: output:"; echo "$OUT10" | sed 's/^/      /'
    FAIL=1
fi

echo " 11. T368: archive --dry-run archives the task once its findings are absorbed"
rm findings/TARCH1-test.json
OUT11=$(MANAGENT_STORE="$STORE2" "$MG" archive --dry-run 2>&1)
if echo "$OUT11" | grep -q "archivable: 1 row(s) TARCH1" && echo "$OUT11" | grep -q "0 unabsorbed findings"; then
    echo "    PASS: TARCH1 archivable, 0 unabsorbed findings"
else
    echo "    FAIL: output:"; echo "$OUT11" | sed 's/^/      /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-standing: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-standing: FAILURES ==="
    exit 1
fi
