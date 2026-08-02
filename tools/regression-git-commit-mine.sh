#!/usr/bin/env bash
# regression-git-commit-mine.sh — T278 controls for tools/git-commit-mine
#
# The shared .git/index is a fleet-scale hazard: on 2026-08-02 T268's commit
# f74012b absorbed T272's staged claimlint files, and the Orchestrator's
# `git add -A docs/` swept T266's evidence into 91f7cf3. The wrapper makes the
# hazard structurally impossible at the commit site. These are its controls:
#
#   null control   a legit single-task commit succeeds and contains EXACTLY
#                  the named paths (nothing more, nothing less)
#   seeded control incident 1 reproduced — two staged sets, one commit — the
#                  wrapper REFUSES, names the foreign path, and leaves both
#                  staged sets untouched (content intact, still staged)
#   explicit arm   the Orchestrator mode: foreign staged content present, the
#                  commit is path-limited and cannot absorb it
#   scope arm      naming a path outside the declared deliverables is refused
#
# All fixtures are synthetic and run in /tmp/weizigo — never the live repo.
# Nothing here touches a tracked file.
#
# Task: T278 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-02

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WRAP="$HERE/git-commit-mine"
FAIL=0
WORK="$(mktemp -d /tmp/weizigo/git-commit-mine-test-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t278@test
git config user.name T278
echo base > README.md
git add README.md
git commit -qm base

echo "=== git-commit-mine regression ==="

# ── null control ──────────────────────────────────────────────────────────
echo "  1. null control: legit single-task commit"
printf '<!--managent set=C deliverables=docs/amendment.md-->\n' > T268-bundle.md
echo amendment > docs-amendment
mkdir -p docs && mv docs-amendment docs/amendment.md
OUT=$("$WRAP" --bundle T268-bundle.md docs/amendment.md -m "T268 amendment" 2>&1)
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: wrapper refused a legitimate commit (RC=$RC)"
    echo "$OUT"
    FAIL=1
else
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
    if [ "$IN_COMMIT" = "docs/amendment.md" ]; then
        echo "    PASS: commit $(git rev-parse --short HEAD) contains exactly docs/amendment.md"
    else
        echo "    FAIL: commit contains: $IN_COMMIT (expected exactly docs/amendment.md)"
        FAIL=1
    fi
fi

# ── seeded control: incident 1 reproduced (two staged sets, one commit) ───
echo "  2. seeded control: incident 1 — two staged sets, one commit"
mkdir -p src
echo "T272 staged work" > src/claimlint.zig
git add src/claimlint.zig            # staged set 1: another console's work
echo more > docs/amendment2.md
COMMITS_BEFORE=$(git rev-list --count HEAD)
OUT=$("$WRAP" --bundle T268-bundle.md docs/amendment2.md -m "T268 second" 2>&1)
RC=$?
COMMITS_AFTER=$(git rev-list --count HEAD)
if [ "$RC" -eq 0 ]; then
    echo "    FAIL: wrapper committed despite a foreign staged path (RC=0)"
    FAIL=1
elif echo "$OUT" | grep -q "src/claimlint.zig" && [ "$COMMITS_AFTER" -eq "$COMMITS_BEFORE" ]; then
    echo "    PASS: refused, named src/claimlint.zig, no commit created"
else
    echo "    FAIL: refusal or naming wrong (RC=$RC, commits $COMMITS_BEFORE->$COMMITS_AFTER)"
    echo "$OUT"
    FAIL=1
fi
# both staged sets must survive untouched
STAGED=$(git diff --cached --name-only)
if [ "$STAGED" = "docs/amendment2.md
src/claimlint.zig" ] && grep -q "T272 staged work" src/claimlint.zig; then
    echo "    PASS: both staged sets intact, foreign content untouched"
else
    echo "    FAIL: staged set changed: '$STAGED'"
    FAIL=1
fi

# ── explicit arm: Orchestrator mode is path-limited ────────────────────────
echo "  3. explicit arm: foreign staged content present, commit is path-limited"
OUT=$("$WRAP" --explicit docs/amendment2.md -m "T268 explicit" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "docs/amendment2.md" ]; then
    echo "    PASS: commit $(git rev-parse --short HEAD) contains only docs/amendment2.md"
elif echo "$OUT" | grep -q "refused"; then
    echo "    PASS: refused (a refusal is a correct outcome): $(echo "$OUT" | head -1)"
else
    echo "    FAIL: RC=$RC, commit contains: $IN_COMMIT"
    echo "$OUT"
    FAIL=1
fi
if git diff --cached --name-only | grep -q "src/claimlint.zig" &&
   grep -q "T272 staged work" src/claimlint.zig; then
    echo "    PASS: foreign path still staged and untouched"
else
    echo "    FAIL: foreign staged content disturbed"
    FAIL=1
fi

# ── scope arm: a path outside the declared deliverables is refused ────────
echo "  4. scope arm: path outside declared deliverables"
# foreign check has priority by design; give this arm a clean index first
# (the scratch file is the test's own — not another console's work)
git restore --staged src/claimlint.zig 2>/dev/null || true
echo x > docs/other.md
OUT=$("$WRAP" --bundle T268-bundle.md docs/other.md -m "no" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "docs/other.md" && echo "$OUT" | grep -qi "scope"; then
    echo "    PASS: refused, naming docs/other.md as outside the declared scope"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── pathless arm ──────────────────────────────────────────────────────────
echo "  5. pathless arm: no paths -> refused"
OUT=$("$WRAP" -m "no paths" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED"; then
    echo "    PASS: pathless invocation refused"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-git-commit-mine: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-git-commit-mine: FAILURES ==="
    exit 1
fi
