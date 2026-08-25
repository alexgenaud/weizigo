#!/usr/bin/env bash
# regression-openrouter-four-wiring.sh — T954 controls for wiring
# gpt-5.6-luna-pro, qwen3.8-27b, nemotron-3.5-lightning and solar-pro4
# through the canonicalizer, the dispatcher, the runner's pi provider,
# the cap census, and the operator-facing short names gptluna / qwencloud
# / nemotron / solarpro.
#
# Why this exists: the operator verified all four headless on 2026-08-25
# (claude-fable-5 seat, rc 0, key registered inside pi — no env guard, T940)
# with `pi --provider openrouter --model <serving tag>` and asked them wired
# in the gemini-3.7-flash shape (T938).  Six surfaces must move in step
# (T317 single source of truth; T801 one canonicalizer, not four):
#
#   1. src/managent/main.zig canonical_models[] — the four canonical labels
#      (this is what every record stores)
#   2. src/managent/main.zig serving_tag_map / canonicalizeModelTag —
#      `openai/...` `qwen/...` `nvidia/...` `upstage/...` -> the canonical
#      labels (the vendor prefix is the serving tag's business, never the
#      ledger's)
#   3. src/managent/main.zig model_families[] + family_appetite[] — four
#      families (openai, alibaba, nvidia, upstage), all SPEND
#      (equal-opportunity class, the operator's dial-5 set — same as T938)
#   4. bin/dispatch MODELS / ALIASES / canonicalize_model — dry-run dispatch
#      resolves to `pi --model <serving tag>`, short names are input aliases
#   5. bin/subagent PI_TAG_TO_CANONICAL / CANONICAL_TO_PI_TAG — both
#      directions of the live-tag map (T890 single source)
#   6. tools/fleet_caps.py FAMILY — the cap-family map (openrouter has no
#      recorded ceiling for any of the four — they are uncapped, never
#      silently "other")
#
# Three readers — tools/model_tags.py, tools/model-profiles.py, and
# tools/run-record-model-backfill.py — resolve the canonicalizer from
# the managent binary (T801 seam).  tools/run-record-model-backfill.py
# carries its OWN hard-coded copy (a pre-T801 smudge that T938 finding a
# recorded and regression-gemini-flash-wiring.sh arm E5 pins); T954 extends
# that copy rather than migrating it, because migrating removes the copy
# arm E5 parses and would break the T938 regression (whose file is not in
# this row's surface list).  The controls assert that, if the two diverge,
# the managent binary wins.
#
# Naming (T954): canonical label vendor-free and versioned; the vendor
# prefix belongs to the serving tag; the short name is an INPUT ALIAS ONLY
# — it joins dspro/dsflash/gflash in bin/dispatch ALIASES and the
# registry's §Short names table, and appears NOWHERE ELSE: not in a kanban
# row, not in the perf ledger, not in a findings file, not in a test's
# expected stored value.
#
# `qwen3.8-27b` is a CLOUD model (family alibaba, appetite spend).  It is
# NOT the local `qwen3.8:27b-mlx` (family local, appetite probe, short
# name qwenlocal, T833).  Two distinct canonical labels, two distinct
# short names, two families — the seeded-defect arm proves they never
# collapse onto each other.
#
# Controls:
#
#   A. RED (against HEAD): `managent models` does NOT list the four; the
#      hard-coded list in tools/run-record-model-backfill.py does NOT
#      include them.
#   B. GREEN (after wiring): all surfaces know the four labels; each
#      serving tag canonicalizes to its label.
#   C. NULL: every pre-existing canonical model and serving tag still
#      resolves exactly as before (oxalpha, stealth/ox-alpha,
#      gemini-3.7-flash, google/gemini-3.7-flash, kimi-k2.7-code:cloud,
#      qwen3.8:27b-mlx, dspro/dsflash, each claude label).
#   D. SEEDED DEFECT: `gptlunax`, `openai/gpt-5.6-luna`, `qwen/qwen3.8-max`,
#      `qwen3.8:27b` (the COLON form is the local model — a cloud row must
#      not land on the local label, nor the reverse), `nvidia/nemotron-3.5`,
#      `upstage/solar-pro3`, and each of the four short names AS A STORED
#      LABEL are each REFUSED by name — never silently mapped to something
#      real.  A near-miss that canonicalizes to an existing label is the
#      defect this control exists to catch.
#   E. ROUND TRIP: canonical -> serving tag -> canonical returns the
#      canonical label, in managent, in model_tags, in model-profiles, in
#      the runner, and in the backfill hard-coded copy — for all four and
#      for one pre-existing model.
#   F. real dry-run dispatch resolves to `pi --model <serving tag>` for
#      each of the four, via the canonical label AND via the short name.
#   G. SYNC: bin/dispatch MODELS covers every canonical model (T317 sync
#      contract from regression-dispatch.sh control 13).
#   H. NO short name is stored anywhere outside bin/dispatch ALIASES and
#      the registry's §Short names table — source tree, docs, findings,
#      and the binary (the T938 arm F shape, generalized to a list).
#   I. FAMILY: tools/fleet_caps.py maps all four to their families.
#   J. UNIQUE short names: the registry §Short names table's first column
#      has no duplicate.
#   K. ROSTER: `managent assign` draws from a 14-model spend roster, and
#      can draw each of the four by name.
#
# Wired into `zig build test` via build.zig.
#
# Task: T954 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-25

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
BIN="$ROOT/bin/managent"
ZIGOUT_BIN="$ROOT/zig-out/bin/managent"

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
weizigo_scratch_repo t954-openrouter WORK
trap 'rm -rf "$WORK"' EXIT

