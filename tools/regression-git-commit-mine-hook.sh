#!/bin/sh
# regression-git-commit-mine-hook.sh — T282 controls for the staged-path
# subset backstop in tools/hooks/pre-commit (gate 2).
#
# The wrapper (tools/git-commit-mine) enforces "staged ⊆ your scope" on the
# way in; the backstop enforces it for anyone who bypasses the wrapper — the
# case that actually bit us three times on 2026-08-02 (T268 absorbed T272's
# staged claimlint work into f74012b; the Orchestrator's `git add -A docs/`
# swept T266's evidence into 91f7cf3). Scope is resolved by
# tools/git-commit-mine-lib.sh — the SAME implementation the wrapper uses, so
# the hook cannot refuse the wrapper's own commits.
#
# Six arms, all synthetic in /tmp/weizigo — never the live repo:
#   1. null          identity known, staged ⊆ scope       -> hook exit 0
#   2. seeded        identity known, foreign staged       -> hook REFUSES (exit 1),
#                     naming the foreign path (T268 fixture shape)
#   3. unlabelled    no MANAGENT_TASK_ID, foreign staged  -> warns, ALLOWS (exit 0),
#                     naming the path (human / court seat ruling)
#   4. explicit      GIT_MINE_EXPLICIT=1, foreign staged  -> warns, ALLOWS (exit 0)
#   5. unresolvable  MANAGENT_TASK_ID not in kanban       -> warns, ALLOWS (exit 0),
#                     listing the paths
#   6. findings      staged file under findings/<id>-*.json is in scope -> exit 0
#
# The scratch repo carries a stub bin/weizigo-claimlint (the claimlint gate is
# NOT the instrument under test here — it has its own control in
# regression-precommit.sh) plus a scratch kanban (MANAGENT_STORE).
#
# Task: T282 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIVE="$(cd "$HERE/.." && pwd)"
HOOK="$LIVE/tools/hooks/pre-commit"
FAIL=0

stub_claimlint() {  # $1 = scratch repo root
    mkdir -p "$1/bin"
    cat > "$1/bin/weizigo-claimlint" <<'EOF'
#!/bin/sh
echo "  calibration: PASS"
echo "  C1a orphans / C1b alarms      0 / 0   (FAILS)"
echo "  C2 dangling evidence paths    0   (FAILS)"
echo "  C3 PROVEN w/o committed evid.      0   (debt...)"
echo "  C6 cite-tag mismatches        0   (FAILS)"
echo "  C9 tree-mapping violations      0   (FAILS)"
exit 0
EOF
    chmod +x "$1/bin/weizigo-claimlint"
}

seed_kanban() {  # $1 = repo root  $2 = task id  $3 = bundle name
    mkdir -p "$1/docs/infra/managent"
    printf '{"%s": {"bundle": "%s"}}\n' "$2" "$3" > "$1/docs/infra/managent/tasks.json"
}

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch path once sent this suite's arms
# into the LIVE repo (2026-08-18 incident). `exit` inside $() only leaves the
# subshell, so the failure branch kills the whole script by PID.
new_scratch() {
    mkdir -p /tmp/weizigo
    mktemp -d /tmp/weizigo/gcm-hook-test-XXXXXX || {
        echo "regression-git-commit-mine-hook: FATAL — scratch mktemp failed; refusing to run (T445)" >&2
        kill -TERM $$
        exit 2
    }
}

run_hook() {  # $1 = repo root; env: MANAGENT_TASK_ID, MANAGENT_STORE, GIT_MINE_EXPLICIT
    cd "$1" || exit 2
    FLOOR_FILE="$LIVE/tools/hooks/claimlint-floor.json" \
    MANAGENT_TASK_ID="${MANAGENT_TASK_ID:-}" \
    MANAGENT_STORE="${MANAGENT_STORE:-}" \
    GIT_MINE_EXPLICIT="${GIT_MINE_EXPLICIT:-0}" \
    "$HOOK" 2>&1
}

echo "=== regression-git-commit-mine-hook (staged-path subset backstop) ==="

# ── arm 1: null — identity known, staged ⊆ scope ─────────────────────────
echo "  1. null: identity known, staged paths in scope"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
seed_kanban "$WORK" T282H T282H-bundle.md
printf '<!--managent set=B deliverables=docs/ok.md-->\n' > T282H-bundle.md
mkdir -p docs
echo ok > docs/ok.md
git add docs/ok.md
OUT=$(MANAGENT_TASK_ID=T282H MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "⊆ scope"; then
    echo "    PASS: hook allowed (RC=0), reported staged ⊆ scope"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -3)"
    FAIL=1
