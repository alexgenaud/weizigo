#!/usr/bin/env bash
# regression-canonicalizer-parity.sh
#
# T801 — ONE parity control over the canonicalizer, covering every registry
# tag and all four implementations.  The serving-tag -> canonical transform
# (strip `:cloud`, kimi-k2.7-code -> kimi-k2.7, stealth/ox-alpha -> ox-alpha)
# used to be implemented four times (src/managent/main.zig canonicalizeModelTag,
# tools/token-capture.py canon_tag, tools/model-profiles.py canon_tag,
# tools/runner._model_from_argv) and drifted: token-capture lacked the stealth
# mapping, the runner did not canonicalize at all, and an unrecognized tag
# passed through unchanged — which is how a serving tag reached the ledger.
#
# After T801 the transform lives in ONE place (managent) and the three Python
# tools RESOLVE it via tools/model_tags.py.  This script asserts:
#   (1) agreement — for every canonical label and every serving tag the
#       registry names, all four implementations produce the SAME result
#       (a canonical label, or a loud REJECT);
#   (2) null control — every canonical label maps to itself;
#   (3) reject control — a tag the registry does not list (and the dead
#       kimi-k2-thinking tag) is REJECTED loudly, never passed through;
#   (4) seeded arm — a fake serving tag added to a fixture canonicalizer maps
#       through every reader, and removing it makes them reject it.
#
# The parity arm is RED against HEAD (runner._model_from_argv returned the
# literal --model value; token-capture/model-profiles passed unknown tags
# through) and GREEN after T801.
#
# Usage: tools/regression-canonicalizer-parity.sh [--build]
#   --build: rebuild managent from source first (else use the deployed bin).
#   Wired into `zig build test` via build.zig.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
REGISTRY="$PROJECT/docs/infra/model-registry.md"
FAIL=0

if [ "${1:-}" = "--build" ] || [ ! -x "$MG" ]; then
    echo "  rebuilding managent (canonicalizer source of truth)..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1 | tail -5)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

if [ ! -x "$MG" ]; then
    echo "FATAL: no managent binary at $MG (build with --build)" >&2
    exit 2
fi

echo ""
echo "  T801 regression: one canonicalizer, four implementations agree"

# The heavy lifting is Python (the three readers are Python; the Zig verb is
# called as a subprocess).  It loads the readers by path so the hyphenated /
# extensionless names import.
python3 - "$MG" "$REGISTRY" "$PROJECT" <<'PYEOF'
import importlib.util
import json
import os
import subprocess
import sys

mg, registry_path, project = sys.argv[1], sys.argv[2], sys.argv[3]
tools = os.path.join(project, "tools")
if tools not in sys.path:
    sys.path.insert(0, tools)

import model_tags as mt  # noqa: E402


def load(name, path):
    spec = importlib.util.spec_from_loader(
        name, importlib.machinery.SourceFileLoader(name, path))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


tc = load("token_capture", os.path.join(tools, "token-capture.py"))
mp = load("model_profiles", os.path.join(tools, "model-profiles.py"))
runner = load("runner", os.path.join(tools, "runner"))

rules = mt.load_canonicalizer()
canonical = sorted(rules["canonical_list"])

fail = 0


