#!/usr/bin/env bash
# regression-managent-holds.sh
# T539 regression: the `holds=` bundle header is parsed into the store at
# registration (add), `--holds a,b` is an explicit writer, `holds --sync`
# reconciles stale rows, and the vacuous one-writer check (store holds empty
# while the bundle declares holds) is loud instead of silently "no conflict".
#
# The defect (T539): 34 of 49 rows whose bundle declares `holds=` had
# `"holds": []` in the store — the field had no writer on the registration
# path the fleet actually used, so holdsConflict compared empty sets and always
# passed, while the keeper reported a one-writer invariant it never enforced.
#
# Must be RED against the pre-T539 binary: a bundle `holds=a.zig` registered
# via `add` did not split comma lists (a two-file hold became one
# "a.zig,b.zig" element), there was no `--holds` flag, no `holds --sync`
# verb, and a claim whose bundle declared holds but whose store row was empty
# proceeded silently.
#
# Arms (all against a scratch MANAGENT_STORE outside a fake repo_root):
#   1. seeded writer — `add` from a bundle `holds=a.zig` stores ["a.zig"].
#   2. seeded writer — `add` from `holds=a.zig,b.zig` stores TWO elements
#      (comma-split; the old code stored one "a.zig,b.zig" string).
#   3. seeded writer — `add --holds x.sh,y.sh` on a no-holds bundle stores
#      ["x.sh","y.sh"] (the explicit writer for rows without a bundle holds).
#   4. seeded conflict — holder in_progress on a.zig; claimant whose store
#      holds is empty but whose bundle declares a.zig is REFUSED, naming the
#      holder, AND stderr warns about the registration gap.
#   5. null conflict — claimant declares b.zig → claim succeeds (no brake on
#      non-conflicting work).
#   6. seeded sync — two stale rows (bundle declares holds, store empty) are
#      both filled by `holds --sync`, the diff is printed to stdout, and a
#      second run is a no-op (idempotent).
#   7. null no-holds — a bundle with no `holds=` leaves the store row [] and
#      `add` exits 0.
#   8. dispatch warning — dispatching a row whose bundle declares holds but
#      whose store row is empty warns on stderr naming row and files.
#
# Usage:  tools/regression-managent-holds.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

# T268: the deployed copy must BE what we built.
stamp_of() {
    "$1" --version 2>&1 | grep -oE '[a-z][a-z0-9-]* [0-9a-f]{7}(-dirty)? built' | head -1 | sed 's/ built$//' || true
}
BUILT_STAMP=$(stamp_of "$PROJECT/zig-out/bin/managent")
DEPLOYED_STAMP=$(stamp_of "$MG")
echo "  T268: deployed stamp check"
if [ -z "$DEPLOYED_STAMP" ]; then
    echo "    FAIL: bin/managent missing or unstamped — run 'zig build' then deploy"
    FAIL=1
elif [ -z "$BUILT_STAMP" ]; then
    echo "    SKIP: no built zig-out/bin/managent (build with 'zig build') — cannot stamp-check"
    exit 0
elif [ "$BUILT_STAMP" = "$DEPLOYED_STAMP" ]; then
    echo "    PASS: deployed bin/$DEPLOYED_STAMP == built zig-out/$BUILT_STAMP"
else
    echo "    FAIL: deployed bin/$DEPLOYED_STAMP != built zig-out/$BUILT_STAMP — bin/ is stale"
    FAIL=1