fi
rm -rf "$WORK"

# ── arm 2: seeded — identity known, foreign staged path (T268 fixture) ───
echo "  2. seeded: identity known, foreign staged path REFUSED, naming it"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
seed_kanban "$WORK" T282H T282H-bundle.md
printf '<!--managent set=B deliverables=docs/ok.md-->\n' > T282H-bundle.md
mkdir -p docs
echo ok > docs/ok.md
echo foreign > docs/foreign.md
git add docs/ok.md docs/foreign.md
OUT=$(MANAGENT_TASK_ID=T282H MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "REFUSED" && echo "$OUT" | grep -q "docs/foreign.md"; then
    echo "    PASS: refused (RC=$RC), naming docs/foreign.md as outside the task scope"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL=1
fi
rm -rf "$WORK"

# ── arm 3: unlabelled — no identity, foreign staged → warn-and-allow ─────
echo "  3. unlabelled: no MANAGENT_TASK_ID, foreign staged -> warns and allows, naming it"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
mkdir -p docs
echo foreign > docs/foreign.md
git add docs/foreign.md
OUT=$(MANAGENT_TASK_ID="" MANAGENT_STORE="" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARNING" && echo "$OUT" | grep -q "docs/foreign.md"; then
    echo "    PASS: warned (RC=0), naming docs/foreign.md"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL=1
fi
rm -rf "$WORK"

# ── arm 4: explicit — GIT_MINE_EXPLICIT=1, foreign staged → warn-and-allow ─
echo "  4. explicit: GIT_MINE_EXPLICIT=1, foreign staged -> warns and allows, naming it"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
seed_kanban "$WORK" T282H T282H-bundle.md
printf '<!--managent set=B deliverables=docs/ok.md-->\n' > T282H-bundle.md
mkdir -p docs
echo ok > docs/ok.md
echo foreign > docs/foreign.md
git add docs/ok.md docs/foreign.md
OUT=$(MANAGENT_TASK_ID=T282H MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" GIT_MINE_EXPLICIT=1 run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARNING" && echo "$OUT" | grep -q "explicit"; then
    echo "    PASS: warned (RC=0) with the explicit-mode note, path listed"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL=1
fi
rm -rf "$WORK"

# ── arm 5: unresolvable identity → warn-and-allow, paths listed ──────────
echo "  5. unresolvable: MANAGENT_TASK_ID not in kanban -> warns and allows, listing paths"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
seed_kanban "$WORK" T282H T282H-bundle.md
printf '<!--managent set=B deliverables=docs/ok.md-->\n' > T282H-bundle.md
mkdir -p docs
echo ok > docs/ok.md
git add docs/ok.md
OUT=$(MANAGENT_TASK_ID=TGHOST MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "WARNING" && echo "$OUT" | grep -q "docs/ok.md"; then
    echo "    PASS: warned (RC=0) listing docs/ok.md (identity unknown = unlabelled)"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL=1
fi
rm -rf "$WORK"

# ── arm 6: findings glob is in scope ─────────────────────────────────────
echo "  6. findings: staged findings/<id>-*.json is in scope"
WORK=$(new_scratch)
cd "$WORK"
git init -q
git config user.email t282@test
git config user.name T282
echo base > README.md
git add README.md
git commit -qm base
mkdir -p tools
cp "$LIVE/tools/git-commit-mine-lib.sh" tools/
stub_claimlint "$WORK"
seed_kanban "$WORK" T282H T282H-bundle.md
printf '<!--managent set=B deliverables=docs/ok.md-->\n' > T282H-bundle.md
mkdir -p docs findings
echo ok > docs/ok.md
echo '{"task_id": "T282H"}' > findings/T282H-find.json
git add docs/ok.md findings/T282H-find.json
OUT=$(MANAGENT_TASK_ID=T282H MANAGENT_STORE="$WORK/docs/infra/managent/tasks.json" run_hook "$WORK")
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "⊆ scope"; then
    echo "    PASS: hook allowed (RC=0) — findings glob included in scope"
else
    echo "    FAIL: RC=$RC, output: $(echo "$OUT" | head -4)"
    FAIL=1
fi
rm -rf "$WORK"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-git-commit-mine-hook: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-git-commit-mine-hook: FAILURES ==="
    exit 1
fi
