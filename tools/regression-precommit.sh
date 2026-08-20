#!/bin/sh
# regression-precommit.sh — controls for the pre-commit hook (T272/T280/T455).
#
# Five checks, all run from the repo root:
#   installed-ness:  core.hooksPath MUST be set to tools/hooks
#   null control:    the hook MUST pass on the current tree
#   seeded-defect:   the hook MUST refuse a commit with a seeded orphan
#   T455 controls:   four synthetic-repo arms exercising the
#                    unlabelled-commit holder-collision guard, all in
#                    /tmp/weizigo (never the live repo):
#      7a. seeded-collision   live in_progress holder + unlabelled
#                              commit touching that path → REFUSED,
#                              naming the holding row + agent
#      7b. null-no-collision  no live holders + unlabelled commit on
#                              arbitrary paths → allowed silently
#                              (operator's normal case, no ceremony)
#      7c. labelled-still-works  labelled commit inside its own
#                              declared scope → allowed (T282 must
#                              still win; the T455 guard only fires
#                              in the unlabelled branch)
#      7d. degraded-kanban    unlabelled commit + kanban unreadable
#                              → today's warn-and-allow, paths listed
#      7e. explicit-still-allows  GIT_MINE_EXPLICIT=1 + foreign held
#                              path → warn-and-allow (T455 finding
#                              recorded this decision)
#
# T280: task · deepseek-v4-pro · 2026-08-02
# T455: four extra controls added · kimi-k2.7 · 2026-08-19

set -e

HOOK="tools/hooks/pre-commit"
CLAIMLINT="bin/weizigo-claimlint"

cd "$(git rev-parse --show-toplevel)"

# Absolute path for the hook — run_hook enters scratch repos via `cd`,
# where the relative $HOOK would not resolve. The earlier three controls
# stay relative (the current tree is where they run).
HOOK_ABS="$PWD/tools/hooks/pre-commit"

echo "=== regression-precommit: installed-ness check ==="
# GRAND-AUDIT §1c (2026-08-02): a mechanism nobody installed is prose.
# The next clone must fail loudly until someone runs the install command.
INSTALLED=$(git config core.hooksPath 2>/dev/null || echo "")
if [ "$INSTALLED" != "tools/hooks" ]; then
    echo "FAIL: core.hooksPath is not set to 'tools/hooks' (current: '${INSTALLED:-unset}')"
    echo "  Install with: git config core.hooksPath tools/hooks"
    exit 1
fi
echo "  core.hooksPath = $INSTALLED — installed"

echo ""
echo "=== regression-precommit: null control ==="
echo "Running pre-commit hook on current tree (must pass — floor is not exceeded)..."
if "$HOOK"; then
    echo "PASS: null control — hook allowed the commit (at or below floor)"
else
    echo "FAIL: null control — hook blocked a commit that should be allowed"
    exit 1
fi

echo ""
echo "=== regression-precommit: seeded-defect control ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build && cp zig-out/bin/weizigo-claimlint bin/'"
    exit 0
fi

