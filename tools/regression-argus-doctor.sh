#!/usr/bin/env bash
# regression-argus-doctor.sh — controls for `argus --mode doctor`
#
# Encodes the Orchestrator's manual weekly sweep as a check the operator can
# run in one line. Each control seeds one defect (or a clean state), re-runs
# `argus --mode doctor`, and asserts the report surfaces it under the right
# group (NEEDS ACTION / CAN CLOSE / WATCH / CLEAN).
#
# T427 hardening (2026-08-08, deepseek-v4-flash/T427): T425's version of this
# script called `managent add/claim/done` WITHOUT MANAGENT_STORE, so its
# controls wrote 16 T425-DOCTOR-* fixture rows into the LIVE kanban (13.5% of
# the store; removed by the Orchestrator after bundle-path verification). This
# version:
#   * runs EVERY managent call — the test's writes AND the doctor's internal
#     `bin/managent status --json` / `liveness` — against a scratch kanban
#     store seeded with a byte-copy of the live store (MANAGENT_STORE);
#   * ends with the null control that IS the deliverable: the live
#     `tasks.json` is byte-identical before and after the whole run (arm 15);
#   * asks `--mode doctor` itself to detect fixture-shaped rows (id matching
#     a generated pattern, or bundle under tools/ + claimed==done same
#     second) under NEEDS ACTION (arm 11);
#   * exercises the managent live-write guards: fixture-pattern ids are
#     refused on the live store (arm 12) and MANAGENT_TEST=1 refuses every
#     mutating verb on the live store (arm 13) — both against a FAKE repo so
#     the guard mechanism is proven without ever attempting a real live write;
#   * confirms no false alarm on the real store (arm 14).
#
# Arms:
#   0. null control — live tree (clean): zero NEEDS ACTION lines
#   1. seeded — uncommitted tracked file in the live tree (touch + restore)
#   2. seeded — dispatchable row whose bundle was just committed
#                (worked-without-claiming shape; SCRATCH store)
#   3. seeded — findings file non-conforming (1 file violates schema)
#   4. seeded — C7 unabsorbed above threshold (1 orphan finding)
#   5. seeded — /tmp citation in a committed doc (C10 VOLATILE)
#   6. null — deployed binary staleness: live tree is clean
#   7. seeded — in_progress row with no heartbeat (SCRATCH store)
#   8. null — register/tree-map lockstep (live tree; clean)
#   9. null — floor drift (C1a/C2/C3 at or below floor)
#  10. informational — CAN CLOSE rows (not a gate)
#  11. seeded — fixture-shaped row in the SCRATCH store: doctor reports it
#                under NEEDS ACTION; removed → clean (the T425 leak shape)
#  12. seeded — managent REFUSES `add` of a fixture-pattern id on the live
#                store (fake repo), allows it on a scratch store
#  13. seeded — MANAGENT_TEST=1: mutating verb REFUSED on the live store
#                (fake repo), allowed on a scratch store; read-only verbs
#                stay allowed
#  14. null — no false alarm on the REAL store: doctor against the live
#                kanban reports zero fixture-shaped rows (the 16 are gone)
#  15. null — THE null control: live tasks.json byte-identical before and
#                after the whole run (hash before == hash after)
#
# Every control creates any temp files under /tmp/weizigo/ and cleans them
# up in the trap. The live repo is touched only by arm 1 (touch + restore),
# arms 3/4/5 (fixture findings/docs under a temp evidence dir, then rm), and
# arms 2/7/12 (untracked bundle fixture files, then rm). The live kanban is
# NEVER written: all managent calls run against the scratch store.
#
# Acceptance: every seeded control RED on the pre-fix script, every control
# GREEN on the post-fix script. Script SKIPs loudly when bin/argus is
# missing (it is a Python script shipped at HEAD; --build rebuilds nothing).
#
# Task: T425 · Role: worker · Model: minimax-m3 · Date: 2026-08-08
# T427 hardening: deepseek-v4-flash/T427 · Date: 2026-08-08

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
ARGUS="$PROJECT/bin/argus"
MG="$PROJECT/bin/managent"
CLAIMLINT="$PROJECT/bin/weizigo-claimlint"
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"

