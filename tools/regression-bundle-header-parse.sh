#!/usr/bin/env bash
# regression-bundle-header-parse.sh
# T880 regression: a bundle header's list-valued keys (holds=, needs=,
# deliverables=) accept space-separated values as fully as comma-separated
# ones, and the registration confirmation line names every hold that landed.
#
# The defect (T880, measured by the seat): parseBundleMeta tokenizes the
# header on spaces, so `holds=a.zig b.zig c.zig` registered only a.zig —
# two files silently dropped, no warning — while the confirmation line
# printed `holds a.zig` whether one hold or three landed.  T872 (green-up
# delete wave) declared four holds (space-separated) and its store row
# carries ZERO; T877 lost two of three.  The one-writer guard protected
# nothing it claimed to.
#
# Must be RED against the pre-T880 binary: space-separated holds truncated
# to the first element, the confirmation line lied, and a conflicting claim
# on a NON-FIRST held file was not refused (the store held one path of
# three, so the guard could not see the conflict).
#
# Arms (all against a scratch MANAGENT_STORE outside a fake repo_root):
#   1. space-separated  holds=a.zig b.zig c.zig  stores all THREE elements
#   2. comma-separated  holds=a.zig,b.zig,c.zig   still stores all THREE (guard)
#   3. mixed            holds=a.zig,b.zig c.zig   stores all THREE
#   4. the registration confirmation names every hold AND the count
#   5. null: one hold reports `holds 1 (a.zig)` — never an empty list as a path
#   6. null: no holds= leaves [] and the confirmation carries no holds mention
#   7. round-trip: a row declared 3 holds and is in_progress; a conflicting
#      claim on its SECOND held file is REFUSED, naming the holder (the
#      guard sees all three, not the first one only)
#   8. needs= space-separated stores every element (needs is a sibling
#      list-valued header field — same token loop, same defect)
#   9. needs= comma-separated still stores every element (guard)
#  10. a following header KEY (priority=N, waiting=1) is NOT absorbed as a
#      list item — the first sync run polluted 26 live rows with
#      "priority=99" holds before this was pinned (D022: priority lives in
#      the meta line, fleet-keeper reads it)
#  11. holds --sync fills a space-separated bundle's holds fully and is
#      idempotent (the T872 backfill shape)
#
# Usage:  tools/regression-bundle-header-parse.sh [--build]
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

# T445: /tmp/weizigo decays. Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent a suite's arms into the LIVE repo.
mkdir -p /tmp/weizigo
ROOT="$(mktemp -d /tmp/weizigo/bundle-header-parse-XXXXXX)" || { echo "regression-bundle-header-parse.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

REPO="$ROOT/repo"
SCRATCH="$ROOT/scratch"
mkdir -p "$REPO/untracked" "$SCRATCH/docs/infra/managent"
git init -q "$REPO"
git -C "$REPO" config user.email "t880@test"
git -C "$REPO" config user.name "T880"

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
    printf '<!--managent %s-->\n# %s — %s\n\n**Landmark:** none directly; unblocks T880 regression\n' "$meta" "$id" "$slug" > "$REPO/untracked/$id-$slug.md"
}

# store_list <id> <field> → the JSON array for a row (or the literal "MISSING").
store_list() {
    python3 - "$SCRATCH_STORE" "$1" "$2" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
r = d.get(sys.argv[2])
if r is None:
    print("MISSING"); sys.exit(0)
print(json.dumps(r.get(sys.argv[3]) or []))
PYEOF
}

echo ""
echo "  T880 regression: space-separated list headers parse fully, confirmation tells the truth"