# Measure the baseline C1a so we can report the real delta.
BASELINE_C1A=$("$CLAIMLINT" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
echo "  baseline C1a=$BASELINE_C1A"

# Build a seeded CLAIMS.md with one extra PROVEN row depending on
# GLOBAL.C3 (FALSE-AS-SCOPED). Exactly one new orphan is created (the
# seeded row itself; the cascade that T272's version produced was an
# insertion-loop bug — the single-use flag now prevents it).
#
# Unlike T272's version, this control exercises the hook itself, not just
# claimlint — a positive control must exercise the instrument under test,
# not a parallel one (AGENTS.md:146-148; GRAND-AUDIT §1a).
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cp docs/epistemic/CLAIMS.md "$TMPDIR/CLAIMS.md"

# Seeded row: PROVEN, depends on GLOBAL.C3 (FALSE-AS-SCOPED). Exactly one
# orphan — the seeded row itself. Inserted once as the first data row in §2.
SYNTH_ROW='| `GLOBAL.T280-CTRL-SEEDED` | — | all | synthetic: seeded-defect control for pre-commit hook (T280). PROVEN with d:GLOBAL.C3 (FALSE-AS-SCOPED) — exactly one C1a orphan. | PROVEN | `AGENTS.md:1` | `d:GLOBAL.C3` | — | 0 | ? | Z-AUDIT |'

python3 -c "
import sys
lines = open('$TMPDIR/CLAIMS.md').readlines()
in_sec2 = False
past_header = False
inserted = False
out = []
for line in lines:
    if line.startswith('## 2. The register'):
        in_sec2 = True
    elif in_sec2 and line.startswith('## 3.'):
        in_sec2 = False
    if in_sec2 and past_header and not inserted and line.startswith('|') and not line.startswith('|---'):
        out.append('$SYNTH_ROW\n')
        inserted = True
    if in_sec2 and line.startswith('|---'):
        past_header = True
    out.append(line)
open('$TMPDIR/CLAIMS.md', 'w').writelines(out)
"

# Verify claimlint can parse the seeded register and confirm the orphan count.
SEEDED_C1A=$("$CLAIMLINT" "$TMPDIR/CLAIMS.md" 2>&1 | grep '^  C1a orphans / C1b alarms' | grep 'FAILS' | awk '{print $6}')
if [ -z "$SEEDED_C1A" ]; then
    echo "FAIL: seeded-defect control — could not parse C1a from seeded claims (claimlint may have rejected the format)"
    exit 1
fi
echo "  seeded C1a=$SEEDED_C1A (baseline=$BASELINE_C1A, delta=+$((SEEDED_C1A - BASELINE_C1A)))"

echo "Running pre-commit hook with CLAIMS_PATH pointing to the seeded register..."
# Run the hook with the seeded register. Exit 0 = hook PASSED = control FAILED.
if CLAIMS_PATH="$TMPDIR/CLAIMS.md" "$HOOK"; then
    echo "FAIL: seeded-defect control — hook allowed a commit with seeded orphan(s)"
    exit 1
else
    HOOK_EXIT=$?
    echo "PASS: seeded-defect control — hook blocked the commit (exit $HOOK_EXIT)"
fi

# ── T455 controls — unlabelled-commit holder-collision guard ──────────
# All four arms run in synthetic scratch repos under /tmp/weizigo. The
# scratch repo carries a stub bin/weizigo-claimlint (so claimlint always
# reports the seeded 0/0 floors), the live floor file (so the regression
# floor check passes), the live tools/git-commit-mine-lib.sh (so the
# active-holders helper uses the implementation we just modified), and
# a scratch kanban (MANAGENT_STORE).
echo ""
echo "=== regression-precommit: T455 holder-collision guard ==="

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE
# to run if scratch creation fails — an empty scratch path once sent this
# suite's arms into the LIVE repo (2026-08-18 incident). `exit` inside
# $() only leaves the subshell, so the failure branch kills the whole
# script by PID.
new_scratch() {
    mkdir -p /tmp/weizigo
    mktemp -d /tmp/weizigo/precommit-t455-XXXXXX || {
        echo "regression-precommit: FATAL — scratch mktemp failed; refusing to run (T445)" >&2
        kill -TERM $$
        exit 2
    }
}

stub_claimlint() {
    # $1 = scratch dir; $2 = C7 non-conforming count (default 0). T483 added
    # the non-conforming line so the hook's new floor has a number to read;
    # the T455 controls emit 0, the T483 seeded control emits 1.
    STUB_NONCONF="${2:-0}"
    mkdir -p "$1/bin"
    cat > "$1/bin/weizigo-claimlint" <<EOF
#!/bin/sh
echo "  calibration: PASS"
echo "  C1a orphans / C1b alarms      0 / 0   (FAILS)"
echo "  C2 dangling evidence paths    0   (FAILS)"
echo "  C3 PROVEN w/o committed evid.      0   (debt...)"
echo "  C6 cite-tag mismatches        0   (FAILS)"
echo "  C7 non-conforming files        $STUB_NONCONF   (reported)"
echo "  C9 tree-mapping violations      0   (FAILS)"
exit 0
EOF
    chmod +x "$1/bin/weizigo-claimlint"
}

run_hook() {
    cd "$1" || exit 2
    FLOOR_FILE="$REPO/tools/hooks/claimlint-floor.json" \
    MANAGENT_TASK_ID="${MANAGENT_TASK_ID:-}" \
    MANAGENT_STORE="${MANAGENT_STORE:-}" \
    GIT_MINE_EXPLICIT="${GIT_MINE_EXPLICIT:-0}" \
    "$HOOK_ABS" 2>&1
}

REPO="$(git rev-parse --show-toplevel)"
FAIL_T455=0
# Disable errexit while we capture hook output: the seeded-collision
# arm MUST see a hook that exits 1 (refusal) — `OUT=$(...)` under
# `set -e` aborts the script before we can inspect the output.
# Re-enabled after the T455 section completes.
set +e

# ── 7a. seeded-collision: live holder + unlabelled commit on its path → REFUSE ─
echo "  7a. seeded-collision: in_progress T455X holds path; unlabelled commit on that path REFUSED, naming holder"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t455@test
git config user.name T455
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs/infra/managent
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
# Kanban: T455X in_progress holds src/vb_bellman_4x4.zig (the exact path
# the Orchestrator's d7e4bdb swept on 2026-08-18); T347 is done and
# therefore NOT a live holder.
printf '{"T455X": {"status": "in_progress", "identifier": "glm-5.2/T455X", "holds": ["src/vb_bellman_4x4.zig"]}, "T347": {"status": "done", "identifier": "minimax-m3/T347", "holds": ["src/vb_health.zig"]}}\n' > docs/infra/managent/tasks.json
mkdir -p src
echo foreign > src/vb_bellman_4x4.zig
git add src/vb_bellman_4x4.zig
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "REFUSED" \
   && echo "$OUT" | grep -q "T455X" \
   && echo "$OUT" | grep -q "glm-5.2/T455X" \
   && echo "$OUT" | grep -q "src/vb_bellman_4x4.zig"; then
    echo "    PASS: refused (RC=$RC), naming T455X / glm-5.2/T455X and the colliding path"
else
    echo "    FAIL: RC=$RC"
    echo "    output (first 6 lines):"
    echo "$OUT" | head -6 | sed 's/^/      /'
    FAIL_T455=1
fi
rm -rf "$WORK"

# ── 7b. null-no-collision: no live holders + unlabelled commit → ALLOW silently ─
echo "  7b. null-no-collision: no live holders; unlabelled commit on an unheld path allowed silently"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t455@test
git config user.name T455
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs/infra/managent
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
# Empty kanban (no live holders).
printf '{}\n' > docs/infra/managent/tasks.json
mkdir -p docs
echo ok > docs/random.md
git add docs/random.md
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && ! echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: allowed (RC=0), no refusal — operator's normal case stays fast"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -3)"
    FAIL_T455=1
fi
rm -rf "$WORK"

# ── 7c. labelled-still-works: labelled commit inside own scope → ALLOW ─
echo "  7c. labelled-still-works: T282 labelled-scope must still win over the T455 unlabelled guard"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t455@test
git config user.name T455
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs/infra/managent untracked
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
# Two live holders; the labelled committer is T455C with deliverables=
# matching the path it stages.
printf '{"T343": {"status": "in_progress", "identifier": "glm-5.2/T343", "holds": ["src/vb_bellman_4x4.zig"]}, "T455C": {"status": "in_progress", "identifier": "kimi-k2.7/T455C", "holds": ["tools/hooks/pre-commit"], "bundle": "untracked/T455C-bundle.md"}}\n' > docs/infra/managent/tasks.json
printf '<!--managent set=C deliverables=docs/random.md-->\n' > untracked/T455C-bundle.md
mkdir -p docs
echo ok > docs/random.md
git add docs/random.md
OUT=$(MANAGENT_TASK_ID=T455C MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "scope of T455C"; then
    echo "    PASS: labelled T455C allowed (RC=0) via T282 — its scope contained the staged path"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -3)"
    FAIL_T455=1
fi
rm -rf "$WORK"

# ── 7d. degraded-kanban: unlabelled commit + kanban unreadable → warn-and-allow ─
echo "  7d. degraded-kanban: unlabelled commit, no kanban at all -> warn-and-allow (today's behaviour)"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t455@test
git config user.name T455
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
mkdir -p docs
echo ok > docs/random.md
git add docs/random.md
# No docs/infra/managent/tasks.json at all — store unreadable.
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q "WARNING" \
   && echo "$OUT" | grep -q "kanban unreadable" \
   && echo "$OUT" | grep -q "docs/random.md"; then
    echo "    PASS: warned (RC=0), naming the unreadable-kanban reason and the staged path"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL_T455=1
fi
rm -rf "$WORK"

# ── 7e. explicit-still-allows: GIT_MINE_EXPLICIT=1 + foreign held path → warn-and-allow ─
echo "  7e. explicit-still-allows: GIT_MINE_EXPLICIT=1 + foreign held path warns and allows (T455 finding)"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t455@test
git config user.name T455
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs/infra/managent
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
printf '{"T455X": {"status": "in_progress", "identifier": "glm-5.2/T455X", "holds": ["src/vb_bellman_4x4.zig"]}}\n' > docs/infra/managent/tasks.json
mkdir -p src
echo foreign > src/vb_bellman_4x4.zig
git add src/vb_bellman_4x4.zig
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" GIT_MINE_EXPLICIT=1 run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARNING" && echo "$OUT" | grep -q "explicit"; then
    echo "    PASS: warned (RC=0) with the explicit-mode note; the holder collision was NOT enforced (T455 rationale)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -3)"
    FAIL_T455=1
fi
rm -rf "$WORK"

if [ "$FAIL_T455" -eq 0 ]; then
    echo "  T455 controls: ALL CONTROLS PASSED"
else
    echo "  T455 controls: FAILURES — see above"
    set -e
    exit 1
fi
# Re-enable errexit for the final 'all controls passed' line and any
# later additions.
set -e

# ── T483 control: C7-nonconforming floor ──────────────────────────────
# A commit staging invalid findings/*.json must be refused by the hook's
# new C7-nonconforming floor (absorption-spec §6.2). The instrument under
# test is the HOOK's floor comparison — extract the `C7 non-conforming
# files` count from the claimlint summary and refuse when it exceeds the
# recorded floor. The detection half (a malformed findings file reports
# nonconforming=1) is claimlint's contract, already proven by its built-in
# calibration (known-bad 9 + known-bad 11), which the hook itself gates on
# (`calibration: PASS`). So this arm's stub emits the count a real
# claimlint would for the malformed file staged below, and asserts the
# hook refuses — isolating the new floor logic, exactly as the T455 arms
# isolate the holder-collision guard. The malformed file is staged so the
# arm is a seeded commit carrying invalid findings JSON, not a bare
# env-var injection.
echo ""
echo "=== regression-precommit: C7-nonconforming floor control ==="
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t483@test
git config user.name T483
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools docs/infra/managent findings
cp "$REPO/tools/git-commit-mine-lib.sh" tools/
# Empty kanban: unlabelled commit touches no held path → gate 2 allows, so
# the control reaches the claimlint floor comparison it is meant to test.
printf '{}\n' > docs/infra/managent/tasks.json
stub_claimlint "$WORK" 1
# The seeded defect: invalid findings JSON (unclosed object, truncated).
printf '{"task_id": "T483-CTRL", "date": "2026-08-20", "model": "test", "claims": [\n' > findings/T483-ctrl-malformed.json
git add findings/T483-ctrl-malformed.json
set +e
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
set -e
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "C7-nonconforming regressed"; then
    echo "    PASS: refused (RC=$RC) — C7-nonconforming floor compared 1 > 0"
else
    echo "    FAIL: RC=$RC"
    echo "    output (first 8 lines):"
    echo "$OUT" | head -8 | sed 's/^/      /'
    exit 1
fi
rm -rf "$WORK"

echo ""
echo "=== regression-precommit: all controls passed ==="
