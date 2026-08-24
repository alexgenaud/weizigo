#!/usr/bin/env bash
# regression-commit-isolation.sh — T902 controls for tools/git-commit-mine
#
# WHY THIS EXISTS
#
# T547 gave the wrapper a commit mutex: an exclusive flock held across
# stage→verify→commit. It works, and on 2026-08-24 it did not help. T891
# staged its four files BY NAME (`git add -- <paths>`, never -A, exactly as
# the rule requires); T901 then committed and T891's four files landed in
# b47c248 under T901's message. The work survived byte-identical; the
# authorship did not.
#
# The mechanism, reproduced by arm 1 below:
#
#   the lock serialises COMMITTERS. It does not isolate the INDEX.
#
# All consoles share one .git/index. Only wrapper invocations take the mutex,
# so a bare `git add` from any console — or from any tool that is not the
# wrapper — lands in the shared index whenever it likes, including inside the
# lock holder's verify→commit window. The holder's `git commit` then commits
# the whole index, foreign paths and all, and every one of the wrapper's four
# guarantees is satisfied on the way in: it named its paths, it verified the
# staged set, it checked scope. The verification simply happened before the
# foreign content arrived.
#
# Serialising access to shared mutable state is not the same as not sharing
# it. These are the controls for not sharing it: a per-invocation private
# index (GIT_INDEX_FILE), which makes another console's staging structurally
# invisible to this console's commit.
#
# ARMS
#   1. seeded (capture)   B's wrapper commit is delayed mid-flight; console A
#                         bare-`git add`s its own file into the window. B's
#                         commit must contain ONLY b.txt and A's staging must
#                         survive. Run 3x — a race that reproduces sometimes
#                         is not fixed by a test that runs it once. This arm
#                         is the T891/T901 incident, mechanically.
#   2. seeded (wedge)     the same collision the other way round: A's file is
#                         already staged when B starts. Today the shared index
#                         does not merely capture — it also BLOCKS, refusing a
#                         correct commit for a foreign path B never touched.
#   3. seeded (hook)      with the pre-commit backstop installed and identity
#                         set, a wrapper commit must still succeed while a
#                         foreign path sits in the shared index — the hook has
#                         to read the index the commit is actually built from.
#   4. null (quiet)       one console alone commits exactly its paths, AND
#                         leaves the shared index agreeing with HEAD (a
#                         private index that is never reconciled makes every
#                         committed file look staged-for-reversion to the next
#                         plain `git commit`).
#   5. null (no-op)       a named path already committed and unchanged is
#                         still the healthy no-op, not a failure, and creates
#                         no commit.
#   6. null (missing)     a named path that does not exist is still REFUSED,
#                         not silently committed.
#
# Every fixture is synthetic and lives under /tmp/weizigo — never the live
# repo (T445). Nothing here touches a tracked file.
#
# Task: T902 · Role: worker · Model: claude-opus-5 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIVE="$(cd "$HERE/.." && pwd)"
WRAP="$HERE/git-commit-mine"
HOOK="$LIVE/tools/hooks/pre-commit"
REAL_GIT="$(command -v git)"
FAIL=0

# Determinism: the wrapper's env fallback (T454) and the test seams must not
# inherit anything from the caller's shell. The git env must go too — a child
# `git init` with GIT_DIR still set reinitialises the LIVE repo (T849).
unset MANAGENT_TASK_ID MANAGENT_STORE GIT_MINE_EXPLICIT 2>/dev/null || true
unset GCM_TEST_DELAY_COMMIT GCM_TEST_MARKER GCM_LOCK_TIMEOUT_SECS 2>/dev/null || true
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE 2>/dev/null || true

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/commit-isolation-XXXXXX)" || {
    echo "regression-commit-isolation.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2
    exit 2
}
trap 'rm -rf "$WORK"' EXIT

echo "=== git-commit-mine index-isolation regression (T902) ==="

mk_repo() {  # $1 = dir
    mkdir -p "$1"
    (
        cd "$1" || exit 2
        git init -q .
        git config user.email t902@test
        git config user.name T902
        echo base > base.txt
        git add base.txt
        git commit -qm base
    )
}

