#!/usr/bin/env bash
# regression-title-gate.sh
# T906 regression: the 40-char title gate lives at REGISTRATION (managent
# add/suggest), not only at bin/dispatch.
#
# The defect (T906, measured by the seat): bin/dispatch refuses a bundle
# whose title exceeds 40 chars (DELEGATOR.md §Task titles), but rows are
# CREATED by `managent add` / `managent suggest`, which enforced nothing.
# 271 of 726 briefs (37%) carry a title longer than 40 chars — the worst
# is 139 — and the operator reads these in the fleet dashboard, one line
# per lane.  The dispatcher catches a bad title only at dispatch — after
# the row exists, after the brief is written, and never at all for a path
# that skips it.  (Pattern, stated because it recurs: when two entry
# points do one job, a guard added to one of them protects nothing.)
#
# Must be RED against the pre-T906 binary: add/suggest register any title,
# the store row carries no title field, and `show` cannot name the row
# from the store.
#
# Arms (all against a scratch MANAGENT_STORE outside a fake repo_root):
#   1. seeded  — a 60-char title is refused at add, naming title + length;
#                a 40-char title registers (the brief's headline arm)
#   2. null    — a legal short title registers; the store row carries the
#                title and `show` displays it (the row survives its brief)
#   3. null    — a bundle with NO title line is refused for THAT reason,
#                with a different message than the over-long case
#                (two failure modes, two messages — never conflated)
#   4. boundary — exactly 40 passes, exactly 41 is refused (off-by-one pin)
#   5. seeded  — suggest refuses a 41-char slug; a 40-char slug registers
#                (suggest is the sibling registration path)
#   6. seeded  — add --auto (the mint path) refuses a 60-char-title bundle
#
# Usage:  tools/regression-title-gate.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="${MANAGENT_BIN:-$PROJECT/bin/managent}"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent a suite's arms into the LIVE repo.
mkdir -p /tmp/weizigo
ROOT="$(mktemp -d /tmp/weizigo/title-gate-XXXXXX)" || { echo "regression-title-gate.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

REPO="$ROOT/repo"
SCRATCH="$ROOT/scratch"
mkdir -p "$REPO/untracked" "$SCRATCH/docs/infra/managent"
git init -q "$REPO"
git -C "$REPO" config user.email "t906@test"
git -C "$REPO" config user.name "T906"

SCRATCH_STORE="$SCRATCH/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$SCRATCH_STORE"
# T427 belt-and-suspenders: if the store override ever silently points back at
# the live kanban, the harness must refuse to mutate it rather than proceed.
export MANAGENT_TEST=1

# Run managent with cwd in the fake repo (so findRepoRoot globs $REPO/untracked).
mg() {
    (cd "$REPO" && "$MG" "$@")
}

# Write a fixture bundle.  $1 = id, $2 = title portion (after `# <id> — `).
# Empty title portion => no title line at all (only the marker is written).
bundle() {
    local id="$1" title="$2"
    if [ -n "$title" ]; then
        printf '<!--managent set=A type=infra deliverables=docs/%s-x.md-->\n# %s — %s\n**Landmark:** advances `L1 (the dashboard tells the truth)` — fixture\n' \
            "$id" "$id" "$title" > "$REPO/untracked/$id-bundle.md"
    else
        printf '<!--managent set=A type=infra deliverables=docs/%s-x.md-->\n**Landmark:** advances `L1 (the dashboard tells the truth)` — fixture\n' \
            "$id" > "$REPO/untracked/$id-bundle.md"
    fi
}

# Title of exactly N 't' characters.
title_of_len() {  # $1=N
    printf 't%.0s' $(seq 1 "$1")
}

# Row title from the scratch store ("" when the field is absent).
stored_title() {  # $1=id
    python3 - "$SCRATCH_STORE" "$1" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("")
    sys.exit(0)
r = d.get(sys.argv[2], {})
print(r.get("title", ""))
PY
}

echo "=== T906 title-gate-at-registration regression ==="

# ── Arm 1 (red): 60-char title refused by name; 40-char registers ────────
echo "  1. seeded: 60-char title refused at add, naming title + length; 40-char registers"

bundle T9001 "$(title_of_len 60)"
OUT=$("$MG" add T9001 --bundle "$REPO/untracked/T9001-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "60" && echo "$OUT" | grep -q "40" && echo "$OUT" | grep -qi "title"; then
    echo "    PASS: add refused the 60-char title (rc=$RC), naming the length and limit"
else
    echo "    FAIL: rc=$RC; expected a title-length refusal naming 60 and 40:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if python3 - "$SCRATCH_STORE" "T9001" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)  # no store yet — nothing registered
sys.exit(0 if sys.argv[2] not in d else 1)
PY
then
    echo "    PASS: refused row not registered"
else
    echo "    FAIL: T9001 present in the store despite the refusal"; FAIL=1
fi

bundle T9002 "$(title_of_len 40)"
OUT=$("$MG" add T9002 --bundle "$REPO/untracked/T9002-bundle.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: 40-char title registered (rc=0)"
else
    echo "    FAIL: rc=$RC; a legal 40-char title refused:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── Arm 2 (null): legal short title registers; store carries title; show names it ──
echo "  2. null: legal short title registers; store row carries title; show names it"

bundle T9003 "title gate fixture"
"$MG" add T9003 --bundle "$REPO/untracked/T9003-bundle.md" >/dev/null 2>&1
ST=$(stored_title T9003)
if [ "$ST" = "title gate fixture" ]; then
    echo "    PASS: store row carries the title"
else
    echo "    FAIL: stored title is '$ST' (expected 'title gate fixture')"; FAIL=1
fi
SHOW=$("$MG" show T9003 2>&1)
if echo "$SHOW" | grep -q "title gate fixture"; then
    echo "    PASS: show displays the stored title (the row survives its brief)"
else
    echo "    FAIL: show does not name the row's title:"; echo "$SHOW" | sed 's/^/    | /'
    FAIL=1
fi

# ── Arm 3 (null): no title line refused for THAT reason, different message ──
echo "  3. null: bundle with no title line refused with the missing-title message"

bundle T9004 ""
OUT=$("$MG" add T9004 --bundle "$REPO/untracked/T9004-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "no .*# T.*title.*line"; then
    echo "    PASS: no-title-line bundle refused for that reason (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected a missing-title-line refusal:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if echo "$OUT" | grep -q "over the 40-char limit"; then
    echo "    FAIL: missing-title message reuses the over-long message (two modes, one text)"; FAIL=1
else
    echo "    PASS: missing-title message is distinct from the over-long message"
fi
if python3 - "$SCRATCH_STORE" "T9004" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
sys.exit(0 if sys.argv[2] not in d else 1)
PY
then
    echo "    PASS: refused row not registered"
else
    echo "    FAIL: T9004 present in the store despite the refusal"; FAIL=1
fi

# ── Arm 4 (boundary): exactly 40 passes, exactly 41 refused ──────────────
echo "  4. boundary: 40 passes, 41 refused (off-by-one pin)"

bundle T9005 "$(title_of_len 41)"
OUT=$("$MG" add T9005 --bundle "$REPO/untracked/T9005-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "41" && echo "$OUT" | grep -q "40"; then
    echo "    PASS: 41-char title refused (rc=$RC), naming 41 and 40"
else
    echo "    FAIL: rc=$RC; expected refusal naming 41 and 40:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── Arm 5 (seeded): suggest gates the slug (sibling registration path) ───
echo "  5. seeded: suggest refuses a 41-char slug; a 40-char slug registers"

OUT=$("$MG" suggest "$(title_of_len 41)" --type infra 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "41" && echo "$OUT" | grep -q "40"; then
    echo "    PASS: suggest refused the 41-char slug (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected suggest to refuse the over-long slug:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

OUT=$("$MG" suggest "$(title_of_len 40)" --type infra 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: suggest accepted the 40-char slug (rc=0)"
else
    echo "    FAIL: rc=$RC; a legal 40-char slug refused:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── Arm 6 (seeded): add --auto (mint path) refuses a 60-char-title bundle ──
echo "  6. seeded: add --auto refuses a 60-char-title bundle"

bundle T9006 "$(title_of_len 60)"
OUT=$("$MG" add --auto --bundle "$REPO/untracked/T9006-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "60" && echo "$OUT" | grep -q "40"; then
    echo "    PASS: add --auto refused the 60-char title (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected the mint path to refuse too:"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T906 title gate: ALL CHECKS PASS"
else
    echo "  T906 title gate: SOME CHECKS FAILED"
fi
exit "$FAIL"
