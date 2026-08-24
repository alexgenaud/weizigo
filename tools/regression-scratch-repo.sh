#!/usr/bin/env bash
# regression-scratch-repo.sh — controls for tools/lib/scratch-repo.sh.
#
# The helper is the ONE place a scratch git repository is created, so its
# own controls are the point (T849, 2026-08-24): they prove the helper
# (a) makes a working scratch repo from a healthy shell, (b) prevents the
# 2026-08-24 incident even when GIT_DIR is inherited pointing at a real
# repository — and that the OLD hand-rolled pattern under the same
# conditions DID damage a repo, so the control has teeth — (c) is safe to
# call more than once, and (d) leaves no accumulation.
#
# Four arms:
#   A. null         — healthy call → working repo, REAL repo untouched.
#   B. seeded-defect — helper with GIT_DIR aimed at a throwaway "victim"
#                     repo leaves the victim intact (incident prevented);
#                     the OLD pattern under the same conditions truncates
#                     a throwaway victim (incident reproduced). The OLD
#                     arm is NEVER run against this repository.
#   C. idempotence  — two calls in one script → two distinct working repos.
#   D. cleanup      — scratch dirs are ordinary dirs under the normalised
#                     root; created, removed, none remain (no accumulation).
#
# Red-then-green: arm B is shown red first (the old pattern reproduces the
# incident against a throwaway victim) then green (the helper prevents it
# against another throwaway victim). Arms A, C, D assert invariants the
# standing tooling rule permits when a defect cannot be re-observed failing
# in the thing under test; each names the invariant it would catch.
#
# Everything scratch lives under /tmp/weizigo; the REAL repository is read
# only (worktree/treecount checks) and never written by any arm.
#
# Task: T849 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
LIB="$PROJECT/tools/lib/scratch-repo.sh"
FAIL=0
ARMS=4

cleanup() { [ -n "${CLEANUP:-}" ] && rm -rf $CLEANUP 2>/dev/null || true; }
trap cleanup EXIT
CLEANUP=""

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# real-repo invariants — read only
real_toplevel="$(git -C "$PROJECT" rev-parse --show-toplevel)"
real_worktree="$(git -C "$PROJECT" config --get core.worktree || true)"
real_tree="$(git -C "$PROJECT" ls-tree -r --name-only HEAD | wc -l | tr -d ' ')"

echo "=== regression-scratch-repo (T849) — $ARMS arms ==="
echo "  real repo: toplevel=$real_toplevel worktree=[${real_worktree}] tree=$real_tree"

# ── A. null control — healthy call, real repo untouched ──────────────────
echo "  A. null: healthy call → working repo; real repo intact (invariant)"
# (would catch: a helper that set core.worktree on the real repo, or that
#  failed to actually `git init`.)
source "$LIB"
weizigo_scratch_repo t849-null A_DIR
CLEANUP="$A_DIR"
if git -C "$A_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "helper produced a working git repo"
else
    fail "helper did not produce a git repo at $A_DIR"
fi
wt="$(git -C "$PROJECT" config --get core.worktree || true)"
tc="$(git -C "$PROJECT" ls-tree -r --name-only HEAD | wc -l | tr -d ' ')"
tl="$(git -C "$PROJECT" rev-parse --show-toplevel)"
if [ -z "$wt" ] && [ "$tc" = "$real_tree" ] && [ "$tl" = "$real_toplevel" ]; then
    pass "real repo untouched (worktree unset, tree $tc, toplevel ok)"
else
    fail "real repo changed: worktree=[${wt}] tree=$tc toplevel=$tl"
fi

# ── B. seeded-defect — the incident, reproduced then prevented ───────────
echo "  B. seeded-defect: GIT_DIR aimed at a victim — old pattern damages it (red), helper does not (green)"
make_victim() {  # $1 = dir → a throwaway repo with 5 committed files
    local v="$1"
    ( cd "$v" && git init -q && git config user.email t/t && git config user.name t \
        && for i in 1 2 3 4 5; do echo "f$i" > "file$i"; done \
        && git add -A && git commit -qm base ) >/dev/null 2>&1
}
victim_tree() { git -C "$1" ls-tree -r --name-only HEAD | wc -l | tr -d ' '; }
victim_wt()   { git -C "$1" config --get core.worktree || true; }

# B-red: the OLD hand-rolled pattern (no unset) truncates a throwaway victim
V_RED="$(mktemp -d /tmp/weizigo/t849-red-V-XXXXXX)"; CLEANUP="$CLEANUP $V_RED"
make_victim "$V_RED"
red_before=$(victim_tree "$V_RED"); red_before_wt=$(victim_wt "$V_RED")
S_RED="$(mktemp -d /tmp/weizigo/t849-red-S-XXXXXX)"; CLEANUP="$CLEANUP $S_RED"
echo lone > "$S_RED/only.txt"
# exactly the inherited-env shape git gives a hook child
GIT_DIR="$V_RED/.git" GIT_WORK_TREE="$S_RED" bash -c \
    'cd "$0" && git init -q && git add -A && git commit -qm trunc' "$S_RED" >/dev/null 2>&1