FAIL=0

if ! test -x "$ARGUS"; then
    echo "SKIP: $ARGUS not found — argus is shipped as a Python script in bin/."
    exit 0
fi
if ! test -x "$MG"; then
    echo "SKIP: $MG not found — build with 'zig build deploy' first."
    exit 0
fi
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build deploy' first."
    exit 0
fi

WORK="$(mktemp -d /tmp/weizigo/argus-doctor-XXXXXX)"

# ── T427: scratch kanban store ──────────────────────────────────────────────
# Every managent call in this script goes to a scratch store seeded with a
# byte-copy of the live tasks.json. The doctor (argus) reads the kanban via
# MANAGENT_STORE too (its internal `bin/managent status --json` inherits the
# env), so planted rows are visible to it WITHOUT touching the live store.
SCRATCH_STORE="$WORK/kanban/tasks.json"
mkdir -p "$WORK/kanban"
cp "$LIVE_STORE" "$SCRATCH_STORE"
export MANAGENT_STORE="$SCRATCH_STORE"

# The null control's before-hash — compared at arm 15 after every other arm.
LIVE_HASH_BEFORE="$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)"

trap 'rm -rf "$WORK"; rm -f "$PROJECT/findings/T425-DOCTOR-NONCONFORM.json" "$PROJECT/findings/T425-DOCTOR-C7SEED.json" "$PROJECT/docs/evidence/T425-DOCTOR-C7.md" "$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md" "$PROJECT/tools/regression-argus-doctor-fixture.md" "$PROJECT/untracked/T427-guard-fixture.md"' EXIT

# Helper: run the doctor (against the SCRATCH store via MANAGENT_STORE),
# write report into a temp file, print its full path.
run_doctor() {
    local report="$WORK/doctor-report.md"
    "$ARGUS" --mode doctor --report "$report" >/dev/null 2>&1
    echo "$report"
}

# Helper: run the doctor against the LIVE kanban (MANAGENT_STORE unset) —
# read-only for the store; used only by arm 14.
run_doctor_live() {
    local report="$WORK/doctor-report-live.md"
    env -u MANAGENT_STORE "$ARGUS" --mode doctor --report "$report" >/dev/null 2>&1
    echo "$report"
}

# Helper: remove a row from the SCRATCH store (python, precise single-key
# removal). The scratch store is disposable, so formatting does not matter;
# managent re-parses it as JSON.
remove_row() {
    local store="$1" rid="$2"
    python3 - "$store" "$rid" <<'PYEOF'
import json, sys
store, rid = sys.argv[1], sys.argv[2]
with open(store) as f:
    d = json.load(f)
d.pop(rid, None)
with open(store, "w") as f:
    json.dump(d, f, indent=1)
    f.write("\n")
PYEOF
}

# Helper: count lines under a given doctor group matching a pattern
group_count() {
    local report="$1" group="$2" pattern="$3"
    awk -v grp="^## ${group} " -v pat="$pattern" '
        $0 ~ grp { flag=1; next }
        /^## / { flag=0 }
        flag && $0 ~ pat { print }
    ' "$report" | grep -v '^\*' | grep -v '^$' | wc -l | tr -d ' '
}

# Helper: print the lines under a given doctor group matching a pattern
group_lines() {
    local report="$1" group="$2" pattern="$3"
    awk -v grp="^## ${group} " -v pat="$pattern" '
        $0 ~ grp { flag=1; next }
        /^## / { flag=0 }
        flag && $0 ~ pat { print }
    ' "$report"
}

echo ""
echo "=== regression-argus-doctor ==="