def zig_result(tag):
    """The Zig source of truth: `managent canonicalize <tag>` -> label or REJECT."""
    r = subprocess.run([mg, "canonicalize", tag],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else "REJECT"


def py_result(fn, tag):
    try:
        return fn(tag)
    except mt.UnknownModelTag:
        return "REJECT"


def runner_result(tag):
    # No canonicalizer arg: the runner resolves the single source (managent,
    # or the WEIZIGO_CANONICALIZER_JSON fixture seam) exactly as production
    # does — this is what makes the seeded arm reach the runner too.  Its
    # reject warning is suppressed (it is a diagnostic, not a result).
    import contextlib
    import io
    with contextlib.redirect_stderr(io.StringIO()):
        r = runner._model_from_argv(["pi", "--model", tag])
    return r if r is not None else "REJECT"


def all_results(tag):
    return {
        "zig": zig_result(tag),
        "model_tags": py_result(mt.canon_tag, tag),
        "token_capture": py_result(tc.canon_tag, tag),
        "model_profiles": py_result(mp.canon_tag, tag),
        "runner": runner_result(tag),
    }


def reader_results(tag):
    return {k: v for k, v in all_results(tag).items() if k != "zig"}


def check_agree(tag, expected=None):
    global fail
    rs = all_results(tag)
    vals = set(rs.values())
    if len(vals) != 1:
        print("    FAIL: disagreement on %r -> %s" % (tag, rs))
        fail += 1
        return
    got = vals.pop()
    if expected is not None and got != expected:
        print("    FAIL: %r -> %r, expected %r (%s)" % (tag, got, expected, rs))
        fail += 1


# ── (1) null control: every canonical label maps to itself ──────────────
print("  1. null control: every canonical label maps to itself, all four agree")
for m in canonical:
    check_agree(m, m)
print("    %d canonical labels checked" % len(canonical))

# ── (2) agreement over the registry's serving tags, with expected values ─
# The expected values come from docs/infra/model-registry.md §Serving tags
# and §Short names (the independent fact surface — NOT the canonicalizer).
registry = open(registry_path).read()
print("  2. serving tags: registry-named tags map correctly, all four agree")
serving_cases = [
    ("glm-5.2:cloud", "glm-5.2", "the glm tag"),
    ("minimax-m3:cloud", "minimax-m3", "the minimax tag"),
    ("kimi-k2.7:cloud", "kimi-k2.7", ":cloud strip (do NOT dispatch, but maps)"),
    ("kimi-k2.7-code", "kimi-k2.7", "serving tag, never a canonical"),
    ("kimi-k2.7-code:cloud", "kimi-k2.7", "the kimi tag today"),
    ("stealth/ox-alpha", "ox-alpha", "ox-alpha serving tag"),
    ("qwen3.8:27b-mlx", "qwen3.8:27b-mlx", "local qwen (already canonical)"),
]
for tag, expected, why in serving_cases:
    if tag not in registry:
        print("    FAIL: %r vanished from model-registry.md" % tag)
        fail += 1
        continue
    check_agree(tag, expected)

# every serving-tag row in the registry's §Serving tags table is exercised:
# parse the `| \`tag\` |` left column of that section and assert each agrees.
import re
serving_block = registry.split("## Serving tags", 1)[1].split("\n##", 1)[0]
reg_tags = re.findall(r"^\| `([^`]+)` \|", serving_block, re.M)
for t in reg_tags:
    check_agree(t)  # agree with each other; the known ones already pin the value
print("    %d serving-tag rows swept from the registry" % len(reg_tags))

# ── (3) reject control: unrecognized / dead / short-name tags are REJECTED ─
print("  3. reject control: unknown and presentation-only tags are rejected")
reject_cases = [
    ("kimi-k2-thinking:cloud", "retired at 2026-06-16 (dead)"),
    ("opus", "short name — presentation only, never a stored label"),
    ("dsflash", "short name — presentation only, never a stored label"),
    ("bogus-model", "not in the registry"),
]
for tag, why in reject_cases:
    check_agree(tag, "REJECT")
print("    %d reject cases checked" % len(reject_cases))

# ── (4) seeded arm: fake serving tag maps through every reader; removing it ─
# rejects it.  Uses the WEIZIGO_CANONICALIZER_JSON fixture seam.
print("  4. seeded arm: injected serving tag maps; removing it rejects")
import atexit, shutil, tempfile
d = tempfile.mkdtemp(prefix="t801-parity-")
atexit.register(shutil.rmtree, d, ignore_errors=True)
def write_fixture(serving_tags):
    path = os.path.join(d, "canon.json")
    json.dump({
        "canonical_models": canonical,
        "strip_suffix": ":cloud",
        "serving_tags": serving_tags,
    }, open(path, "w"))
    return path

# seed: fake/model -> deepseek-v4-pro must map through every READER (the Zig
# binary's table is fixed at compile time; the fixture seam is the readers')
os.environ["WEIZIGO_CANONICALIZER_JSON"] = write_fixture(
    {"kimi-k2.7-code": "kimi-k2.7", "stealth/ox-alpha": "ox-alpha",
     "fake/model": "deepseek-v4-pro"})
mt._CACHE.clear()
seeded = reader_results("fake/model")
if set(seeded.values()) != {"deepseek-v4-pro"}:
    print("    FAIL: seeded fake/model did not map through every reader ->", seeded)
    fail += 1

# un-seed: remove fake/model -> every reader must reject it
os.environ["WEIZIGO_CANONICALIZER_JSON"] = write_fixture(
    {"kimi-k2.7-code": "kimi-k2.7", "stealth/ox-alpha": "ox-alpha"})
mt._CACHE.clear()
unseeded = reader_results("fake/model")
if set(unseeded.values()) != {"REJECT"}:
    print("    FAIL: removed fake/model still accepted ->", unseeded)
    fail += 1

del os.environ["WEIZIGO_CANONICALIZER_JSON"]
mt._CACHE.clear()
shutil.rmtree(d, ignore_errors=True)
print("    seeded map + unseed-reject both hold across the four implementations")

# ── (5) the runner's write-time canonicalization (the RED arm pre-T801) ──
print("  5. runner canonicalizes a serving tag at write time (was RED pre-T801)")
if runner._model_from_argv(["pi", "--model", "stealth/ox-alpha"], canonicalizer=rules) != "ox-alpha":
    print("    FAIL: runner._model_from_argv did not canonicalize stealth/ox-alpha")
    fail += 1
if runner._model_from_argv(["pi", "--model", "kimi-k2.7-code:cloud"], canonicalizer=rules) != "kimi-k2.7":
    print("    FAIL: runner._model_from_argv did not canonicalize kimi-k2.7-code:cloud")
    fail += 1

# ── the model_tags list and the registry's canonical block must agree ────
print("  6. resolved canonical list matches `managent models` (single source)")
out = subprocess.run([mg, "models"], capture_output=True, text=True).stdout
zig_list = [l for l in out.split("\n") if l]
if sorted(zig_list) != sorted(canonical):
    print("    FAIL: model_tags canonical list != `managent models`")
    print("      model_tags:", sorted(canonical))
    print("      managent:   ", sorted(zig_list))
    fail += 1
else:
    print("    %d labels identical" % len(canonical))

print("")
if fail:
    print("  T801: SOME CHECKS FAILED (%d)" % fail)
    sys.exit(1)
print("  T801: ALL CHECKS PASS")
PYEOF

if [ $? -ne 0 ]; then FAIL=1; fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T801 canonicalizer parity: ALL CHECKS PASS"
else
    echo "  T801 canonicalizer parity: FAILURES"
fi
exit "$FAIL"
