#!/usr/bin/env bash
# regression-serving-tag-single-path.sh — T890 controls for the one
# serving-tag path (bin/subagent --provider ollama|pi).
#
# The defect this catches: `bin/subagent --provider ollama --model
# kimi-k2.7:cloud` was accepted (both `kimi-k2.7:cloud` and
# `kimi-k2.7-code:cloud` canonicalize to `kimi-k2.7`), launched, and died
# in 0.9 s — reported to the operator as a nonce failure ("the worker did
# not read the bundle") when the model was never reached.  `bin/dispatch`
# was immune: it canonicalizes then RE-DERIVES the live serving tag from
# its own table, so the dead tag never reached ollama.  Two paths did the
# same thing differently; the un-gated one (subagent) walked into a death
# the gated one (dispatch) sidesteps.
#
# The fix (T890): the serving tag used for launch is ALWAYS re-derived
# from the canonical label — never the hand-typed one.  A hand-typed
# serving tag is accepted only as input convenience that must canonicalize
# to a known canonical; if it does not match the derived LIVE tag it is
# REFUSED by name (arm A — the dead-tag class).  For an ollama lane the
# derived live tag is validated against what the host actually serves
# before launch and refused by name if absent (arm B — the stops-the-class
# arm).  Dead alias-map entries are deleted, not re-documented.
#
# Arms:
#   1. RED  dead tag kimi-k2.7:cloud → REFUSED with a named error (today
#      it launches/dry-runs green).  Must be red before the fix.
#   2. RED  round-trip: kimi-k2.7 by canonical label through BOTH entry
#      points resolves to the SAME live serving tag kimi-k2.7-code:cloud.
#      Today bin/subagent passes the bare canonical to ollama (diverges
#      from bin/dispatch's kimi-k2.7-code:cloud).  Must be red before.
#   3. seeded-defect (arm B): a canonical whose live tag the host does NOT
#      serve is REFUSED, naming the model, the tag tried, and the host's
#      actual offerings (WEIZIGO_OLLAMA_OFFERED injects the host).  No
#      spawn — refused before launch.  This is the arm that stops the bug
#      class returning.
#   4. null control: every ollama/pi canonical model dispatches by
#      canonical label (dry-run succeeds, derives the live tag).  The fix
#      does not refuse everything.
#   5. cross-check: bin/subagent's live-tag maps ↔ its canonicalization
#      maps ↔ src/managent/main.zig canonical_models[] are consistent, and
#      bin/dispatch's MODELS table agrees with bin/subagent's derived live
#      tag for every ollama canonical — one truth, verified not duplicated.
#
# All fixtures synthetic under /tmp/weizigo.  subagent --dry-run is driven
# against a scratch FILE target (no bundle, no kanban).  No real ollama
# launch is performed; arm B uses the WEIZIGO_OLLAMA_OFFERED injection hook.
#
# Task: T890 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
DISPATCH="$ROOT/bin/dispatch"
MAIN_ZIG="$ROOT/src/managent/main.zig"
FAIL=0