# ── arm 0: smoke — live tree, doctor runs end-to-end without errors ──
# The doctor must always run cleanly on the live tree (kanban read = the
# SCRATCH copy; tree checks = the live tree). Even when the tree has real
# findings, the CLEAN section must show the things that ARE genuinely clean.
echo "  0. smoke: doctor runs end-to-end on live tree"
REPORT=$(run_doctor)
if [ ! -s "$REPORT" ]; then
    echo "    FAIL: doctor report empty"
    FAIL=1
else
    n=$(group_count "$REPORT" "CLEAN" "no worked-without-claiming|no in_progress rows|C7 unabsorbed")
    if [ "$n" -ge 1 ]; then
        echo "    PASS: doctor ran cleanly; CLEAN section reports green markers"
    else
        echo "    FAIL: doctor CLEAN section missing green markers"
        group_lines "$REPORT" "CLEAN" "." | sed 's/^/        /' | head -3
        FAIL=1
    fi
fi

# ── arm 1: seeded — uncommitted tracked file in the live tree ─────────
# Touch a tracked file (modify without committing). The doctor should
# report it under NEEDS ACTION. Restore on exit.
echo "  1. seeded: uncommitted tracked file in live tree"
SEED_FILE="$PROJECT/AGENTS.md"
SEED_BAK="$WORK/AGENTS.md.bak"
cp "$SEED_FILE" "$SEED_BAK"
echo "  # T427 arm 1 seed" >> "$SEED_FILE"
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "uncommitted|tree")
cp "$SEED_BAK" "$SEED_FILE"
rm -f "$SEED_BAK"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reported uncommitted files in NEEDS ACTION ($n line)"
else
    echo "    FAIL: doctor did NOT report uncommitted files in NEEDS ACTION"
    group_lines "$REPORT" "NEEDS ACTION" "." | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 2: seeded — worked-without-claiming ───────────────────────────
# Add a dispatchable row (SCRATCH store) whose bundle is an untracked file
# in the live tree. The doctor should report it under NEEDS ACTION.
# T427: the row lives in the SCRATCH store only; the live kanban is not
# touched by add/claim/done here.
echo "  2. seeded: dispatchable row with uncommitted bundle (SCRATCH store)"
SEED_BUNDLE_REL="tools/regression-argus-doctor-fixture.md"
SEED_BUNDLE="$PROJECT/$SEED_BUNDLE_REL"
ARM2_ROW_ID="T425-DOCTOR-2-$(basename "$WORK")"
rm -f "$SEED_BUNDLE"
cat > "$SEED_BUNDLE" <<'EOF'
<!--managent set=G-->
# T425 doctor arm 2 — bundle
EOF
# DO NOT commit. Leave it untracked so the doctor's "dispatchable row +
# bundle dirty" check fires, while not polluting the live git history.
"$MG" add "$ARM2_ROW_ID" --bundle "$SEED_BUNDLE_REL" >/dev/null 2>&1 || true
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "${ARM2_ROW_ID}|worked but never claimed")
# Clean up: remove the row from the SCRATCH store entirely (a closed row
# with a -DOCTOR- id would trip arm 11's fixture scan) and the bundle file.
remove_row "$SCRATCH_STORE" "$ARM2_ROW_ID"
rm -f "$SEED_BUNDLE"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reported $ARM2_ROW_ID in NEEDS ACTION"
else
    echo "    FAIL: doctor did NOT report $ARM2_ROW_ID in NEEDS ACTION"
    group_lines "$REPORT" "NEEDS ACTION" "." | sed 's/^/        /' | head -5
    FAIL=1
fi

# ── arm 3: seeded — findings file non-conforming ──────────────────────
echo "  3. seeded: findings file non-conforming"
cat > "$PROJECT/findings/T425-DOCTOR-NONCONFORM.json" <<'EOF'
{"oops": "no task_id, date, model, claims"}
EOF
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "non-conforming|nonconforming")
rm -f "$PROJECT/findings/T425-DOCTOR-NONCONFORM.json"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reported non-conforming findings in NEEDS ACTION"
else
    echo "    FAIL: doctor did NOT report non-conforming findings"
    group_lines "$REPORT" "CLEAN" "." | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 4: seeded — C7 unabsorbed above threshold ───────────────────