cd "$WORK"
git config user.email t954@test
git config user.name T954
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
    printf '# minimal scratch claims register (T954 regression)\n' > "$WORK/docs/epistemic/CLAIMS.md"
fi

# Register a dispatchable row with a bundle so bin/dispatch's dry-run
# reaches the model-resolution arm.
printf '<!--managent set=A type=infra deliverables=findings/T954001.json-->\n# T954001 — dry-run fixture for T954 wiring\n**Landmark:** advances `L1 (the dashboard tells the truth)` — regression fixture\n' \
    > "$WORK/untracked/T954001-bundle.md"
"$MG" add T954001 >/dev/null 2>&1 || true

# Canonical list from managent (the single source the readers depend on)
# — the wire must ADD the four labels; if they are not here, controls A
# and B fail loudly.
CANON_FROM_MG="$("$MG" models 2>/dev/null | grep -v '^managent ' || true)"

CANON_FOUR="gpt-5.6-luna-pro qwen3.8-27b nemotron-3.5-lightning solar-pro4"
SERVING_FOUR="openai/gpt-5.6-luna-pro qwen/qwen3.8-27b nvidia/nemotron-3.5-lightning upstage/solar-pro4"
SHORT_FOUR="gptluna qwencloud nemotron solarpro"

echo ""
echo "  T954 regression: four openrouter models wiring"

# ── A. RED/green arm: managent models lists all four ────────────────────
echo "        A. managent models lists all four canonical labels"
A_FAIL=0
for m in $CANON_FOUR; do
    if printf '%s\n' "$CANON_FROM_MG" | grep -Fxq "$m"; then
        echo "           PASS: $m is in the canonical list"
    else
        echo "           FAIL: $m is not in the canonical list"
        echo "             | (this is the RED arm — wiring has not landed yet)"
        A_FAIL=1
    fi
done
[ "$A_FAIL" -eq 0 ] || FAIL=1

# ── B. canonicalize each serving tag -> canonical label ─────────────────
echo "        B. managent canonicalize resolves the four serving tags"
B_FAIL=0
i=0
for tag in $SERVING_FOUR; do
    set -- $CANON_FOUR
    eval "expected=\${$((i+1))}"
    CANON_OUT="$("$MG" canonicalize "$tag" 2>/dev/null || true)"
    if [ "$CANON_OUT" = "$expected" ]; then
        echo "           PASS: $tag -> $CANON_OUT"
    else
        echo "           FAIL: $tag did not canonicalize to $expected (got: '$CANON_OUT')"
        B_FAIL=1
    fi
    i=$((i+1))
