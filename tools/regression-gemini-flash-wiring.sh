#!/usr/bin/env bash
# regression-gemini-flash-wiring.sh — T938 controls for wiring
# gemini-3.7-flash through the canonicalizer, the dispatcher, the runner's
# pi provider, and the operator-facing short name `gflash`.
#
# Why this exists: the operator verified the model headless on 2026-08-25
# with `pi --provider openrouter --model google/gemini-3.7-flash` and asked
# it be wired like oxalpha.  Six surfaces must move in step (T317 single
# source of truth; T801 one canonicalizer, not four):
#
#   1. src/managent/main.zig canonical_models[] — the canonical label
#      `gemini-3.7-flash` (this is what every record stores)
#   2. src/managent/main.zig serving_tag_map / canonicalizeModelTag —
#      `google/gemini-3.7-flash` -> `gemini-3.7-flash` (the serving tag
#      is input convenience only; it never reaches the ledger)
#   3. src/managent/main.zig model_families[] + family_appetite[] —
#      the new family `google` (so a later gemini-pro joins it) with
#      SPEND (equal-opportunity set, the operator's class for oxalpha)
#   4. bin/dispatch MODELS / ALIASES / canonicalize_model — dry-run
#      dispatch resolves to `pi --model google/gemini-3.7-flash`
#   5. bin/subagent PI_TAG_TO_CANONICAL / CANONICAL_TO_PI_TAG — both
#      directions of the live-tag map (T890 single source)
#   6. tools/fleet_caps.py FAMILY — the cap-family map must include
#      `gemini-3.7-flash` -> `google` (so a gemini dispatch is in the
#      cap census, not silently uncapped "other")
#
# Three readers — tools/model_tags.py, tools/model-profiles.py, and
# tools/run-record-model-backfill.py — resolve the canonicalizer from
# the managent binary (T801 seam).  tools/run-record-model-backfill.py
# carries its OWN hard-coded copy (a pre-T801 smudge); the controls assert
# that, if the two diverge, the managent binary wins.
#
# Controls:
#
#   A. RED (against HEAD): `managent models` does NOT list
#      `gemini-3.7-flash`; `managent canonicalize google/gemini-3.7-flash`
#      does NOT resolve to `gemini-3.7-flash`; `bin/dispatch` does not
#      know the alias `gflash`; the hard-coded list in
#      `tools/run-record-model-backfill.py` does NOT include
#      `gemini-3.7-flash`.
#   B. GREEN (after wiring): all six surfaces know the label;
#      `managent canonicalize google/gemini-3.7-flash` -> `gemini-3.7-flash`;
#      `bin/dispatch --dry-run ... gemini-3.7-flash` resolves to
#      `pi --model google/gemini-3.7-flash`; `gflash` aliases in
#      `bin/dispatch`; the model_tags canonicalizer (resolved from managent)
#      and the hard-coded list in run-record-model-backfill.py both
#      include the new label (drift would be a finding).
#   C. NULL: every pre-existing canonical model still resolves exactly
#      as before (oxalpha, deepseek-v4-pro, deepseek-v4-flash, etc.).
#   D. SEEDED DEFECT: `gflashx`, `google/gemini-3.7-pro`, and `gflash`
#      AS A STORED LABEL are each REFUSED by name — not silently mapped
#      to something real.  A near-miss that canonicalizes to an existing
#      label is the defect this control exists to catch.
#   E. ROUND TRIP: canonical -> serving tag -> canonical returns the
#      canonical label, in managent, in model_tags, and in the runner.
#   F. NO `gflash` IS STORED ANYWHERE — a grep for the literal short
#      name across the source tree, the docs, and the binary, restricted
#      to the alias table (the one place it is allowed).
#   G. SYNC: bin/dispatch covers the new label — every canonical model
#      in managent must be in bin/dispatch's MODELS map (T317 sync
#      contract from regression-dispatch.sh control 13).
#   I. FAMILY: tools/fleet_caps.py maps `gemini-3.7-flash` -> `google`.
#
# Wired into `zig build test` via build.zig.
#
# Task: T938 · Role: worker · Model: minimax-m3 · Date: 2026-08-25

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
MG="$ROOT/bin/managent"
SRC="$ROOT/src/managent/main.zig"
DISPATCH="$ROOT/bin/dispatch"
SUBAGENT="$ROOT/bin/subagent"
MODEL_TAGS="$ROOT/tools/model_tags.py"
MODEL_PROFILES="$ROOT/tools/model-profiles.py"
BACKFILL="$ROOT/tools/run-record-model-backfill.py"
FLEET_CAPS="$ROOT/tools/fleet_caps.py"
REGISTRY="$ROOT/docs/infra/model-registry.md"