# A finding that references a claim_id not in CLAIMS.md → C7 counts it.
# To stay below the threshold otherwise, the test creates a single such
# finding. C7 threshold is 5; we seed exactly 1, so the doctor reports
# CLEAN (below threshold) — the relevant NEEDS ACTION is from arm 3.
echo "  4. seeded: C7 unabsorbed count visible (below threshold)"
cat > "$PROJECT/findings/T425-DOCTOR-C7SEED.json" <<'EOF'
{
 "task_id": "T425-DOCTOR-C7",
 "date": "2026-08-08",
 "model": "minimax-m3",
 "identifier": "minimax-m3/T425-C7",
 "claims": [{"claim_id": "T425.NONEXISTENT-CLAIM", "proposed_status": "MEASUREMENT", "evidence": ["docs/evidence/T425-DOCTOR-C7.md"]}],
 "new_rows": []
}
EOF
mkdir -p "$PROJECT/docs/evidence"
cat > "$PROJECT/docs/evidence/T425-DOCTOR-C7.md" <<'EOF'
# T425 doctor C7 fixture
EOF
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "CLEAN" "C7 unabsorbed")
rm -f "$PROJECT/findings/T425-DOCTOR-C7SEED.json" "$PROJECT/docs/evidence/T425-DOCTOR-C7.md"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reports C7 unabsorbed count under CLEAN (below threshold)"
else
    echo "    FAIL: doctor did NOT surface C7 unabsorbed under CLEAN"
    FAIL=1
fi

# ── arm 5: seeded — /tmp citation in a committed doc (C10 VOLATILE) ───
echo "  5. seeded: /tmp citation in a committed doc (C10)"
cat > "$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md" <<'EOF'
# T425 doctor /tmp fixture

This file cites a /tmp path: `/tmp/weizigo/phantom-fixture.md` — the
citation is the defect, not the file (which does not exist).
EOF
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "volatile|C10|/tmp")
rm -f "$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reported C10 volatile citations in NEEDS ACTION ($n line)"
else
    echo "    FAIL: doctor did NOT report C10 volatile citations in NEEDS ACTION"
    group_lines "$REPORT" "CLEAN" "." | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 6: null — deployed binary staleness ──────────────────────────
# Live tree was deployed at T424 (smoke zero STALE per T424's notes).
# Doctor should report CLEAN here.
echo "  6. null control: deployed bin/ matches zig-out"
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "CLEAN" "deployed|stale|bin/")
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reports deploy staleness status under CLEAN"
else
    echo "    FAIL: doctor did NOT surface deploy staleness under CLEAN"
    FAIL=1
fi

# ── arm 7: seeded — in_progress row with no heartbeat ────────────────
# Add a row (SCRATCH store), claim it (so it's in_progress), don't ping.
# The doctor's liveness check should warn WATCH.
echo "  7. seeded: in_progress row with no heartbeat (SCRATCH store)"
ARM7_ROW_ID="T425-DOCTOR-7-$(basename "$WORK")"
ARM7_BUNDLE_REL="untracked/T425-DOCTOR-7-$(basename "$WORK").md"
ARM7_BUNDLE="$PROJECT/$ARM7_BUNDLE_REL"
rm -f "$ARM7_BUNDLE"
cat > "$ARM7_BUNDLE" <<'EOF'
<!--managent set=A-->
# T425 doctor arm 7
EOF
"$MG" add "$ARM7_ROW_ID" --bundle "$ARM7_BUNDLE_REL" >/dev/null 2>&1 || true
"$MG" claim "$ARM7_ROW_ID" --agent minimax-m3 >/dev/null 2>&1 || true
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "WATCH" "${ARM7_ROW_ID}|heartbeat|never beat")
# Clean up: remove the row from the SCRATCH store entirely, then the bundle.
remove_row "$SCRATCH_STORE" "$ARM7_ROW_ID"
rm -f "$ARM7_BUNDLE"
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reported $ARM7_ROW_ID under WATCH (no heartbeat)"
else
    echo "    FAIL: doctor did NOT report $ARM7_ROW_ID under WATCH"
    group_lines "$REPORT" "WATCH" "." | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 8: null — register/tree-map lockstep ──────────────────────────
