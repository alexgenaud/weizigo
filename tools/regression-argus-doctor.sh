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
#  16. T441 — doctor console line derives from doctor groups
#  17. controlled — C7 above-threshold in a SCRATCH findings dir (controlled
#                counter) → doctor reports under NEEDS ACTION. Pairs with
#                arm 4 (null, controlled counter). Both arms test the doctor's
#                BEHAVIOUR under a controlled C7 count, not the live count
#                (the pre-T442 arm 4 was a state-dependent reading wearing a
#                test's clothes: it asserted "C7 unabsorbed" appeared under
#                CLEAN, which is only true when live C7 < 5 — so it went
#                red whenever the project had a backlog, regardless of the
#                doctor's own correctness).
#  18. informational — live C7 unabsorbed reading (operator-facing, never a
#                gate). The operator reads the live C7 from this line; the
#                suite never fails on it.
#  19. T448 — kill-survival self-check (start-up refusal) + arm 20 null
#  20. T448 — null: live tree byte-identical after the full run
#  21. T430 — seeded: ≥1 NEEDS ACTION item (controlled C7 seed) → console
#                verdict is NOT clean and exit status 1 distinguishes it
#  22. T430 — null: empty NEEDS ACTION → clean verdict, exit 0 (a fix that
#                prints "not clean" unconditionally must fail this one)
#  23. T430 — freshness: two consecutive --dry-run runs, the first seeds a
#                C7 finding the second does not — the second must NOT print
#                the first's finding (and must still print its own log)
#  24. T430 — permanent: a normal, non-fixture `add` on the live store still
#                SUCCEEDS and writes the row (a guard that refused every
#                live write would pass arms 12/13 while silently breaking
#                fleet registration)
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
# T442 de-state: arm 4 / 17. T448: startup check refuses to run if any
# fixture from a previous (killed) run still lives in the live tree —
# tools/runner SIGKILLs on wall/CPU/RSS/progress guards, so a stale
# fixture is the routine outcome, not an exotic one. arm 19 below is the
# kill-survival self-check; arm 20 is the byte-identical-tree null.
#
# Task: T425 · Role: worker · Model: minimax-m3 · Date: 2026-08-08
# T427 hardening: deepseek-v4-flash/T427 · Date: 2026-08-08
# T448: kill-survival + startup check (glm-5.2/T448, 2026-08-19)
# T430: doctor console-verdict arms (21/22) + --dry-run freshness (23) +
#       live non-fixture add positive control (24) (deepseek-v4-flash/T430, 2026-08-20)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"

# ── T448: --check-fixtures-only ──────────────────────────────────────────
# A no-arms mode that runs ONLY the stale-fixture startup check and exits.
# Used by arm 19 (kill-survival self-check) to assert the check is real
# without re-running the whole suite. Anything that survives SIGKILL would
# be visible to a fresh run; this mode is the load-bearing half of the
# cleanup story — the trap is a safety net, but SIGKILL bypasses traps
# entirely, so the only honest guard is "refuse to start if anything
# looks like residue."
if [ "${1:-}" = "--check-fixtures-only" ]; then
    PROJECT="$PROJECT"
    # The static list is the source of truth (FIXTURE_PATHS below); --check
    # re-declares just enough of the check to assert it without sourcing
    # the whole script.
    STALE=0
    for p in \
        "$PROJECT/findings/T425-DOCTOR-NONCONFORM.json" \
        "$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md" \
        "$PROJECT/tools/regression-argus-doctor-fixture.md" \
        "$PROJECT/untracked/T427-guard-fixture.md"; do
        if [ -e "$p" ]; then echo "stale: $p" >&2; STALE=1; fi
    done
    if [ -f "$PROJECT/AGENTS.md" ] && grep -q "^  # T427 arm 1 seed$" "$PROJECT/AGENTS.md"; then
        echo "stale: $PROJECT/AGENTS.md (carries '  # T427 arm 1 seed' sentinel — arm 1 was killed mid-run)" >&2
        STALE=1
    fi
    if [ "$STALE" -ne 0 ]; then exit 3; fi
    exit 0
fi

ARGUS="$PROJECT/bin/argus"
MG="$PROJECT/bin/managent"
. "$PROJECT/tools/lib/scratch-repo.sh"   # T873: weizigo_reset_census for remove_row direct writes
CLAIMLINT="$PROJECT/bin/weizigo-claimlint"
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"

# ── T448: live-tree fixture registry ─────────────────────────────────────
# Every live-tree path this script creates (and the inline `rm -f` calls
# in each arm clean up on a normal exit). The trap removes them on
# EXIT/INT/TERM/HUP; the startup check below refuses to run if any of
# them is already present (evidence of a SIGKILLed previous run).
#
# Paths whose names include runtime values ($WORK, $BASHPID) cannot be
# in this static list — register them with `track_fixture` once computed.
declare -a FIXTURE_PATHS=(
    "$PROJECT/findings/T425-DOCTOR-NONCONFORM.json"
    "$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md"
    "$PROJECT/tools/regression-argus-doctor-fixture.md"
    "$PROJECT/untracked/T427-guard-fixture.md"
)
# arm 1 sentinel: AGENTS.md gets a `  # T427 arm 1 seed` line appended and
# restored inline by the arm. The inline restore uses $SEED_BAK which is
# under $WORK; if the process is killed mid-arm the restore never runs
# and AGENTS.md carries the sentinel. The startup check looks for the
# sentinel (the file always exists — checking for presence wouldn't help).
ARM1_SENTINEL='^  # T427 arm 1 seed$'

