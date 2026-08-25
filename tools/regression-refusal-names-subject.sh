#!/usr/bin/env bash
# regression-refusal-names-subject.sh — T953: a failure must name its cause
#
# The rule under test (T953, 2026-08-25): **a failure names its cause and,
# where one exists, the action that fixes it.** Every arm below seeds the
# REAL failure from the T953 table and asserts the output carries the cause
# — and, per arm, the concrete action string. Per NOTE 7 of the round-1
# audit, what counts as "cause" and "action" is defined per arm HERE, as the
# grep targets below, so the test cannot pass on a paraphrase.
#
# Arms (one per table row of the T953 brief):
#
#   A1  pop-next dispatch refusal (row 1; fix already landed — control).
#       cause:  "dispatch REFUSED <task>" + "full message follows:" + every
#               line of the gate's refusal (title text, char count, limit,
#               the "brief's body" line).
#       action: (none asserted — the gate's own "Shorten it" rides inside
#               the full refusal; the defect was its DISCARD, not its wording)
#       Seeded defect: a scratch copy of pop-next.sh with the fix reverted
#       (`| tail -1`) must FAIL the assertions — the red half.
#
#   A2  regression-ollama-dispatcher.sh control 4 (row 2).
#       cause:  "SKIP: control 4 — host has <N> MB committed; control 4
#               needs a quiet fleet" (the arbiter's committed figure, from
#               its own refusal line).
#       action: "Re-run this suite when the fleet is quiet."
#       Seeded world: a scratch arbiter ledger with a 65536 MB admitted
#       entry forces the refusal on ANY host — deterministic red.
#       Null world: an empty ledger — control 4 must PASS (or SKIP with the
#               named cause on an extremely busy host); a bare
#               "FAIL: ... exit code 1" is never acceptable.
#
#   A3  claimlint C2 (row 3).
#       cause:  the missing path itself, in the C2 detail section
#               (already there) + the action line (the defect).
#       action: "action (any one of): commit the missing file" ...
#               "Then re-run claimlint."
#       Seeded: one committed dangling evidence path + one freshly staged
#               /tmp citation — the exact shape behind the
#               "summary says 1, detail says (none)" hunt: the C2 summary
#               count folds in C10-NEW, and the reader must be told so.
#       Null: a clean register — "(none)", no action line, no C10-NEW note.
#
#   A4  S09 contract: declared-and-absent (row 4; the D3 rule).
#       cause:  "declared and absent: tools/regression-t953-ghost.sh" +
#               "declared in <contract>" — a contract-level refusal, not an
#               opaque red name, not a baselined KNOWN RED (the contract
#               carries a known-red line for the ghost on purpose: the old
#               gate would have treated the deletion as non-blocking).
#       action: "Restore the script" + "remove the declaration".
#       Null: every declared script present — the hook completes, exit 0,
#               no "declared and absent" anywhere.
#
#   A5  managent assign --exclude <unknown-token> (row 5; the D2 decision).
#       cause:  "names no family and no canonical model" + the token
#               verbatim.
#       action: "valid families: ..." listing every family_appetite name
#               (ollama-cloud among them — the token the fleet mistyped).
#       Null: a valid token (ollama-cloud) is accepted (rc 0, a draw made).
#       Seeded world: the CURRENT behaviour is the silent no-op — the arm
#       is red against the unpatched binary by construction.
#
#   A6  pop-next unspec window (row 6; fix already landed — control).
#       cause:  (the defect was a misclassification, not a message: a row
#               WITH acceptance= read as UNSPEC). The arm asserts the
#               row is read as specified: "WOULD dispatch <task>" and no
#               "UNSPEC" — with a >400-byte metadata line (the T954 shape:
#               acceptance= beyond byte 400 of the file).
#       Seeded defect: a scratch copy with the old `raw[:400]` logic must
#       print UNSPEC — the red half.
#
# All fixtures are synthetic and run in scratch repos under /tmp/weizigo —
# never the live kanban, never a live dispatch. Nothing here touches a
# tracked file (T445).
#
# Task: T953 · Worker: qwen3.8-27b/T953 · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/tools/lib/scratch-repo.sh"

FAIL=0
RED_EXPECTED_SHOWN=0

