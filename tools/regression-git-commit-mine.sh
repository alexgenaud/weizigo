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
#   seeded control incident 1 reproduced — two staged sets, one commit. Until
#                  T902 the wrapper REFUSED here, naming the foreign path: it
#                  could see another console's staged work, so it had to stop.
#                  It now stages into a PRIVATE index (GIT_INDEX_FILE), so the
#                  foreign path is invisible instead of merely refused — the
#                  commit lands with the named path alone and the foreign
#                  staged set survives untouched. The stronger property: the
#                  shared index can no longer either capture a commit or block
#                  one (b47c248, 2026-08-24).
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
# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/git-commit-mine-test-XXXXXX)" || { echo "regression-git-commit-mine.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
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
echo more > docs/amendment2.md       # left unstaged for the explicit arm below
printf '<!--managent set=C deliverables=docs/isolated.md-->\n' > T902-bundle.md
echo isolated > docs/isolated.md     # staged set 2: this console's own work
COMMITS_BEFORE=$(git rev-list --count HEAD)
OUT=$("$WRAP" --bundle T902-bundle.md docs/isolated.md -m "T268 second" 2>&1)
RC=$?
COMMITS_AFTER=$(git rev-list --count HEAD)
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "docs/isolated.md" ] && [ "$COMMITS_AFTER" -eq $((COMMITS_BEFORE + 1)) ]; then
    echo "    PASS: committed docs/isolated.md alone — the foreign staged path was invisible, not absorbed (T902)"
else
    echo "    FAIL: RC=$RC, commit='$IN_COMMIT', commits $COMMITS_BEFORE->$COMMITS_AFTER"
    echo "$OUT"
    FAIL=1
fi
# the foreign staged set must survive untouched, and the wrapper must not
# have left its own path staged in the SHARED index (the private index is
# reconciled back to HEAD for the paths it committed)
STAGED=$(git diff --cached --name-only)
if [ "$STAGED" = "src/claimlint.zig" ] && grep -q "T272 staged work" src/claimlint.zig; then
    echo "    PASS: foreign staged set intact and untouched; shared index carries nothing of ours"
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

# ── T282 arms: already-committed paths (defect 1) ───────────────────────
# T282's defect: invoked with a path whose content was already committed by
# an earlier commit, the wrapper reported "FAIL — commit <sha> does not
# contain: <path>" even though nothing was wrong (nothing to commit). The
# fix distinguishes three cases: committed by THIS invocation / already
# committed and unchanged (healthy no-op, reported as such) / genuinely
# missing (real failure). These two arms are the null controls for the fix;
# the seeded control (foreign staged path refused, arm 2) is unchanged and
# still the known-bad the wrapper catches.

# arm 4 left docs/other.md staged (the wrapper staged it before the scope
# refusal); it is the test's own file, unstage it — the foreign check would
# otherwise refuse every arm below by design.
git restore --staged docs/other.md 2>/dev/null || true

echo "  6. T282 null: already-committed path alone reports cleanly (no-op)"
# docs/amendment.md was committed in arm 1; re-invoking the wrapper on it
# must be a healthy no-op, not a refusal and not a FAIL.
COMMITS_PRE_NOOP=$(git rev-list --count HEAD)
OUT=$("$WRAP" --bundle T268-bundle.md docs/amendment.md -m "T282 noop" 2>&1)
RC=$?
COMMITS_NOW=$(git rev-list --count HEAD)
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "already committed and unchanged"; then
    echo "    PASS: RC=0, reported already-committed, no commit created ($COMMITS_PRE_NOOP->$COMMITS_NOW)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -2)"
    FAIL=1
fi

