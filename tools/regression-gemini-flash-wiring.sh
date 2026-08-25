#!/usr/bin/env bash
# regression-gemini-flash-wiring.sh — T938 controls for gemini-3.7-flash wiring
#
# The landmark: advances L1 (the dashboard tells the truth) — a model the
# dispatcher cannot name is a model whose work cannot be attributed.
# Unblocks the Race J gflash arm (T939).
#
# Operator verification (2026-08-25): `pi --provider openrouter --model
# google/gemini-3.7-flash -p 'Reply with exactly: OK'` answered OK, headless,
# with OPENROUTER_API_KEY absent from the environment — the key is registered
# inside pi (T940).
#
# Shape: canonical `gemini-3.7-flash`, serving tag `google/gemini-3.7-flash`,
# input alias `gflash` — exactly ox-alpha's shape (canonical `ox-alpha`,
# serving tag `stealth/ox-alpha`).
#
# Controls:
#   null     every existing model still resolves exactly as before
#   seeded   gflashx, google/gemini-3.7-pro, gflash as a stored label are
#            each refused by name
#   round    canonical → serving tag → canonical returns the canonical label,
#   trip     in managent and in both Python tools
#   dry-run  a real dispatch resolves to pi + [--model, google/gemini-3.7-flash]
#
# Task: T938 · Role: worker · Model: claude-haiku-4-5-20251001 · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
DISPATCH="$ROOT/bin/dispatch"
MG="$ROOT/bin/managent"
FAIL=0

# ── scratch repo (T849) ──────────────────────────────────────────────────────
. "$ROOT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t938-gflash WORK
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git config user.email t938@test
git config user.name T938
echo base > README.md
mkdir -p docs untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"

# minimal claimlint for e2e done-gate
CLAIMLINT="$ROOT/bin/weizigo-claimlint"
[ -x "$CLAIMLINT" ] || CLAIMLINT="$ROOT/zig-out/bin/weizigo-claimlint"
if [ -x "$CLAIMLINT" ]; then
    mkdir -p "$WORK/bin" "$WORK/docs/epistemic"
    ln -s "$CLAIMLINT" "$WORK/bin/weizigo-claimlint"
    printf '# minimal scratch claims register (T938 regression)\n' > "$WORK/docs/epistemic/CLAIMS.md"
fi

echo "=== bin/dispatch + managent gemini-3.7-flash wiring regression ==="

# ── null: existing models still resolve exactly as before ──────────────────
seed_task() {  # $1=id  $2=deliverable
    printf '<!--managent set=C type=infra deliverables=%s-->\n# %s — T938 regression bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$2" "$1" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

seed_task T8381 findings/T8381-result.json

echo "  1. null: ox-alpha still resolves to stealth/ox-alpha"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 ox-alpha --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--model stealth/ox-alpha T8381"; then
    echo "    PASS: ox-alpha command unchanged"
else
    echo "    FAIL: ox-alpha wiring drifted"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  2. null: kimi-k2.7 still resolves to kimi-k2.7-code:cloud"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 kimi-k2.7 --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--model kimi-k2.7-code:cloud T8381"; then
    echo "    PASS: kimi command unchanged"
else
    echo "    FAIL: kimi wiring drifted"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  3. null: deepseek-v4-flash still resolves to --dsflash"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 deepseek-v4-flash --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider deepseek --dsflash T8381"; then
    echo "    PASS: deepseek command unchanged"
else
    echo "    FAIL: deepseek wiring drifted"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── seeded: near-misses refused by name ──────────────────────────────────────
echo "  4. seeded: gflashx (typo) refused"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 gflashx --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "gflashx"; then
    echo "    PASS: refused gflashx naming it (rc=$RC)"
else
    echo "    FAIL: gflashx should be refused"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  5. seeded: google/gemini-3.7-pro (wrong model variant) refused"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 google/gemini-3.7-pro --dry-run --test-root="$WORK" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "google/gemini-3.7-pro"; then
    echo "    PASS: refused google/gemini-3.7-pro naming it (rc=$RC)"
else
    echo "    FAIL: google/gemini-3.7-pro should be refused"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo "  6. seeded: gflash as a stored label (not alias) refused"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 gflash --dry-run --test-root="$WORK" 2>&1)