FAIL=0

if [ ! -x "$MG" ]; then
    echo "FATAL: no managent binary at $MG (build with 'zig build')" >&2
    exit 2
fi

# A stale depth stamp from a worker-run suite would trip the cap control.
unset WEIZIGO_AGENT_DEPTH || true

# Scratch repo with a dispatchable task (bin/dispatch needs a real row in
# the store + a bundle for dry-run; the live store must not be touched).
. "$ROOT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t938-gemini WORK
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git config user.email t938@test
git config user.name T938
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
# bin/managent done runs weizigo-claimlint from CWD on done; the dry-run
# arm never reaches done, but claimlint is also referenced by the live
# regression so a symlink is the cheapest substrate.
CLAIMLINT="$ROOT/bin/weizigo-claimlint"
[ -x "$CLAIMLINT" ] || CLAIMLINT="$ROOT/zig-out/bin/weizigo-claimlint"
if [ -x "$CLAIMLINT" ]; then
    mkdir -p "$WORK/bin" "$WORK/docs/epistemic"
    ln -s "$CLAIMLINT" "$WORK/bin/weizigo-claimlint"
    printf '# minimal scratch claims register (T938 regression)\n' > "$WORK/docs/epistemic/CLAIMS.md"
fi

# Register a dispatchable row with a bundle so bin/dispatch's dry-run
# reaches the model-resolution arm.
printf '<!--managent set=A type=infra deliverables=findings/T938001.json-->\n# T938001 — dry-run fixture for T938 wiring\n**Landmark:** none directly; regression fixture\n' \
    > "$WORK/untracked/T938001-bundle.md"
"$MG" add T938001 >/dev/null 2>&1 || true

# Canonical list from managent (the single source the readers depend on)
# — the wire must ADD `gemini-3.7-flash`; if it's not here, controls A
# and B fail loudly.
CANON_FROM_MG="$("$MG" models 2>/dev/null | grep -v '^managent ' || true)"

echo ""
echo "  T938 regression: gemini-3.7-flash wiring"

# ── A. RED/green arm: managent models lists gemini-3.7-flash ────────────
echo "        A. managent models lists gemini-3.7-flash"
if printf '%s\n' "$CANON_FROM_MG" | grep -Fxq "gemini-3.7-flash"; then
    echo "           PASS: gemini-3.7-flash is in the canonical list"
else
    echo "           FAIL: gemini-3.7-flash is not in the canonical list"
    echo "             | (this is the RED arm — wiring has not landed yet)"
    FAIL=1
fi

# ── B. canonicalize google/gemini-3.7-flash -> gemini-3.7-flash ─────────
echo "        B. managent canonicalize resolves google/gemini-3.7-flash"
CANON_OUT="$("$MG" canonicalize google/gemini-3.7-flash 2>/dev/null || true)"
if [ "$CANON_OUT" = "gemini-3.7-flash" ]; then
    echo "           PASS: google/gemini-3.7-flash -> $CANON_OUT"
else
    echo "           FAIL: google/gemini-3.7-flash did not canonicalize to gemini-3.7-flash (got: '$CANON_OUT')"
    FAIL=1
fi

# ── C. NULL — every pre-existing canonical label still resolves to itself
echo "        C. null — every pre-existing canonical label still resolves to itself"
NULL_FAIL=0
for m in claude-opus-5 claude-sonnet-5 claude-fable-5 claude-haiku-4-5-20251001 \
         deepseek-v4-pro deepseek-v4-flash glm-5.2 minimax-m3 kimi-k2.7 \
         qwen3.8:27b-mlx oxalpha; do
    got="$("$MG" canonicalize "$m" 2>/dev/null || true)"
    if [ "$got" != "$m" ]; then
        echo "           FAIL: $m canonicalized to '$got' (should be self)"
        NULL_FAIL=1
    fi