track_fixture() {
    # Register a live-tree fixture path whose name contains runtime
    # values (so it can't be in the static FIXTURE_PATHS list above).
    # Use this AFTER the variable is computed — usually right before
    # the arm's `cat > "$path" <<EOF`.
    FIXTURE_PATHS+=("$1")
}

# T448 startup check: refuse to run if any live-tree fixture from a
# previous run is still present. SIGKILL cannot be trapped at all, so
# the trap is a safety net for SIGINT/SIGTERM/SIGHUP only — this check
# is the load-bearing half. We refuse rather than silently overwrite,
# because overwriting hides the evidence (a stray fixture could be a
# real edit by another console; T445 staged 1659 files this way).
check_stale_fixtures() {
    local stale=()
    local p
    for p in "${FIXTURE_PATHS[@]}"; do
        if [ -e "$p" ]; then stale+=("$p"); fi
    done
    if [ -f "$PROJECT/AGENTS.md" ] && grep -qE "$ARM1_SENTINEL" "$PROJECT/AGENTS.md"; then
        stale+=("$PROJECT/AGENTS.md (carries the arm-1 sentinel — that arm was killed mid-run)")
    fi
    if [ "${#stale[@]}" -gt 0 ]; then
        echo "regression-argus-doctor.sh: REFUSED — stale live-tree fixture(s) from a previous run remain:" >&2
        local s
        for s in "${stale[@]}"; do echo "    $s" >&2; done
        echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
        echo "The startup check is the load-bearing guard — SIGKILL bypasses traps, and" >&2
        echo "tools/runner's SIGKILL on wall/CPU/RSS/progress guards is routine in this fleet." >&2
        echo "Remove the files by hand (after inspecting that they are fixture-shaped and not yours)" >&2
        echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
        exit 3
    fi
}

# T448 trap: named cleanup function so EXIT/INT/TERM/HUP share the same
# path. Order matters — restore AGENTS.md BEFORE removing $WORK (the
# backup lives there), and remove fixtures BEFORE removing $WORK (the
# arm 7 fixture lives under $PROJECT/untracked/, not $WORK, but the
# scratch FAKE repo's fixture does live under $WORK, and removing $WORK
# last is the safest order for everything).
cleanup() {
    # arm 1: restore AGENTS.md from the backup if the inline restore
    # didn't run. The inline restore at the end of the arm body handles
    # the common case; this is the safety net for signals that bypass
    # inline code but still let the trap run (SIGINT/SIGTERM/SIGHUP).
    if [ -n "${SEED_BAK:-}" ] && [ -f "${SEED_BAK}" ]; then
        cp "$SEED_BAK" "$PROJECT/AGENTS.md" 2>/dev/null || true
    fi
    local p
    for p in "${FIXTURE_PATHS[@]}"; do
        rm -f "$p"
    done
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM HUP

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

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/argus-doctor-XXXXXX)" || { echo "regression-argus-doctor.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }

# T448: refuse to run if a previous run left live-tree residue behind.
# Must run AFTER $WORK is created (cleanup depends on $WORK for the
# AGENTS.md backup restore) but BEFORE any arm touches the live tree.
check_stale_fixtures

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

# T448: trap (cleanup) is set above (right after the helper definitions).
# EXIT/INT/TERM/HUP all run the same cleanup function — restores AGENTS.md
# from $SEED_BAK (if present), removes every live-tree fixture in
# FIXTURE_PATHS, and finally removes $WORK. SIGKILL bypasses traps, so
# the startup check (check_stale_fixtures) is the load-bearing guard.

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
    weizigo_reset_census "$store"   # T873: direct removal bypasses the S10 census
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

# ── T442: scratch findings dir for controlled C7 testing ──────────────────
# The doctor reads `bin/weizigo-claimlint` with `cwd=str(self.root)`, and
# claimlint reads `findings/*.json` and `findings/rejections.json` and
# `docs/epistemic/CLAIMS.md` from cwd. Pass `--root <scratch-tree>` to make
# the doctor read everything from the scratch tree, not the live repo.
#
# The scratch tree must carry:
#   * bin/weizigo-claimlint (copy of the live one — the doctor's internal
#     _run uses cwd=str(root), and the script is invoked as bin/weizigo-claimlint
#     RELATIVE to that root)
#   * bin/argus (copy of the live Python script, same reason)
#   * bin/managent (the doctor calls managent status / liveness; on a scratch
#     tree we accept these as missing — the resulting WATCH lines are noise,
#     but the C7 finding is what arm 4 / arm 17 assert on)
#   * findings/ (initially empty for the null arm; seeded for the seeded arm)
#   * findings/rejections.json (valid JSON; the loader refuses malformed files)
#   * docs/epistemic/CLAIMS.md (a register with at least one backticked row
#     in the §2 register table; the header must carry 11 columns)
SCRATCH_TREE_ROOT="$WORK/scratch-tree"
SCRATCH_CLAIMS_REL="docs/epistemic/CLAIMS.md"
SCRATCH_FINDINGS_DIR="findings"

