#!/usr/bin/env bash
# regression-commit-concurrency.sh — T547 controls for tools/git-commit-mine
#
# The shared .git/index is a fleet-scale hazard even when the one-writer
# invariant holds: two rows can legally hold disjoint files and still collide
# at commit time, because `git add <path>` stages that path's ENTIRE current
# working-tree content (which may be another row's in-flight edit) and
# `.git/index` is one shared mutable file with no lock held across a worker's
# stage→commit sequence. T521's 784235a absorbed T531/T545's build.zig hunks
# and T512's regression-dispatch.sh arms under the T521 message. These are
# the controls for the two mechanisms that make the hazard structural:
# a commit mutex (flock around stage→verify→commit) and a holds check
# (refuse to stage a path held by a different in_progress row).
#
#   seeded (absorption)  two concurrent runs, disjoint paths, one commit
#                        delayed → each commit contains ONLY its own paths.
#                        Against pre-mutex code the delayed run absorbs the
#                        other's staged file (the delay widens the
#                        verify→commit window deterministically).
#   seeded (holds)       row A in_progress holds a.zig; row B tries to stage
#                        a.zig → refused, naming A, index untouched.
#   seeded (explicit)    the same with --explicit → allowed, escape recorded
#                        loudly.
#   null                 single commit on a quiet repo → unchanged behaviour.
#   null                 two concurrent runs staging genuinely disjoint paths
#                        with no foreign in-flight content → both succeed,
#                        no cross-absorption (the mutex must not brake a
#                        healthy fleet; it also removes the .git/index.lock
#                        contention that made the pre-mutex null arm fail).
#   seeded (contention)  an external holder takes the commit lock; a wrapper
#                        with GCM_LOCK_TIMEOUT_SECS=1 refuses, naming the
#                        mutex (proves the lock is actually exclusive).
#
# All fixtures are synthetic and run under /tmp/weizigo — never the live
# repo. Nothing here touches a tracked file.
#
# Task: T547 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
WRAP="$HERE/git-commit-mine"
REAL_GIT="$(command -v git)"
FAIL=0

# Test determinism: the wrapper's env-fallback (T454) and the shim/delay
# seams must not inherit anything from the caller's shell.
unset MANAGENT_TASK_ID GCM_TEST_DELAY_COMMIT GCM_LOCK_TIMEOUT_SECS 2>/dev/null || true

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent a sibling suite's
# arms into the LIVE repo (2026-08-18 incident). Never rely on a silent cd "".
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/git-commit-concurrency-XXXXXX)" || { echo "regression-commit-concurrency.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

echo "=== git-commit-mine commit-concurrency regression (T547) ==="

mk_repo() {
    local dir="$1"
    mkdir -p "$dir"
    (
        cd "$dir" || exit 2
        git init -q
        git config user.email t547@test
        git config user.name T547
        echo base > base.txt
        git add base.txt
        git commit -qm base
    )
}

commit_files() {  # print a commit's changed paths, one per line, sorted
    git -C "$1" show --format= --name-only "$2" | grep -v '^$' | sort
}