# The deployed binaries under test (honour *_BIN overrides, like the other
# regressions; --build rebuilds managent from source, ReleaseSafe).
CLAIMLINT="$ROOT/zig-out/bin/weizigo-claimlint"
[ -x "$CLAIMLINT" ] || CLAIMLINT="$ROOT/bin/weizigo-claimlint"
MG="${MANAGENT_BIN:-$ROOT/bin/managent}"

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$ROOT" && "$ROOT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$ROOT/tools/deploy.sh" "$ROOT/zig-out/bin/managent" "$ROOT/bin/managent"
    MG="$ROOT/bin/managent"
fi

# expect_red: run $3 (a snippet) with $1's assertions; it MUST fail.
# Usage: expect_red <label> <grep-target-must-be-absent-or-wrong> ...
# Simpler: each arm drives its own seeded-defect check inline.

scratch() { weizigo_scratch_repo "t953-$1" "W_$1"; }

# ── stub bin/dispatch for A1: the gate's full 3-line refusal ─────────────
# The title text is 54 chars — the count in the message must match, or the
# arm's "names the cause" assertion is a lie.
SEED_TITLE="this seeded title deliberately exceeds forty characters"
TITLE_LEN=${#SEED_TITLE}

make_dispatch_stub() { # $1 = dir
    # The gate's real message wraps the title in backticks. The stub is a
    # /bin/sh script, so those lines are double-quoted echoes with escaped
    # backticks (\`) — literals, not command substitution.
    python3 - "$1" "$SEED_TITLE" "$TITLE_LEN" > "$1/bin/dispatch" <<'PYSTUB'
import sys
d, title, n = sys.argv[1], sys.argv[2], sys.argv[3]
print("#!/bin/sh")
print('echo "dispatch: REFUSED \u2014 title \`%s\` is %s chars, over the 40-char limit (DELEGATOR.md \u00a7Task titles)."' % (title, n))
print('echo "  The title is a display surface, not a summary: a title that needs more than 40 chars is a sign the task is two tasks. Shorten it;"')
print('echo "  the long form goes in the brief\'s body."')
print("exit 1")
PYSTUB
    chmod +x "$1/bin/dispatch"
}

# ── stub bin/managent for A1/A6: reap + assign only ──────────────────────
make_managent_stub() { # $1 = dir
    cat > "$1/bin/managent" <<'EOF'
#!/bin/sh
case "$1" in
  reap) echo "orphans: 0" ;;
  assign) echo '{"id":"T9991","method":"stub","model":"stub-model","candidates":[],"reasons":[]}' ;;
esac
exit 0
EOF
    chmod +x "$1/bin/managent"
}

# ── a dispatchable store + queue row ─────────────────────────────────────
# $1 = dir, $2 = task id, $3 = bundle header line (the <!--managent ... -->)
seed_pop_store() {
    mkdir -p "$1/docs/infra/managent" "$1/docs/infra" "$1/untracked"
    cat > "$1/untracked/$2.md" <<EOF
$3
# $2 — scratch row
EOF
    python3 - "$1" "$2" <<'PY'
import json, sys
d, t = sys.argv[1], sys.argv[2]
store = {t: {
    "status": "dispatchable", "agent": None, "model": None,
    "bundle": f"untracked/{t}.md", "set": "A", "holds": [], "needs": [], "caps": [],
    "added": "2026-08-01T00:00:00Z", "claimed": None, "done": None,
    "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 0,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
}}
json.dump(store, open(f"{d}/docs/infra/managent/tasks.json", "w"), indent=1)
PY
    printf '%s\t1\tx\tAUTO\n' "$2" > "$1/docs/infra/dispatch-queue.tsv"
}

echo "=== T953: a failure must name its cause ==="