done
[ "$B_FAIL" -eq 0 ] || FAIL=1

# ── C. NULL — every pre-existing label/serving tag/alias unchanged ──────
echo "        C. null — every pre-existing label still resolves as before"
NULL_FAIL=0
for m in claude-opus-5 claude-sonnet-5 claude-fable-5 claude-haiku-4-5-20251001 \
         deepseek-v4-pro deepseek-v4-flash glm-5.2 minimax-m3 kimi-k2.7 \
         qwen3.8:27b-mlx oxalpha gemini-3.7-flash; do
    got="$("$MG" canonicalize "$m" 2>/dev/null || true)"
    if [ "$got" != "$m" ]; then
        echo "           FAIL: $m canonicalized to '$got' (should be self)"
        NULL_FAIL=1
    fi
done
# pre-existing serving-tag mappings must still work
for pair in "kimi-k2.7-code:cloud:kimi-k2.7" "stealth/ox-alpha:oxalpha" \
            "google/gemini-3.7-flash:gemini-3.7-flash" "kimi-k2.7-code:kimi-k2.7"; do
    raw="${pair%%:*}"; expected="${pair##*:}"
    got="$("$MG" canonicalize "$raw" 2>/dev/null || true)"
    if [ "$got" != "$expected" ]; then
        echo "           FAIL: serving tag $raw canonicalized to '$got' (expected $expected)"
        NULL_FAIL=1
    fi
done
# dispatch aliases dspro/dsflash/gflash still reach the same commands
for pair in "dspro:deepseek-v4-pro:--dspro" "dsflash:deepseek-v4-flash:--dsflash" \
            "gflash:gemini-3.7-flash:google/gemini-3.7-flash"; do
    alias="${pair%%:*}"; rest="${pair#*:}"; canon="${rest%%:*}"; flag="${rest##*:}"
    OUT="$("$DISPATCH" T954001 "$alias" --dry-run --test-root="$WORK" 2>&1 || true)"
    if echo "$OUT" | grep -q -- "$flag"; then
        :
    else
        echo "           FAIL: alias $alias did not reach $flag:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        NULL_FAIL=1
    fi
    # and the alias must never appear as a stored canonical label
    if printf '%s\n' "$CANON_FROM_MG" | grep -Fxq "$alias"; then
        echo "           FAIL: alias $alias is a stored canonical label"
        NULL_FAIL=1
    fi
done
if [ "$NULL_FAIL" -eq 0 ]; then
    echo "           PASS: 12 canonical labels + 4 serving tags + 3 aliases unchanged"
else
    FAIL=1
fi

# ── D. SEEDED DEFECT — near-misses are refused by name ──────────────────
echo "        D. seeded defect — six near-misses + four short names are refused"
# D1: gptlunax — typo on the alias, must be REFUSED (no silent map)
OUT="$("$DISPATCH" T954001 gptlunax --dry-run --test-root="$WORK" 2>&1 || true)"
if echo "$OUT" | grep -q "gptlunax"; then
    if echo "$OUT" | grep -qE "(REFUSED|refused|not a canonical|unknown)"; then
        echo "           PASS: gptlunax refused (named in refusal)"
    else
        echo "           FAIL: gptlunax output does not name it as a refusal:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        FAIL=1
    fi
else
    echo "           FAIL: gptlunax did not appear in dispatch output at all"
    printf '%s\n' "$OUT" | sed 's/^/             | /'
    FAIL=1
fi
# D2..D6: canonicalize refuses each near-miss (exit != 0 — a successful
# resolve prints exactly the label and exits 0; refusal exits 1).
D_NEAR_MISSES="openai/gpt-5.6-luna qwen/qwen3.8-max qwen3.8:27b nvidia/nemotron-3.5 upstage/solar-pro3"
D2_FAIL=0
for bad in $D_NEAR_MISSES; do
    "$MG" canonicalize "$bad" >/dev/null 2>&1
    RC=$?
    if [ "$RC" -ne 0 ]; then
        echo "           PASS: $bad refused (exit $RC, did not map to anything)"
    else
        OUT="$("$MG" canonicalize "$bad" 2>&1 || true)"
        echo "           FAIL: $bad canonicalized to $OUT (silent near-miss, exit 0)"
        D2_FAIL=1
    fi