echo "  7. T282 null: mixed — one new + one already-committed path"
# The commit succeeds with exactly the NEW path; the already-committed path
# is noted, never reported as FAIL. The mixed bundle declares BOTH paths so
# the identity scope check passes — this arm exercises the verify-after
# three-case distinction, not the scope check.
printf '<!--managent set=B deliverables=docs/amendment3.md,docs/amendment.md-->\n' > T282-mixed-bundle.md
echo "  amendment3" > docs/amendment3.md
OUT=$("$WRAP" --bundle T282-mixed-bundle.md docs/amendment3.md docs/amendment.md -m "T282 mixed" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "docs/amendment3.md" ] && ! echo "$OUT" | grep -q "FAIL"; then
    echo "    PASS: RC=0, commit contains exactly docs/amendment3.md, no FAIL, already-committed noted"
else
    echo "    FAIL: RC=$RC, commit: $IN_COMMIT, output: $(echo "$OUT" | head -3)"
    FAIL=1
fi

# ── T282 arm: task identity through the kanban (previously untested) ─────
# T278's controls only exercised --bundle mode; the MANAGENT_TASK_ID / kanban
# path (which the pre-commit backstop now also relies on) was never run.

echo "  8. T282 task identity: MANAGENT_TASK_ID + kanban scope"
mkdir -p docs/infra/managent
cat > docs/infra/managent/tasks.json <<'JSON'
{"T282-ARM8": {"bundle": "T282-arm8-bundle.md"}}
JSON
printf '<!--managent set=B deliverables=docs/amendment4.md-->\n' > T282-arm8-bundle.md
echo "  amendment4" > docs/amendment4.md
OUT=$(MANAGENT_TASK_ID=T282-ARM8 "$WRAP" docs/amendment4.md -m "T282 task-mode" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "docs/amendment4.md" ]; then
    echo "    PASS: commit $(git rev-parse --short HEAD) contains exactly docs/amendment4.md via kanban scope"
else
    echo "    FAIL: RC=$RC, commit: $IN_COMMIT, output: $(echo "$OUT" | head -2)"
    FAIL=1
fi

echo "  9. T282 seeded: task identity + path outside kanban scope"
echo "  foreign5" > docs/notdeclared.md
OUT=$(MANAGENT_TASK_ID=T282-ARM8 "$WRAP" docs/notdeclared.md -m "no" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "docs/notdeclared.md" && echo "$OUT" | grep -qi "scope"; then
    echo "    PASS: refused, naming docs/notdeclared.md as outside the task scope"
    git restore --staged docs/notdeclared.md 2>/dev/null || true
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -1)"
    FAIL=1
fi

