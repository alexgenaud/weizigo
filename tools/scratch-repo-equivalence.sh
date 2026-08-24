#!/usr/bin/env bash
# scratch-repo-equivalence.sh — prove a scratch-repo conversion does not
# change a regression script's observable behaviour.
#
# Why (T849, 2026-08-24): the remaining 53 single-`git init` scripts are
# converted to source tools/lib/scratch-repo.sh one at a time, and a
# conversion that changes what a script prints or returns is a FAILED
# conversion, not an improvement. This harness is what makes serial
# conversion safe: for a named script it runs the version currently
# committed at HEAD (the unconverted "before") and the version in the
# working tree (the converted "after"), normalises the scratch paths
# that must differ between two runs, and asserts the two agree.
#
# Usage:
#   tools/scratch-repo-equivalence.sh <script>
#       <script> — repo-relative path to a tracked regression script,
#                  e.g. tools/regression-managent-lanes.sh
#
# Method:
#   1. back the working-tree (after) version up to a temp file;
#   2. `git show HEAD:<script>` — the last-committed (before) version —
#      installed at the script's real path so $0/`dirname` resolution is
#      identical for both runs (scripts derive PROJECT from $0);
#   3. run BEFORE from the real path, capture stdout+stderr+exit;
#   4. restore the AFTER version from the backup;
#   5. run AFTER from the real path, capture;
#   6. normalise scratch paths in both, compare byte-for-byte AND exit code.
#
#   A trap restores the working-tree version no matter how the harness
#   exits, so an interrupted run never leaves the before-version in the
#   tree.
#
# Normalisation: every /tmp/weizigo/<slug>-XXXXXX and
# /private/tmp/weizigo/<slug>-XXXXXX path (and the "Initialized empty Git
# repository in <path>/.git/" line git prints) is reduced to <SCRATCH>,
# because the random mktemp suffix and the /tmp→/private/tmp symlink
# resolution legitimately differ between runs. Anything ELSE that differs
# is a real behaviour change and fails the comparison.
#
# Exit codes:
#   0 — before and after agree (conversion is behaviour-preserving)
#   1 — they differ (conversion changed behaviour; revert and report)
#   2 — harness error (script untracked, backup failed, …)
#
# This harness writes nothing that gets cited as evidence; its temp files
# live under /tmp/weizigo and are removed on exit.
#
# Task: T849 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
cd "$PROJECT"

SCRIPT="${1:-}"
if [ -z "$SCRIPT" ]; then
    echo "usage: scratch-repo-equivalence.sh <script>" >&2
    exit 2
fi
# repo-relative, and require it be tracked (so `git show HEAD:` works)
case "$SCRIPT" in
    /*) SCRIPT="${SCRIPT#$PROJECT/}";;
esac
if ! git cat-file -e "HEAD:$SCRIPT" 2>/dev/null; then
    echo "scratch-repo-equivalence: '$SCRIPT' is not tracked at HEAD (cannot read a before-version)" >&2
    exit 2
fi
if [ ! -f "$SCRIPT" ]; then
    echo "scratch-repo-equivalence: '$SCRIPT' not in the working tree" >&2
    exit 2
fi

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t849-equiv-XXXXXX)" || { echo "scratch-repo-equivalence: FATAL — mktemp failed (T445)" >&2; exit 2; }
trap 'rc=$?; [ -f "$BACKUP" ] && cp "$BACKUP" "$SCRIPT" 2>/dev/null || true; rm -rf "$WORK"; exit $rc' EXIT

BACKUP="$WORK/after.sh"
BEFORE="$WORK/before.sh"
BEFORE_OUT="$WORK/before.out"
AFTER_OUT="$WORK/after.out"

cp "$SCRIPT" "$BACKUP" || { echo "scratch-repo-equivalence: backup failed" >&2; exit 2; }
git show "HEAD:$SCRIPT" > "$BEFORE" || { echo "scratch-repo-equivalence: git show HEAD:$SCRIPT failed" >&2; exit 2; }

# normalise: scratch paths (both spellings) and git's init banner line
normalise() {
    sed -E \
        -e 's#/private/tmp/weizigo/[^ "/'"'"'	]+#<SCRATCH>#g' \
        -e 's#/tmp/weizigo/[^ "/'"'"'	]+#<SCRATCH>#g' \
        -e 's#Initialized empty Git repository in <SCRATCH>/\.git/#Initialized empty Git repository in <SCRATCH>/.git/#g'
}

run() {  # $1 = script-path-on-disk (installed at real $SCRIPT), $2 = out-file
    local out="$2"
    # do not let this agent's task identity leak into the run
    env -u MANAGENT_TASK_ID -u MANAGENT_STORE bash "$1" >"$out" 2>&1
    return $?
}

# ── BEFORE run (HEAD version, installed at the real path) ────────────────
cp "$BEFORE" "$SCRIPT"
run "$SCRIPT" "$BEFORE_OUT"
BEFORE_RC=$?

# ── AFTER run (working-tree version restored) ───────────────────────────
cp "$BACKUP" "$SCRIPT"
run "$SCRIPT" "$AFTER_OUT"
AFTER_RC=$?

normalise < "$BEFORE_OUT" > "$BEFORE_OUT.norm"
normalise < "$AFTER_OUT"  > "$AFTER_OUT.norm"

STATUS=0
if ! diff -u "$BEFORE_OUT.norm" "$AFTER_OUT.norm" > "$WORK/diff" 2>&1; then
    STATUS=1
fi
if [ "$BEFORE_RC" != "$AFTER_RC" ]; then
    STATUS=1
fi

echo "=== scratch-repo-equivalence: $SCRIPT ==="
echo "  before exit: $BEFORE_RC   after exit: $AFTER_RC"
if [ "$STATUS" -eq 0 ]; then
    echo "  EQUIVALENT: normalised stdout/stderr/exit agree"
else
    echo "  NOT EQUIVALENT — conversion changed observable behaviour:"
    [ "$BEFORE_RC" != "$AFTER_RC" ] && echo "    exit code differs: $BEFORE_RC -> $AFTER_RC"
    sed 's/^/    /' "$WORK/diff" 2>/dev/null | head -80
fi
exit "$STATUS"