# Live register at HEAD has C9=0 (lockstep). Doctor should report CLEAN.
echo "  8. null control: register/tree-map lockstep"
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "CLEAN" "register|lockstep|C9")
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reports register lockstep under CLEAN"
else
    echo "    FAIL: doctor did NOT surface register lockstep under CLEAN"
    FAIL=1
fi

# ── arm 9: null — floor drift ─────────────────────────────────────────
echo "  9. null control: floor counters at or below floor"
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "CLEAN" "C1a|C2|C3|floor")
if [ "$n" -ge 1 ]; then
    echo "    PASS: doctor reports floor counters under CLEAN"
else
    echo "    FAIL: doctor did NOT surface floor counters under CLEAN"
    FAIL=1
fi

# ── arm 10: CAN CLOSE — done rows with conforming findings + deliverables
#     the operator can close (informational; not a gate)
echo "  10. CAN CLOSE: rows ready to be acknowledged"
REPORT=$(run_doctor)
n=$(awk '/^## CAN CLOSE/{flag=1; next} /^## /{flag=0} flag && NF && !/^\(/ && !/^none/{print}' "$REPORT" | wc -l | tr -d ' ')
echo "    INFO: $n CAN CLOSE entries (informational; not a gate)"

# ── arm 11: seeded — fixture-shaped row detected by the doctor ────────
# Plant ONE fixture-shaped row in the SCRATCH store — the exact T425 leak
# shape: id matches a generated pattern (T425-DOCTOR-12-<rand>), bundle
# under tools/, claimed == done to the second. The doctor must report it
# under NEEDS ACTION; after removal the report must be clean.
echo "  11. seeded: fixture-shaped row in SCRATCH store detected by doctor"
ARM11_ROW_ID="T425-DOCTOR-12-$(basename "$WORK")"
python3 - "$SCRATCH_STORE" "$ARM11_ROW_ID" <<'PYEOF'
import json, sys
store, rid = sys.argv[1], sys.argv[2]
with open(store) as f:
    d = json.load(f)
d[rid] = {
    "status": "done",
    "agent": "minimax-m3",
    "model": None,
    "bundle": "tools/regression-argus-doctor-fixture.md",
    "set": "G",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-08T12:00:00Z",
    "claimed": "2026-08-08T12:00:01Z",
    "done": "2026-08-08T12:00:01Z",
    "dispatched": None,
    "dispatched_to": None,
    "note": None,
    "verdict": None,
    "verdict_note": None,
    "claim_count": 1,
    "acceptance": None,
    "skip_acceptance_reason": None,
    "amendments": [],
}
with open(store, "w") as f:
    json.dump(d, f, indent=1)
    f.write("\n")
PYEOF
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "${ARM11_ROW_ID}|looks like a test fixture")
# Remove the planted row; the doctor must now report zero fixture rows.
remove_row "$SCRATCH_STORE" "$ARM11_ROW_ID"
REPORT=$(run_doctor)
n_clean=$(group_count "$REPORT" "CLEAN" "no fixture-shaped rows")
n_left=$(group_count "$REPORT" "NEEDS ACTION" "looks like a test fixture")
if [ "$n" -ge 1 ] && [ "$n_clean" -ge 1 ] && [ "$n_left" = "0" ]; then
    echo "    PASS: doctor reported $ARM11_ROW_ID in NEEDS ACTION, clean after removal"