# ── T484 arm: CLAIMS.md + findings/rejections.json in every task's scope ──
echo "  10. T484 scope: register + rejections committed under task identity"
mkdir -p docs/epistemic findings
echo "  register row" > docs/epistemic/CLAIMS.md
echo '{}' > findings/rejections.json
OUT=$(MANAGENT_TASK_ID=T282-ARM8 "$WRAP" docs/epistemic/CLAIMS.md findings/rejections.json -m "T484 scope" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && \
   printf '%s\n' "$IN_COMMIT" | grep -Fxq "docs/epistemic/CLAIMS.md" && \
   printf '%s\n' "$IN_COMMIT" | grep -Fxq "findings/rejections.json"; then
    echo "    PASS: RC=0, commit contains docs/epistemic/CLAIMS.md and findings/rejections.json (register + rejections in every task's scope)"
else
    echo "    FAIL: RC=$RC, commit: $IN_COMMIT, output: $(echo "$OUT" | head -3)"
    FAIL=1
fi

# ── T505 arms: commit-subject length gate (≤72 chars) ───────────────────
# The 72-char subject rule (fleet-git-isolation.md §4.1a) was written down
# and then violated three times in one session. The gate makes it
# mechanical: the subject (text up to the first newline of -m) over 72
# chars is refused unless --long-subject <reason> declares a loud escape.
SUB71=$(printf 'x%.0s' $(seq 1 71))   # 71 chars — under the limit, passes
SUB73=$(printf 'y%.0s' $(seq 1 73))   # 73 chars — over the limit, refused

echo "  11. T505 null: 71-char subject passes"
echo "  amendment5" > docs/amendment5.md
printf '<!--managent set=B deliverables=docs/amendment5.md-->\n' > T505-bundle.md
OUT=$("$WRAP" --bundle T505-bundle.md docs/amendment5.md -m "$SUB71" 2>&1)
RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: 71-char subject committed ($(git rev-parse --short HEAD))"
else
    echo "    FAIL: 71-char subject refused (RC=$RC)"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  12. T505 seeded: 73-char subject refused, naming the limit"
echo "  amendment6" > docs/amendment6.md
printf '<!--managent set=B deliverables=docs/amendment6.md-->\n' > T505-bundle.md
COMMITS_BEFORE=$(git rev-list --count HEAD)
OUT=$("$WRAP" --bundle T505-bundle.md docs/amendment6.md -m "$SUB73" 2>&1)
RC=$?
COMMITS_AFTER=$(git rev-list --count HEAD)
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "73" \
   && echo "$OUT" | grep -qi "subject" && [ "$COMMITS_AFTER" -eq "$COMMITS_BEFORE" ]; then
    echo "    PASS: refused 73-char subject, named the length, no commit"
else
    echo "    FAIL: RC=$RC, commits $COMMITS_BEFORE->$COMMITS_AFTER"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  13. T505 escape: --long-subject <reason> allows 73-char subject (loud)"
echo "  amendment7" > docs/amendment7.md
printf '<!--managent set=B deliverables=docs/amendment7.md-->\n' > T505-bundle.md
OUT=$("$WRAP" --bundle T505-bundle.md docs/amendment7.md \
      -m "$SUB73" --long-subject "integration commit spanning two gates" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "docs/amendment7.md" ] \
   && echo "$OUT" | grep -qi "long-subject"; then
    echo "    PASS: --long-subject escape allowed 73-char subject, loud note printed"
else
    echo "    FAIL: RC=$RC, commit: $IN_COMMIT"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  14. T505 escape: --long-subject with no reason is refused (silent escape dies)"
echo "  amendment8" > docs/amendment8.md
printf '<!--managent set=B deliverables=docs/amendment8.md-->\n' > T505-bundle.md
OUT=$("$WRAP" --bundle T505-bundle.md docs/amendment8.md -m "$SUB73" --long-subject 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "long-subject"; then
    echo "    PASS: --long-subject with no reason refused"
else
    echo "    FAIL: RC=$RC; expected refusal"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── T739 arm: tracked file under an ignored directory ────────────────────
# The T739 deliverable untracked/watch-fleet.sh is TRACKED but lives under the
# gitignored untracked/ dir. Apple Git 2.50.1 exits 1 from `git add <path>`
# whenever the pathspec lies under an ignored directory — even for a tracked
# file it stages correctly — so the wrapper's rc check refused the commit
# ("a named path is missing or ignored"). No commit touched untracked/ between
# T547 (17:36) and T739, so the breakage went unexercised. Red: REFUSED.
# Green: the commit contains exactly the named path.
echo " 15. tracked file under an ignored directory stages and commits"
mkdir -p untracked
printf 'untracked/\n' > .gitignore
git add .gitignore && git commit -qm ignore
echo base > untracked/watch-fleet.sh
git add -f untracked/watch-fleet.sh
git commit -qm seed
echo v2 > untracked/watch-fleet.sh
printf '<!--managent set=B deliverables=untracked/watch-fleet.sh-->\n' > T739-arm-bundle.md
OUT=$("$WRAP" --bundle T739-arm-bundle.md untracked/watch-fleet.sh -m "T739 arm" 2>&1)
RC=$?
IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "untracked/watch-fleet.sh" ]; then
    echo "    PASS: commit contains exactly untracked/watch-fleet.sh"
else
    echo "    FAIL: RC=$RC, commit: $IN_COMMIT"; echo "$OUT" | sed 's/^/    | /'
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