# ── arm 1: seeded absorption — two concurrent runs, one commit delayed ───
# A and B stage disjoint paths. A's index-mode commit is delayed 2s through a
# PATH shim, so B's `git add` deterministically lands inside A's
# verify→commit window. Without the mutex, A's plain `git commit` absorbs
# B's staged file; with it, A holds the lock and B blocks until A releases.
arm1() {
    echo "  1. seeded absorption: two concurrent runs, disjoint paths, delayed commit"
    local W1="$WORK/arm1"
    mk_repo "$W1" || return 1
    cd "$W1" || return 1
    echo "A work" > a.txt
    echo "B work" > b.txt
    printf '<!--managent set=A deliverables=a.txt-->\n' > bundleA.md
    printf '<!--managent set=A deliverables=b.txt-->\n' > bundleB.md
    mkdir -p shim
    cat > shim/git <<SHIM
#!/bin/sh
if [ "\$1" = "commit" ] && [ "\$2" = "-m" ] && [ "\$#" -eq 3 ] && [ "\${GCM_TEST_DELAY_COMMIT:-0}" = "1" ]; then
    sleep 2
fi
exec "$REAL_GIT" "\$@"
SHIM
    chmod +x shim/git
    ( PATH="$W1/shim:$PATH" GCM_TEST_DELAY_COMMIT=1 "$WRAP" --bundle bundleA.md a.txt -m "A commit" > a.log 2>&1; echo $? > a.rc ) &
    local APID=$!
    sleep 0.5
    ( PATH="$W1/shim:$PATH" "$WRAP" --bundle bundleB.md b.txt -m "B commit" > b.log 2>&1; echo $? > b.rc ) &
    local BPID=$!
    wait "$APID" 2>/dev/null; wait "$BPID" 2>/dev/null
    local ARC BRC
    ARC=$(cat a.rc 2>/dev/null || echo 99)
    BRC=$(cat b.rc 2>/dev/null || echo 99)
    local A_COMMIT B_COMMIT
    A_COMMIT=$(git log --format=%H --grep="A commit" -1)
    B_COMMIT=$(git log --format=%H --grep="B commit" -1)
    if [ -z "$A_COMMIT" ] || [ -z "$B_COMMIT" ]; then
        echo "    FAIL: missing commit(s) — A=$(git log --oneline --grep='A commit' -1 | cut -c1-7) B=$(git log --oneline --grep='B commit' -1 | cut -c1-7) (A rc=$ARC, B rc=$BRC)"
        sed 's/^/    | a.log: /' a.log; sed 's/^/    | b.log: /' b.log
        return 1
    fi
    local A_FILES B_FILES
    A_FILES=$(commit_files "$W1" "$A_COMMIT")
    B_FILES=$(commit_files "$W1" "$B_COMMIT")
    if [ "$A_FILES" = "a.txt" ] && [ "$B_FILES" = "b.txt" ] && [ "$ARC" -eq 0 ] && [ "$BRC" -eq 0 ]; then
        echo "    PASS: A=$(git rev-parse --short "$A_COMMIT")=[a.txt] B=$(git rev-parse --short "$B_COMMIT")=[b.txt], both rc=0, no cross-absorption"
        return 0
    fi
    echo "    FAIL: A files='$A_FILES' B files='$B_FILES' (A rc=$ARC, B rc=$BRC) — one absorbed the other"
    sed 's/^/    | a.log: /' a.log; sed 's/^/    | b.log: /' b.log
    return 1
}

# ── arm 2: seeded holds — row A holds a.zig, row B tries to stage it ─────
arm2() {
    echo "  2. seeded holds: row A in_progress holds a.zig; row B stages it → refused, naming A"
    local W2="$WORK/arm2"
    mk_repo "$W2" || return 1
    cd "$W2" || return 1
    echo "A in-flight edit" > a.zig
    echo "B work" > b.zig
    mkdir -p docs/infra/managent
    cat > docs/infra/managent/tasks.json <<'JSON'
{"A": {"status": "in_progress", "identifier": "workerA", "holds": ["a.zig"]},
 "B": {"status": "in_progress", "identifier": "workerB", "holds": ["b.zig"], "bundle": "B-bundle.md"}}
JSON
    printf '<!--managent set=A deliverables=b.zig-->\n' > B-bundle.md
    local COMMITS_BEFORE COMMITS_AFTER
    COMMITS_BEFORE=$(git rev-list --count HEAD)
    local OUT RC
    OUT=$("$WRAP" --task B a.zig -m "B tries to stage A's file" 2>&1)
    RC=$?
    COMMITS_AFTER=$(git rev-list --count HEAD)
    local ok=1
    if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "a.zig" && echo "$OUT" | grep -q "held by A" \
       && [ "$COMMITS_AFTER" -eq "$COMMITS_BEFORE" ]; then
        echo "    PASS: refused, named a.zig and holder A, no commit created"
    else
        echo "    FAIL: RC=$RC, commits $COMMITS_BEFORE->$COMMITS_AFTER"; echo "$OUT" | sed 's/^/    | /'
        ok=0
    fi
    # the index must be untouched by the refusal (the check runs BEFORE staging)
    if [ -z "$(git diff --cached --name-only)" ]; then
        echo "    PASS: index untouched (refusal left nothing staged)"
    else
        echo "    FAIL: refusal left staged content: $(git diff --cached --name-only)"
        ok=0
    fi
    return $(( 1 - ok ))
}

