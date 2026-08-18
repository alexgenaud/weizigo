#!/usr/bin/env bash
# regression-managent-resume.sh — T286 controls for `managent resume`
#
# The resume surface must never lie: a cold agent composes its picture of the
# world from it and has no way to cross-check. GRAND-AUDIT §4 found the previous
# surface (docs/status/CURRENT.md) stale within 24 hours of the remediation
# aimed at it. Controls:
#
#   null control      empty kanban + clean tree → the command SAYS "NOTHING IN
#                     FLIGHT" (an explicit statement, not an empty section that
#                     reads like an error), exit 0
#   seeded control    a task in_progress holding a file → BOTH the task id and
#                     the held path appear in the composed surface
#   degradation       sources that cannot exist in a scratch repo (claimlint,
#                     channel STATE.md, hook install) degrade to explicit
#                     "unavailable"/"none"/"NOT INSTALLED" markers — never
#                     empty silence and never fabricated numbers
#   self-defense      (T289) the surface reports its OWN provenance — "self:
#                     built from …", "source: HEAD …", "self-check: …" — so a
#                     stale binary cannot answer a cold agent with silence
#
# All fixtures are synthetic and run in /tmp/weizigo — the live kanban and live
# repo are never touched. MANAGENT_STORE points at a scratch kanban and the
# command is invoked from the scratch repo, so findRepoRoot resolves there.
#
# Binary resolution: $MANAGENT_BIN → zig-out/bin/managent (built, not yet
# deployed — T286 leaves the deploy to Orcha while the fleet is live) →
# bin/managent. SKIP (loudly) when none carries the resume command — a fresh
# clone without a build cannot run the control, same convention as
# regression-precommit.sh's claimlint SKIP.
#
# Task: T286 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-03

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

# ── binary resolution ─────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy (zig build deploy-managent)"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "managent resume"; then
    echo "SKIP: $MG does not carry the resume command — rebuild from src/managent/main.zig"
    exit 0
fi

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/managent-resume-XXXXXX)" || { echo "regression-managent-resume.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t286@test
git config user.name T286
echo base > README.md
mkdir -p docs untracked docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

echo "=== managent resume regression ==="

# ── null control ──────────────────────────────────────────────────────────
echo "  1. null control: nothing in flight + clean tree says so explicitly"
OUT=$("$MG" resume 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "NOTHING IN FLIGHT"; then
    echo "    PASS: empty kanban + clean tree → explicit 'NOTHING IN FLIGHT', RC=0"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── degradation: unbuildable sources degrade, not lie ─────────────────────
echo "  2. degradation control: unavailable sources are named, not silently empty"
if echo "$OUT" | grep -q "claimlint: unavailable" && \
   echo "$OUT" | grep -q "fresh clone has no channel" && \
   echo "$OUT" | grep -q "pre-commit hook: NOT INSTALLED"; then
    echo "    PASS: claimlint/STATE.md/hook all degrade to explicit markers"
else
    echo "    FAIL: output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── seeded control: in_progress task + held file both appear ──────────────
echo "  3. seeded control: in_progress task and its held file both appear"
cat > "$STORE" <<'JSONEOF'
{
  "TSEED": {"status":"in_progress","agent":"t286","model":"deepseek-v4-flash","bundle":"untracked/TSEED-bundle.md","set":"C","holds":["docs/engine/ARCHITECTURE.md"],"needs":[],"caps":[],"added":"2026-08-03T00:00:00Z","claimed":"2026-08-03T00:00:00Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"claim_count":1},
  "_sys": {"next_id": 9000, "directive_next": 1}
}
JSONEOF
OUT=$("$MG" resume 2>/dev/null)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "TSEED" && echo "$OUT" | grep -q "docs/engine/ARCHITECTURE.md"; then
    echo "    PASS: TSEED and its held path both present, RC=0"
else
    echo "    FAIL: RC=$RC, output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── seeded control 2: nothing-in-flight statement must NOT appear now ─────
echo "  4. seeded control: with a live task the empty-state statement is gone"
if echo "$OUT" | grep -q "NOTHING IN FLIGHT"; then
    echo "    FAIL: seeded kanban still reports NOTHING IN FLIGHT — the surface lies"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
else
    echo "    PASS: no NOTHING-IN-FLIGHT statement under a live task"
fi

# ── self-defense control (T289): the surface reports its own provenance ────
echo "  5. self-defense control: resume reports its own provenance + a verdict"
if echo "$OUT" | grep -q "self: built from" && \
   echo "$OUT" | grep -q "source: HEAD" && \
   echo "$OUT" | grep -q "self-check:"; then
    echo "    PASS: self block present (binary built from the real repo, HEAD is the scratch repo — a mismatch verdict is expected and stated, never silence)"
else
    echo "    FAIL: self block missing from resume output:"
    echo "$OUT" | sed 's/^/      /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-managent-resume: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-managent-resume: FAILURES ==="
    exit 1
fi