# Build a minimal scratch tree. Idempotent — arm 17 re-uses the tree and
# only adds / removes its seed findings file.
setup_scratch_tree() {
    mkdir -p "$SCRATCH_TREE_ROOT/bin" "$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR" "$SCRATCH_TREE_ROOT/docs/epistemic"
    # Copy the live binaries so the doctor's internal _run can find them.
    cp "$PROJECT/bin/weizigo-claimlint" "$SCRATCH_TREE_ROOT/bin/weizigo-claimlint" 2>/dev/null || true
    cp "$PROJECT/bin/weizigo-claimlint.real" "$SCRATCH_TREE_ROOT/bin/weizigo-claimlint.real" 2>/dev/null || true
    cp "$PROJECT/bin/argus" "$SCRATCH_TREE_ROOT/bin/argus" 2>/dev/null || true
    cp "$PROJECT/bin/managent" "$SCRATCH_TREE_ROOT/bin/managent" 2>/dev/null || true
    # Minimal register with one backticked row in the §2 table — the ID
    # schema is `<SCOPE>.<LEGACY>` (CLAIMS.md §1). Header MUST be 11 columns
    # (claims_register.zig REGISTER_COLS = 11, T305). The doctor reads C7
    # from this register's count of unabsorbed findings.
    cat > "$SCRATCH_TREE_ROOT/$SCRATCH_CLAIMS_REL" <<'CLAIMS_EOF'
# CLAIMS — scratch register for argus doctor controlled-state testing

**Created:** 2026-08-19

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `scratch.scratch-row` | — | all | scratch row for argus controlled C7 testing | PROVEN | AGENTS.md:1 | — | — | 0 | ? | Z-TEST |
CLAIMS_EOF
    # Minimal rejections registry. Must be valid JSON (claimlint refuses
    # malformed files — T269).
    cat > "$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR/rejections.json" <<'REJ_EOF'
{"description": "scratch rejections registry for argus controlled C7 testing","rejections": []}
REJ_EOF
}