# ── arm 3: seeded explicit — same setup, --explicit allows, loudly ───────
arm3() {
    echo "  3. seeded explicit: held path with --explicit → allowed, escape recorded loudly"
    local W3="$WORK/arm3"
    mk_repo "$W3" || return 1
    cd "$W3" || return 1
    echo "A in-flight edit" > a.zig
    mkdir -p docs/infra/managent
    cat > docs/infra/managent/tasks.json <<'JSON'
{"A": {"status": "in_progress", "identifier": "workerA", "holds": ["a.zig"]}}
JSON
    local OUT RC
    OUT=$("$WRAP" --explicit a.zig -m "explicit commit of held path" 2>&1)
    RC=$?
    local IN_COMMIT
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
    if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "a.zig" ] \
       && echo "$OUT" | grep -qi "explicit" && echo "$OUT" | grep -q "held by A" && echo "$OUT" | grep -q "a.zig"; then
        echo "    PASS: --explicit allowed the held path, escape recorded loudly (named A and a.zig)"
        return 0
    fi
    echo "    FAIL: RC=$RC, commit: '$IN_COMMIT'"; echo "$OUT" | sed 's/^/    | /'
    return 1
}

# ── arm 4: null — single commit on a quiet repo ──────────────────────────
arm4() {
    echo "  4. null: single commit on a quiet repo → unchanged behaviour"
    local W4="$WORK/arm4"
    mk_repo "$W4" || return 1
    cd "$W4" || return 1
    echo amendment > amendment.md
    printf '<!--managent set=A deliverables=amendment.md-->\n' > bundle4.md
    local OUT RC
    OUT=$("$WRAP" --bundle bundle4.md amendment.md -m "null single commit" 2>&1)
    RC=$?
    local IN_COMMIT
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$')
    if [ "$RC" -eq 0 ] && [ "$IN_COMMIT" = "amendment.md" ]; then
        echo "    PASS: RC=0, commit $(git rev-parse --short HEAD) contains exactly amendment.md"
        return 0
    fi
    echo "    FAIL: RC=$RC, commit: '$IN_COMMIT'"; echo "$OUT" | sed 's/^/    | /'
    return 1
}

