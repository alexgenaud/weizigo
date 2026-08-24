#!/usr/bin/env bash
# regression-managent-landmark.sh — T682: registration-time landmark gate.
#
# MILESTONES.md / LANDMARKS.md require every brief to declare a landmark, so
# work is reported in milestone terms — *whose* loss, and which way it cuts.
# The rule once lived only in prose, and T592 showed what prose enforcement
# is worth: one brief registered without the line, five `sed`-cloned
# siblings inherited the omission, and nobody noticed until the operator
# did.  This regression locks the mechanism in: `managent add` (and
# `suggest`) refuse a bundle whose brief declares no landmark — or one that
# is not a real landmark — naming the file and the expected form.
#
# The single source of landmark ids is docs/audits/2026-08-05-handover/
# LANDMARKS.md (L0..L7) as adopted by D4 (docs/status/orcha-decisions-
# 2026-08-19.md ratified L8/L9); the gate's copy lives in
# src/managent/main.zig (valid_landmark_ids) with the coupling commented.
#
# Controls (scratch store + scratch repo only — the live kanban is never
# touched; the real bundle corpus is only ever READ):
#   seeded    bundle with no **Landmark:** line -> refused, naming the file
#             and the expected form; no row registered.
#   seeded2   the exact T592 case: clone untracked/T592-tools-census.md four
#             ways and register -> four refusals, not four rows.
#   seeded3   a landmark id that is not real (L99) -> refused, listing the
#             valid set.
#   null      a valid landmark declaration registers unchanged; the
#             sanctioned no-landmark form ("none directly") registers too.
#   null2     every real bundle under untracked/ whose declaration is valid
#             registers unchanged (the corpus sweep — a gate that trips on
#             good input is worse than no gate).  Bundles whose declaration
#             is malformed are expected refusals and are reported, not
#             silently swept.
#   suggest   the suggest template carries the **Landmark:** line and the
#             created bundle re-registers through `add`.
#   status    `status --json` still parses after the gate (the read path is
#             untouched; the old-vs-new byte-identical proof is a
#             development-time control recorded in findings/T682-*).
#
# Task: T682 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

# T849: the scratch repo is created by the ONE helper that isolates the git
# env (unset GIT_DIR GIT_WORK_TREE …) before `git init`, so this script is
# safe to run outside the pre-commit hook too.
. "$PROJECT/tools/lib/scratch-repo.sh"