# Run the doctor against the SCRATCH TREE via --root. The doctor's
# internal _run calls (bin/weizigo-claimlint, bin/managent) inherit cwd
# from --root, so all paths resolve under the scratch tree, not the
# live repo. The live repo is untouched.
#
# Args: $1 = report file path (in WORK)
run_doctor_scrap() {
    local report="$1"
    "$ARGUS" --mode doctor --root "$SCRATCH_TREE_ROOT" --report "$report" >/dev/null 2>&1
    echo "$report"
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
#
# T448: the inline restore uses $SEED_BAK under $WORK. The trap (set at
# top of script) restores AGENTS.md from $SEED_BAK if the inline restore
# did not run (SIGINT/SIGTERM/SIGHUP) — and the startup check refuses to
# run at all if the sentinel line from a SIGKILLed arm 1 is still in
# AGENTS.md. AGENTS.md is the only tracked file the suite touches; the
# 2026-08-18 T445 incident recorded "+1 fixture line" as observed damage.
echo "  1. seeded: uncommitted tracked file in live tree"
SEED_FILE="$PROJECT/AGENTS.md"
SEED_BAK="$WORK/AGENTS.md.bak"
cp "$SEED_FILE" "$SEED_BAK"
echo "  # T427 arm 1 seed" >> "$SEED_FILE"
REPORT=$(run_doctor)
n=$(group_count "$REPORT" "NEEDS ACTION" "uncommitted|tree")
# Inline restore: the common path. Trap restores if this doesn't run.
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
cat > "$SEED_BUNDLE" <<EOF
<!--managent set=G type=infra-->
# $ARM2_ROW_ID — fixture
**Landmark:** none directly; unblocks regression fixture
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

# ── arm 4: null, controlled — C7 below threshold in scratch findings ─────
# Build a SCRATCH findings/CLAIMS.md bin/ tree with an empty findings dir
# (so claimlint's C7 reads 0, well below the threshold of 5). Run the
# doctor against the SCRATCH tree via --root. The doctor MUST report C7
# under CLEAN.
#
# T442 de-state: the pre-T442 arm asserted "C7 unabsorbed" appears under
# CLEAN against the LIVE tree — which is only true when live C7 < 5. So the
# arm went red whenever the project had a backlog, regardless of the
# doctor's own correctness. The new arm is a controlled-state null: a
# scratch findings dir with zero unabsorbed, asserting the doctor surfaces
# the CLEAN marker correctly.
echo "  4. null, controlled: scratch findings (C7=0) → doctor reports CLEAN"
setup_scratch_tree
REPORT=$(run_doctor_scrap "$WORK/doctor-report-4.md")
n=$(group_count "$REPORT" "CLEAN" "C7 unabsorbed")
c7_value=$(group_lines "$REPORT" "CLEAN" "C7 unabsorbed" | head -1)
if [ "$n" -ge 1 ] && echo "$c7_value" | grep -qE "C7 unabsorbed: 0 \(below threshold"; then
    echo "    PASS: doctor reports controlled C7=0 under CLEAN (controlled counter, not live)"
else
    echo "    FAIL: doctor did NOT surface controlled C7=0 under CLEAN"
    group_lines "$REPORT" "CLEAN" "C7" | sed 's/^/        /' | head -3
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
# T873/R11: the original arm hard-coded CLEAN, asserting the deploy-
# staleness reading appears there. That is only true when bin/ is freshly
# deployed — an environmental precondition the arm does not establish, so
# it was red whenever bin/ lagged zig-out (the classification's diagnosis).
# The arm's subject is "the doctor surfaces the deploy-staleness reading";
# assert it appears under the group matching the ACTUAL deploy state, so the
# verdict depends on the code under test, not on whether someone deployed.
echo "  6. null control: doctor surfaces deploy-staleness reading"
REPORT=$(run_doctor)
n_clean=$(group_count "$REPORT" "CLEAN" "deployed|stale|bin/")
n_needs=$(group_count "$REPORT" "NEEDS ACTION" "deployed|stale|bin/")
# Determine the honest group: CLEAN iff bin/managent matches zig-out.
DEPLOYED=0
if [ -x "$PROJECT/bin/managent" ] && [ -x "$PROJECT/zig-out/bin/managent" ] \
   && cmp -s "$PROJECT/bin/managent" "$PROJECT/zig-out/bin/managent"; then
    DEPLOYED=1
fi
if [ "$DEPLOYED" -eq 1 ] && [ "$n_clean" -ge 1 ]; then
    echo "    PASS: bin deployed -> doctor reports deploy staleness under CLEAN"
elif [ "$DEPLOYED" -eq 0 ] && [ "$n_needs" -ge 1 ]; then
    echo "    PASS: bin stale -> doctor reports deploy staleness under NEEDS ACTION"
else
    echo "    FAIL: doctor did NOT surface deploy staleness (deployed=$DEPLOYED clean=$n_clean needs=$n_needs)"
    FAIL=1
fi

# ── arm 7: seeded — in_progress row with no heartbeat ────────────────
# Add a row (SCRATCH store), claim it (so it's in_progress), don't ping.
# The doctor's liveness check should warn WATCH.
#
# T448: the bundle path includes $WORK so it can't be in FIXTURE_PATHS
# statically — register it via track_fixture once computed. The inline
# rm -f handles normal exit; the trap handles signals.
echo "  7. seeded: in_progress row with no heartbeat (SCRATCH store)"
ARM7_ROW_ID="T425-DOCTOR-7-$(basename "$WORK")"
ARM7_BUNDLE_REL="untracked/T425-DOCTOR-7-$(basename "$WORK").md"
ARM7_BUNDLE="$PROJECT/$ARM7_BUNDLE_REL"
rm -f "$ARM7_BUNDLE"
track_fixture "$ARM7_BUNDLE"   # T448: trap must remove on signal
cat > "$ARM7_BUNDLE" <<EOF
<!--managent set=A type=infra-->
# $ARM7_ROW_ID — fixture
**Landmark:** none directly; unblocks regression fixture
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
<!--managent set=G type=infra-->
# T427 — guard fixture
**Landmark:** none directly; unblocks regression fixture
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
cat > "$GUARD_FIXTURE" <<EOF
<!--managent set=G type=infra-->
# $ARM12_C — fixture
**Landmark:** none directly; unblocks regression fixture
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
cat > "$GUARD_FIXTURE" <<EOF
<!--managent set=G type=infra-->
# $ARM13_ROW_ID — fixture
**Landmark:** none directly; unblocks regression fixture
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

# ── arm 15: null — THE null control: this run wrote nothing to live ──
# T873/R11: the original arm asserted the live tasks.json was byte-identical
# before/after the run. That proves "this regression wrote nothing" ONLY when
# no other console writes to the live store meanwhile -- an ambient condition
# this script does not control. Under live fleet activity (observed
# 2026-08-25: 5 in_progress lanes) the live store legitimately changes during
# the ~90 s run and the byte-identity check fails for a cause that is not the
# regression's. The honest subject is "this script wrote no FIXTURE-SHAPED row
# to the live store" (the T425 leak shape); assert that none of the ids this
# run minted (ARM2/ARM7/ARM11/ARM12/ARM13/ARM24) appear in the live store
# afterwards, which is the actual contract and does not depend on other
# consoles' activity.
echo "  15. null control: no fixture row (arms 0-15) leaked to the live store"
LIVE_FIXTURE_LEAKED=$(python3 - "$LIVE_STORE" "${ARM2_ROW_ID:-}" "${ARM7_ROW_ID:-}" "${ARM11_ROW_ID:-}" <<'PYEOF'
import json, sys
store = sys.argv[1]
ids = [i for i in sys.argv[2:] if i]
try:
    with open(store) as f:
        d = json.load(f)
except Exception:
    print(1); sys.exit(0)
leaked = [i for i in ids if i in d]
print(1 if leaked else 0)
PYEOF
)
if [ "$LIVE_FIXTURE_LEAKED" = "0" ]; then
    echo "    PASS: no fixture row minted so far appears in the live store"
else
    echo "    FAIL: a fixture row minted so far leaked into the live store"
    FAIL=1
fi

# ── arm 16: T441 — doctor console line derives from doctor groups ─────
# The pre-T441 code filtered findings by sweep grade (must/critical/should)
# and doctor findings are all "could", so it always said "clean — no
# violations" even when the report showed NEEDS ACTION. The fix makes the
# console line derive from the doctor's own sections.
echo "  16. T441: doctor console line matches doctor group counts"
STDERR_LOG="$WORK/doctor-stderr-16.txt"
"$ARGUS" --mode doctor --report "$WORK/doctor-report-16.md" >/dev/null 2>"$STDERR_LOG" || true
STDERR_LINE=$(head -1 "$STDERR_LOG")
# The old broken output pattern: "clean — no violations" while NEEDS ACTION > 0
if echo "$STDERR_LINE" | grep -qE "^(argus: NEEDS ACTION|argus: CAN CLOSE|argus: WATCH|argus: clean)"; then
    echo "    PASS: console line uses doctor-derived format: $STDERR_LINE"
else
    echo "    FAIL: console line missing expected format: $STDERR_LINE"
    FAIL=1
fi
# Verify it does NOT say "clean — no violations" in a non-clean state
NEED_COUNT=$(group_count "$WORK/doctor-report-16.md" "NEEDS ACTION" "")
if [ "$NEED_COUNT" -gt 0 ]; then
    if echo "$STDERR_LINE" | grep -q "clean — no violations"; then
        echo "    FAIL: doctor says 'clean — no violations' but report has NEEDS ACTION ($NEED_COUNT)"
        FAIL=1
    else
        echo "    PASS: non-clean state correctly NOT reported as 'clean — no violations'"
    fi
fi

# ── arm 17: controlled, seeded — C7 above threshold in scratch findings ─
# Pairs with arm 4. Drop a fixture findings file with 6 unabsorbed claim IDs
# (all `scratch.NONEXISTENT-N`, NOT in the scratch register) into the scratch
# tree's findings/ dir. The doctor MUST report C7=6 under NEEDS ACTION
# (threshold is 5). This is the same controlled counter arm 4 uses, but
# seeded — together they cover both sides of the threshold transition.
#
# T442 de-state: paired with arm 4 (null), this arm proves the doctor's
# C7 reporting behaves correctly when the controlled counter crosses the
# threshold. Neither arm reads the live tree's C7 — both are scratch-tree
# controlled. The pre-T442 arm was a live-state reading wearing a test's
# clothes; the post-T442 pair tests the doctor's BEHAVIOUR.
echo "  17. controlled, seeded: scratch findings (C7=6 ≥ 5) → doctor reports NEEDS ACTION"
setup_scratch_tree  # arm 17 re-uses the scratch tree built by arm 4
SEED_FINDINGS="$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR/T425-DOCTOR-C7SEED.json"
cat > "$SEED_FINDINGS" <<'SEED_EOF'
{
  "task_id": "T425-DOCTOR-C7-SEED",
  "date": "2026-08-19",
  "model": "minimax-m3",
  "identifier": "minimax-m3/T425-C7-SEED",
  "claims": [
    {"id": "scratch.NONEXISTENT-1", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 1", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-2", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 2", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-3", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 3", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-4", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 4", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-5", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 5", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-6", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 6", "evidence_path": "AGENTS.md"}
  ],
  "new_rows": []
}
SEED_EOF
REPORT=$(run_doctor_scrap "$WORK/doctor-report-17.md")
rm -f "$SEED_FINDINGS"
# Assert: doctor reports C7 ≥ threshold under NEEDS ACTION, with the exact
# controlled count visible. The arm's point is BEHAVIOUR, not a specific
# number — accept any count ≥ 5 surfaced under NEEDS ACTION.
n_na=$(group_count "$REPORT" "NEEDS ACTION" "C7 unabsorbed=")
n_clean=$(group_count "$REPORT" "CLEAN" "C7 unabsorbed: [0-9]")
c7_value=$(group_lines "$REPORT" "NEEDS ACTION" "C7 unabsorbed=" | head -1)
if [ "$n_na" -ge 1 ] && [ "$n_clean" = "0" ] && [ -n "$c7_value" ]; then
    echo "    PASS: doctor reports controlled C7 ≥ 5 under NEEDS ACTION (controlled counter, not live): $c7_value"
else
    echo "    FAIL: doctor did NOT surface controlled C7 ≥ 5 under NEEDS ACTION (na=$n_na clean=$n_clean c7='$c7_value')"
    group_lines "$REPORT" "NEEDS ACTION" "C7" | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 18: informational — live C7 unabsorbed reading ────────────────
# Operator-facing readout: the live tree's C7 unabsorbed count and whether
# STANDING-ABSORB should fire. This arm NEVER fails the suite — it is the
# only place the operator can read the live C7 from the suite, and it is
# explicitly NOT a gate (T442: a project-state reading is operator-facing,
# not a regression-control signal). The arm 4 / arm 17 pair above are the
# controls; this is the dashboard.
echo "  18. informational: live C7 unabsorbed (operator-facing, not a gate)"
LIVE_REPORT=$(run_doctor)
LIVE_C7_LINE=$(group_lines "$LIVE_REPORT" "NEEDS ACTION" "C7 unabsorbed=" | head -1)
LIVE_C7_CLEAN=$(group_lines "$LIVE_REPORT" "CLEAN" "C7 unabsorbed:" | head -1)
if [ -n "$LIVE_C7_LINE" ]; then
    echo "    INFO: live tree is red: $LIVE_C7_LINE (run STANDING-ABSORB or absorb by hand)"
elif [ -n "$LIVE_C7_CLEAN" ]; then
    echo "    INFO: live tree is green: $LIVE_C7_CLEAN"
else
    echo "    INFO: live tree has no C7 marker in either section (unexpected — investigate)"
fi

# ── arm 19: T448 — kill-survival self-check ───────────────────────────
# Plant a stale fixture (mimics a SIGKILLed previous run leaving residue)
# and re-invoke the script in --check-fixtures-only mode. The script must
# refuse with the expected exit code and name the stale path. This is the
# load-bearing half of T448 — the trap is the safety net, but SIGKILL
# bypasses traps, so the startup check is what actually catches residue.
echo "  19. T448: kill-survival — start-up check refuses stale fixture"
STALE_DOC="$PROJECT/docs/evidence/T425-DOCTOR-FIXTURE.md"
cat > "$STALE_DOC" <<'EOF'
# stale fixture from T448 arm 19
EOF
# --check-fixtures-only runs the SAME startup check the main run does,
# in a child shell, and returns RC=3 on stale / RC=0 on clean. Output
# goes to stderr (the refusal message); capture both streams.
OUT=$( sh "$0" --check-fixtures-only 2>&1 )
RC=$?
# The stale fixture is itself a live-tree fixture — remove it via the
# same path the trap uses. Track it first so cleanup is consistent.
track_fixture "$STALE_DOC"
cleanup >/dev/null 2>&1 || true
# Re-check: with the fixture gone, --check-fixtures-only must now PASS.
OUT_CLEAN=$( sh "$0" --check-fixtures-only 2>&1 )
RC_CLEAN=$?
if [ "$RC" -eq 3 ] && echo "$OUT" | grep -q "stale:" && echo "$OUT" | grep -q "T425-DOCTOR-FIXTURE.md"; then
    echo "    PASS: stale fixture refused (RC=3), named the path"
else
    echo "    FAIL: stale-fixture refusal (RC=$RC, expected 3):"
    echo "$OUT" | sed 's/^/        /' | head -5
    FAIL=1
fi
if [ "$RC_CLEAN" -eq 0 ]; then
    echo "    PASS: --check-fixtures-only returns 0 once fixtures are cleaned"
else
    echo "    FAIL: --check-fixtures-only still refused after cleanup (RC=$RC_CLEAN):"
    echo "$OUT_CLEAN" | sed 's/^/        /' | head -3
    FAIL=1
fi

# ── arm 20: T448 — null: live tree byte-identical after the full run ──
# The trap and the inline rms together leave the live repo untouched by
# the suite's arms. arm 15 already proves tasks.json is byte-identical;
# this arm extends the proof to FIXTURE_PATHS — none of them exist
# after a normal run, and the AGENTS.md sentinel is absent. The brief
# calls for `git status --porcelain`; we use the FIXTURE_PATHS scan
# instead because (a) git status would catch unrelated user edits, and
# (b) the live tree is allowed to carry OTHER uncommitted work by other
# consoles — the assertion is scoped to what THIS script created.
echo "  20. T448: null — live tree byte-identical after the full run"
RESIDUE=0
for p in "${FIXTURE_PATHS[@]}"; do
    if [ -e "$p" ]; then
        echo "    FAIL: residue after run: $p"
        RESIDUE=1
    fi
done
if [ -f "$PROJECT/AGENTS.md" ] && grep -qE "$ARM1_SENTINEL" "$PROJECT/AGENTS.md"; then
    echo "    FAIL: AGENTS.md still carries the arm-1 sentinel"
    RESIDUE=1
fi
if [ "$RESIDUE" -eq 0 ]; then
    echo "    PASS: no live-tree residue; AGENTS.md clean"
else
    FAIL=1
fi

# ── helper: seed 6 unabsorbed C7 findings into the scratch tree ─────────
# Controlled counter ≥ threshold 5 (same shape as arm 17's seed) — the
# doctor MUST surface it under NEEDS ACTION. Used by arms 21 and 23.
seed_c7_findings() {
    cat > "$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR/T425-DOCTOR-C7SEED.json" <<'SEED_EOF'
{
  "task_id": "T425-DOCTOR-C7-SEED",
  "date": "2026-08-19",
  "model": "minimax-m3",
  "identifier": "minimax-m3/T425-C7-SEED",
  "claims": [
    {"id": "scratch.NONEXISTENT-1", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 1", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-2", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 2", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-3", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 3", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-4", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 4", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-5", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 5", "evidence_path": "AGENTS.md"},
    {"id": "scratch.NONEXISTENT-6", "proposed_status": "PROVEN", "rationale": "controlled C7 seed 6", "evidence_path": "AGENTS.md"}
  ],
  "new_rows": []
}
SEED_EOF
}

# ── arm 21: T430 — seeded: NEEDS ACTION ≥ 1 → console honest, exit 1 ──
# The T430 defect: the console verdict filtered findings by sweep grade
# (must/critical/should) while every doctor finding is graded "could", so
# the one-line check printed "clean — no violations" on every run, forever.
# T441 fixed the console TEXT; this arm pins the BEHAVIOUR deterministically
# (controlled C7 seed, no dependence on live-tree state) and pins the exit
# status: a run whose report has ≥1 NEEDS ACTION item must NOT print a
# clean verdict and its exit status must distinguish it (exit 1).
echo "  21. T430 seeded: NEEDS ACTION ≥ 1 → console not clean, exit 1"
setup_scratch_tree
seed_c7_findings
STDERR_21="$WORK/doctor-stderr-21.txt"
"$ARGUS" --mode doctor --root "$SCRATCH_TREE_ROOT" --report "$WORK/doctor-report-21.md" >/dev/null 2>"$STDERR_21"
RC_21=$?
rm -f "$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR/T425-DOCTOR-C7SEED.json"
STDERR_LINE_21=$(head -1 "$STDERR_21")
NEED_21=$(group_count "$WORK/doctor-report-21.md" "NEEDS ACTION" "^-")
if echo "$STDERR_LINE_21" | grep -q "^argus: NEEDS ACTION"; then
    echo "    PASS: console verdict reports NEEDS ACTION (need=$NEED_21): $STDERR_LINE_21"
else
    echo "    FAIL: console verdict missing NEEDS ACTION (need=$NEED_21): $STDERR_LINE_21"
    FAIL=1
fi
if echo "$STDERR_LINE_21" | grep -q "clean — no violations"; then
    echo "    FAIL: console still says 'clean — no violations' while NEEDS ACTION=$NEED_21"
    FAIL=1
else
    echo "    PASS: old 'clean — no violations' lie absent"
fi
if [ "$RC_21" -eq 1 ]; then
    echo "    PASS: exit 1 distinguishes the seeded state (rc=$RC_21)"
else
    echo "    FAIL: seeded run exit=$RC_21 (expected 1 — exit status must distinguish NEEDS ACTION)"
    FAIL=1
fi

# ── arm 22: T430 — null: empty NEEDS ACTION → clean verdict, exit 0 ──
# Pairs with arm 21: a run whose report has an empty NEEDS ACTION section
# MUST print the clean verdict and exit 0. A fix that prints "not clean"
# unconditionally must fail this arm. The scratch tree still carries WATCH
# noise (missing kanban, host ps) — the assertion is scoped to what is
# deterministic: no NEEDS ACTION claimed, the clean count present in the
# verdict line, exit 0.
echo "  22. T430 null: NEEDS ACTION empty → clean verdict, exit 0"
setup_scratch_tree
STDERR_22="$WORK/doctor-stderr-22.txt"
"$ARGUS" --mode doctor --root "$SCRATCH_TREE_ROOT" --report "$WORK/doctor-report-22.md" >/dev/null 2>"$STDERR_22"
RC_22=$?
STDERR_LINE_22=$(head -1 "$STDERR_22")
NEED_22=$(group_count "$WORK/doctor-report-22.md" "NEEDS ACTION" "^-")
if [ "$NEED_22" = "0" ] && ! echo "$STDERR_LINE_22" | grep -q "NEEDS ACTION"; then
    echo "    PASS: no NEEDS ACTION claimed (report need=$NEED_22)"
else
    echo "    FAIL: console/report claims NEEDS ACTION on a clean run (need=$NEED_22): $STDERR_LINE_22"
    FAIL=1
fi
if echo "$STDERR_LINE_22" | grep -qE "clean \("; then
    echo "    PASS: clean verdict present: $STDERR_LINE_22"
else
    echo "    FAIL: clean verdict missing: $STDERR_LINE_22"
    FAIL=1
fi
if [ "$RC_22" -eq 0 ]; then
    echo "    PASS: exit 0 on empty NEEDS ACTION (rc=$RC_22)"
else
    echo "    FAIL: null run exit=$RC_22 (expected 0)"
    FAIL=1
fi

# ── arm 23: T430 — freshness: --dry-run prints only the current run ──
# The second T430 defect: --dry-run dumped the ACCUMULATED log (fixed
# /tmp/argus-dryrun-watchdog.md), so findings from PREVIOUS runs printed as
# if current, and --log did not redirect it. Two consecutive --dry-run
# invocations: the first seeds a C7 finding (scratch tree), the second does
# not — the second must NOT print the first's finding, and must still print
# its own dry-run log.
echo "  23. T430 freshness: --dry-run prints only the current run's findings"
# Pre-fix the fixed path accumulates across runs — start from empty so the
# arm measures the script, not leftover /tmp state (post-fix these paths
# are unused; the rm is a no-op).
rm -f /tmp/argus-dryrun-watchdog.md /tmp/argus-dryrun-summary.md
setup_scratch_tree
seed_c7_findings
"$ARGUS" --mode doctor --dry-run --root "$SCRATCH_TREE_ROOT" >/dev/null 2>"$WORK/dryrun-23-run1.txt"
RC1_23=$?
rm -f "$SCRATCH_TREE_ROOT/$SCRATCH_FINDINGS_DIR/T425-DOCTOR-C7SEED.json"
"$ARGUS" --mode doctor --dry-run --root "$SCRATCH_TREE_ROOT" >/dev/null 2>"$WORK/dryrun-23-run2.txt"
RC2_23=$?
if grep -q "C7 unabsorbed=6" "$WORK/dryrun-23-run1.txt"; then
    echo "    PASS: run 1 (seeded) printed the C7 finding (rc=$RC1_23)"
else
    echo "    FAIL: run 1 did not print the seeded C7 finding (seed broken or dry-run dump missing)"
    FAIL=1
fi
if grep -q "C7 unabsorbed=6" "$WORK/dryrun-23-run2.txt"; then
    echo "    FAIL: run 2 printed run 1's finding — stale --dry-run output"
    FAIL=1
else
    echo "    PASS: run 2 does not print run 1's finding (rc=$RC2_23)"
fi
if grep -q "dry-run log" "$WORK/dryrun-23-run2.txt"; then
    echo "    PASS: run 2 still prints its own dry-run log"
else
    echo "    FAIL: run 2 dry-run dump missing"
    FAIL=1
fi

# ── arm 24: T430 — non-fixture add on the live store still SUCCEEDS ──
# Arms 12/13 prove the guards fire for fixture ids and MANAGENT_TEST=1.
# The cell that matters most is the inverse: a NORMAL, non-fixture add on
# the live store must still succeed AND write the row. A guard that refused
# every live write would pass arms 12/13 while silently breaking
# registration for the whole fleet (Orchestrator requirement 2026-08-08,
# hand-verified then; permanent arm added T430). Against a fake repo whose
# default store is tracked (= that repo's "live" store), same shape as
# arms 12/13.
echo "  24. T430: non-fixture add on the live store still SUCCEEDS"
# arm 19's kill-survival self-check calls cleanup() mid-suite, which removes
# $WORK — and with it the fake repo built by arms 12/13. Rebuild it here so
# the arm is self-contained (git init on an existing repo is a no-op).
FAKE="$WORK/fake-repo"
mkdir -p "$FAKE/docs/infra/managent" "$FAKE/tools" "$FAKE/untracked"
git -C "$FAKE" init -q 2>/dev/null
cp "$LIVE_STORE" "$FAKE/docs/infra/managent/tasks.json"
git -C "$FAKE" add docs/infra/managent/tasks.json
# Id carries NO fixture marker (DOCTOR/FIXTURE/SEED/PROBE/ARM/TEST — the
# guard matches uppercased substrings) — the WORK basename embeds "doctor"
# (mktemp argus-doctor-XXXXXX) so it must NOT appear in the id.
ARM24_ID="T430LIVE-OK-$(date +%s)$$"
ARM24_BUNDLE="$FAKE/untracked/T430-live-ok-bundle.md"
cat > "$ARM24_BUNDLE" <<EOF
<!--managent set=G type=infra-->
# $ARM24_ID — fixture
**Landmark:** none directly; unblocks regression fixture
EOF
( cd "$FAKE" && env -u MANAGENT_STORE "$MG" add "$ARM24_ID" --bundle "untracked/T430-live-ok-bundle.md" >/dev/null 2>&1 )
rc_24=$?
fake_wrote=$(python3 - "$FAKE/docs/infra/managent/tasks.json" "$ARM24_ID" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    d = json.load(f)
print(1 if sys.argv[2] in d else 0)
PYEOF
)
# Tidy: drop the row + bundle so the fake store stays clean for any later
# reader (the fake repo dies with $WORK in the trap regardless).
remove_row "$FAKE/docs/infra/managent/tasks.json" "$ARM24_ID" 2>/dev/null || true
rm -f "$ARM24_BUNDLE"
if [ "$rc_24" = "0" ] && [ "$fake_wrote" = "1" ]; then
    echo "    PASS: non-fixture add on live store succeeded (rc=$rc_24) and wrote the row"
else
    echo "    FAIL: non-fixture add on live store (rc=$rc_24 wrote=$fake_wrote) — a guard refusing every live write breaks fleet registration"
    FAIL=1
fi

# ── arm 25: final null — no fixture row (whole run) leaked to live ──
# T873/R11: arm 15 runs mid-script (before arms 12-24 mint their ids), so it
# cannot cover the leak-prone live-add arms. This final check, after every
# arm has minted and tidied its ids, asserts the comprehensive contract:
# none of the ids this run minted (across all arms) appears in the live
# store. It replaces the original byte-identity null control, which could
# not distinguish this run's writes from other consoles' concurrent writes.
echo "  25. final null: no fixture row (whole run) leaked to the live store"
LIVE_FIXTURE_LEAKED_FINAL=$(python3 - "$LIVE_STORE" \
    "${ARM2_ROW_ID:-}" "${ARM7_ROW_ID:-}" "${ARM11_ROW_ID:-}" \
    "${ARM12_A:-}" "${ARM12_B:-}" "${ARM12_C:-}" "${ARM13_ROW_ID:-}" \
    "${ARM24_ID:-}" <<'PYEOF'
import json, sys
store = sys.argv[1]
ids = [i for i in sys.argv[2:] if i]
try:
    with open(store) as f:
        d = json.load(f)
except Exception:
    print(1); sys.exit(0)
leaked = [i for i in ids if i in d]
print(1 if leaked else 0)
PYEOF
)
if [ "$LIVE_FIXTURE_LEAKED_FINAL" = "0" ]; then
    echo "    PASS: no fixture row this run minted appears in the live store"
else
    echo "    FAIL: a fixture row this run minted leaked into the live store"
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