# ══ A1 — pop-next: a refused dispatch logs the WHOLE refusal + task id ══
echo "  A1. pop-next: a refused dispatch logs the whole refusal and the task id (fix already landed — control)"
scratch a1; W=$W_a1
mkdir -p "$W/tools" "$W/bin"
cp "$ROOT/tools/pop-next.sh" "$W/tools/pop-next.sh"
make_dispatch_stub "$W"
make_managent_stub "$W"
HDR1='<!--managent set=A deliverables=findings/T9991.json acceptance=sh tools/noop.sh-->'
seed_pop_store "$W" T9991 "$HDR1"
OUT1=$(cd "$W" && MAX_LANES=999 sh tools/pop-next.sh 2>&1); RC1=$?
if echo "$OUT1" | grep -q "dispatch REFUSED T9991" \
   && echo "$OUT1" | grep -q "full message follows:" \
   && echo "$OUT1" | grep -qF "$SEED_TITLE" \
   && echo "$OUT1" | grep -q "${TITLE_LEN} chars, over the 40-char limit" \
   && echo "$OUT1" | grep -q "the long form goes in the brief's body"; then
    echo "    PASS: the whole refusal reached the log with the task id (rc=$RC1)"
else
    echo "    FAIL: the refusal was not fully logged (rc=$RC1):"
    echo "$OUT1" | sed 's/^/    | /'
    FAIL=1
fi
# seeded defect: the pre-T953 fix — `| tail -1` discards the cause.
python3 - "$W/tools/pop-next.sh" <<'PY'
import sys, re
p = sys.argv[1]
s = open(p).read()
# revert the fix exactly: drop the whole-refusal branch, keep the old tail -1
fixed = '''  out=$(bin/dispatch "$pick" "$model" --wall=7200 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "$out" | tail -1
  else
    echo "pop-next: dispatch REFUSED $pick (rc=$rc) — full message follows:"
    echo "$out" | sed 's/^/  | /'
  fi'''
old = '''  out=$(bin/dispatch "$pick" "$model" --wall=7200 2>&1); rc=$?
  echo "$out" | tail -1'''
if fixed in s:
    open(p, "w").write(s.replace(fixed, old))
else:
    print("    SEED-ERROR: could not find the fixed block to revert in pop-next.sh", file=sys.stderr)
    sys.exit(3)
PY
if [ $? -ne 0 ]; then FAIL=1; fi
OUT1R=$(cd "$W" && MAX_LANES=999 sh tools/pop-next.sh 2>&1)
if echo "$OUT1R" | grep -q "the long form goes in the brief's body" \
   && ! echo "$OUT1R" | grep -q "${TITLE_LEN} chars, over the 40-char limit"; then
    echo "    PASS seeded: the reverted (tail -1) pop-next loses the cause — the arm discriminates"
    RED_EXPECTED_SHOWN=1
else
    echo "    FAIL seeded: the reverted pop-next still (or no longer) shows the cause — the arm cannot go red:"
    echo "$OUT1R" | sed 's/^/    | /'
    FAIL=1
fi
rm -rf "$W"

# ══ A6 — pop-next: a long metadata line is not UNSPEC (control) ═════════
echo "  A6. pop-next: a row with acceptance= beyond byte 400 reads as specified, not UNSPEC (fix already landed — control)"
scratch a6; W=$W_a6
mkdir -p "$W/tools" "$W/bin"
cp "$ROOT/tools/pop-next.sh" "$W/tools/pop-next.sh"
make_managent_stub "$W"
# Build the T954 shape: a metadata comment whose acceptance= sits past byte
# 400 of the file (ten holds + deliverables, like T954's 606-byte line).
HDR6=$(python3 - <<'PY'
# Grow the holds list until acceptance= sits beyond byte 400 — the T954 shape
# (ten holds + ten deliverables on one 606-byte line). The total length is
# not the point; the POSITION of acceptance= past the old 400-byte window is.
def hold_path(i): return f"src/module-group-{i:02d}/very-long-module-name.zig"
held, i = [], 0
while True:
    held.append(hold_path(i)); i += 1
    candidate = (f"<!--managent set=A holds={' '.join(held)} "
                 f"deliverables=findings/T9992.json "
                 f"acceptance=sh tools/regression-refusal-names-subject.sh-->")
    if candidate.index("acceptance=") > 400 or i > 50:
        break
assert candidate.index("acceptance=") > 400, "could not push acceptance= past byte 400"
import sys as _s
print("    (header is %d bytes; acceptance= at byte %d)" % (len(candidate), candidate.index("acceptance=")), file=_s.stderr)
print(candidate)
PY
)
seed_pop_store "$W" T9992 "$HDR6"
OUT6=$(cd "$W" && MAX_LANES=999 sh tools/pop-next.sh --dry-run 2>&1); RC6=$?
if echo "$OUT6" | grep -q "WOULD dispatch T9992" && ! echo "$OUT6" | grep -q "UNSPEC"; then
    echo "    PASS: the long-header row reads as specified (rc=$RC6)"
