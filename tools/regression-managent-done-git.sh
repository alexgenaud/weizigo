#!/usr/bin/env bash
# regression-managent-done-git.sh — T278 controls for `managent done`'s
# git-aware deliverable check.
#
# The old check statFile'd each deliverable: T272 closed pass on 2026-08-02
# with all deliverables untracked or uncommitted and the check passed — a
# deliverable that is not in git is not a deliverable. The new check asks git
# (src/managent/main.zig, cmdDone): a deliverable passes iff it is (a) tracked
# and free of uncommitted modifications, (b) a SHA256SUMS-pinned retention
# artifact under untracked/ (ARGUS T211), or (c) deleted in git history (the
# deliverable is the removal). Everything else is refused, naming the path.
#
# Controls (all synthetic, scratch repo under /tmp/weizigo, MANAGENT_STORE
# points at a scratch kanban — the live kanban is never touched):
#   null      committed deliverables -> done closes normally
#   seeded    one untracked deliverable -> refused, naming the path
#   seeded2   one modified (uncommitted) deliverable -> refused, naming it
#   retention SHA256SUMS-pinned untracked/ artifact -> closes normally
#   deletion  staged deletion -> refused; committed deletion -> closes
#
# Task: T278 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-02

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-done-git-XXXXXX)" || { echo "regression-managent-done-git.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t278@test
git config user.name T278
echo base > README.md
mkdir -p docs untracked artifacts docs/infra/managent
# T485: the absorption done-gate runs claimlint on every gated close; the
# scratch repo must carry a claimlint binary + a parseable (empty) register.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ ! -x "$GATE_CL" ]; then
    echo "SKIP: no weizigo-claimlint binary (build with 'zig build') — the done-gate needs it"
    exit 0
fi
mkdir -p bin docs/epistemic
cp "$GATE_CL" bin/weizigo-claimlint
cat > docs/epistemic/CLAIMS.md <<'CLAIMS_EOF'
# scratch register — done-gate control (T485)

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

seed_task() {  # $1=id  $2=deliverables-path
    local id="$1" dl="$2"
    printf '<!--managent set=A deliverables=%s-->\n' "$dl" > "$WORK/untracked/$id-bundle.md"
}

seed_task DNULL docs/ok.md
seed_task DSEED docs/seed.md
seed_task DSEED2 docs/mod.md
seed_task DRET untracked/big.wzo
seed_task DDEL docs/gone.md

cat > "$STORE" <<'JSONEOF'
{
  "DNULL": {"status":"in_progress","agent":"T278","model":"deepseek-v4-flash","bundle":"untracked/DNULL-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-02T00:00:00Z","claimed":"2026-08-02T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "DSEED": {"status":"in_progress","agent":"T278","model":"deepseek-v4-flash","bundle":"untracked/DSEED-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-02T00:00:00Z","claimed":"2026-08-02T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "DSEED2": {"status":"in_progress","agent":"T278","model":"deepseek-v4-flash","bundle":"untracked/DSEED2-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-02T00:00:00Z","claimed":"2026-08-02T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "DRET": {"status":"in_progress","agent":"T278","model":"deepseek-v4-flash","bundle":"untracked/DRET-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-02T00:00:00Z","claimed":"2026-08-02T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "DDEL": {"status":"in_progress","agent":"T278","model":"deepseek-v4-flash","bundle":"untracked/DDEL-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-02T00:00:00Z","claimed":"2026-08-02T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":0},
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF

is_done() {  # $1=id  — task recorded done?
    "$MG" show "$1" 2>/dev/null | grep -q "done"
}

echo "=== managent done git check regression ==="

# ── null control ──────────────────────────────────────────────────────────
echo "  1. null control: committed deliverables close normally"
echo ok > docs/ok.md
git add docs/ok.md && git commit -qm "ok deliverable"
OUT=$("$MG" done DNULL --status pass 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && is_done DNULL; then
    echo "    PASS: DNULL closed (verdict pass), RC=0"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -3)"
    FAIL=1
fi

# ── seeded control: untracked deliverable ─────────────────────────────────
echo "  2. seeded control: untracked deliverable is refused, naming it"
echo seed > docs/seed.md            # on disk, NOT committed (the T272 hole)
OUT=$("$MG" done DSEED --status pass 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "docs/seed.md" && ! is_done DSEED; then
    echo "    PASS: refused, named docs/seed.md, task stays in_progress"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -5)"
    FAIL=1
fi

# ── seeded control 2: modified deliverable ────────────────────────────────
echo "  3. seeded control: modified (uncommitted) deliverable is refused"
echo mod > docs/mod.md
git add docs/mod.md && git commit -qm "mod deliverable"
echo more >> docs/mod.md            # uncommitted modification now
OUT=$("$MG" done DSEED2 --status pass 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "docs/mod.md" && ! is_done DSEED2; then
    echo "    PASS: refused, named docs/mod.md, task stays in_progress"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -5)"
    FAIL=1
fi
git checkout -- docs/mod.md

# ── retention control: SHA256SUMS-pinned untracked/ artifact ──────────────
echo "  4. retention control: SHA256SUMS-pinned untracked/ artifact passes"
echo "deadbeef  untracked/big.wzo" > artifacts/SHA256SUMS
echo wzo > untracked/big.wzo        # deliberately never committed (ARGUS T211)
OUT=$("$MG" done DRET --status pass 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && is_done DRET; then
    echo "    PASS: DRET closed via retention rule (untracked/ + SHA256SUMS)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -5)"
    FAIL=1
fi

# ── deletion control: staged deletion refused; committed deletion closes ──
echo "  5. deletion control: staged deletion refused, committed deletion closes"
echo gone > docs/gone.md
git add docs/gone.md && git commit -qm "gone deliverable"
git rm -q docs/gone.md              # staged deletion, not committed
OUT=$("$MG" done DDEL --status pass 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "docs/gone.md" && ! is_done DDEL; then
    echo "    PASS: staged-but-uncommitted deletion refused, naming docs/gone.md"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -5)"
    FAIL=1
fi
git commit -qm "delete gone"
OUT=$("$MG" done DDEL --status pass 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && is_done DDEL; then
    echo "    PASS: committed deletion accepted (deliverable is the removal)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | tail -5)"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-done-git: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-done-git: FAILURES ==="
    exit 1
fi