fi

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent a suite's arms into the LIVE repo.
mkdir -p /tmp/weizigo
ROOT="$(mktemp -d /tmp/weizigo/managent-holds-XXXXXX)" || { echo "regression-managent-holds.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

REPO="$ROOT/repo"
SCRATCH="$ROOT/scratch"
mkdir -p "$REPO/untracked" "$SCRATCH/docs/infra/managent"
git init -q "$REPO"
git -C "$REPO" config user.email "t539@test"
git -C "$REPO" config user.name "T539"

SCRATCH_STORE="$SCRATCH/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$SCRATCH_STORE"
# T427 belt-and-suspenders: if the store override ever silently points back at
# the live kanban, the harness must refuse to mutate it rather than proceed.
export MANAGENT_TEST=1

# Run managent with cwd in the fake repo (so findRepoRoot globs $REPO/untracked).
mg() {
    (cd "$REPO" && "$MG" "$@")
}

# Write a bundle header.  $1 = id, $2 = slug, $3 = header content after
# "<!--managent " (may be empty).
write_bundle() {
    local id="$1" slug="$2" meta="$3"
    printf '<!--managent %s-->\n# %s — %s\n' "$meta" "$id" "$slug" > "$REPO/untracked/$id-$slug.md"
}

# store_holds <id> → the holds JSON array for a row (or the literal "MISSING").
store_holds() {
    python3 - "$SCRATCH_STORE" "$1" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
r = d.get(sys.argv[2])
if r is None:
    print("MISSING"); sys.exit(0)
print(json.dumps(r.get("holds") or []))
PYEOF
}

echo ""
echo "  T539 regression: holds= gets a writer, --sync reconciles, vacuous case is loud"

# ── Arm 1: seeded writer — single-file holds from the bundle header ────────
echo "    1. add from bundle holds=a.zig stores [\"a.zig\"]"
write_bundle T539W1 w1 'set=A holds=a.zig'
mg add T539W1 >/dev/null 2>&1 || { echo "       FAIL: add T539W1 exited non-zero"; FAIL=1; }
if [ "$(store_holds T539W1)" = '["a.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\"]"
else
    echo "       FAIL: store holds == $(store_holds T539W1), expected [\"a.zig\"]"
    FAIL=1
fi

# ── Arm 2: seeded writer — comma-separated holds split into elements ───────
echo "    2. add from bundle holds=a.zig,b.zig stores TWO elements (comma-split)"
write_bundle T539W2 w2 'set=A holds=a.zig,b.zig'
mg add T539W2 >/dev/null 2>&1 || { echo "       FAIL: add T539W2 exited non-zero"; FAIL=1; }
H2="$(store_holds T539W2)"
if [ "$H2" = '["a.zig", "b.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\", \"b.zig\"] (two elements, not one \"a.zig,b.zig\")"
else
    echo "       FAIL: store holds == $H2, expected two elements [\"a.zig\", \"b.zig\"]"
    FAIL=1
fi

# ── Arm 3: seeded writer — explicit --holds flag on a no-holds bundle ──────
echo "    3. add --holds x.sh,y.sh on a no-holds bundle stores [\"x.sh\",\"y.sh\"]"
write_bundle T539W3 w3 'set=A'
mg add T539W3 --holds x.sh,y.sh >/dev/null 2>&1 || { echo "       FAIL: add T539W3 exited non-zero"; FAIL=1; }
H3="$(store_holds T539W3)"
if [ "$H3" = '["x.sh", "y.sh"]' ]; then
    echo "       PASS: store holds == [\"x.sh\", \"y.sh\"]"
else
    echo "       FAIL: store holds == $H3, expected [\"x.sh\", \"y.sh\"]"
    FAIL=1
fi

# ── Arm 4: seeded conflict — vacuous case refuses and names the holder ─────
echo "    4. claim whose store holds is empty but bundle declares a held file is REFUSED"
write_bundle T539HOLDER holder 'set=A holds=src/held.zig'
write_bundle T539CAND cand 'set=A holds=src/held.zig'
mg add T539HOLDER >/dev/null 2>&1
mg add T539CAND >/dev/null 2>&1
mg claim T539HOLDER --agent deepseek-v4-pro >/dev/null 2>&1 || { echo "       FAIL: claim T539HOLDER exited non-zero"; FAIL=1; }
# Simulate the historical registration gap: the candidate's store holds is
# empty even though its bundle declares src/held.zig.
python3 - "$SCRATCH_STORE" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["T539CAND"]["holds"] = []
d["T539CAND"]["status"] = "dispatchable"
json.dump(d, open(p, "w"), indent=2)
PYEOF
CLAIM4_OUT="$(mg claim T539CAND --agent deepseek-v4-flash 2>&1 || true)"
CLAIM4_RC=0; mg claim T539CAND --agent deepseek-v4-flash >/dev/null 2>&1 && CLAIM4_RC=0 || CLAIM4_RC=$?
if echo "$CLAIM4_OUT" | grep -q 'REJECTED: holds conflict on file'; then
    echo "       PASS: claim refused on holds conflict"
else
    echo "       FAIL: claim was not refused; output:"
    printf '%s\n' "$CLAIM4_OUT" | sed 's/^/             | /'
    FAIL=1
fi
if echo "$CLAIM4_OUT" | grep -q 'T539HOLDER'; then
    echo "       PASS: rejection named the holder T539HOLDER"
else
    echo "       FAIL: rejection did not name the holder T539HOLDER"
    FAIL=1
fi
if echo "$CLAIM4_OUT" | grep -q 'declares holds in its bundle but the store row has none'; then
    echo "       PASS: stderr warned about the registration gap (vacuous case is loud)"
else
    echo "       FAIL: no registration-gap warning on stderr"
    FAIL=1
fi
if [ "$CLAIM4_RC" -ne 0 ]; then
    echo "       PASS: claim exit code non-zero ($CLAIM4_RC)"
else
    echo "       FAIL: claim exit code 0 on a refused claim"
    FAIL=1
fi

# ── Arm 5: null conflict — non-conflicting claim succeeds ─────────────────
echo "    5. claim declaring b.zig succeeds (mechanism does not brake non-conflicting work)"
write_bundle T539NULL null 'set=A holds=src/other.zig'
mg add T539NULL >/dev/null 2>&1
CLAIM5_OUT="$(mg claim T539NULL --agent deepseek-v4-flash 2>&1 || true)"
if echo "$CLAIM5_OUT" | grep -q 'claimed T539NULL'; then
    echo "       PASS: non-conflicting claim succeeded"
else
    echo "       FAIL: non-conflicting claim did not succeed; output:"
    printf '%s\n' "$CLAIM5_OUT" | sed 's/^/             | /'
    FAIL=1
fi
if echo "$CLAIM5_OUT" | grep -q 'REJECTED'; then
    echo "       FAIL: non-conflicting claim was rejected (over-braking)"
    FAIL=1
else
    echo "       PASS: no rejection for the non-conflicting claim"
fi

# ── Arm 6: seeded sync — two stale rows filled, diff printed, idempotent ──
echo "    6. holds --sync fills two stale rows, prints the diff, and is idempotent"
write_bundle T539S1 s1 'set=A holds=tools/one.sh'
write_bundle T539S2 s2 'set=A holds=tools/two.sh,tools/three.sh'
mg add T539S1 >/dev/null 2>&1
mg add T539S2 >/dev/null 2>&1
# Make both stale: bundle declares holds, store has none.
python3 - "$SCRATCH_STORE" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["T539S1"]["holds"] = []
d["T539S2"]["holds"] = []
json.dump(d, open(p, "w"), indent=2)
PYEOF
SYNC1="$(mg holds --sync 2>/dev/null || true)"
echo "       sync run 1 (stdout):"
printf '%s\n' "$SYNC1" | sed 's/^/             | /'
if [ "$(store_holds T539S1)" = '["tools/one.sh"]' ]; then
    echo "       PASS: T539S1 filled from its bundle"
else
    echo "       FAIL: T539S1 holds == $(store_holds T539S1), expected [\"tools/one.sh\"]"
    FAIL=1
fi
if [ "$(store_holds T539S2)" = '["tools/two.sh", "tools/three.sh"]' ]; then
    echo "       PASS: T539S2 filled (comma-split) from its bundle"
else
    echo "       FAIL: T539S2 holds == $(store_holds T539S2), expected [\"tools/two.sh\", \"tools/three.sh\"]"
    FAIL=1
fi
if echo "$SYNC1" | grep -q 'T539S1 \[\] -> \[tools/one.sh\]'; then
    echo "       PASS: diff for T539S1 printed to stdout"
else
    echo "       FAIL: no diff line for T539S1 on stdout"
    FAIL=1
fi
SYNC2="$(mg holds --sync 2>/dev/null || true)"
if echo "$SYNC2" | grep -q '0 updated'; then
    echo "       PASS: second sync is a no-op (0 updated, idempotent)"
else
    echo "       FAIL: second sync not idempotent; summary:"
    printf '%s\n' "$SYNC2" | sed 's/^/             | /'
    FAIL=1
fi

# ── Arm 7: null no-holds — a bundle with no holds= stays [] and add exits 0 ─
echo "    7. bundle with no holds= leaves the store row [] and add exits 0"
write_bundle T539NOB nob 'set=A'
mg add T539NOB >/dev/null 2>&1 || { echo "       FAIL: add T539NOB exited non-zero"; FAIL=1; }
if [ "$(store_holds T539NOB)" = '[]' ]; then
    echo "       PASS: store holds == [] for a no-holds bundle"
else
    echo "       FAIL: store holds == $(store_holds T539NOB), expected []"
    FAIL=1
fi

# ── Arm 8: dispatch warning — vacuous case is loud at dispatch too ────────
echo "    8. dispatch of a bundle-declared-holds / empty-store row warns on stderr"
write_bundle T539DISP disp 'set=A holds=tools/disp.sh'
mg add T539DISP >/dev/null 2>&1
python3 - "$SCRATCH_STORE" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["T539DISP"]["holds"] = []
json.dump(d, open(p, "w"), indent=2)
PYEOF
DISP_OUT="$(mg dispatch T539DISP --to deepseek-v4-flash 2>&1 || true)"
if echo "$DISP_OUT" | grep -q 'declares holds in its bundle but the store row has none'; then
    echo "       PASS: dispatch warned about the registration gap on stderr"
else
    echo "       FAIL: dispatch did not warn; output:"
    printf '%s\n' "$DISP_OUT" | sed 's/^/             | /'
    FAIL=1
fi
if echo "$DISP_OUT" | grep -q 'tools/disp.sh'; then
    echo "       PASS: dispatch warning named the declared file"
else
    echo "       FAIL: dispatch warning did not name the declared file"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T539: ALL CHECKS PASS"
else
    echo "  T539: SOME CHECKS FAILED"
fi
exit "$FAIL"