else
    echo "    FAIL: the long-header row was misread (rc=$RC6):"
    echo "$OUT6" | sed 's/^/    | /'
    FAIL=1
fi
# seeded defect: the pre-T953 fix — the 400-byte window.
python3 - "$W/tools/pop-next.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
fixed = """    head=''
    try:
        raw=open(b).read()
        m=re.search(r'<!--managent(.*?)-->', raw, re.S)
        head=m.group(1) if m else raw[:400]
    except Exception: head=''"""
old = """    head=''
    try:
        head=open(b).read()[:400]
    except Exception: head=''"""
if fixed in s:
    open(p, "w").write(s.replace(fixed, old))
else:
    print("    SEED-ERROR: could not find the fixed block to revert in pop-next.sh", file=sys.stderr)
    sys.exit(3)
PY
if [ $? -ne 0 ]; then FAIL=1; fi
OUT6R=$(cd "$W" && MAX_LANES=999 sh tools/pop-next.sh --dry-run 2>&1)
if echo "$OUT6R" | grep -q "UNSPEC" && ! echo "$OUT6R" | grep -q "WOULD dispatch T9992"; then
    echo "    PASS seeded: the 400-byte window reads the row as UNSPEC — the arm discriminates"
else
    echo "    FAIL seeded: the 400-byte window did not misread the row — the arm cannot go red:"
    echo "$OUT6R" | sed 's/^/    | /'
    FAIL=1
fi
rm -rf "$W"

# ══ A3 — claimlint C2: the detail names the path AND the action ═════════
echo "  A3. claimlint C2: a dangling path is named with an action, and the C10-NEW summary component is labelled"
if [ ! -x "$CLAIMLINT" ]; then
    echo "    SKIP: no weizigo-claimlint binary (build with 'zig build') — A3 needs it"
else
    scratch a3; W=$W_a3
    mkdir -p "$W/docs/evidence" "$W/docs/epistemic"
    # Two rows: one committed dangling evidence path (real C2), one freshly
    # staged /tmp citation (C10-NEW, folded into the C2 summary count).
    cat > "$W/docs/epistemic/CLAIMS.md" <<'EOF'
# scratch register — T953 A3 seeded

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
| `T953-A3-DANGLING` | — | all | seeded: a dangling citation for the T953 C2 arm. | CLAIMED | `docs/evidence/T953-A3-DANGLING/missing-probe-file.md` | — | — | 0 | ? | Z-AUDIT |
| `T953-A3-VOLATILE` | — | all | seeded: a fresh /tmp citation for the T953 C2-summary arm. | CLAIMED | `/tmp/weizigo/t953-a3-volatile-file.txt` | — | — | 0 | ? | Z-AUDIT |
EOF
    cd "$W" && git add -A >/dev/null 2>&1
    C2OUT=$(cd "$W" && "$CLAIMLINT" 2>&1)
    if echo "$C2OUT" | grep -q "C2 DEAD-LINKS  docs/evidence/T953-A3-DANGLING/missing-probe-file.md"; then
        echo "      (path named in the C2 detail)"
    else
        echo "    FAIL: the missing path is not named in the C2 detail:"
        echo "$C2OUT" | sed -n '/== C2/,/== C3/p' | sed 's/^/    | /'
        FAIL=1
    fi
    if echo "$C2OUT" | grep -q "action (any one of): commit the missing file" \
       && echo "$C2OUT" | grep -q "Then re-run claimlint"; then
        echo "      (action line present: cause AND action)"
    else
        echo "    FAIL: the C2 detail has no action line — the reader has a path but no remedy (the row-3 defect):"
        echo "$C2OUT" | sed -n '/missing paths/,/C2 DEAD-LINKS total/p' | sed 's/^/    | /'
        FAIL=1
    fi
    # the C2 summary folds in C10-NEW: with 1 real + 1 volatile, the count
    # is 2 — the reader must be told one of the two lives under C10-NEW.
    if echo "$C2OUT" | grep "C2 dangling evidence paths" | grep -q "listed under the C10-NEW section"; then
        echo "      (C2 summary labels its C10-NEW component — no phantom path to hunt)"
    else
        echo "    FAIL: the C2 summary count includes C10-NEW but does not say so — the 'summary says N, detail says (none)' hunt repeats:"
        echo "$C2OUT" | grep -E "C2 dangling|C10-NEW" | sed 's/^/    | /'
        FAIL=1
    fi
    # null: a clean register — no failure, no spurious action line or note.
    cat > "$W/docs/epistemic/CLAIMS.md" <<'EOF'