# A PATH shim that parks the wrapper inside its own verify→commit window.
# The marker file makes the race deterministic: the foreign `git add` waits
# for the shim to announce it is parked, so the collision lands in exactly
# the window the incident used, every run.
mk_delay_shim() {  # $1 = dir
    mkdir -p "$1/shim"
    cat > "$1/shim/git" <<SHIM
#!/bin/sh
if [ "\$1" = "commit" ] && [ "\$2" = "-m" ] && [ "\$#" -eq 3 ] && [ "\${GCM_TEST_DELAY_COMMIT:-0}" = "1" ]; then
    : > "\${GCM_TEST_MARKER:-/dev/null}"
    sleep 2
fi
exec "$REAL_GIT" "\$@"
SHIM
    chmod +x "$1/shim/git"
}

commit_files() {  # $1 = repo  $2 = rev → changed paths, one per line, sorted
    git -C "$1" show --format= --name-only "$2" | grep -v '^$' | sort
}

wait_for() {  # $1 = file, waits up to 10s
    local i
    for i in $(seq 1 100); do [ -f "$1" ] && return 0; sleep 0.1; done
    return 1
}

# ── arm 1: seeded capture — the T891/T901 incident, 3 runs ───────────────
arm1_once() {  # $1 = run number
    local n="$1"
    local W="$WORK/arm1-$n"
    mk_repo "$W" || return 1
    mk_delay_shim "$W"
    cd "$W" || return 1
    echo "B work" > b.txt
    echo "A work" > a.txt          # A's file exists but is NOT yet staged
    printf '<!--managent set=A deliverables=b.txt-->\n' > bundleB.md

    # console B: wrapper commit, parked inside its verify→commit window
    (
        PATH="$W/shim:$PATH" GCM_TEST_DELAY_COMMIT=1 GCM_TEST_MARKER="$W/parked" \
            "$WRAP" --bundle bundleB.md b.txt -m "B commit run $n" > b.log 2>&1
        echo $? > b.rc
    ) &
    local BPID=$!

    # console A: a bare, by-name `git add` — the exact shape T891 used —
    # landing inside B's window. A takes no mutex; nothing stops it.
    if wait_for "$W/parked"; then
        git add -- a.txt
    else
        echo "    FAIL(run $n): the wrapper never reached its commit (shim marker absent)"
        sed 's/^/    | b.log: /' b.log 2>/dev/null
        wait "$BPID" 2>/dev/null
        return 1
    fi
    wait "$BPID" 2>/dev/null

    local BRC B_COMMIT B_FILES STILL_STAGED
    BRC=$(cat b.rc 2>/dev/null || echo 99)
    B_COMMIT=$(git log --format=%H --grep="B commit run $n" -1)
    if [ -z "$B_COMMIT" ]; then
        echo "    FAIL(run $n): B produced no commit (rc=$BRC)"
        sed 's/^/    | b.log: /' b.log 2>/dev/null
        return 1
    fi
    B_FILES=$(commit_files "$W" "$B_COMMIT")
    STILL_STAGED=$(git diff --cached --name-only)
    local ok=1
    if [ "$B_FILES" != "b.txt" ]; then
        echo "    FAIL(run $n): B's commit $(git rev-parse --short "$B_COMMIT") contains [$(echo "$B_FILES" | tr '\n' ' ')] — it captured console A's file"
        ok=0
    fi
    if [ "$BRC" -ne 0 ]; then
        echo "    FAIL(run $n): B rc=$BRC (a correct commit for B's own path must not be refused)"
        sed 's/^/    | b.log: /' b.log 2>/dev/null
        ok=0
    fi
    if ! printf '%s\n' "$STILL_STAGED" | grep -Fxq "a.txt"; then
        echo "    FAIL(run $n): console A's staged a.txt did not survive (staged now: [$(echo "$STILL_STAGED" | tr '\n' ' ')])"
        ok=0
    fi
    [ "$ok" -eq 1 ] && echo "    PASS(run $n): B=$(git rev-parse --short "$B_COMMIT")=[b.txt], A's a.txt still staged and unattributed to B"
    return $(( 1 - ok ))
}

arm1() {
    echo "  1. seeded capture: bare 'git add' inside the wrapper's commit window (3 runs)"
    local rc=0 n
    for n in 1 2 3; do
        arm1_once "$n" || rc=1
    done
    return $rc
}