# ── arm 5: null — two concurrent runs, disjoint, no foreign content ──────
arm5() {
    echo "  5. null: two concurrent runs, genuinely disjoint, no in-flight content"
    local W5="$WORK/arm5"
    mk_repo "$W5" || return 1
    cd "$W5" || return 1
    echo "A work" > a.txt
    echo "B work" > b.txt
    printf '<!--managent set=A deliverables=a.txt-->\n' > bundleA.md
    printf '<!--managent set=A deliverables=b.txt-->\n' > bundleB.md
    ( "$WRAP" --bundle bundleA.md a.txt -m "A null" > a.log 2>&1; echo $? > a.rc ) &
    local APID=$!
    ( "$WRAP" --bundle bundleB.md b.txt -m "B null" > b.log 2>&1; echo $? > b.rc ) &
    local BPID=$!
    wait "$APID" 2>/dev/null; wait "$BPID" 2>/dev/null
    local ARC BRC
    ARC=$(cat a.rc 2>/dev/null || echo 99)
    BRC=$(cat b.rc 2>/dev/null || echo 99)
    local A_COMMIT B_COMMIT
    A_COMMIT=$(git log --format=%H --grep="A null" -1)
    B_COMMIT=$(git log --format=%H --grep="B null" -1)
    if [ -z "$A_COMMIT" ] || [ -z "$B_COMMIT" ]; then
        echo "    FAIL: missing commit(s) — A=$(git log --oneline --grep='A null' -1 | cut -c1-7) B=$(git log --oneline --grep='B null' -1 | cut -c1-7) (A rc=$ARC, B rc=$BRC)"
        sed 's/^/    | a.log: /' a.log; sed 's/^/    | b.log: /' b.log
        return 1
    fi
    local A_FILES B_FILES
    A_FILES=$(commit_files "$W5" "$A_COMMIT")
    B_FILES=$(commit_files "$W5" "$B_COMMIT")
    if [ "$A_FILES" = "a.txt" ] && [ "$B_FILES" = "b.txt" ] && [ "$ARC" -eq 0 ] && [ "$BRC" -eq 0 ]; then
        echo "    PASS: both succeeded, A=[a.txt] B=[b.txt], no cross-absorption (mutex did not brake a healthy fleet)"
        return 0
    fi
    echo "    FAIL: A files='$A_FILES' B files='$B_FILES' (A rc=$ARC, B rc=$BRC)"
    sed 's/^/    | a.log: /' a.log; sed 's/^/    | b.log: /' b.log
    return 1
}

# ── arm 6: seeded contention — external holder takes the lock ────────────
arm6() {
    echo "  6. seeded contention: external holder → wrapper with short timeout refuses"
    local W6="$WORK/arm6"
    mk_repo "$W6" || return 1
    cd "$W6" || return 1
    echo work > work.txt
    printf '<!--managent set=A deliverables=work.txt-->\n' > bundle6.md
    mkdir -p docs/infra/managent
    python3 - "$W6/docs/infra/managent/git-commit-mine.lock" "$W6/locked.marker" <<'PYEOF' &
import fcntl, time, sys
lock, marker = sys.argv[1], sys.argv[2]
f = open(lock, "w")
fcntl.flock(f.fileno(), fcntl.LOCK_EX)
open(marker, "w").write("locked")
time.sleep(3)
PYEOF
    local HOLDER=$!
    local _ i
    for i in $(seq 1 50); do [ -f "$W6/locked.marker" ] && break; sleep 0.1; done
    local OUT RC
    OUT=$(GCM_LOCK_TIMEOUT_SECS=1 "$WRAP" --bundle bundle6.md work.txt -m "contended commit" 2>&1)
    RC=$?
    wait "$HOLDER" 2>/dev/null
    local ok=1
    if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "mutex"; then
        echo "    PASS: refused after the short timeout, naming the commit mutex (lock is exclusive)"
    else
        echo "    FAIL: RC=$RC, expected mutex refusal"; echo "$OUT" | sed 's/^/    | /'
        ok=0
    fi
    # the holder is gone; the lock must be acquirable again (no stale lock)
    local OUT2 RC2
    OUT2=$("$WRAP" --bundle bundle6.md work.txt -m "retry after holder gone" 2>&1)
    RC2=$?
    if [ "$RC2" -eq 0 ]; then
        echo "    PASS: lock re-acquired after the holder released (no stale-lock wedge)"
    else
        echo "    FAIL: retry after release failed RC=$RC2"; echo "$OUT2" | sed 's/^/    | /'
        ok=0
    fi
    return $(( 1 - ok ))
}

arm1 || FAIL=1
arm2 || FAIL=1
arm3 || FAIL=1
arm4 || FAIL=1
arm5 || FAIL=1
arm6 || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-commit-concurrency: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-commit-concurrency: FAILURES ==="
    exit 1
fi