# T527: clear inherited depth — a depth-3 leaf running this suite would see
# every dispatch REFUSED at the cap (correct in production, noise here).
unset WEIZIGO_AGENT_DEPTH

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t890-serving-tag-XXXXXX)" || { echo "FATAL — scratch mktemp failed (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# A scratch file target so subagent --dry-run needs no bundle/kanban (the
# file-target branch builds a prompt and prints the cmd without resolving
# a T-id bundle).
printf 'scratch prompt target for T890 regression\n' > "$WORK/target.md"

echo "=== serving-tag-single-path regression (T890) ==="

# ── helpers ───────────────────────────────────────────────────────────────
# Extract the ollama launch tag from a subagent --dry-run one-line cmd.
launch_tag() { printf '%s\n' "$1" | grep -oE 'ollama launch pi --model [^ ]+' | sed 's/^ollama launch pi --model //'; }
# Extract the openrouter (pi) launch tag.
pi_tag() { printf '%s\n' "$1" | grep -oE 'pi --provider openrouter --model [^ ]+' | sed 's/^pi --provider openrouter --model //'; }


# ── arm 1: RED — dead tag kimi-k2.7:cloud is REFUSED with a named error ──
echo "  1. dead tag kimi-k2.7:cloud → REFUSED, naming model/tag (RED before fix)"
OUT=$(cd "$ROOT" && "$SUBAGENT" --provider ollama --model kimi-k2.7:cloud --override-admission=t890-regression --dry-run "$WORK/target.md" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -qi "REFUSED" \
   && echo "$OUT" | grep -qF "kimi-k2.7" \
   && echo "$OUT" | grep -qF "kimi-k2.7:cloud"; then
    echo "    PASS: dead tag refused (rc=$RC), names model + tag tried"
else
    echo "    FAIL: expected REFUSED naming kimi-k2.7 / kimi-k2.7:cloud; rc=$RC"
    echo "$OUT" | sed 's/^/      | /'
    FAIL=1
fi

# ── arm 2: RED — round-trip, both entry points → same live tag ───────────
echo "  2. round-trip: kimi-k2.7 via dispatch and subagent → kimi-k2.7-code:cloud (RED before fix)"
# subagent by canonical label (file target, dry-run).
SUB_OUT=$(cd "$ROOT" && "$SUBAGENT" --provider ollama --model kimi-k2.7 --override-admission=t890-regression --dry-run "$WORK/target.md" 2>&1)
SUB_RC=$?
SUB_TAG="$(launch_tag "$SUB_OUT")"
# dispatch by canonical label: read its MODELS table straight from source
# (the live-tag derivation dispatch already owns; one truth, verified not
# duplicated — arm 5 checks the two agree).
DISPATCH_TAG=$(python3 - "$DISPATCH" <<'PY' || { echo "      FAIL: cannot parse bin/dispatch MODELS"; FAIL=1; }
import importlib.util, importlib.machinery, sys
spec = importlib.util.spec_from_file_location(
    "dispatch", sys.argv[1],
    loader=importlib.machinery.SourceFileLoader("dispatch", sys.argv[1]))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
entry = m.MODELS.get("kimi-k2.7")
if entry is None:
    sys.exit("no MODELS entry for kimi-k2.7")
prov, flags = entry
for i, f in enumerate(flags):
    if f == "--model" and i + 1 < len(flags):
        print(flags[i + 1])
        sys.exit(0)
sys.exit("no --model in flags")
PY
)
if [ "$SUB_RC" -eq 0 ] && [ "$SUB_TAG" = "kimi-k2.7-code:cloud" ] && [ "$DISPATCH_TAG" = "kimi-k2.7-code:cloud" ] && [ "$SUB_TAG" = "$DISPATCH_TAG" ]; then
    echo "    PASS: both resolve kimi-k2.7 → kimi-k2.7-code:cloud (subagent='$SUB_TAG', dispatch='$DISPATCH_TAG')"
else
    echo "    FAIL: subagent='$SUB_TAG' (rc=$SUB_RC), dispatch='$DISPATCH_TAG'; expected both kimi-k2.7-code:cloud"
    echo "$SUB_OUT" | sed 's/^/      | /'
    FAIL=1
fi

# ── arm 3: seeded-defect (arm B) — unserved live tag REFUSED, names offerings ─
echo "  3. seeded-defect: unserved live tag REFUSED, names model + tag + host offerings"
# Inject a host that serves only glm/minimax — kimi's live tag is absent.
OUT=$(cd "$ROOT" && WEIZIGO_OLLAMA_OFFERED="glm-5.2:cloud,minimax-m3:cloud" \
      "$SUBAGENT" --provider ollama --model kimi-k2.7 --override-admission=t890-regression --dry-run "$WORK/target.md" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -qi "REFUSED" \
   && echo "$OUT" | grep -qF "kimi-k2.7" \
   && echo "$OUT" | grep -qF "kimi-k2.7-code:cloud" \
   && echo "$OUT" | grep -qF "glm-5.2:cloud" \
   && echo "$OUT" | grep -qF "minimax-m3:cloud"; then
    echo "    PASS: unserved live tag refused, names model + tag tried + host offerings"
else
    echo "    FAIL: expected REFUSED naming kimi-k2.7, kimi-k2.7-code:cloud, glm-5.2:cloud, minimax-m3:cloud; rc=$RC"
    echo "$OUT" | sed 's/^/      | /'
    FAIL=1
fi

# ── arm 4: null control — every ollama/pi canonical dispatches by canonical label ─
echo "  4. null control: every ollama/pi canonical dispatches by label (dry-run green)"
# A host that serves every live tag, so arm B passes for all.
OFFER_ALL="glm-5.2:cloud,minimax-m3:cloud,kimi-k2.7-code:cloud,qwen3.8:27b-mlx"
NULL_FAIL=0
for pair in "ollama glm-5.2" "ollama minimax-m3" "ollama kimi-k2.7" "ollama qwen3.8:27b-mlx"; do
    prov=${pair%% *}; canon=${pair#* }
    OUT=$(cd "$ROOT" && WEIZIGO_OLLAMA_OFFERED="$OFFER_ALL" \
          "$SUBAGENT" --provider "$prov" --model "$canon" --override-admission=t890-regression --dry-run "$WORK/target.md" 2>&1)
    rc=$?
    tag="$(launch_tag "$OUT")"
    if [ "$rc" -ne 0 ]; then
        echo "    FAIL: $prov $canon dry-run refused (rc=$rc)"; echo "$OUT" | sed 's/^/      | /'; NULL_FAIL=1
    elif [ -z "$tag" ]; then
        echo "    FAIL: $prov $canon dry-run printed no ollama launch tag"; echo "$OUT" | sed 's/^/      | /'; NULL_FAIL=1
    else
        echo "    PASS: $prov $canon → $tag"
    fi
done
# pi canonical (no ollama validation; arm A only).
OUT=$(cd "$ROOT" && "$SUBAGENT" --provider pi --model ox-alpha --override-admission=t890-regression --dry-run "$WORK/target.md" 2>&1)
rc=$?
tag="$(pi_tag "$OUT")"
if [ "$rc" -eq 0 ] && [ "$tag" = "stealth/ox-alpha" ]; then
    echo "    PASS: pi ox-alpha → stealth/ox-alpha"
else
    echo "    FAIL: pi ox-alpha → expected stealth/ox-alpha, got '$tag' (rc=$rc)"; echo "$OUT" | sed 's/^/      | /'; NULL_FAIL=1
fi
[ "$NULL_FAIL" -ne 0 ] && FAIL=1

# ── arm 5: cross-check — one truth, verified not duplicated ───────────────
echo "  5. cross-check: subagent live-tag ↔ canonicalization ↔ canonical_models[] ↔ dispatch MODELS"
python3 - "$ROOT" <<'PY' || { echo "    FAIL: cross-check"; FAIL=1; }
import importlib.util, importlib.machinery, re, sys
root = sys.argv[1]
# Load bin/subagent's maps (module import — its main() is guarded by __name__).
spec = importlib.util.spec_from_file_location(
    "subagent", f"{root}/bin/subagent",
    loader=importlib.machinery.SourceFileLoader("subagent", f"{root}/bin/subagent"))
sub = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sub)
# Load bin/dispatch's MODELS.
specd = importlib.util.spec_from_file_location(
    "dispatch", f"{root}/bin/dispatch",
    loader=importlib.machinery.SourceFileLoader("dispatch", f"{root}/bin/dispatch"))
disp = importlib.util.module_from_spec(specd)
specd.loader.exec_module(disp)
# canonical_models[] from source (the T317 single source of truth).
with open(f"{root}/src/managent/main.zig") as f:
    src = f.read()
m = re.search(r'const canonical_models = \[_\]\[\]const u8\{\s*(.*?)\};', src, re.DOTALL)
assert m, "cannot parse canonical_models[]"
canon = set(re.findall(r'"([^"]+)"', m.group(1)))

ok = True
# Ollama: every canonical in CANONICAL_TO_OLLAMA_TAG must be a canonical model,
# and its live tag must canonicalize back to it.
c2l = getattr(sub, "CANONICAL_TO_OLLAMA_TAG", None)
assert c2l is not None, "bin/subagent missing CANONICAL_TO_OLLAMA_TAG (T890)"
for c, live in c2l.items():
    if c not in canon:
        print(f"    FAIL: ollama live-tag canonical {c!r} not in canonical_models[]"); ok = False
    back = sub.OLLAMA_TAG_TO_CANONICAL.get(live)
    if back != c:
        print(f"    FAIL: ollama live tag {live!r} -> {back!r}, expected canonical {c!r}"); ok = False
    d = disp.MODELS.get(c)
    if d is None:
        print(f"    FAIL: bin/dispatch MODELS has no entry for ollama canonical {c!r}"); ok = False
    else:
        dtag = None
        prov, flags = d
        for i, f in enumerate(flags):
            if f == "--model" and i + 1 < len(flags):
                dtag = flags[i + 1]
        if dtag != live:
            print(f"    FAIL: dispatch MODELS[{c!r}] = {dtag!r}, subagent live tag = {live!r}"); ok = False
# pi: same for CANONICAL_TO_PI_TAG.
p2l = getattr(sub, "CANONICAL_TO_PI_TAG", None)
assert p2l is not None, "bin/subagent missing CANONICAL_TO_PI_TAG (T890)"
for c, live in p2l.items():
    if c not in canon:
        print(f"    FAIL: pi live-tag canonical {c!r} not in canonical_models[]"); ok = False
    back = sub.PI_TAG_TO_CANONICAL.get(live)
    if back != c:
        print(f"    FAIL: pi live tag {live!r} -> {back!r}, expected canonical {c!r}"); ok = False
    d = disp.MODELS.get(c)
    if d is None:
        print(f"    FAIL: bin/dispatch MODELS has no entry for pi canonical {c!r}"); ok = False
    else:
        dtag = None
        prov, flags = d
        for i, f in enumerate(flags):
            if f == "--model" and i + 1 < len(flags):
                dtag = flags[i + 1]
        if dtag != live:
            print(f"    FAIL: dispatch MODELS[{c!r}] = {dtag!r}, subagent pi live tag = {live!r}"); ok = False
# Dead entry must be gone from the canonicalization map (deletion before addition).
if "kimi-k2.7:cloud" in sub.OLLAMA_TAG_TO_CANONICAL:
    print("    FAIL: dead alias 'kimi-k2.7:cloud' still in OLLAMA_TAG_TO_CANONICAL (T890 delete)"); ok = False
if ok:
    print("    PASS: subagent live-tag maps ↔ canonicalization ↔ canonical_models[] ↔ dispatch MODELS all agree")
sys.exit(0 if ok else 1)
PY

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-serving-tag-single-path: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-serving-tag-single-path: FAILURES ==="
    exit 1
fi