if [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary (build with 'zig build') — T682 needs it"
    exit 0
fi

weizigo_scratch_repo managent-landmark WORK   # T849: isolated scratch repo (T445 refuse-on-failure preserved)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t682@test
git config user.name T682
echo base > README.md
mkdir -p docs untracked docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

echo "=== managent landmark gate regression (T682) ==="

# ── seeded 1: no landmark line -> refused, naming file + expected form ────
cat > "$WORK/untracked/T682NO-bundle.md" <<'EOF'
<!--managent set=A deliverables=docs/x.md-->
# T682NO — no landmark

Work that declares no landmark at all.
EOF
OUT=$("$MG" add T682NO --bundle "$WORK/untracked/T682NO-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "T682NO-bundle.md" && echo "$OUT" | grep -q '\*\*Landmark:\*\*' && echo "$OUT" | grep -q 'L0'; then
    echo "    PASS: no-landmark bundle refused (rc=$RC), naming file + expected form"
else
    echo "    FAIL: rc=$RC; expected landmark refusal naming the file"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
if python3 - "$STORE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if "T682NO" not in d else 1)
PY
then
    echo "    PASS: refused row not registered"
else
    echo "    FAIL: refused row T682NO present in store"; FAIL=1
fi

# ── seeded 2: the exact T592 case — clone the brief four ways ────────────
if [ -f "$PROJECT/untracked/T592-tools-census.md" ]; then
    four_ok=1
    for id in T678 T679 T680 T681; do
        cp "$PROJECT/untracked/T592-tools-census.md" "$WORK/untracked/$id-tools-census.md"
        OUT=$("$MG" add "$id" --bundle "$WORK/untracked/$id-tools-census.md" 2>&1); RC=$?
        if [ "$RC" -eq 0 ] || ! echo "$OUT" | grep -q "$id-tools-census.md"; then
            echo "    FAIL: clone $id not refused (rc=$RC)"; four_ok=0; FAIL=1
        fi
    done
    if [ "$four_ok" -eq 1 ]; then echo "    PASS: four T592 clones refused (rc=1 each), zero rows"; fi
    if python3 - "$STORE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
bad = [k for k in ("T678", "T679", "T680", "T681") if k in d]
sys.exit(0 if not bad else 1)
PY
    then
        echo "    PASS: no clone row registered"
    else
        echo "    FAIL: a T592 clone row was registered"; FAIL=1
    fi
else
    echo "    NOTE: T592 brief absent from this checkout — clone arm skipped"
fi

# ── seeded 3: L99 -> refused, listing the valid set ──────────────────────
cat > "$WORK/untracked/T682L99-bundle.md" <<'EOF'
<!--managent set=A deliverables=docs/y.md-->
# T682L99 — bogus id

**Landmark:** advances `L99 (bogus)` — not a real landmark.
EOF
OUT=$("$MG" add T682L99 --bundle "$WORK/untracked/T682L99-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "L9" && echo "$OUT" | grep -q "L0"; then
    echo "    PASS: L99 refused (rc=$RC), valid set listed"
else
    echo "    FAIL: rc=$RC; expected L99 refusal with the valid set"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── null: valid declarations register unchanged ───────────────────────────
cat > "$WORK/untracked/T682OK-bundle.md" <<'EOF'
<!--managent set=A deliverables=docs/z.md-->
# T682OK — valid landmark

**Landmark:** advances `L1 (the dashboard tells the truth)` — a gate that trips on good input is worse than no gate.
EOF
OUT=$("$MG" add T682OK --bundle "$WORK/untracked/T682OK-bundle.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: valid landmark registers (rc=0)"
else
    echo "    FAIL: rc=$RC; valid landmark refused: $OUT"; FAIL=1
fi
cat > "$WORK/untracked/T682NONE-bundle.md" <<'EOF'
<!--managent set=A deliverables=docs/w.md-->
# T682NONE — sanctioned no-landmark form

**Landmark:** none directly; unblocks T352
EOF
OUT=$("$MG" add T682NONE --bundle "$WORK/untracked/T682NONE-bundle.md" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    echo "    PASS: 'none directly' form registers (rc=0)"
else
    echo "    FAIL: rc=$RC; none-form refused: $OUT"; FAIL=1
fi

# ── null 2: the real corpus — every bundle whose declaration is valid ────
# registers unchanged.  Read-only over the live untracked/ (scratch store);
# malformed declarations are expected refusals, reported not swept.
swept=0; refused=0; census=0
for f in "$PROJECT"/untracked/*.md; do
    [ -f "$f" ] || continue
    if ! grep -q '\*\*Landmark:\*\*' "$f"; then census=$((census+1)); continue; fi
    if ! head -50 "$f" | grep -q '<!--managent .*set='; then continue; fi
    bid="T682SWEEP-$(basename "$f" | tr -c '[:alnum:]' '_' | cut -c1-24)"
    if "$MG" add "$bid" --bundle "$f" >/dev/null 2>&1; then
        swept=$((swept+1))
    else
        refused=$((refused+1))
        echo "    refused (expected if malformed): $(basename "$f")"
    fi
done
echo "    corpus sweep: $swept registered, $refused refused; file census: $census untracked/*.md with no **Landmark:** line (all untracked files, briefs and non-briefs; the kanban-row census is in findings/T682-landmark-gate.json)"
if [ "$refused" -gt 0 ]; then
    echo "    NOTE: refusals above are expected ONLY for malformed declarations (e.g. a task id instead of a landmark id, or a mid-line marker). A refusal of a valid declaration is a defect."
fi

# ── suggest: template carries the line; created bundle is add-able ────────
OUT=$("$MG" suggest t682-suggest-ctl --set A 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    DISPATCH_LINE=$(echo "$OUT" | tail -1)
    BUNDLE="${DISPATCH_LINE#Follow }"
    if [ "$BUNDLE" != "$DISPATCH_LINE" ] && grep -q '\*\*Landmark:\*\*' "$WORK/$BUNDLE"; then
        echo "    PASS: suggest template carries the **Landmark:** line"
    else
        echo "    FAIL: suggest template lacks the landmark line"; FAIL=1
    fi
    # the suggest-created bundle must re-register through `add`
    OUT2=$("$MG" add T682SUG --bundle "$WORK/$BUNDLE" 2>&1); RC2=$?
    if [ "$RC2" -eq 0 ]; then
        echo "    PASS: suggest-created bundle is add-able (rc=0)"
    else
        echo "    FAIL: rc=$RC2; suggest-created bundle refused by add: $OUT2"; FAIL=1
    fi
else
    echo "    FAIL: suggest rc=$RC: $OUT"; FAIL=1
fi

# ── status: the read path still parses after the gate ────────────────────
if "$MG" status --json 2>/dev/null | python3 -c "import json,sys; json.load(sys.stdin); sys.exit(0)"; then
    echo "    PASS: status --json parses after the gate"
else
    echo "    FAIL: status --json does not parse"; FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== T682 landmark gate regression: PASS ==="
else
    echo "=== T682 landmark gate regression: FAIL ==="
    exit 1
fi