# ── arm 2: seeded wedge — foreign staged content blocks a correct commit ──
arm2() {
    echo "  2. seeded wedge: foreign path already staged → B's own commit must still land"
    local W="$WORK/arm2"
    mk_repo "$W" || return 1
    cd "$W" || return 1
    echo "A work" > a.txt
    echo "B work" > b.txt
    printf '<!--managent set=A deliverables=b.txt-->\n' > bundleB.md
    git add -- a.txt                      # console A stages by name, no wrapper
    local OUT RC
    OUT=$("$WRAP" --bundle bundleB.md b.txt -m "B commit over foreign staging" 2>&1)
    RC=$?
    local IN_COMMIT STILL_STAGED ok=1
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$' | sort | tr '\n' ' ')
    STILL_STAGED=$(git diff --cached --name-only)
    if [ "$RC" -ne 0 ]; then
        echo "    FAIL: RC=$RC — another console's staging blocked B's correct commit"
        echo "$OUT" | sed 's/^/    | /'
        ok=0
    elif [ "$IN_COMMIT" != "b.txt " ]; then
        echo "    FAIL: commit contains [$IN_COMMIT], expected b.txt only"
        echo "$OUT" | sed 's/^/    | /'
        ok=0
    fi
    if ! printf '%s\n' "$STILL_STAGED" | grep -Fxq "a.txt"; then
        echo "    FAIL: console A's staged a.txt was consumed (staged now: [$(echo "$STILL_STAGED" | tr '\n' ' ')])"
        ok=0
    fi
    [ "$ok" -eq 1 ] && echo "    PASS: B committed b.txt alone; A's staged a.txt untouched"
    return $(( 1 - ok ))
}

# ── arm 3: seeded hook — the backstop must read the commit's own index ────
arm3() {
    echo "  3. seeded hook: pre-commit backstop installed, foreign path staged → commit still lands"
    local W="$WORK/arm3"
    mk_repo "$W" || return 1
    cd "$W" || return 1
    mkdir -p tools/hooks bin docs/infra/managent
    cp "$HOOK" tools/hooks/pre-commit
    cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
    cp "$LIVE/tools/hooks/claimlint-floor.json" tools/hooks/
    # the claimlint gate is not the instrument under test here — it has its own
    # control in regression-precommit.sh. Stub it clean.
    cat > bin/weizigo-claimlint <<'STUB'
#!/bin/sh
if [ "$1" = "c7" ]; then
    echo "  non-conforming: 0 (fails the run when > 0; spec §6.1)"
    echo "  unabsorbed: 0"
    echo "  dispositioned: 0"
    exit 0
fi
echo "  calibration: PASS"
echo "  C1a orphans / C1b alarms      0 / 0   (FAILS)"
echo "  C2 dangling evidence paths    0   (FAILS)"
echo "  C3 PROVEN w/o committed evid.      0   (debt...)"
echo "  C6 cite-tag mismatches        0   (FAILS)"
echo "  C7 non-conforming files        0   (reported)"
echo "  C9 tree-mapping violations      0   (FAILS)"
exit 0
STUB
    chmod +x bin/weizigo-claimlint
    git config core.hooksPath tools/hooks
    printf '<!--managent set=A deliverables=b.txt-->\n' > B-bundle.md
    printf '{"B": {"status": "in_progress", "identifier": "workerB", "bundle": "B-bundle.md"}}\n' \
        > docs/infra/managent/tasks.json
    echo "A work" > a.txt
    echo "B work" > b.txt
    git add -- a.txt                      # foreign staging, present at hook time
    local OUT RC
    OUT=$(MANAGENT_TASK_ID=B "$WRAP" --task B b.txt -m "B commit under the hook" 2>&1)
    RC=$?
    local IN_COMMIT ok=1
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$' | sort | tr '\n' ' ')
    if [ "$RC" -ne 0 ] || [ "$IN_COMMIT" != "b.txt " ]; then
        echo "    FAIL: RC=$RC, commit=[$IN_COMMIT] — the backstop judged the shared index, not the commit's"
        echo "$OUT" | sed 's/^/    | /'
        ok=0
    else
        echo "    PASS: hook allowed the commit; it contains b.txt alone"
    fi
    if ! git diff --cached --name-only | grep -Fxq "a.txt"; then
        echo "    FAIL: console A's staged a.txt did not survive the hook path"
        ok=0
    fi
    return $(( 1 - ok ))
}