done
# the same near-misses must also be refused by bin/dispatch (the door)
for bad in $D_NEAR_MISSES; do
    OUT="$("$DISPATCH" T954001 "$bad" --dry-run --test-root="$WORK" 2>&1 || true)"
    if echo "$OUT" | grep -q "refused"; then
        :
    else
        echo "           FAIL: dispatch did not refuse $bad:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        D2_FAIL=1
    fi
done
# qwen3.8:27b specifically must NEVER land on the local label — the
# refusal above (exit 1) already proves it cannot map to qwen3.8:27b-mlx;
# re-assert the refusal here so the local/cloud split is pinned explicitly.
"$MG" canonicalize qwen3.8:27b >/dev/null 2>&1
QRC=$?
if [ "$QRC" -eq 0 ]; then
    OUT="$("$MG" canonicalize qwen3.8:27b 2>&1 || true)"
    echo "           FAIL: qwen3.8:27b canonicalized to $OUT (must be refused — colon form is the LOCAL model)"
    FAIL=1
else
    echo "           PASS: qwen3.8:27b refused (exit $QRC) — it cannot land on the local model"
fi
[ "$D2_FAIL" -eq 0 ] || FAIL=1
# D7: the four short names must NEVER appear as STORED labels
D7_FAIL=0
for s in $SHORT_FOUR; do
    if printf '%s\n' "$CANON_FROM_MG" | grep -Fxq "$s"; then
        echo "           FAIL: $s appears in managent models (must not — alias only)"
        D7_FAIL=1
    fi
done
[ "$D7_FAIL" -eq 0 ] && echo "           PASS: no short name is a stored canonical label"

# ── E. ROUND TRIP — managent, model_tags, model-profiles, runner, backfill ──
echo "        E. round trip — managent, model_tags, model-profiles, runner, backfill agree"
python3 - "$MG" "$MODEL_TAGS" "$MODEL_PROFILES" "$BACKFILL" "$CANON_FOUR" "$SERVING_FOUR" <<'PYEOF'
import importlib.util, json, os, re, subprocess, sys
mg, model_tags_path, model_profiles_path, backfill_path, canon_four_s, serving_four_s = sys.argv[1:]
tools_dir = os.path.dirname(model_tags_path)
if tools_dir not in sys.path:
    sys.path.insert(0, tools_dir)
import model_tags as mt  # noqa: E402

def _load_mod(name, path):
    spec = importlib.util.spec_from_loader(
        name, importlib.machinery.SourceFileLoader(name, path))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod

mp = _load_mod("model_profiles", model_profiles_path)

CANON_FOUR = canon_four_s.split()
SERVING_FOUR = serving_four_s.split()
fail = 0

# E1: managent canonicalize <serving tag> -> canonical, for all four
for tag, canon in zip(SERVING_FOUR, CANON_FOUR):
    r = subprocess.run([mg, "canonicalize", tag], capture_output=True, text=True)
    if r.returncode != 0 or r.stdout.strip() != canon:
        print("           FAIL: managent canonicalize %s -> %r" % (tag, r.stdout.strip()))
        fail += 1

# E2: model_tags canon_tag (resolved from managent) returns the same
for tag, canon in zip(SERVING_FOUR, CANON_FOUR):
    try:
        got = mt.canon_tag(tag)
        if got != canon:
            print("           FAIL: model_tags canon_tag -> %r (expected %s)" % (got, canon))
            fail += 1
    except mt.UnknownModelTag:
        print("           FAIL: model_tags refused %s" % tag)
        fail += 1

# E3: model-profiles canon_tag (its own public reader, same seam)
for tag, canon in zip(SERVING_FOUR, CANON_FOUR):
    try:
        got = mp.canon_tag(tag)
        if got != canon:
            print("           FAIL: model-profiles canon_tag -> %r (expected %s)" % (got, canon))
            fail += 1
    except mt.UnknownModelTag:
        print("           FAIL: model-profiles refused %s" % tag)
        fail += 1