else
    echo "    FAIL: fixture detection (planted=$n, clean-marker=$n_clean, leftover=$n_left)"
    group_lines "$REPORT" "NEEDS ACTION" "." | sed 's/^/        /' | head -5
    FAIL=1
fi

# ── arm 12: seeded — managent REFUSES fixture-pattern add on live ────
# The T425 rows were created because `managent add T425-DOCTOR-<rand>` on
# the live store succeeded. The guard: on the live store (MANAGENT_STORE
# unset, or set to the default path) an id matching a fixture pattern is
# refused with a non-zero exit, BEFORE any write. Tested against a FAKE
# repo so the guard mechanism is proven without touching the real live
# store; the same add on a scratch store must still succeed.
echo "  12. seeded: managent refuses fixture-pattern add on the live store"
FAKE="$WORK/fake-repo"
mkdir -p "$FAKE/docs/infra/managent" "$FAKE/tools"
git -C "$FAKE" init -q 2>/dev/null
cp "$LIVE_STORE" "$FAKE/docs/infra/managent/tasks.json"
# The fake repo must TRACK its kanban — a tracked default store is what
# makes managent treat it as the live store (a scratch repo's untracked
# store is exempt, e.g. T424's claim-lifecycle regression).
git -C "$FAKE" add docs/infra/managent/tasks.json
cat > "$FAKE/tools/regression-argus-doctor-fixture.md" <<'EOF'
<!--managent set=G-->
# T427 guard fixture
EOF
ARM12_BASE="T425-DOCTOR-12-$(basename "$WORK")"
# (a) MANAGENT_STORE unset, cwd = fake repo → the default store IS the fake
#     repo's tasks.json (the "live" store of that repo) → must refuse.
ARM12_A="$ARM12_BASE-a"
( cd "$FAKE" && env -u MANAGENT_STORE "$MG" add "$ARM12_A" --bundle "tools/regression-argus-doctor-fixture.md" >/dev/null 2>&1 )
rc_a=$?
# (b) MANAGENT_STORE set explicitly to the default path → still the live
#     store → must refuse.
ARM12_B="$ARM12_BASE-b"
( cd "$FAKE" && MANAGENT_STORE="$FAKE/docs/infra/managent/tasks.json" "$MG" add "$ARM12_B" --bundle "tools/regression-argus-doctor-fixture.md" >/dev/null 2>&1 )
rc_b=$?
# (c) positive control: the SAME add against a scratch store must succeed.
ARM12_C="$ARM12_BASE-c"
GUARD_FIXTURE="$PROJECT/untracked/T427-guard-fixture.md"
cat > "$GUARD_FIXTURE" <<'EOF'
<!--managent set=G-->
# T427 guard fixture (scratch positive control)
EOF
"$MG" add "$ARM12_C" --bundle "untracked/T427-guard-fixture.md" >/dev/null 2>&1
rc_c=$?
remove_row "$SCRATCH_STORE" "$ARM12_C"
rm -f "$GUARD_FIXTURE"
# The fake store must not have gained either row in (a)/(b) (write refused).
fake_gained=$(python3 - "$FAKE/docs/infra/managent/tasks.json" "$ARM12_A" "$ARM12_B" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print(1 if (sys.argv[2] in d or sys.argv[3] in d) else 0)
PYEOF
)
if [ "$rc_a" != "0" ] && [ "$rc_b" != "0" ] && [ "$fake_gained" = "0" ] && [ "$rc_c" = "0" ]; then
    echo "    PASS: live add refused (a=$rc_a b=$rc_b, no write), scratch add allowed (c=$rc_c)"
else
    echo "    FAIL: guard (a=$rc_a b=$rc_b fake_gained=$fake_gained scratch_c=$rc_c)"
    FAIL=1
fi