# ── Arm 1: space-separated holds — ALL elements stored ─────────────────────
echo "    1. add from bundle holds=a.zig b.zig c.zig stores all THREE"
write_bundle T880S1 s1 'set=A type=infra holds=a.zig b.zig c.zig'
ADD1="$(mg add T880S1 2>&1)" || { echo "       FAIL: add T880S1 exited non-zero"; FAIL=1; }
H1="$(store_list T880S1 holds)"
if [ "$H1" = '["a.zig", "b.zig", "c.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\", \"b.zig\", \"c.zig\"]"
else
    echo "       FAIL: store holds == $H1, expected three elements (the space list was truncated to its first entry)"
    FAIL=1
fi

# ── Arm 2: comma-separated holds still work (regression guard) ────────────
echo "    2. add from bundle holds=a.zig,b.zig,c.zig stores all THREE (comma)"
write_bundle T880S2 s2 'set=A type=infra holds=a.zig,b.zig,c.zig'
ADD2="$(mg add T880S2 2>&1)" || { echo "       FAIL: add T880S2 exited non-zero"; FAIL=1; }
H2="$(store_list T880S2 holds)"
if [ "$H2" = '["a.zig", "b.zig", "c.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\", \"b.zig\", \"c.zig\"]"
else
    echo "       FAIL: store holds == $H2, expected three elements"
    FAIL=1
fi

# ── Arm 3: mixed separators ───────────────────────────────────────────────
echo "    3. add from bundle holds=a.zig,b.zig c.zig stores all THREE (mixed)"
write_bundle T880S3 s3 'set=A type=infra holds=a.zig,b.zig c.zig'
mg add T880S3 >/dev/null 2>&1 || { echo "       FAIL: add T880S3 exited non-zero"; FAIL=1; }
H3="$(store_list T880S3 holds)"
if [ "$H3" = '["a.zig", "b.zig", "c.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\", \"b.zig\", \"c.zig\"]"
else
    echo "       FAIL: store holds == $H3, expected three elements"
    FAIL=1
fi

# ── Arm 4: the confirmation line names every hold and the count ───────────
echo "    4. registration confirmation names every hold AND the count"
if printf '%s' "$ADD1" | grep -Fq 'registered T880S1  [set: A, holds 3 (a.zig, b.zig, c.zig)]'; then
    echo "       PASS: T880S1 confirmation names all three + count"
else
    echo "       FAIL: T880S1 confirmation does not name all three; got:"
    printf '%s\n' "$ADD1" | grep 'registered' | sed 's/^/             | /'
    FAIL=1
fi
if printf '%s' "$ADD2" | grep -Fq 'registered T880S2  [set: A, holds 3 (a.zig, b.zig, c.zig)]'; then
    echo "       PASS: T880S2 confirmation names all three + count"
else
    echo "       FAIL: T880S2 confirmation does not name all three; got:"
    printf '%s\n' "$ADD2" | grep 'registered' | sed 's/^/             | /'
    FAIL=1
fi

# ── Arm 5: null — one hold reports one ────────────────────────────────────
echo "    5. add from bundle holds=a.zig reports holds 1 (a.zig)"
write_bundle T880N1 n1 'set=A type=infra holds=a.zig'
ADD5="$(mg add T880N1 2>&1)" || { echo "       FAIL: add T880N1 exited non-zero"; FAIL=1; }
if [ "$(store_list T880N1 holds)" = '["a.zig"]' ]; then
    echo "       PASS: store holds == [\"a.zig\"]"
else
    echo "       FAIL: store holds == $(store_list T880N1 holds), expected [\"a.zig\"]"
    FAIL=1
fi
if printf '%s' "$ADD5" | grep -Fq 'registered T880N1  [set: A, holds 1 (a.zig)]'; then
    echo "       PASS: confirmation reports one hold"
else
    echo "       FAIL: confirmation for the one-hold case wrong; got:"
    printf '%s\n' "$ADD5" | grep 'registered' | sed 's/^/             | /'
    FAIL=1
fi

# ── Arm 6: null — no holds= leaves [] and never an empty-list path ────────
echo "    6. bundle with no holds= leaves [] and the confirmation has no holds mention"
write_bundle T880N2 n2 'set=A type=infra'
ADD6="$(mg add T880N2 2>&1)" || { echo "       FAIL: add T880N2 exited non-zero"; FAIL=1; }
if [ "$(store_list T880N2 holds)" = '[]' ]; then
    echo "       PASS: store holds == []"
else
    echo "       FAIL: store holds == $(store_list T880N2 holds), expected []"
    FAIL=1
fi
if printf '%s' "$ADD6" | grep -q 'holds'; then
    echo "       FAIL: confirmation mentions holds for a no-holds bundle:"
    printf '%s\n' "$ADD6" | grep 'registered' | sed 's/^/             | /'
    FAIL=1
else
    echo "       PASS: confirmation carries no holds mention for a no-holds bundle"
fi

# ── Arm 7: round-trip — the one-writer guard sees ALL three holds ─────────
echo "    7. round-trip: claim conflicting with the SECOND of three held files is REFUSED"
write_bundle T880H h 'set=A type=infra holds=src/held1.zig src/held2.zig src/held3.zig'
mg add T880H >/dev/null 2>&1 || { echo "       FAIL: add T880H exited non-zero"; FAIL=1; }
H7="$(store_list T880H holds)"
if [ "$H7" = '["src/held1.zig", "src/held2.zig", "src/held3.zig"]' ]; then
    echo "       PASS: holder store holds all three (guard precondition)"
else
    echo "       FAIL: holder store holds == $H7, expected all three — the guard cannot see a conflict on held2/held3"
    FAIL=1
fi
mg claim T880H --agent deepseek-v4-pro >/dev/null 2>&1 || { echo "       FAIL: claim T880H exited non-zero"; FAIL=1; }
# Candidate conflicts on the holder's SECOND held file — the file the
# truncated store could not see.
write_bundle T880C c 'set=A type=infra holds=src/held2.zig'
mg add T880C >/dev/null 2>&1 || { echo "       FAIL: add T880C exited non-zero"; FAIL=1; }
CLAIM7_OUT="$(mg claim T880C --agent deepseek-v4-flash 2>&1 || true)"
CLAIM7_RC=0; mg claim T880C --agent deepseek-v4-flash >/dev/null 2>&1 && CLAIM7_RC=0 || CLAIM7_RC=$?
if echo "$CLAIM7_OUT" | grep -q 'REJECTED: holds conflict on file'; then
    echo "       PASS: conflicting claim refused on holds conflict"
else
    echo "       FAIL: conflicting claim was not refused; output:"
    printf '%s\n' "$CLAIM7_OUT" | sed 's/^/             | /'
    FAIL=1
fi
if echo "$CLAIM7_OUT" | grep -q 'T880H'; then
    echo "       PASS: rejection named the holder T880H"
else
    echo "       FAIL: rejection did not name the holder T880H"
    FAIL=1
fi
if [ "$CLAIM7_RC" -ne 0 ]; then
    echo "       PASS: refused claim exit code non-zero ($CLAIM7_RC)"
else
    echo "       FAIL: refused claim exited 0"
    FAIL=1
fi

# ── Arm 8: needs= space-separated stores every element ────────────────────
echo "    8. add from bundle needs=T880A1 T880A2 stores both needs"
write_bundle T880A1 a1 'set=A type=infra'
write_bundle T880A2 a2 'set=A type=infra'
mg add T880A1 >/dev/null 2>&1 || { echo "       FAIL: add T880A1 exited non-zero"; FAIL=1; }
mg add T880A2 >/dev/null 2>&1 || { echo "       FAIL: add T880A2 exited non-zero"; FAIL=1; }
write_bundle T880NE ne 'set=A type=infra needs=T880A1 T880A2'
mg add T880NE >/dev/null 2>&1 || { echo "       FAIL: add T880NE exited non-zero"; FAIL=1; }
NE="$(store_list T880NE needs)"
if [ "$NE" = '["T880A1", "T880A2"]' ]; then
    echo "       PASS: store needs == [\"T880A1\", \"T880A2\"]"
else
    echo "       FAIL: store needs == $NE, expected both (the space list was truncated to its first entry)"
    FAIL=1
fi

# ── Arm 9: needs= comma-separated still works (regression guard) ──────────
echo "    9. add from bundle needs=T880A1,T880A2 stores both needs (comma)"
write_bundle T880NC nc 'set=A type=infra needs=T880A1,T880A2'
mg add T880NC >/dev/null 2>&1 || { echo "       FAIL: add T880NC exited non-zero"; FAIL=1; }
NC="$(store_list T880NC needs)"
if [ "$NC" = '["T880A1", "T880A2"]' ]; then
    echo "       PASS: store needs == [\"T880A1\", \"T880A2\"]"
else
    echo "       FAIL: store needs == $NC, expected both"
    FAIL=1
fi

# ── Arm 10: a following header KEY is not absorbed as a list item ──────────
# priority=N / waiting=1 / acceptance=… are header keys (D022, fleet-keeper
# reads priority from the meta line), never held files.  The first sync run
# polluted 26 live rows with "priority=99" holds before this was pinned.
echo "    10. holds=tools/one.sh priority=99 stores ONE hold (the key is not absorbed)"
write_bundle T880P1 p1 'set=A type=infra holds=tools/one.sh priority=99'
ADD10="$(mg add T880P1 2>&1)" || { echo "       FAIL: add T880P1 exited non-zero"; FAIL=1; }
H10="$(store_list T880P1 holds)"
if [ "$H10" = '["tools/one.sh"]' ]; then
    echo "       PASS: store holds == [\"tools/one.sh\"] (priority=99 not absorbed)"
else
    echo "       FAIL: store holds == $H10, expected [\"tools/one.sh\"] — a header key leaked into holds"
    FAIL=1
fi
if printf '%s' "$ADD10" | grep -Fq 'registered T880P1  [set: A, holds 1 (tools/one.sh)]'; then
    echo "       PASS: confirmation reports one hold"
else
    echo "       FAIL: confirmation wrong; got:"
    printf '%s\n' "$ADD10" | grep 'registered' | sed 's/^/             | /'
    FAIL=1
fi

# ── Arm 11: holds --sync fills space-separated holds and is idempotent ────
echo "    11. holds --sync fills a space-separated bundle's holds; second run no-op"
write_bundle T880SY1 sy1 'set=A type=infra holds=tools/s1.sh tools/s2.sh tools/s3.sh'
mg add T880SY1 >/dev/null 2>&1 || { echo "       FAIL: add T880SY1 exited non-zero"; FAIL=1; }
# make it stale: store holds emptied (the T872 shape: declared, not stored)
python3 - "$SCRATCH_STORE" <<'PYEOF'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["T880SY1"]["holds"] = []
json.dump(d, open(p, "w"), indent=2)
PYEOF
SYNC1="$(mg holds --sync 2>/dev/null || true)"
if [ "$(store_list T880SY1 holds)" = '["tools/s1.sh", "tools/s2.sh", "tools/s3.sh"]' ]; then
    echo "       PASS: sync filled all three from the space-separated bundle"
else
    echo "       FAIL: sync left store holds == $(store_list T880SY1 holds), expected all three"
    FAIL=1
fi
if echo "$SYNC1" | grep -q 'T880SY1 \[\] -> \[tools/s1.sh,tools/s2.sh,tools/s3.sh\]'; then
    echo "       PASS: sync diff printed the full fill"
else
    echo "       FAIL: no diff line for T880SY1; output:"
    printf '%s\n' "$SYNC1" | sed 's/^/             | /'
    FAIL=1
fi
SYNC2="$(mg holds --sync 2>/dev/null || true)"
if echo "$SYNC2" | grep -q '0 updated'; then
    echo "       PASS: second sync is a no-op (idempotent)"
else
    echo "       FAIL: second sync not idempotent; summary:"
    printf '%s\n' "$SYNC2" | sed 's/^/             | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T880: ALL CHECKS PASS"
else
    echo "  T880: SOME CHECKS FAILED"
fi
exit "$FAIL"