done
# pre-existing serving-tag mappings must still work
for pair in "kimi-k2.7-code:cloud:kimi-k2.7" "stealth/ox-alpha:oxalpha"; do
    raw="${pair%%:*}"; expected="${pair##*:}"
    got="$("$MG" canonicalize "$raw" 2>/dev/null || true)"
    if [ "$got" != "$expected" ]; then
        echo "           FAIL: serving tag $raw canonicalized to '$got' (expected $expected)"
        NULL_FAIL=1
    fi
done
if [ "$NULL_FAIL" -eq 0 ]; then
    echo "           PASS: 11 canonical labels + 2 serving tags unchanged"
else
    FAIL=1
fi

# ── D. SEEDED DEFECT — three near-misses are refused by name ──────────
echo "        D. seeded defect — gflashx / google/gemini-3.7-pro / gflash-as-stored are refused"
# D1: gflashx — typo on the alias, must be REFUSED (no silent map)
OUT="$("$DISPATCH" T938001 gflashx --dry-run --test-root="$WORK" 2>&1 || true)"
if echo "$OUT" | grep -q "gflashx"; then
    if echo "$OUT" | grep -qE "(REFUSED|refused|not a canonical|unknown)"; then
        echo "           PASS: gflashx refused (named in refusal)"
    else
        echo "           FAIL: gflashx output does not name it as a refusal:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        FAIL=1
    fi
else
    echo "           FAIL: gflashx did not appear in dispatch output at all"
    printf '%s\n' "$OUT" | sed 's/^/             | /'
    FAIL=1
fi
# D2: google/gemini-3.7-pro — different model, must NOT silently map to gemini-3.7-flash
# `managent canonicalize` exits 0 with the label on stdout when it resolves,
# and exits 1 with a multi-line error (which lists ALL canonical models) on
# refusal.  The right check is the EXIT CODE, not a substring hunt: a
# successful resolve prints exactly "gemini-3.7-flash" and exits 0.
"$MG" canonicalize google/gemini-3.7-pro >/dev/null 2>&1
D2_RC=$?
if [ "$D2_RC" -ne 0 ]; then
    echo "           PASS: google/gemini-3.7-pro refused (exit $D2_RC, did not map to gemini-3.7-flash)"
else
    OUT="$("$MG" canonicalize google/gemini-3.7-pro 2>&1 || true)"
    echo "           FAIL: google/gemini-3.7-pro canonicalized to $OUT (silent near-miss, exit 0)"
    FAIL=1
fi
# D3: gflash — must never appear as a STORED LABEL.  managent models
#     must NOT list it; bin/dispatch ALIASES is the only legal home.
if printf '%s\n' "$CANON_FROM_MG" | grep -Fxq "gflash"; then
    echo "           FAIL: gflash appears in managent models (must not — alias only)"
    FAIL=1
else
    echo "           PASS: gflash is not a stored canonical label"
fi

# ── E. ROUND TRIP — managent, model_tags, runner agree ────────────────
echo "        E. round trip — managent, model_tags, runner all agree on gemini-3.7-flash"
python3 - "$MG" "$MODEL_TAGS" "$BACKFILL" <<'PYEOF'
import importlib.util, os, re, subprocess, sys
mg, model_tags_path, backfill_path = sys.argv[1], sys.argv[2], sys.argv[3]
tools_dir = os.path.dirname(model_tags_path)
if tools_dir not in sys.path:
    sys.path.insert(0, tools_dir)
import model_tags as mt  # noqa: E402

fail = 0

# E1: managent canonicalize <google/gemini-3.7-flash> -> gemini-3.7-flash
r = subprocess.run([mg, "canonicalize", "google/gemini-3.7-flash"],
                  capture_output=True, text=True)
if r.returncode != 0 or r.stdout.strip() != "gemini-3.7-flash":
    print("           FAIL: managent canonicalize google/gemini-3.7-flash -> %r" % r.stdout.strip())
    fail += 1

# E2: model_tags canon_tag (resolved from managent) returns the same
try:
    got = mt.canon_tag("google/gemini-3.7-flash")
    if got != "gemini-3.7-flash":
        print("           FAIL: model_tags canon_tag -> %r (expected gemini-3.7-flash)" % got)
        fail += 1