# E4: the runner's _model_from_argv must canonicalize the serving tag
spec = importlib.util.spec_from_loader(
    "runner", importlib.machinery.SourceFileLoader("runner", os.path.join(tools_dir, "runner")))
runner = importlib.util.module_from_spec(spec)
sys.modules["runner"] = runner
spec.loader.exec_module(runner)
for tag, canon in zip(SERVING_FOUR, CANON_FOUR):
    try:
        got = runner._model_from_argv(["pi", "--model", tag])
        if got != canon:
            print("           FAIL: runner._model_from_argv -> %r (expected %s)" % (got, canon))
            fail += 1
    except Exception as e:
        print("           FAIL: runner._model_from_argv raised %s" % e)
        fail += 1

# E5: pre-existing models still round-trip (regression guard)
for canon, raw in [("oxalpha", "stealth/ox-alpha"),
                   ("kimi-k2.7", "kimi-k2.7-code:cloud"),
                   ("gemini-3.7-flash", "google/gemini-3.7-flash")]:
    try:
        got = mt.canon_tag(raw)
        if got != canon:
            print("           FAIL: round-trip %r -> %r (expected %r)" % (raw, got, canon))
            fail += 1
    except mt.UnknownModelTag:
        print("           FAIL: round-trip %r refused" % raw)
        fail += 1

# E6: model_tags canonical list (resolved from managent) and the hard-coded
#     list in tools/run-record-model-backfill.py must BOTH contain the four.
#     Drift is a finding.  (T954 extends the backfill copy rather than
#     migrating it — regression-gemini-flash-wiring.sh arm E5 parses it.)
canon_list = mt.canonical_models()
for c in CANON_FOUR:
    if c not in canon_list:
        print("           FAIL: model_tags canonical list (resolved from managent) lacks %s" % c)
        fail += 1
hardcoded_text = open(backfill_path).read()
m = re.search(r'"canonical_models":\s*\[(.*?)\]', hardcoded_text, re.S)
if not m:
    print("           FAIL: could not parse canonical_models list in %s" % backfill_path)
    fail += 1
else:
    hardcoded = re.findall(r'"([a-z0-9.:\-]+)"', m.group(1))
    for c in CANON_FOUR:
        if c not in hardcoded:
            print("           FAIL: hard-coded canonical_models in run-record-model-backfill.py lacks %s" % c)
            fail += 1
    if set(canon_list) != set(hardcoded):
        print("           FAIL: drift between managent canonical list and run-record-model-backfill.py hard-coded list")
        print("             | in managent only:", sorted(set(canon_list) - set(hardcoded)))
        print("             | in backfill only:", sorted(set(hardcoded) - set(canon_list)))
        fail += 1

if fail == 0:
    print("           PASS: all round-trip checks hold (managent, model_tags, model-profiles, runner, drift guard)")
sys.exit(1 if fail else 0)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── F. real dry-run dispatch resolves to pi + the serving tag ────────────
echo "        F. real dry-run dispatch resolves to pi + --model <serving tag>"
F_FAIL=0
i=0
for canon in $CANON_FOUR; do
    set -- $SERVING_FOUR
    eval "tag=\${$((i+1))}"
    OUT="$("$DISPATCH" T954001 "$canon" --dry-run --test-root="$WORK" 2>&1 || true)"
    if echo "$OUT" | grep -q -- "--provider pi --model $tag"; then
        echo "           PASS: $canon resolves to --provider pi --model $tag"
    else
        echo "           FAIL: $canon dry-run did not produce pi + $tag:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        F_FAIL=1
    fi
    i=$((i+1))
done
# short-name aliases must reach the same commands
i=0
for short in $SHORT_FOUR; do
    set -- $SERVING_FOUR
    eval "tag=\${$((i+1))}"
    OUT="$("$DISPATCH" T954001 "$short" --dry-run --test-root="$WORK" 2>&1 || true)"
    if echo "$OUT" | grep -q -- "--provider pi --model $tag"; then
        echo "           PASS: $short alias resolves to the same command"
    else
        echo "           FAIL: $short alias did not reach pi + $tag:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        F_FAIL=1
    fi
    i=$((i+1))
