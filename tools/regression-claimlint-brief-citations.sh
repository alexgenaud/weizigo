#!/bin/sh
# regression-claimlint-brief-citations.sh — controls for the C15 BRIEF-CITATIONS
# check (T764).
#
# C15 scans untracked/T*.md briefs for path-shaped references that do not
# resolve in the working tree, classifying docs/- and findings/-shaped
# references as UNCOMMITTED (the ruling-class warning — DELEGATOR.md says
# "a brief cites committed paths") and any other reference as DEAD.
# Report-only (T764, seed ruling 6): a display/taste gate is a warning, not
# a refusal. C15 reports without failing the run; the floor is proposed
# separately, just as C10's was.
#
# Three checks, all run from the repo root:
#   seeded-defect: a fixture brief citing a NONEXISTENT path must be reported
#                  by C15, naming the path. The fixture is created in
#                  /tmp/weizigo/c15-seeded/ (scratch store per AGENTS.md
#                  §"Untracked directories — two types, never conflat") and
#                  is unrelated to anything in the repo.
#   null-control:  with the fixture removed, the C15 report must NOT name
#                  the seeded path, and the rest of the claimlint output
#                  must be byte-identical to the fixture-less baseline.
#   report-only:   C15 must not change the run's exit status (it reports;
#                  it does not fail, yet).
#
# Task: T764 · Role: worker · Model: minimax-m3 · Date: 2026-08-24

set -e

CLAIMLINT="zig-out/bin/weizigo-claimlint"
SEED_DIR="/tmp/weizigo/c15-seeded"
SEED_BRIEF="$SEED_DIR/T999-c15-regression.md"
SEEDED_TOKEN="docs/this/path/does/not/exist-c15-regression.md"
SEEDED_TOKEN2="findings/T999-c15-regression.json"

# ── pre-flight ───────────────────────────────────────────────────────────
cd "$(git rev-parse --show-toplevel)"
echo "=== regression-claimlint-brief-citations: pre-flight ==="
if ! test -x "$CLAIMLINT"; then
    echo "SKIP: $CLAIMLINT not found — build with 'zig build' first"
    exit 0
fi
echo "  $CLAIMLINT is executable"

# The seeded citations must point at paths that do NOT exist — the whole
# defect is that the brief names a path the worker would have to reconstruct.
rm -rf "$SEED_DIR"
mkdir -p "$SEED_DIR"
cat > "$SEED_BRIEF" <<EOF
# T999 — C15 regression control (do not commit)

This fixture brief cites a path that does not resolve in the working tree:

