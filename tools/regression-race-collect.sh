#!/bin/sh
# regression-race-collect.sh — controls for tools/race-collect.py, the
# mechanical collection+blinding instrument of race-protocol-v2 (T779).
#
# The protocol (docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-protocol-v2.md)
# rules 2-3: lanes write only their own untracked/race-*/lane-<id>/ dir, never
# commit, and attribution lives in the sidecar manifest, never inside the
# artifact; a script (not a model) gathers outputs under content-hash names.
# These controls pin the collector's contract:
#
#   SELF-ATTRIBUTION seeded   an artifact containing a model label/family
#                             (e.g. "I am Claude") -> exit 1, lane named in
#                             the compliance report, NO blind set emitted.
#   GIT-COMMIT      seeded    a lane dir tracked in git -> exit 1, lane named,
#                             NO blind set emitted.
#   null            clean     untracked clean lanes in a scratch git repo ->
#                             exit 0, blind set emitted under content-hash
#                             names, stdout carries ONLY hash names (never the
#                             lane ids), manifest sealed, report clean, blind
#                             file bytes byte-identical to the artifact.
#   MISSING-ARTIFACT         a lane dir with no artifact -> excluded + noted,
#                             remaining lanes still blinded, exit 0.
#   manifest seal            a second collection over the same blind dir
#                             refuses (exit 2) rather than silently re-mapping.
#
# No real model is ever dispatched and no real repo state is touched: every
# fixture lives in scratch dirs under /tmp/weizigo; the only scratch git
# repos are created there.  The live tree is read-only (the collector binary
# and nothing else).
#
# Task: T779 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
COLLECT="$ROOT/tools/race-collect.py"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t779-race-collect-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

say()  { printf 'race-collect-regression: %s\n' "$*"; }
fail() { say "FAIL: $*"; FAIL=1; }
pass() { say "pass: $*"; }

# make_lane <race-root> <lane-id> <contents> — writes lane-<id>/out.md
make_lane() {
    rr="$1"; id="$2"; body="$3"
    mkdir -p "$rr/lane-$id"
    printf '%s' "$body" > "$rr/lane-$id/out.md"
}

# ── ARM 1 — seeded SELF-ATTRIBUTION (red) ───────────────────────────────
say "ARM 1: seeded self-attribution must be caught"
R1="$WORK/r1"
mkdir -p "$R1"
make_lane "$R1" a "The glossary entry reads clean prose."
make_lane "$R1" b "I am Claude, and my rewrite of section B is below."
"$COLLECT" "$R1" > "$R1/stdout" 2> "$R1/stderr"
rc=$?
if [ "$rc" -eq 0 ]; then
    fail "ARM 1: seeded artifact carrying a model name was NOT caught (exit 0)"
elif [ "$rc" -ne 1 ]; then
    fail "ARM 1: expected exit 1 on a blinding breach, got $rc"
else
    pass "ARM 1: exit 1 on seeded self-attribution"
fi
if [ ! -f "$R1/collect-report.json" ]; then
    fail "ARM 1: no compliance report written on refusal"
elif ! grep -q "lane-b" "$R1/collect-report.json"; then
    fail "ARM 1: compliance report does not name the breaching lane"
elif ! grep -q "SELF-ATTRIBUTION" "$R1/collect-report.json"; then
    fail "ARM 1: compliance report does not name the breach class"
else
    pass "ARM 1: compliance report names lane-b + SELF-ATTRIBUTION"
fi
if [ -d "$R1/blind" ] && [ -n "$(ls -A "$R1/blind" 2>/dev/null)" ]; then
    fail "ARM 1: blind set was emitted despite the breach"
else
    pass "ARM 1: blind set NOT emitted on refusal"
fi
if [ -s "$R1/stdout" ]; then
    fail "ARM 1: stdout must be empty on refusal (a leaked set is worse than none)"
else
    pass "ARM 1: stdout empty on refusal"
fi

# ── ARM 2 — null run over clean fixtures (green) ────────────────────────
say "ARM 2: null run over clean fixtures passes silently"
R2="$WORK/r2"
git init -q "$R2" || { fail "ARM 2: scratch git init failed"; exit 2; }
(cd "$R2" && git config user.email test@example.invalid && git config user.name "race-collect regression"
 echo "scratch repo for the race-collect null arm" > README.md
 git add README.md && git commit -qm init)