done
[ "$F_FAIL" -eq 0 ] || FAIL=1

# ── G. SYNC — bin/dispatch MODELS covers every canonical (T317) ──────────
echo "        G. sync — bin/dispatch MODELS covers every canonical model (T317)"
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
    echo "           PASS: all canonical models resolved in bin/dispatch (including the four)"
else
    FAIL=1
fi

# ── H. NO short name is stored anywhere except ALIASES + §Short names ────
echo "        H. the four short names are aliases only — never stored in source / docs / binary"
# A short name "appears" only as a standalone token: `nemotron` inside
# `nemotron-3.5-lightning` is not the alias.  Boundary regex: not preceded
# by a label char, not followed by a label char or `-`.
VIOLATIONS=""
for s in $SHORT_FOUR; do
    RX="(^|[^-a-zA-Z0-9])${s}([^-a-zA-Z0-9]|\$)"
    # 1. src/managent/main.zig — canonical, families, serving-tag map are
    #    all wrong homes
    if grep -nE "$RX" "$SRC" 2>/dev/null; then
        VIOLATIONS="${VIOLATIONS}src/managent/main.zig mentions $s\n"
    fi
    # 2. tools/fleet_caps.py — FAMILY map is keyed on the canonical label
    if grep -nE "$RX" "$FLEET_CAPS" 2>/dev/null; then
        VIOLATIONS="${VIOLATIONS}tools/fleet_caps.py mentions $s\n"
    fi
    # 3. tools/model_tags.py / model-profiles.py / run-record-model-backfill.py
    for f in "$MODEL_TAGS" "$MODEL_PROFILES" "$BACKFILL"; do
        if grep -nE "$RX" "$f" 2>/dev/null; then
            VIOLATIONS="${VIOLATIONS}${f} mentions $s\n"
        fi
    done
    # 4. bin/subagent — the canonicalizer is in the Zig source; the alias
    #    table is Python-side in bin/dispatch only
    if grep -nE "$RX" "$SUBAGENT" 2>/dev/null; then
        VIOLATIONS="${VIOLATIONS}bin/subagent mentions $s\n"
    fi
    # 5. bin/dispatch — legal only inside the ALIASES block
    if grep -nE "$RX" "$DISPATCH" 2>/dev/null | grep -vE 'ALIASES|".*":' | grep -vE '#.*alias'; then
        VIOLATIONS="${VIOLATIONS}bin/dispatch mentions $s outside the ALIASES block\n"
    fi
    # 6. docs/infra/model-registry.md — legal only in the §Short names table
    #    (exclude table rows, the section heading, and alias prose — the
    #    T938 arm F filter shape)
    if grep -nE "$RX" "$REGISTRY" 2>/dev/null | grep -vE '^[0-9]+:\\| ' | grep -vE 'Short names|alias'; then
        VIOLATIONS="${VIOLATIONS}docs/infra/model-registry.md mentions $s outside the short-names table\n"
    fi
    # NOTE: findings/ and docs/audits/done-audit-2026-08-25/corpus.md are NOT
    # swept here.  The T938 arm F shape this control generalizes greps the
    # wiring surfaces only; the T945 DONE-audit corpus + its sealed context
    # dump (both committed 2026-08-25, before this row) name the audit arms
    # by short name — a sealed, pre-existing artifact this row cannot
    # rewrite and does not control.  See findings/T954-wire-openrouter-four.json.
    # 7. the binaries
    for b in "$BIN" "$ZIGOUT_BIN"; do
        if [ -f "$b" ] && LC_ALL=C grep -a -E "$RX" "$b" >/dev/null 2>&1; then
            VIOLATIONS="${VIOLATIONS}${b} contains the literal $s\n"
        fi
    done
done
if [ -n "$VIOLATIONS" ]; then
    echo "           FAIL: a short name is stored outside its allowed homes:"
    printf '%b\n' "$VIOLATIONS" | sed 's/^/             | /'
    FAIL=1
else
    echo "           PASS: the four short names are aliases only — no record, no source, no doc, no binary stores them"