\`$SEEDED_TOKEN\`

Under a missing check the brief is loaded into a register or absorbed, the
citation is silently dropped, and the worker has to reconstruct the referent
from prose — exactly the 2026-08-23 defect. C15 must report it.

A second citation, findings/-shaped, also does not resolve:

\`$SEEDED_TOKEN2\`

It too must appear in the C15 report (as UNCOMMITTED).
EOF
echo "  seeded brief: $SEED_BRIEF"
echo "  seeded tokens: $SEEDED_TOKEN"
echo "                 $SEEDED_TOKEN2"

# ── baseline (no fixture): capture the run the tree is expected to keep ──
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; rm -rf "$SEED_DIR"; }
trap cleanup EXIT INT TERM HUP

set +e
"$CLAIMLINT" > "$TMPDIR/baseline.out" 2>/dev/null
BASELINE_EXIT=$?
set -e
echo ""
echo "=== regression-claimlint-brief-citations: baseline (no fixture) ==="
echo "  baseline exit: $BASELINE_EXIT"

# ── seeded-defect: fixture brief citing nonexistent paths ───────────────
echo ""
echo "=== regression-claimlint-brief-citations: seeded-defect ==="
echo "  fixture: $SEED_BRIEF"
set +e
"$CLAIMLINT" > "$TMPDIR/seeded.out" 2>/dev/null
SEEDED_EXIT=$?
set -e
echo "  seeded exit: $SEEDED_EXIT (must equal baseline exit $BASELINE_EXIT — report-only)"

# The seeded brief is in /tmp/weizigo/, NOT in the repo's untracked/. The
# C15 scanner walks the working tree's untracked/T*.md, so the seeded brief
# must be MOVED into untracked/ for the scanner to see it. This is a
# deeper check than C10: the brief itself must reach the scanner, which
# tests the scanner's directory-walk, not just the per-body tokenizer.
mv "$SEED_BRIEF" "untracked/T999-c15-regression.md"
set +e
"$CLAIMLINT" > "$TMPDIR/seeded.out" 2>/dev/null
SEEDED_EXIT=$?
set -e
echo "  seeded exit (post-move): $SEEDED_EXIT"

if ! grep -Fq "$SEEDED_TOKEN" "$TMPDIR/seeded.out"; then
    echo "FAIL: seeded-defect — $SEEDED_TOKEN is not reported by claimlint."
    echo "      A brief (untracked/T*.md) citing a nonexistent docs/-shaped path"
    echo "      must be reported by C15 as UNCOMMITTED. This is the ruling-class"
    echo "      warning the DELEGATOR.md §\"Naming and citing\" rule speaks to."
    exit 1
fi
echo "PASS: seeded-defect — uncommitted token $SEEDED_TOKEN is reported"

if ! grep -Fq "$SEEDED_TOKEN2" "$TMPDIR/seeded.out"; then
    echo "FAIL: seeded-defect — $SEEDED_TOKEN2 is not reported by claimlint."
    echo "      A findings/-shaped reference is also UNCOMMITTED."
    exit 1
fi
echo "PASS: seeded-defect — uncommitted token $SEEDED_TOKEN2 is reported"

if [ "$SEEDED_EXIT" -ne "$BASELINE_EXIT" ]; then
    echo "FAIL: report-only — C15 changed the exit status ($BASELINE_EXIT -> $SEEDED_EXIT)."
    echo "      C15 must report without failing the run; the floor is proposed separately."
    exit 1
fi
echo "PASS: report-only — C15 does not change the run's exit status"

# ── null-control: fixture removed, output returns to baseline ────────────
rm -f untracked/T999-c15-regression.md
echo ""
echo "=== regression-claimlint-brief-citations: null-control ==="
set +e
"$CLAIMLINT" > "$TMPDIR/null.out" 2>/dev/null
NULL_EXIT=$?
set -e

if grep -Fq "$SEEDED_TOKEN" "$TMPDIR/null.out"; then
    echo "FAIL: null-control — $SEEDED_TOKEN still reported after the fixture was removed"
    exit 1
fi
echo "PASS: null-control — seeded token absent once the fixture brief is gone"

# The null run is on the same tree as the baseline (both fixture-less), so the
# outputs must be byte-identical — the C15 counter included. The ONE tolerated
# difference is the "repo index: NNNN files" line, which moves by 1 when the
# fixture brief is staged (the index walks the working tree). Anything else
# differs is a counter the new code moved, which the regression forbids.
sed -E 's/^repo index: [0-9]+ files/repo index: <N> files/' "$TMPDIR/baseline.out" > "$TMPDIR/baseline.stripped"
sed -E 's/^repo index: [0-9]+ files/repo index: <N> files/' "$TMPDIR/null.out" > "$TMPDIR/null.stripped"
if ! cmp -s "$TMPDIR/baseline.stripped" "$TMPDIR/null.stripped"; then
    echo "FAIL: null-control — claimlint output differs between two identical runs (after stripping index count):"
    diff "$TMPDIR/baseline.stripped" "$TMPDIR/null.stripped" | head -20
    exit 1
fi
echo "PASS: null-control — output byte-identical to baseline on the same tree"

# ── null — no live-tree residue ─────────────────────────────────────────
echo ""
echo "=== regression-claimlint-brief-citations: null — no live-tree residue ==="
if [ ! -e untracked/T999-c15-regression.md ]; then
    echo "PASS: untracked/T999-c15-regression.md absent after the run"
else
    echo "FAIL: untracked/T999-c15-regression.md still present after the run:"
    ls -la untracked/T999-c15-regression.md | sed 's/^/      /'
    exit 1
fi

echo ""
echo "=== regression-claimlint-brief-citations: all controls passed ==="