# scratch register — T953 A3 null

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
EOF
    cd "$W" && git add -A >/dev/null 2>&1
    C2OUTN=$(cd "$W" && "$CLAIMLINT" 2>&1)
    if ! echo "$C2OUTN" | grep -q "action (any one of): commit the missing file" \
       && ! echo "$C2OUTN" | grep "C2 dangling evidence paths" | grep -q "listed under the C10-NEW section"; then
        echo "    PASS: null — a clean register names no path, no action, no C10-NEW note"
    else
        echo "    FAIL: null — spurious naming on clean input:"
        echo "$C2OUTN" | grep -E "action \(any|C2 dangling" | sed 's/^/    | /'
        FAIL=1
    fi
    cd "$ROOT"
    rm -rf "$W"
fi

# ══ A2 — ollama-dispatcher control 4: a busy fleet is a named SKIP ══════
echo "  A2. regression-ollama-dispatcher control 4: arbiter refusal -> SKIP naming the committed MB, never a bare 'exit code 1'"
OLLAMA_REG="$ROOT/tools/regression-ollama-dispatcher.sh"
# Seeded world: a scratch ledger with one 65536 MB admitted entry forces the
# refusal on any host. (WEIZIGO_ARBITER_STATE_FILE is the runner's own
# inject-don't-exhaust test hook — this uses the gate's documented knob, not
# a re-implementation.)
scratch a2; W=$W_a2
python3 - "$W/arb-busy.json" <<'PY'
import json, sys, time
json.dump({"admitted": {"T953-A2-BUSY": {"ram_mb": 65536, "ts": time.time()}}}, open(sys.argv[1], "w"))
PY
OUT2B=$(WEIZIGO_ARBITER_STATE_FILE="$W/arb-busy.json" sh "$OLLAMA_REG" 2>&1); RC2B=$?
if echo "$OUT2B" | grep -q "SKIP: control 4 — host has" \
   && echo "$OUT2B" | grep -q "MB committed; control 4 needs a quiet fleet" \
   && echo "$OUT2B" | grep -q "Re-run this suite when the fleet is quiet." \
   && ! echo "$OUT2B" | grep -q "FAIL: ollama dispatch exit code"; then
    echo "    PASS: busy fleet -> control 4 SKIPs, naming the committed MB and the action (suite rc=$RC2B)"
else
    echo "    FAIL: busy fleet -> the cause was not named (suite rc=$RC2B):"
    echo "$OUT2B" | sed -n '/4\. qwen3.8/,/5\. depth-cap/p' | sed 's/^/    | /'
    FAIL=1
fi
# Null world: an empty ledger — control 4 must PASS, or SKIP with the named
# cause (an extremely busy host). A bare FAIL is the defect.
OUT2Q=$(WEIZIGO_ARBITER_STATE_FILE="$W/arb-quiet.json" sh "$OLLAMA_REG" 2>&1); RC2Q=$?
CTRL4_OK=0
if echo "$OUT2Q" | grep -q "PASS launch: ollama launch pi --model qwen3.8:27b-mlx"; then
    CTRL4_OK=1
elif echo "$OUT2Q" | grep -q "SKIP: control 4 — host has"; then
    CTRL4_OK=1
    echo "      (host is extremely busy even with an empty ledger — the named SKIP is the honest reading)"