# ── arm 4: null — one console alone, and the shared index left honest ────
arm4() {
    echo "  4. null: single console commits exactly its paths and leaves the shared index == HEAD"
    local W="$WORK/arm4"
    mk_repo "$W" || return 1
    cd "$W" || return 1
    echo "solo work" > solo.txt
    printf '<!--managent set=A deliverables=solo.txt-->\n' > bundle4.md
    local OUT RC
    OUT=$("$WRAP" --bundle bundle4.md solo.txt -m "null solo commit" 2>&1)
    RC=$?
    local IN_COMMIT STAGED_AFTER STATUS_AFTER ok=1
    IN_COMMIT=$(git show --format= --name-only HEAD | grep -v '^$' | tr '\n' ' ')
    STAGED_AFTER=$(git diff --cached --name-only)
    # tracked state only: the fixture leaves its own bundle/kanban files
    # untracked on purpose, and those are not what this arm is measuring.
    STATUS_AFTER=$(git status --porcelain --untracked-files=no)
    if [ "$RC" -ne 0 ] || [ "$IN_COMMIT" != "solo.txt " ]; then
        echo "    FAIL: RC=$RC, commit=[$IN_COMMIT]"
        echo "$OUT" | sed 's/^/    | /'
        ok=0
    fi
    # The reconciliation check: a private index that is never written back
    # leaves the shared index holding the pre-commit blob, so the file reads
    # as "staged for reversion" and the next plain `git commit` reverts it.
    if [ -n "$STAGED_AFTER" ] || [ -n "$STATUS_AFTER" ]; then
        echo "    FAIL: shared index/worktree not reconciled after the commit —"
        echo "    |   git diff --cached: [$(echo "$STAGED_AFTER" | tr '\n' ' ')]"
        echo "    |   git status --porcelain: [$(echo "$STATUS_AFTER" | tr '\n' ' ')]"
        ok=0
    fi
    [ "$ok" -eq 1 ] && echo "    PASS: commit $(git rev-parse --short HEAD)=[solo.txt], shared index agrees with HEAD"
    return $(( 1 - ok ))
}

# ── arm 5: null — already committed and unchanged is still a healthy no-op ─
arm5() {
    echo "  5. null: a named path already committed and unchanged → healthy no-op, no new commit"
    local W="$WORK/arm5"
    mk_repo "$W" || return 1
    cd "$W" || return 1
    printf '<!--managent set=A deliverables=base.txt-->\n' > bundle5.md
    local BEFORE AFTER OUT RC
    BEFORE=$(git rev-parse HEAD)
    OUT=$("$WRAP" --bundle bundle5.md base.txt -m "no-op commit" 2>&1)
    RC=$?
    AFTER=$(git rev-parse HEAD)
    if [ "$RC" -eq 0 ] && [ "$BEFORE" = "$AFTER" ] && echo "$OUT" | grep -qi "nothing to commit"; then
        echo "    PASS: reported as a healthy no-op, HEAD unmoved"
        return 0
    fi
    echo "    FAIL: RC=$RC, HEAD $BEFORE -> $AFTER"
    echo "$OUT" | sed 's/^/    | /'
    return 1
}

# ── arm 6: null — a nonexistent named path is still refused ──────────────
arm6() {
    echo "  6. null: a named path that does not exist → REFUSED, no commit"
    local W="$WORK/arm6"
    mk_repo "$W" || return 1
    cd "$W" || return 1
    printf '<!--managent set=A deliverables=ghost.txt-->\n' > bundle6.md
    local BEFORE AFTER OUT RC
    BEFORE=$(git rev-parse HEAD)
    OUT=$("$WRAP" --bundle bundle6.md ghost.txt -m "commit a file that isn't there" 2>&1)
    RC=$?
    AFTER=$(git rev-parse HEAD)
    if [ "$RC" -ne 0 ] && [ "$BEFORE" = "$AFTER" ]; then
        echo "    PASS: refused (rc=$RC), HEAD unmoved"
        return 0
    fi
    echo "    FAIL: RC=$RC, HEAD $BEFORE -> $AFTER — a missing path was silently accepted"
    echo "$OUT" | sed 's/^/    | /'
    return 1
}

arm1 || FAIL=1
arm2 || FAIL=1
arm3 || FAIL=1
arm4 || FAIL=1
arm5 || FAIL=1
arm6 || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-commit-isolation: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-commit-isolation: FAILURES ==="
    exit 1
fi