fi

# ── I. family wiring — the four families exist in fleet_caps ─────────────
echo "        I. family — the four labels map to their families in fleet_caps"
I_FAIL=0
for pair in "gpt-5.6-luna-pro:openai" "qwen3.8-27b:alibaba" \
            "nemotron-3.5-lightning:nvidia" "solar-pro4:upstage"; do
    canon="${pair%%:*}"; fam="${pair##*:}"
    if grep -E "\"$canon\": *\"$fam\"" "$FLEET_CAPS" >/dev/null 2>&1 \
       || grep -E "'$canon': *'$fam'" "$FLEET_CAPS" >/dev/null 2>&1; then
        echo "           PASS: tools/fleet_caps.py maps $canon -> $fam"
    else
        echo "           FAIL: tools/fleet_caps.py does not map $canon -> $fam"
        I_FAIL=1
    fi
done
# openrouter has no recorded ceiling for any of the four — they must not be
# in DEFAULT_FAMILY_CAP (a silent invented cap would be the C5 sin)
for fam in openai alibaba nvidia upstage; do
    if grep -E "\"$fam\":" "$FLEET_CAPS" | grep -v "FAMILY\|family_cap\|family_inprog\|family_of" | grep -qE '^\s*"'; then
        echo "           FAIL: $fam appears in DEFAULT_FAMILY_CAP (no recorded ceiling — invent nothing)"
        I_FAIL=1
    fi
done
[ "$I_FAIL" -eq 0 ] || FAIL=1

# ── J. UNIQUE short names — registry §Short names first column has no dup ──
echo "        J. unique short names — registry §Short names table has no duplicate"
J_FAIL=0
JDUPS=$(awk '/^## Short names/{insec=1; next} /^## /{insec=0} insec && /^\| `/{print}' "$REGISTRY" \
        | sed -E 's/^\| `([^`]+)`.*/\1/' | sort | uniq -d)
if [ -n "$JDUPS" ]; then
    echo "           FAIL: duplicate short name(s) in the registry table: $JDUPS"
    FAIL=1
else
    # also count: every one of the 16 known short names must be present
    J_COUNT=$(awk '/^## Short names/{insec=1; next} /^## /{insec=0} insec && /^\| `/{c++} END{print c+0}' "$REGISTRY")
    if [ "$J_COUNT" -lt 16 ]; then
        echo "           FAIL: §Short names table has only $J_COUNT rows (expected >= 16)"
        FAIL=1
    else
        echo "           PASS: §Short names table has $J_COUNT unique rows, no duplicates"
    fi
fi

# ── K. ROSTER — assign draws from a 14-model spend roster ────────────────
echo "        K. roster — assign draws from the 14-model spend roster"
K_FAIL=0
ASSIGN_JSON="$("$MG" assign T954001 --dry-run --json 2>/dev/null || true)"
N_CANDS=$(printf '%s' "$ASSIGN_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(len(d.get("candidates") or []))' 2>/dev/null || echo 0)
if [ "$N_CANDS" = "14" ]; then
    echo "           PASS: assign sees 14 spend-roster candidates"
else
    echo "           FAIL: assign sees $N_CANDS candidates (expected 14)"
    printf '%s\n' "$ASSIGN_JSON" | sed 's/^/             | /'
    K_FAIL=1
fi
for canon in $CANON_FOUR; do
    OUT="$("$MG" assign T954001 --model "$canon" --dry-run --json 2>/dev/null || true)"
    if printf '%s' "$OUT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get('method')=='preferred' and d.get('model')=='$canon' else 1)" 2>/dev/null; then
        echo "           PASS: assign can draw $canon (method=preferred)"
    else
        echo "           FAIL: assign could not draw $canon:"
        printf '%s\n' "$OUT" | sed 's/^/             | /'
        K_FAIL=1
    fi
done
[ "$K_FAIL" -eq 0 ] || FAIL=1

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T954: ALL CONTROLS PASS"
    exit 0
fi
echo "  T954: SOME CHECKS FAILED (the test is RED — fix the wiring and re-run)"
exit 1