red_after=$(victim_tree "$V_RED"); red_after_wt=$(victim_wt "$V_RED")
if [ "$red_after" -lt "$red_before" ] && [ -n "$red_after_wt" ]; then
    pass "RED: old pattern truncated victim ${red_before}->${red_after} and set core.worktree (incident reproduced)"
else
    fail "RED: old pattern did NOT reproduce the incident (tree ${red_before}->${red_after}, wt=[${red_after_wt}]) -- control lacks teeth"
fi

# B-green: the helper, with the SAME inherited env, leaves a victim intact
V_GRN="$(mktemp -d /tmp/weizigo/t849-grn-V-XXXXXX)"; CLEANUP="$CLEANUP $V_GRN"
make_victim "$V_GRN"
grn_before=$(victim_tree "$V_GRN"); grn_before_wt=$(victim_wt "$V_GRN")
# inherit the incident-shaped env, then source the helper and use it
G_DIR=""
GIT_DIR="$V_GRN/.git" GIT_WORK_TREE="/tmp/weizigo/t849-grn-env" bash -c '
    set -u
    source "$1"
    weizigo_scratch_repo t849-grn G
    ( cd "$G" && git config user.email t/t && git config user.name t \
        && echo lone > only.txt && git add -A && git commit -qm base2 ) >/dev/null 2>&1
    printf "%s" "$G"
' _ "$LIB" > /tmp/weizigo/t849-grn-out 2>/dev/null
G_DIR="$(cat /tmp/weizigo/t849-grn-out 2>/dev/null)"; CLEANUP="$CLEANUP $G_DIR"
grn_after=$(victim_tree "$V_GRN"); grn_after_wt=$(victim_wt "$V_GRN")
if [ "$grn_after" = "$grn_before" ] && [ -z "$grn_after_wt" ]; then
    pass "GREEN: helper left victim intact (tree ${grn_before}->${grn_after}, worktree still unset)"
else
    fail "GREEN: helper changed the victim (tree ${grn_before}->${grn_after}, worktree=[${grn_after_wt}])"
fi
if [ -n "$G_DIR" ] && git -C "$G_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    pass "GREEN: helper built a working repo of its own at the normalised root"
else
    fail "GREEN: helper did not produce a working repo"
fi

# ── C. idempotence — two calls, two distinct repos ───────────────────────
echo "  C. idempotence: two calls → two distinct working repos (invariant)"
# (would catch: a helper that reused one dir, or that broke a second call)
weizigo_scratch_repo t849-idem C1
weizigo_scratch_repo t849-idem C2
CLEANUP="$CLEANUP $C1 $C2"
if [ -n "$C1" ] && [ -n "$C2" ] && [ "$C1" != "$C2" ]; then
    pass "two calls yielded distinct paths"
else
    fail "two calls did not yield distinct paths: [$C1] vs [$C2]"
fi
git -C "$C1" rev-parse --is-inside-work-tree >/dev/null 2>&1 && pass "first repo is a git repo" || fail "first repo not a git repo"
git -C "$C2" rev-parse --is-inside-work-tree >/dev/null 2>&1 && pass "second repo is a git repo" || fail "second repo not a git repo"

# ── D. cleanup — scratch dirs do not accumulate ──────────────────────────
echo "  D. cleanup: scratch dirs are ordinary dirs; created and removed, none remain (invariant)"
# (would catch: a helper that created dirs outside the normalised root, or
#  that left hidden state a `rm -rf` could not clear)
weizigo_scratch_repo t849-cln D1
weizigo_scratch_repo t849-cln D2
weizigo_scratch_repo t849-cln D3
made="$D1 $D2 $D3"
count=0
for d in $made; do
    case "$d" in "$WEIZIGO_SCRATCH_ROOT"/*) count=$((count+1));; esac
done
if [ "$count" -eq 3 ]; then
    pass "all three dirs live under the normalised root $WEIZIGO_SCRATCH_ROOT"
else
    fail "a dir escaped the normalised root: $made"
fi
rm -rf $made
left=0
for d in $D1 $D2 $D3; do [ -e "$d" ] && left=$((left+1)); done
if [ "$left" -eq 0 ]; then
    pass "rm -rf cleared all three; no accumulation"
else
    fail "$left dir(s) survived rm -rf: $made"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-scratch-repo: ALL $ARMS ARMS PASSED"
else
    echo "regression-scratch-repo: FAILURES"
    exit 1
fi