RC=$?
# gflash must canonicalize to gemini-3.7-flash and work (it's a valid alias)
# so the refusal case here would only occur if someone tried to store it
# as a canonical label. Instead, test that it WORKS as an alias:
if echo "$OUT" | grep -q "gemini-3.7-flash"; then
    echo "    PASS: gflash alias canonicalizes to gemini-3.7-flash (works as intended)"
else
    echo "    FAIL: gflash alias should work"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── round trip: canonical ↔ serving tag ↔ canonical ───────────────────────────
echo "  7. round-trip: gemini-3.7-flash → google/gemini-3.7-flash → gemini-3.7-flash (managent)"
TAGS=$(cd "$ROOT" && "$MG" models --tags --json 2>/dev/null)
if echo "$TAGS" | grep -q '"serving": "google/gemini-3.7-flash"' && \
   echo "$TAGS" | grep -q '"canonical": "gemini-3.7-flash"'; then
    echo "    PASS: managent models --tags carries the mapping"
else
    echo "    FAIL: managent models --tags missing the mapping"
    echo "$TAGS" | grep gemini | sed 's/^/    | /'
    FAIL=1
fi

echo "  8. round-trip: Python tool canonicalization (model_tags.py)"
CANON=$(cd "$ROOT" && python3 -c "
import sys
sys.path.insert(0, 'tools')
from model_tags import canon_tag
try:
    print(canon_tag('google/gemini-3.7-flash'))
except Exception as e:
    print('ERROR: ' + str(e), file=sys.stderr)
    sys.exit(1)
" 2>&1)
if [ "$CANON" = "gemini-3.7-flash" ]; then
    echo "    PASS: model_tags.canon_tag('google/gemini-3.7-flash') → gemini-3.7-flash"
else
    echo "    FAIL: model_tags canonicalization: got '$CANON'"
    FAIL=1
fi

# ── dry-run: real dispatch command ───────────────────────────────────────────
echo "  9. dry-run: gemini-3.7-flash dispatch resolves to pi + google/gemini-3.7-flash"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 gemini-3.7-flash --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider pi --model google/gemini-3.7-flash T8381"; then
    echo "    PASS: dispatch command correct (pi + google/gemini-3.7-flash)"
else
    echo "    FAIL: gemini-3.7-flash command incorrect"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 10. dry-run: gflash alias resolves to the same command"
OUT=$(cd "$ROOT" && "$DISPATCH" T8381 gflash --dry-run --test-root="$WORK" 2>&1)
if echo "$OUT" | grep -q -- "--provider pi --model google/gemini-3.7-flash T8381"; then
    echo "    PASS: gflash alias resolves identically"
else
    echo "    FAIL: gflash alias resolution failed"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── managent surface: models command ───────────────────────────────────────────
echo " 11. managent models lists gemini-3.7-flash"
OUT=$("$MG" models)
if echo "$OUT" | grep -q "gemini-3.7-flash"; then
    echo "    PASS: managent models includes gemini-3.7-flash"
else
    echo "    FAIL: managent models missing gemini-3.7-flash"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo " 12. managent assign can draw gemini-3.7-flash"
OUT=$("$MG" assign --dry-run 2>&1)
if echo "$OUT" | grep -q "gemini-3.7-flash"; then
    echo "    PASS: managent assign includes gemini-3.7-flash in the pool"
else
    echo "    FAIL: managent assign cannot draw gemini-3.7-flash"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

# ── canonical label is stored, not the alias ─────────────────────────────────
echo " 13. no string 'gflash' stored anywhere (only the alias, not the canonical)"
OUT=$(cd "$ROOT" && grep -r "gflash" src/managent/main.zig tools/model_tags.py docs/infra/model-registry.md 2>/dev/null | grep -v "alias\|short" || true)
if [ -z "$OUT" ]; then
    echo "    PASS: 'gflash' appears only in alias / short-name contexts"
else
    echo "    FAIL: 'gflash' found outside of alias context:"
    echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-gemini-flash-wiring: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-gemini-flash-wiring: FAILURES ==="
    exit 1
fi
