#!/bin/sh
# regression-runner-worktree.sh — T449 controls for tools/runner inside a
# git WORKTREE.
#
# The runner's _find_repo_root() used to walk up looking for a `.git`
# DIRECTORY (os.path.isdir).  In a git worktree `.git` is a FILE carrying a
# `gitdir:` pointer, so the walk ran to the filesystem root and returned
# None — silently disabling heartbeats, directive reads, and the auto-claim
# path for any runner launched from a worktree.  The T447 race (2026-08-18)
# ran five lanes under tools/runner from a worktree and produced NO
# heartbeats.  T376 fixed the identical defect in tools/bakeoff.sh with
# `git rev-parse --show-toplevel`; T449 applies the same fix to the runner,
# keeping the walk-up only as the fallback for a non-git directory.
#
# Three arms:
#   seeded (the point)  a runner launched from inside a fresh worktree
#                       resolves the WORKTREE as repo_root: a heartbeat
#                       line lands in the worktree's own untracked/
#                       heartbeat.jsonl with the right identifier.
#   seeded (directive)  a `pause` directive written into the worktree's
#                       directives.jsonl is READ by the runner (pending
#                       directives printed, exit 124).
#   null                the same run from the MAIN checkout is unchanged:
#                       exactly one heartbeat line lands in the main
#                       checkout's untracked/heartbeat.jsonl with the
#                       right identifier (compare before/after counts).
#
# Isolation: the worktree lives under /tmp/weizigo; the main checkout's
# untracked/heartbeat.jsonl receives exactly one line (the null arm, with
# a T449-REG-NULL identifier — the same append the runner makes on every
# invocation; there is no way to redirect it, and asserting the line is
# the point).  The seeded arms write only inside the scratch worktree.
#
# T448 start-up check: a SIGKILLed previous run leaves the fixture worktree
# registered (the EXIT trap cannot run on SIGKILL), so REFUSE to run until
# the operator removes it by hand — silently re-adding over stale evidence
# is the T445 incident class.
#
# Task: T449 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-20

set -u

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
WT="/tmp/weizigo/t449-reg-worktree"
FAIL=0

# ── start-up check (T448): stale fixture from a killed run ────────────────
if [ -d "$WT" ] || git -C "$PROJECT" worktree list 2>/dev/null | grep -q " $WT "; then
    echo "regression-runner-worktree.sh: REFUSED — stale fixture worktree from a previous run:" >&2
    echo "    $WT" >&2
    echo "A previous run was killed (SIGKILL or uncaught signal); the EXIT trap did not run." >&2
    echo "Remove it by hand (git -C '$PROJECT' worktree remove --force '$WT'; rm -rf '$WT')" >&2
    echo "and re-run. The script will not silently overwrite — that hides evidence (T445)." >&2
    exit 3
fi

cleanup() {
    git -C "$PROJECT" worktree remove --force "$WT" 2>/dev/null || git -C "$PROJECT" worktree prune 2>/dev/null || true
    rm -rf "$WT" 2>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

# git is a hard dependency of this control (a worktree is the subject).
if ! command -v git >/dev/null 2>&1; then
    echo "SKIP: git not found — worktree control cannot run"
    exit 0
fi
if ! command -v "$RUNNER" >/dev/null 2>&1 && [ ! -x "$RUNNER" ]; then
    echo "SKIP: $RUNNER not executable"
    exit 0
fi

echo "=== regression-runner-worktree ==="

# ── seeded: runner from inside a fresh worktree writes a heartbeat ────────
git -C "$PROJECT" worktree add --detach "$WT" HEAD >/dev/null 2>&1 || {
    echo "FAIL: could not create worktree $WT" >&2
    exit 1
}

(cd "$WT" && MANAGENT_TASK_ID=T449-REG-CTRL "$RUNNER" --no-prepend-zig -- sleep 0.3) >/dev/null 2>&1

HB="$WT/untracked/heartbeat.jsonl"
if [ -f "$HB" ] && grep -q '"identifier": "T449-REG-CTRL"' "$HB" 2>/dev/null; then
    echo "PASS: seeded — heartbeat landed in the WORKTREE's untracked/ with identifier T449-REG-CTRL"
else
    echo "FAIL: seeded — no heartbeat with identifier T449-REG-CTRL in $HB"
    echo "  (the bug: repo_root resolved to None from the worktree; heartbeat silently dropped)"
    FAIL=1
fi

# ── seeded: a directive in the worktree's directives.jsonl is read ────────
# Append a pause directive addressed to the seeded identifier, then re-run
# the runner from the worktree: it must print the pending directive and
# exit 124.  The worktree's directives.jsonl is committed content in the
# scratch tree — appending touches nothing in the main checkout.
DIRECTIVES="$WT/docs/infra/managent/directives.jsonl"
if [ -f "$DIRECTIVES" ]; then
    printf '%s\n' '{"id":"D900-T449-REG","target":"T449-REG-CTRL","directive":"pause","note":"T449 regression: directive must reach a runner inside a worktree","from":"T449","ts":"2026-08-20T00:00:00Z","read":false}' >> "$DIRECTIVES"
else
    # worktree predates the directives file — create the parent and a fresh one
    mkdir -p "$(dirname "$DIRECTIVES")"
    printf '%s\n' '{"id":"D900-T449-REG","target":"T449-REG-CTRL","directive":"pause","note":"T449 regression: directive must reach a runner inside a worktree","from":"T449","ts":"2026-08-20T00:00:00Z","read":false}' > "$DIRECTIVES"
fi

set +e
OUT=$(cd "$WT" && MANAGENT_TASK_ID=T449-REG-CTRL "$RUNNER" --no-prepend-zig -- sleep 0.3 2>&1)
RC=$?
set -e
if [ "$RC" -eq 124 ] && printf '%s' "$OUT" | grep -q 'pending directives' && printf '%s' "$OUT" | grep -q 'PAUSE'; then
    echo "PASS: seeded — directive read from the WORKTREE's directives.jsonl (exit 124, PAUSE printed)"
else
    echo "FAIL: seeded — directive not read (exit $RC; pending-directives print:"
    printf '%s' "$OUT" | grep 'pending directives' || echo "  none"
    echo "  )"
    FAIL=1
fi

# ── null: same run from the MAIN checkout is unchanged ────────────────────
MAIN_HB="$PROJECT/untracked/heartbeat.jsonl"
count_null() { grep -c '"identifier": "T449-REG-NULL"' "$MAIN_HB" 2>/dev/null || true; }
BEFORE=$(count_null)
[ -n "$BEFORE" ] || BEFORE=0
(cd "$PROJECT" && MANAGENT_TASK_ID=T449-REG-NULL "$RUNNER" --no-prepend-zig -- sleep 0.3) >/dev/null 2>&1
AFTER=$(count_null)
[ -n "$AFTER" ] || AFTER=0
if [ "$AFTER" -eq "$((BEFORE + 1))" ]; then
    echo "PASS: null — main-checkout run unchanged (exactly one new heartbeat line, identifier T449-REG-NULL)"
else
    echo "FAIL: null — expected heartbeat count $((BEFORE + 1)), got $AFTER"
    FAIL=1
fi

# ── cleanup ───────────────────────────────────────────────────────────────
cleanup
trap - EXIT INT TERM HUP

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-runner-worktree: all controls passed ==="
else
    echo "=== regression-runner-worktree: FAILURES ===" >&2
    exit 1
fi