except mt.UnknownModelTag:
    print("           FAIL: model_tags refused google/gemini-3.7-flash")
    fail += 1

# E3: the runner's _model_from_argv must canonicalize the serving tag to the label
# tools/runner has no .py extension; the SourceFileLoader takes the path as-is.
spec = importlib.util.spec_from_loader(
    "runner", importlib.machinery.SourceFileLoader("runner", os.path.join(tools_dir, "runner")))
runner = importlib.util.module_from_spec(spec)
sys.modules["runner"] = runner
spec.loader.exec_module(runner)
try:
    got = runner._model_from_argv(["pi", "--model", "google/gemini-3.7-flash"])
    if got != "gemini-3.7-flash":
        print("           FAIL: runner._model_from_argv -> %r (expected gemini-3.7-flash)" % got)
        fail += 1
except Exception as e:
    print("           FAIL: runner._model_from_argv raised %s" % e)
    fail += 1

# E4: pre-existing models still round-trip (regression guard)
for canon, raw in [("oxalpha", "stealth/ox-alpha"),
                   ("kimi-k2.7", "kimi-k2.7-code:cloud")]:
    try:
        got = mt.canon_tag(raw)
        if got != canon:
            print("           FAIL: round-trip %r -> %r (expected %r)" % (raw, got, canon))
            fail += 1
    except mt.UnknownModelTag:
        print("           FAIL: round-trip %r refused" % raw)
        fail += 1

# E5: model_tags canonical list (resolved from managent) and the hard-coded
#     list in tools/run-record-model-backfill.py must BOTH contain
#     gemini-3.7-flash.  Drift is a finding.
canon_list = mt.canonical_models()
if "gemini-3.7-flash" not in canon_list:
    print("           FAIL: model_tags canonical list (resolved from managent) lacks gemini-3.7-flash")
    fail += 1
hardcoded_text = open(backfill_path).read()
m = re.search(r'"canonical_models":\s*\[(.*?)\]', hardcoded_text, re.S)
if not m:
    print("           FAIL: could not parse canonical_models list in %s" % backfill_path)
    fail += 1
else:
    hardcoded = re.findall(r'"([a-z0-9.:\-]+)"', m.group(1))
    if "gemini-3.7-flash" not in hardcoded:
        print("           FAIL: hard-coded canonical_models in run-record-model-backfill.py lacks gemini-3.7-flash")
        fail += 1
    if set(canon_list) != set(hardcoded):
        print("           FAIL: drift between managent canonical list and run-record-model-backfill.py hard-coded list")
        print("             | in managent only:", sorted(set(canon_list) - set(hardcoded)))
        print("             | in backfill only:", sorted(set(hardcoded) - set(canon_list)))
        fail += 1

if fail == 0:
    print("           PASS: all five round-trip checks hold (managent, model_tags, runner, regression guard, drift guard)")
sys.exit(1 if fail else 0)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── F. real dry-run dispatch resolves to pi + google/gemini-3.7-flash ───
echo "        F. real dry-run dispatch resolves to pi + google/gemini-3.7-flash"
OUT="$("$DISPATCH" T938001 gemini-3.7-flash --dry-run --test-root="$WORK" 2>&1 || true)"
if echo "$OUT" | grep -q -- "--provider pi --model google/gemini-3.7-flash"; then
    echo "           PASS: dispatch resolves to --provider pi --model google/gemini-3.7-flash"
else
    echo "           FAIL: dry-run did not produce the expected provider+flags:"
    printf '%s\n' "$OUT" | sed 's/^/             | /'
    FAIL=1
fi
# gflash alias must reach the same command
OUT_ALIAS="$("$DISPATCH" T938001 gflash --dry-run --test-root="$WORK" 2>&1 || true)"
if echo "$OUT_ALIAS" | grep -q -- "--provider pi --model google/gemini-3.7-flash"; then
    echo "           PASS: gflash alias resolves to the same command"
else
    echo "           FAIL: gflash alias did not reach the expected command:"
    printf '%s\n' "$OUT_ALIAS" | sed 's/^/             | /'
    FAIL=1
fi