fi
if [ "$CTRL4_OK" -eq 1 ] && ! echo "$OUT2Q" | grep -q "FAIL: ollama dispatch exit code"; then
    echo "    PASS: quiet fleet -> control 4 runs unambiguously (suite rc=$RC2Q)"
else
    echo "    FAIL: quiet fleet -> control 4 is ambiguous or red (suite rc=$RC2Q):"
    echo "$OUT2Q" | sed -n '/4\. qwen3.8/,/5\. depth-cap/p' | sed 's/^/    | /'
    FAIL=1
fi
rm -rf "$W"

# ══ A4 — S09 contract: a declared-and-absent script fails at contract level ══
echo "  A4. pre-commit: a declared script that does not exist is refused at contract level, naming the declaration"
HOOK="$ROOT/tools/hooks/pre-commit"
FLOOR="$ROOT/tools/hooks/claimlint-floor.json"

make_hook_fixture() { # $1 = dir, $2 = contract contents file
    mkdir -p "$1/bin" "$1/tools" "$1/docs/epistemic"
    cp "$FLOOR" "$1/floor.json"
    # stub claimlint — the surfaces the hook reads (regression-precommit.sh's stub)
    cat > "$1/bin/weizigo-claimlint" <<'EOF'
#!/bin/sh
if [ "$1" = "c7" ]; then
    echo "  non-conforming: 0 (fails the run when > 0; spec §6.1)"
    echo "  unabsorbed: 0"
    echo "  dispositioned: 0"
    exit 0
fi
echo "  calibration: PASS"
echo "  C1a orphans / C1b alarms      0 / 0   (FAILS)"
echo "  C2 dangling evidence paths    0   (FAILS)"
echo "  C3 PROVEN w/o committed evid.      0   (debt...)"
echo "  C6 cite-tag mismatches        0   (FAILS)"
echo "  C9 tree-mapping violations      0   (FAILS)"
exit 0
EOF
    chmod +x "$1/bin/weizigo-claimlint"
    # the test-gate surface: build.zig (presence), smoke.sh (exec), runner (passthrough)
    echo "// fixture" > "$1/build.zig"
    echo '#!/bin/sh
exit 0' > "$1/tools/smoke.sh"
    echo '#!/bin/sh
while [ "$1" != "--" ]; do shift; done
shift
exec "$@"' > "$1/tools/runner"
    chmod +x "$1/tools/smoke.sh" "$1/tools/runner"
    # every other fast-pool script, as a stub that passes: the fixture stands
    # in for a repo whose pool is intact, so the arm isolates the CONTRACT check.
    for s in regression-claimlint-output regression-claimlint-c7-json regression-claimlint-c7-scope \
             regression-claimlint-promotion regression-claimlint-volatile regression-orient \
             regression-directive-id-uniqueness regression-directive-integrity \
             regression-managent-models regression-managent-landmark regression-suite-surfaces \
             regression-canonicalizer-parity; do
        echo '#!/bin/sh
exit 0' > "$1/tools/$s.sh"
        chmod +x "$1/tools/$s.sh"
    done
    cp "$2" "$1/contract.md"
    echo "ok" > "$1/docs/epistemic/CLAIMS.md"
    cd "$1" && git add -A >/dev/null 2>&1
}

# seeded: the contract declares a ghost with a known-red line for it — the
# old gate would have baselined the deletion as non-blocking.
scratch a4; W=$W_a4
cat > /tmp/weizigo/t953-a4-contract.md <<'EOF'
test tools/regression-t953-ghost.sh covers docs/epistemic
test tools/smoke.sh covers docs/epistemic
known-red tools/regression-t953-ghost.sh T953 repair
EOF
make_hook_fixture "$W" /tmp/weizigo/t953-a4-contract.md
OUT4=$(cd "$W" && FLOOR_FILE="$W/floor.json" TEST_GATE_CONTRACT="$W/contract.md" sh "$HOOK" 2>&1); RC4=$?
if [ "$RC4" -ne 0 ] && echo "$OUT4" | grep -q "declared and absent: tools/regression-t953-ghost.sh" \
   && echo "$OUT4" | grep -q "declared in" \
   && echo "$OUT4" | grep -q "Restore the script"; then
    echo "    PASS: the deletion is a contract-level refusal naming the declaration (rc=$RC4), not a baselined KNOWN RED"