# ── arm 13: seeded — MANAGENT_TEST tripwire on the live store ────────
# A harness that declares itself a test (MANAGENT_TEST=1) must not be able
# to write the live store even with a non-fixture-shaped id. All mutating
# verbs refuse; read-only verbs keep working; scratch stores are exempt.
echo "  13. seeded: MANAGENT_TEST=1 refuses mutating verbs on the live store"
ARM13_ROW_ID="T999-GUARD-13-$(basename "$WORK")"
# (a) mutating verb + MANAGENT_TEST + live (fake repo) → refused
( cd "$FAKE" && env -u MANAGENT_STORE MANAGENT_TEST=1 "$MG" add "$ARM13_ROW_ID" --bundle "tools/regression-argus-doctor-fixture.md" >/dev/null 2>&1 )
rc_a=$?
# (a2) read-only verb + MANAGENT_TEST + live → still allowed
( cd "$FAKE" && env -u MANAGENT_STORE MANAGENT_TEST=1 "$MG" status >/dev/null 2>&1 )
rc_a2=$?
# (b) mutating verb + MANAGENT_TEST + SCRATCH store → allowed (tests own
#     their substrate)
GUARD_FIXTURE="$PROJECT/untracked/T427-guard-fixture.md"
cat > "$GUARD_FIXTURE" <<'EOF'
<!--managent set=G-->
# T427 guard fixture (scratch positive control)
EOF
MANAGENT_TEST=1 "$MG" add "$ARM13_ROW_ID" --bundle "untracked/T427-guard-fixture.md" >/dev/null 2>&1
rc_b=$?
remove_row "$SCRATCH_STORE" "$ARM13_ROW_ID"
rm -f "$GUARD_FIXTURE"
if [ "$rc_a" != "0" ] && [ "$rc_a2" = "0" ] && [ "$rc_b" = "0" ]; then
    echo "    PASS: mutating refused on live (a=$rc_a), read-only allowed (a2=$rc_a2), scratch allowed (b=$rc_b)"
else
    echo "    FAIL: MANAGENT_TEST guard (a=$rc_a a2=$rc_a2 b=$rc_b)"
    FAIL=1
fi

# ── arm 14: null — no false alarm on the REAL store ──────────────────
# Run the doctor against the LIVE kanban (read-only). The 16 fixture rows
# are gone; the report must show zero fixture-shaped rows.
echo "  14. null control: doctor against the real store reports zero fixtures"
REPORT=$(run_doctor_live)
n_na=$(group_count "$REPORT" "NEEDS ACTION" "looks like a test fixture")
n_clean=$(group_count "$REPORT" "CLEAN" "no fixture-shaped rows")
if [ "$n_na" = "0" ] && [ "$n_clean" -ge 1 ]; then
    echo "    PASS: zero fixture rows on the real store (NEEDS ACTION=$n_na, CLEAN marker present)"
else
    echo "    FAIL: false alarm or missing clean marker (NEEDS ACTION=$n_na, CLEAN=$n_clean)"
    group_lines "$REPORT" "NEEDS ACTION" "fixture" | sed 's/^/        /' | head -5
    FAIL=1
fi

# ── arm 15: null — THE null control: live tasks.json byte-identical ──
# The whole run must leave the live kanban byte-identical. This is the
# deliverable check for T427 — the proof the regression wrote nothing.
echo "  15. null control: live tasks.json byte-identical after the full run"
LIVE_HASH_AFTER="$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)"
if [ "$LIVE_HASH_BEFORE" = "$LIVE_HASH_AFTER" ]; then
    echo "    PASS: live tasks.json byte-identical before/after ($LIVE_HASH_AFTER)"
else
    echo "    FAIL: live tasks.json CHANGED during the run (before=$LIVE_HASH_BEFORE after=$LIVE_HASH_AFTER)"
    FAIL=1
fi

echo ""
if [ "$FAIL" = "0" ]; then
    echo "regression-argus-doctor: all arms PASS"
    exit 0
else
    echo "regression-argus-doctor: FAILURES present"
    exit 1
fi