# ── G. SYNC — regression-dispatch.sh's control 13 (T317) sync arm ────
# Re-run the same sync check the existing regression-dispatch.sh does
# (every canonical model in managent must be in bin/dispatch's MODELS map).
echo "        G. sync — bin/dispatch MODELS covers gemini-3.7-flash (T317 single source)"
SYNC_FAIL=0
for m in $CANON_FROM_MG; do
    if grep -q "\"$m\"" "$DISPATCH"; then
        :
    elif echo "$m" | grep -q "^claude-" && grep -q "claude-" "$DISPATCH"; then
        :
    else
        echo "           FAIL: canonical model '$m' not in bin/dispatch MODELS"
        SYNC_FAIL=1
    fi
done
if [ "$SYNC_FAIL" -eq 0 ]; then
    echo "           PASS: all canonical models resolved in bin/dispatch (including gemini-3.7-flash)"
else
    FAIL=1
fi

# ── H. NO `gflash` IS STORED ANYWHERE except the ALIAS table ──────────
echo "        H. gflash is only an alias — never stored in source / docs / binary"
# 1. src/managent/main.zig — must not contain gflash (canonical, families,
#    serving-tag map are all wrong homes)
VIOLATIONS=""
if grep -nE '\bgflash\b' "$SRC" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}src/managent/main.zig mentions gflash\n"
fi
# 2. tools/fleet_caps.py — FAMILY map is keyed on the canonical label
if grep -nE '\bgflash\b' "$FLEET_CAPS" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}tools/fleet_caps.py mentions gflash\n"
fi
# 3. tools/model_tags.py / model-profiles.py / run-record-model-backfill.py
#    — these carry canonical lists; the alias is the wrong home
for f in "$MODEL_TAGS" "$MODEL_PROFILES" "$BACKFILL"; do
    if grep -nE '\bgflash\b' "$f" 2>/dev/null; then
        VIOLATIONS="${VIOLATIONS}${f} mentions gflash\n"
    fi
done
# 4. bin/dispatch — gflash legal only in the ALIASES block; check it is
#    inside that block (an approximate regex)
if grep -nE '\bgflash\b' "$DISPATCH" 2>/dev/null | grep -vE 'ALIASES|"gflash":' | grep -vE '#.*alias' | grep -vE 'aliases'; then
    VIOLATIONS="${VIOLATIONS}bin/dispatch mentions gflash outside the ALIASES block\n"
fi
# 5. bin/subagent — gflash is the wrong home here; the canonicalizer is in
#    the Zig source (ALIASES is Python-only by convention)
if grep -nE '\bgflash\b' "$SUBAGENT" 2>/dev/null; then
    VIOLATIONS="${VIOLATIONS}bin/subagent mentions gflash\n"
fi
# 6. docs/infra/model-registry.md — gflash legal only in the §Short names
#    table
if grep -nE '\bgflash\b' "$REGISTRY" 2>/dev/null | grep -vE 'short names|\| `?gflash`?' | grep -vE 'alias'; then
    VIOLATIONS="${VIOLATIONS}docs/infra/model-registry.md mentions gflash outside the short-names table\n"
fi
if [ -n "$VIOLATIONS" ]; then
    echo "           FAIL: gflash is stored outside its allowed homes:"
    printf '%b\n' "$VIOLATIONS" | sed 's/^/             | /'
    FAIL=1
else
    echo "           PASS: gflash is an alias only — no record, no source, no doc stores it"
fi

# ── I. family wiring — `google` family exists in fleet_caps ──────────
echo "        I. family — gemini-3.7-flash is in the google family in fleet_caps"
if grep -E '"gemini-3.7-flash": *"google"' "$FLEET_CAPS" >/dev/null 2>&1 \
   || grep -E "'gemini-3.7-flash': *'google'" "$FLEET_CAPS" >/dev/null 2>&1; then
    echo "           PASS: tools/fleet_caps.py maps gemini-3.7-flash -> google"
else
    echo "           FAIL: tools/fleet_caps.py does not map gemini-3.7-flash -> google"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T938: ALL CONTROLS PASS"
    exit 0
fi
echo "  T938: SOME CHECKS FAILED (the test is RED — fix the wiring and re-run)"
exit 1