else
    echo "    FAIL: the declared-and-absent script was not refused at contract level (rc=$RC4):"
    echo "$OUT4" | tail -12 | sed 's/^/    | /'
    FAIL=1
fi
# null: the same fixture with the ghost restored — the hook completes.
echo '#!/bin/sh
exit 0' > "$W/tools/regression-t953-ghost.sh"
chmod +x "$W/tools/regression-t953-ghost.sh"
cd "$W" && git add -A >/dev/null 2>&1
OUT4N=$(cd "$W" && FLOOR_FILE="$W/floor.json" TEST_GATE_CONTRACT="$W/contract.md" sh "$HOOK" 2>&1); RC4N=$?
if [ "$RC4N" -eq 0 ] && ! echo "$OUT4N" | grep -q "declared and absent"; then
    echo "    PASS: null — every declared script present, the hook completes (rc=0)"
else
    echo "    FAIL: null — the presence check fired (or the hook broke) on a complete tree (rc=$RC4N):"
    echo "$OUT4N" | tail -12 | sed 's/^/    | /'
    FAIL=1
fi
cd "$ROOT"
rm -rf "$W" /tmp/weizigo/t953-a4-contract.md

# ══ A5 — managent assign --exclude: an unknown token is refused, named ══
echo "  A5. managent assign --exclude: a token naming no family and no model is refused, listing the valid families (D2 decision)"
if [ ! -x "$MG" ]; then
    echo "    SKIP: no managent binary (build with 'zig build && tools/deploy.sh') — A5 needs it"
else
    scratch a5; W=$W_a5
    export MANAGENT_STORE="$W/docs/infra/managent/tasks.json"
    mkdir -p "$W/docs/infra/managent" "$W/untracked"
    printf '<!--managent set=A deliverables=-->\n# T9995\n' > "$W/untracked/T9995.md"
    python3 - "$MANAGENT_STORE" <<'PY'
import json, sys
store = {"T9995": {
    "status": "dispatchable", "agent": None, "model": None,
    "bundle": "untracked/T9995.md", "set": "A", "holds": [], "needs": [], "caps": [],
    "added": "2026-08-01T00:00:00Z", "claimed": None, "done": None,
    "dispatched": None, "dispatched_to": None, "note": None,
    "verdict": None, "verdict_note": None, "claim_count": 0,
    "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None,
}}
json.dump(store, open(sys.argv[1], "w"), indent=1)
PY
    OUT5=$(cd "$W" && "$MG" assign T9995 --exclude ollama --dry-run 2>&1); RC5=$?
    if [ "$RC5" -ne 0 ] && echo "$OUT5" | grep -q "names no family and no canonical model" \
       && echo "$OUT5" | grep -q "'ollama'" \
       && echo "$OUT5" | grep -q "valid families:" \
       && echo "$OUT5" | grep -q "ollama-cloud"; then
        echo "    PASS: the token is refused, named, and the valid families are listed (rc=$RC5)"
    else
        if [ "$RC5" -eq 0 ]; then
            echo "    FAIL (the D2 defect, live): the unknown token was SILENTLY IGNORED — the draw proceeded as if the exclusion applied:"
        else
            echo "    FAIL: the refusal does not name the token and the families (rc=$RC5):"
        fi
        echo "$OUT5" | sed 's/^/    | /'
        FAIL=1
    fi
    # null: a valid family token is accepted.
    OUT5N=$(cd "$W" && "$MG" assign T9995 --exclude ollama-cloud --dry-run 2>&1); RC5N=$?
    if [ "$RC5N" -eq 0 ] && ! echo "$OUT5N" | grep -q "names no family"; then
        echo "    PASS: null — a valid token (ollama-cloud) is accepted (rc=0)"
    else
        echo "    FAIL: null — a valid token was refused (rc=$RC5N):"
        echo "$OUT5N" | sed 's/^/    | /'
        FAIL=1
    fi
    rm -rf "$W"
    unset MANAGENT_STORE
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== T953 refusal-names-subject: ALL ARMS PASS ==="
else
    echo "=== T953 refusal-names-subject: FAILURES ==="
fi
exit "$FAIL"