make_lane "$R2" a "A clean glossary entry, no identity anywhere."
make_lane "$R2" b "A second clean rewrite with a worked example."
"$COLLECT" "$R2" > "$R2/stdout" 2> "$R2/stderr"
rc=$?
if [ "$rc" -ne 0 ]; then
    fail "ARM 2: null run expected exit 0, got $rc ($(cat "$R2/stderr"))"
else
    pass "ARM 2: null run exit 0"
fi
blind_count=0
[ -d "$R2/blind" ] && blind_count=$(ls -A "$R2/blind" | grep -v '^manifest.json$' | wc -l | tr -d ' ')
if [ "$blind_count" -ne 2 ]; then
    fail "ARM 2: expected 2 blind files, found $blind_count"
else
    pass "ARM 2: 2 blind files emitted"
fi
for f in "$R2"/blind/*.md; do
    case "$(basename "$f")" in
        [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f].md) : ;;
        *) fail "ARM 2: blind file name '$f' is not a content hash" ;;
    esac
done
if grep -q "lane-a\|lane-b" "$R2/stdout"; then
    fail "ARM 2: stdout leaks lane ids to the judge"
else
    pass "ARM 2: stdout carries only hash names"
fi
[ "$(wc -l < "$R2/stdout")" -eq 2 ] || fail "ARM 2: expected 2 stdout lines, got $(wc -l < "$R2/stdout")"
if [ ! -f "$R2/blind/manifest.json" ]; then
    fail "ARM 2: no sidecar manifest written"
else
    pass "ARM 2: sidecar manifest present"
fi
# manifest maps exactly the two lanes, blind names are content hashes
if python3 -c '
import json, sys, glob
m = json.load(open(sys.argv[1] + "/blind/manifest.json"))
lanes = m["lanes"]
assert set(lanes.values()) == {"lane-a", "lane-b"}, lanes
assert set(lanes) == set(f.split("/")[-1] for f in glob.glob(sys.argv[1] + "/blind/*.md")), lanes
assert "manifest_sha256" in m and len(m["manifest_sha256"]) == 64
print("ok")
' "$R2" > /dev/null 2>&1; then
    pass "ARM 2: manifest maps both lanes to hash names and is self-sealed"
else
    fail "ARM 2: manifest content wrong"
fi
# byte-identical copy: every blind file re-hashes to its own name
if python3 -c '
import glob, hashlib, os, sys
ok = True
for f in glob.glob(sys.argv[1] + "/blind/*.md"):
    h = hashlib.sha256(open(f, "rb").read()).hexdigest()[:16]
    if os.path.basename(f) != h + ".md":
        ok = False
sys.exit(0 if ok else 1)
' "$R2"; then
    pass "ARM 2: blind files are byte-identical copies (name == content hash)"
else
    fail "ARM 2: blind file content does not match its hash name"
fi
if python3 -c '
import json, sys
r = json.load(open(sys.argv[1] + "/collect-report.json"))
assert r["breach_count"] == 0, r
assert all(not e["breaches"] for e in r["lanes"]), r["lanes"]
assert r["blind_set_emitted"] is True
print("ok")
' "$R2" > /dev/null 2>&1; then
    pass "ARM 2: null report clean"
else
    fail "ARM 2: null report flags a breach"
fi

# ── ARM 3 — a lane dir that committed to git (red) ──────────────────────
say "ARM 3: a lane that committed to git must be flagged as a compliance breach"
R3="$WORK/r3"
git init -q "$R3" || { fail "ARM 3: scratch git init failed"; exit 2; }
(cd "$R3" && git config user.email test@example.invalid && git config user.name "race-collect regression"
 echo "scratch repo for the git-commit arm" > README.md
 git add README.md && git commit -qm init)
make_lane "$R3" a "A clean artifact that nevertheless got committed."
(cd "$R3" && git add lane-a/out.md && git commit -qm "lane-a violates the do-not-commit rule")
"$COLLECT" "$R3" > "$R3/stdout" 2> "$R3/stderr"
rc=$?
if [ "$rc" -ne 1 ]; then
    fail "ARM 3: committed lane expected exit 1, got $rc"
else
    pass "ARM 3: exit 1 on a lane that committed to git"
fi
if [ ! -f "$R3/collect-report.json" ] || ! grep -q "lane-a" "$R3/collect-report.json" || ! grep -q "GIT-COMMIT" "$R3/collect-report.json"; then
    fail "ARM 3: compliance report does not name lane-a / GIT-COMMIT"
else
    pass "ARM 3: compliance report names lane-a + GIT-COMMIT"
fi
if [ -d "$R3/blind" ] && [ -n "$(ls -A "$R3/blind" 2>/dev/null)" ]; then
    fail "ARM 3: blind set was emitted despite the git breach"
else
    pass "ARM 3: blind set NOT emitted on git breach"
fi

# ── ARM 4 — missing artifact: excluded + noted, rest blinded (green) ────
say "ARM 4: a lane with no artifact is excluded and noted, the rest blind"
R4="$WORK/r4"
mkdir -p "$R4/lane-a" "$R4/lane-b"
printf '%s' "Only lane a produced output." > "$R4/lane-a/out.md"
# lane-b dir exists with no artifact
"$COLLECT" "$R4" > "$R4/stdout" 2> "$R4/stderr"
rc=$?
if [ "$rc" -ne 0 ]; then
    fail "ARM 4: expected exit 0 with a missing-artifact lane, got $rc"
else
    pass "ARM 4: exit 0 with a missing-artifact lane"
fi
if ! grep -q "MISSING-ARTIFACT" "$R4/collect-report.json"; then
    fail "ARM 4: report does not note the missing artifact"
else
    pass "ARM 4: missing artifact recorded in report"
fi
[ "$(wc -l < "$R4/stdout")" -eq 1 ] || fail "ARM 4: expected exactly 1 blind file (lane-a only)"
if grep -q "lane-b" "$R4/stdout"; then
    fail "ARM 4: missing-artifact lane leaked to stdout"
else
    pass "ARM 4: only the present lane blinded"
fi

# ── ARM 5 — manifest seal: a second collection refuses (green) ──────────
say "ARM 5: a second collection over a sealed blind dir refuses"
R5="$WORK/r5"
mkdir -p "$R5"
make_lane "$R5" a "First collection content."
"$COLLECT" "$R5" > /dev/null 2> "$R5/stderr1"
rc1=$?
make_lane "$R5" a "CHANGED content would re-map the judge's set."
"$COLLECT" "$R5" > /dev/null 2> "$R5/stderr2"
rc2=$?
if [ "$rc1" -ne 0 ]; then
    fail "ARM 5: first collection expected exit 0, got $rc1"
elif [ "$rc2" -ne 2 ]; then
    fail "ARM 5: re-collection over a sealed blind dir expected exit 2, got $rc2"
else
    pass "ARM 5: sealed manifest refuses re-collection"
fi

# ── ARM 6 — lowercase algorithm terms must NOT trip (green) ───────────
# G4 case discipline: lowercase "minimax" (the Go search algorithm) and
# "glm" are not model-family mentions in this project's prose.
# (G3-1) A clean artifact may say "the minimax search" or "glm" freely.
# (G3-2) "as a DeepSeek model" is a first-person attribution and IS caught.
say "ARM 6: lowercase algorithm terms are not self-attribution; first-person attribution is"
R6="$WORK/r6"
mkdir -p "$R6"
make_lane "$R6" a "The minimax search on a 4x4 goban and the glm layers both stay out of scope."
make_lane "$R6" b "As a DeepSeek model, I wrote the verdict section below."
"$COLLECT" "$R6" > "$R6/stdout" 2> "$R6/stderr"
rc=$?
if [ "$rc" -ne 1 ]; then
    fail "ARM 6: expected exit 1 (lane-b self-attribution), got $rc"
else
    pass "ARM 6: exit 1"
fi
if grep -q "lane-a" "$R6/collect-report.json" && ! grep -q "SELF-ATTRIBUTION" "$R6/collect-report.json"; then
    fail "ARM 6: lowercase minimax/glm must not trip the detector"
else
    pass "ARM 6: lowercase minimax/glm not flagged"
fi
if grep -q "lane-b" "$R6/collect-report.json" && grep -q "SELF-ATTRIBUTION" "$R6/collect-report.json"; then
    pass "ARM 6: first-person attribution caught"
else
    fail "ARM 6: first-person attribution not caught"
fi

# ── summary ─────────────────────────────────────────────────────────────
say "---"
if [ "$FAIL" -eq 0 ]; then
    say "ALL ARMS PASS"
else
    say "ARMS FAILED"
fi
exit "$FAIL"
