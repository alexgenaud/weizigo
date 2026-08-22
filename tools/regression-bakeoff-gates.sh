#!/bin/sh
# regression-bakeoff-gates.sh — controls for the grand-race gates wired into
# tools/bakeoff.sh (T542): G1 tokens, G2 isolation refusal, G3 family
# exclusion, G4 blinding sanitizer.
#
# G5 (lanes.json + sealed lane map) already held; G6 (impressions) is T522's.
# These controls pin the G1/G2/G3/G4 contracts.  No real model is ever
# dispatched: every "lane" is a fake `pi` shim that echoes a fixed string, so
# no credentials are read and no tokens are spent.  The only real tree touched
# is untracked/ (gitignored): the main checkout receives one run dir (the
# --allow-unisolated override arm) and one heartbeat append, both cleaned up.
#
# Arms:
#   G2 seeded  run root is not a git worktree  -> REFUSED, exit 2, reason
#              names G2 (the pre-T542 code dispatched happily — that red
#              observation is recorded in the findings, not reproduced here).
#   G2 null    a real worktree with keys outside -> dispatch proceeds.
#   G2 seeded  --allow-unisolated "<reason>"     -> proceeds, lanes.json
#              carries the override + reason.
#   G4 seeded  out.md containing "I am Claude"   -> out.sanitized.md has it
#              redacted, out.md byte-identical, lanes.json flags the lane.
#   G4 null    out.md with no self-identification -> sanitized == original,
#              no flag.
#   G3 seeded  grader family == lane family      -> refused at counting, still
#              present in the retained record; the fine-grained family check
#              (glm grader vs qwen lane NOT excluded) is asserted too.
#   G1 seeded  no token reading                  -> null + reason, field
#              present (never absent, never invented).
#   G1 null    a real trailer reading            -> the number matches the
#              runner record; the trailer wins over token-capture.py.
#   T526 (D-f): the grade subcommand enforces family exclusion + sealed-key
#              blind grading MECHANICALLY — seal-key (hash-only, never
#              overwritten), anonymize (letters from out.sanitized.md, map
#              sealed + hashed, never printed), submit (G3 refusal of a
#              same-family grader at the boundary, refusals recorded,
#              duplicates/unknown letters/non-canonical graders refused,
#              key-tamper refusal), status (state without the map), unseal
#              (refuses while incomplete / map tampered / key tampered;
#              --force records a deliberate early unseal; counted scores
#              exclude family grades), plus one end-to-end CLI flow.
#
# Task: T542 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20
# T526 arms: added 2026-08-22 (deepseek-v4-flash/T526)

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
BAKEOFF="$ROOT/tools/bakeoff.sh"
RUNNER="$ROOT/tools/runner"
WT="/tmp/weizigo/t542-reg-worktree"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t542-bakeoff-gates-XXXXXX)" || { echo "FATAL: scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
FAKEBIN="$WORK/bin"
mkdir -p "$FAKEBIN"

# fake pi shim — echoes the fixed string the test wants, ignores args.
cat > "$FAKEBIN/pi" <<'EOF'
#!/bin/sh
printf '%s\n' "$FAKE_PI_OUT"
EOF
chmod +x "$FAKEBIN/pi"

# scratch HOME so the real token-capture.py (present in the main checkout)
# reads an empty session dir when the override arm runs — never ~/.pi.
mkdir -p "$WORK/home"

RUNC="t542-g2override-$$"
cleanup() {
    git -C "$ROOT" worktree remove --force "$WT" 2>/dev/null || git -C "$ROOT" worktree prune 2>/dev/null || true
    rm -rf "$WT" 2>/dev/null || true
    rm -rf "$ROOT/untracked/bakeoff/$RUNC" 2>/dev/null || true
    rm -rf "$WORK" 2>/dev/null || true
}
trap cleanup EXIT INT TERM HUP

# ── start-up check (T448): stale fixture from a killed run ────────────────
if [ -d "$WT" ] || git -C "$ROOT" worktree list 2>/dev/null | grep -q " $WT "; then
    echo "regression-bakeoff-gates.sh: REFUSED — stale fixture worktree $WT" >&2
    echo "Remove by hand: git -C '$ROOT' worktree remove --force '$WT'; rm -rf '$WT'" >&2
    exit 3
fi

if ! command -v git >/dev/null 2>&1; then
    echo "SKIP: git not found — worktree controls cannot run"
    exit 0
fi
if [ ! -f "$BAKEOFF" ] || [ ! -f "$RUNNER" ]; then
    echo "FAIL: $BAKEOFF or $RUNNER missing"
    exit 1
fi

BRIEF="$WORK/brief.md"
ROSTER="$WORK/roster"
printf 'Produce your answer as your final message.\n' > "$BRIEF"
printf 'deepseek deepseek-v4-pro\n' > "$ROSTER"

echo "=== regression-bakeoff-gates ==="

# ── unit controls (G3 + G1) via the imported module ───────────────────────
python3 - "$BAKEOFF" <<'PYEOF'
import importlib.machinery, importlib.util, json, os, sys, tempfile
bakeoff = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("bakeoff", bakeoff)
spec = importlib.util.spec_from_loader("bakeoff", loader)
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

fail = 0
def ok(cond, msg):
    global fail
    print(("PASS" if cond else "FAIL") + ": " + msg)
    if not cond:
        fail = 1

# ── G3: family exclusion at counting ──────────────────────────────────────
fam = {l: b.model_family(l) for l in
       ["claude-opus-5", "deepseek-v4-pro", "deepseek-v4-flash",
        "glm-5.2", "kimi-k2.7", "qwen3.8:27b-mlx"]}

retained = []
g_self = b.grade_family({"grader": "claude-opus-5", "lane": "claude-opus-5", "score": 9}, fam)
retained.append(g_self)
ok(g_self["is_self"] is True and g_self["is_family"] is True,
   "G3 — a self-grade is annotated is_self and is_family (retained, not counted)")
try:
    b.count_grade(g_self, fam)
    ok(False, "G3 — count_grade on a family grade raises FamilyGradeError")
except b.FamilyGradeError:
    ok(True, "G3 — count_grade on a family grade raises FamilyGradeError (hard refusal)")
ok(g_self in retained and retained[0]["score"] == 9,
   "G3 — the family grade is still present in the retained record")

# family = model family, NOT dispatch family: glm (ollama) grades qwen (ollama)
# -> different model families -> NOT excluded.  The G3 note (grand-race §2)
# rests on exactly this: qwen is not a Claude/DeepSeek grader.
g_x = b.grade_family({"grader": "glm-5.2", "lane": "qwen3.8:27b-mlx", "score": 7}, fam)
ok(g_x["is_family"] is False,
   "G3 — glm grader vs qwen lane is NOT family-excluded (model family, not dispatch family)")
b.count_grade(g_x, fam)
ok(True, "G3 — the glm-vs-qwen grade counts without refusal")
g_y = b.grade_family({"grader": "glm-5.2", "lane": "glm-5.2", "score": 8}, fam)
ok(g_y["is_family"] is True, "G3 — glm grader vs glm lane IS family-excluded")

# ── G3: roster-epoch 2026-08-20b exclusion arithmetic ────────────────────
# The grand-race §2 arithmetic the bundle calls "tight": Claude lanes are
# graded by the DeepSeek pair + qwen (3 graders), qwen by everyone (6).  The
# bundle's "DS lanes by the Claude four" UNDERCOUNTS: G3 excludes only
# same-family grades, and qwen is a different family from deepseek, so a DS
# lane has 5 cross-family graders (see the T542.2 finding in
# findings/T542-bakeoff-gates.json).  Asserted with literal epoch labels
# (the roster file docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/roster-2026-08-20b.txt is untracked, so
# a fresh-clone `zig build test` must not depend on it).
roster = [
    "claude-fable-5", "claude-opus-5", "claude-sonnet-5",
    "claude-haiku-4-5-20251001", "deepseek-v4-pro", "deepseek-v4-flash",
    "qwen3.8:27b-mlx",
]
lane_fam = {l: b.model_family(l) for l in roster}
CLAUDE4 = ["claude-fable-5", "claude-opus-5", "claude-sonnet-5",
           "claude-haiku-4-5-20251001"]
DS2 = ["deepseek-v4-pro", "deepseek-v4-flash"]
for lane in roster:
    graders = sorted(g for g in roster if g != lane
                     and b.model_family(g) != lane_fam[lane])
    if lane in CLAUDE4:
        ok(graders == sorted(DS2 + ["qwen3.8:27b-mlx"]),
           "G3 epoch-2026-08-20b — %s graded by the DS pair + qwen (3 graders)" % lane)
    elif lane in DS2:
        # NOTE (T542.2 finding): the bundle says "DS lanes by the Claude four"
        # (4), but grand-race.md §5 says everyone grades everything and G3
        # excludes only SAME-family grades — qwen is a different family from
        # deepseek, so qwen grades DS lanes too (5 cross-family graders).
        ok(graders == sorted(CLAUDE4 + ["qwen3.8:27b-mlx"]),
           "G3 epoch-2026-08-20b — %s graded by the Claude four + qwen (5 cross-family graders; the bundle's 'Claude four' undercounts)" % lane)
    else:
        ok(graders == sorted(CLAUDE4 + DS2),
           "G3 epoch-2026-08-20b — %s graded by everyone (6 graders)" % lane)
    for g in roster:
        if g == lane:
            continue
        gr = b.grade_family({"grader": g, "lane": lane, "score": 5}, lane_fam)
        if b.model_family(g) == lane_fam[lane]:
            try:
                b.count_grade(gr, lane_fam)
                ok(False, "G3 epoch — %s grading %s should refuse" % (g, lane))
            except b.FamilyGradeError:
                pass
        else:
            b.count_grade(gr, lane_fam)
ok(True, "G3 epoch-2026-08-20b — every pair is excluded exactly when families match")

# ── G1: token wiring (trailer wins; capture join; null + reason) ──────────
scratch = tempfile.mkdtemp()
os.makedirs(os.path.join(scratch, "tools"))
# fake token-capture.py reporting deepseek-v4-pro = 300/50
with open(os.path.join(scratch, "tools", "token-capture.py"), "w") as f:
    f.write('import sys, json\nprint(json.dumps({"models": {"deepseek-v4-pro": '
            '{"tokens_in": 300, "tokens_out": 50}}}))\n')

# G1 null: real trailer reading, and it wins over token-capture.py
r = os.path.join(tempfile.mkdtemp(), "run")
os.makedirs(os.path.join(r, "deepseek-v4-pro"))
with open(os.path.join(r, "deepseek-v4-pro", "trailer.log"), "w") as f:
    f.write("argv echo\n[runner] tokens_in=111 tokens_out=222\n")
res = [{"label": "deepseek-v4-pro", "status": "ok"}]
b.collect_tokens(scratch, r, "2026-08-20", res)
ok(res[0]["tokens_in"] == 111 and res[0]["tokens_out"] == 222,
   "G1 null — trailer reading matches the runner record (111/222)")
ok(res[0]["tokens_source"] == "trailer",
   "G1 — the per-lane trailer reading wins over token-capture.py")

# G1 capture join: no trailer -> token-capture.py's per-model reading
r2 = os.path.join(tempfile.mkdtemp(), "run2")
os.makedirs(os.path.join(r2, "deepseek-v4-pro"))
res2 = [{"label": "deepseek-v4-pro", "status": "ok"}]
b.collect_tokens(scratch, r2, "2026-08-20", res2)
ok(res2[0]["tokens_in"] == 300 and res2[0]["tokens_out"] == 50
   and res2[0]["tokens_source"] == "token-capture.py",
   "G1 — bakeoff invokes token-capture.py and joins its per-model reading")

# G1 seeded: no reading anywhere -> null + reason, field present
scratch2 = tempfile.mkdtemp()
r3 = os.path.join(tempfile.mkdtemp(), "run3")
os.makedirs(os.path.join(r3, "deepseek-v4-flash"))
res3 = [{"label": "deepseek-v4-flash", "status": "ok"}]
b.collect_tokens(scratch2, r3, "2026-08-20", res3)
ok(res3[0]["tokens_in"] is None and res3[0]["tokens_out"] is None,
   "G1 seeded — no reading is null, never a number")
ok("tokens_in" in res3[0] and "tokens_missing_reason" in res3[0],
   "G1 seeded — the field is present, not merely absent")
ok(bool(res3[0]["tokens_missing_reason"]),
   "G1 seeded — a null reading carries a reason")

sys.exit(fail)
PYEOF
UNIT_RC=$?
if [ "$UNIT_RC" -ne 0 ]; then FAIL=1; fi

# ── G2 seeded: not a worktree -> refused, exit 2, reason names G2 ──────────
echo ""
echo "  G2 seeded — main checkout (not a worktree) refuses"
set +e
REFUSE_OUT="$(cd "$ROOT" && PATH="$FAKEBIN:$PATH" DEEPSEEK_API_KEY=test \
    "$BAKEOFF" "$BRIEF" "$ROSTER" --run "t542-g2refuse-$$" 2>&1)"
REFUSE_RC=$?
set -e
if [ "$REFUSE_RC" -eq 2 ] && printf '%s' "$REFUSE_OUT" | grep -q "G2 isolation gate"; then
    echo "    PASS: exit 2, reason names G2"
else
    echo "    FAIL: expected exit 2 naming G2, got $REFUSE_RC"
    printf '%s\n' "$REFUSE_OUT"
    FAIL=1
fi
if printf '%s' "$REFUSE_OUT" | grep -q "not a git worktree"; then
    echo "    PASS: reason names the not-a-worktree fact"
else
    echo "    FAIL: reason does not name the not-a-worktree fact"
    FAIL=1
fi

# ── G2 null + G4 seeded: worktree with keys outside dispatches, sanitizer
#    flags the self-identifying lane ────────────────────────────────────────
echo ""
echo "  G2 null + G4 seeded — worktree run with a self-identifying lane"
git -C "$ROOT" worktree add --detach "$WT" HEAD >/dev/null 2>&1 || {
    echo "    FAIL: could not create worktree $WT" >&2
    exit 1
}
# The worktree holds the COMMITTED bakeoff.sh; test the working copy (T542's
# edits are not yet committed at control time) by copying it in.
cp "$BAKEOFF" "$WT/tools/bakeoff.sh"
RUNB="t542-g2null-$$"
set +e
(cd "$WT" && PATH="$FAKEBIN:$PATH" DEEPSEEK_API_KEY=test \
  FAKE_PI_OUT="I am Claude, and here is my deliverable." \
  "$WT/tools/bakeoff.sh" "$BRIEF" "$ROSTER" --run "$RUNB") >/dev/null 2>&1
RUNB_RC=$?
set -e
if [ "$RUNB_RC" -eq 0 ]; then
    echo "    PASS: dispatch proceeded from the worktree (exit 0)"
else
    echo "    FAIL: worktree dispatch did not proceed (exit $RUNB_RC)"
    FAIL=1
fi

python3 - "$WT/untracked/bakeoff/$RUNB" <<'PYEOF'
import json, os, sys
run = sys.argv[1]
fail = 0
def ok(cond, msg):
    global fail
    print(("    PASS" if cond else "    FAIL") + ": " + msg)
    if not cond:
        fail = 1

lanes = json.load(open(os.path.join(run, "lanes.json")))
lane = lanes["lanes"][0]
iso = lanes["isolation"]
ok(iso["root_is_worktree"] is True, "G2 null — lanes.json records root_is_worktree true")
ok(iso.get("allow_unisolated") is False, "G2 null — no override recorded when none given")
out = open(os.path.join(run, "deepseek-v4-pro", "out.md"), "rb").read()
ok(out == b"I am Claude, and here is my deliverable.\n",
   "G4 seeded — out.md is the lane's verbatim output (never modified)")
ok(lane["self_identified"] is True, "G4 seeded — lanes.json flags the lane as self-identifying")
ok("I am Claude" in (lane.get("self_id_matches") or []), "G4 seeded — the match is recorded")
sani = open(os.path.join(run, "deepseek-v4-pro", "out.sanitized.md")).read()
ok("Claude" not in sani and "[SELF-IDENTIFICATION REDACTED]" in sani,
   "G4 seeded — out.sanitized.md has the self-identification redacted")
ok(lane["tokens_in"] is None and lane["tokens_out"] is None,
   "G1 seeded (end-to-end) — no token reading is null")
ok("tokens_missing_reason" in lane and bool(lane["tokens_missing_reason"]),
   "G1 seeded (end-to-end) — the null reading carries a reason and the field is present")
sys.exit(fail)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── G2 seeded (override) + G4 null: --allow-unisolated proceeds, records the
#    reason; a clean lane is not flagged and its sanitized copy is identical ─
echo ""
echo "  G2 seeded (override) + G4 null — --allow-unisolated with a clean lane"
set +e
(cd "$ROOT" && HOME="$WORK/home" PATH="$FAKEBIN:$PATH" DEEPSEEK_API_KEY=test \
  FAKE_PI_OUT="The consolidation merges the keeper and watcher into one tested binary." \
  "$BAKEOFF" "$BRIEF" "$ROSTER" --run "$RUNC" \
  --allow-unisolated "operator accepts risk for the regression control") >/dev/null 2>&1
RUNC_RC=$?
set -e
if [ "$RUNC_RC" -eq 0 ]; then
    echo "    PASS: --allow-unisolated dispatch proceeded (exit 0)"
else
    echo "    FAIL: --allow-unisolated dispatch did not proceed (exit $RUNC_RC)"
    FAIL=1
fi

python3 - "$ROOT/untracked/bakeoff/$RUNC" <<'PYEOF'
import json, os, sys
run = sys.argv[1]
fail = 0
def ok(cond, msg):
    global fail
    print(("    PASS" if cond else "    FAIL") + ": " + msg)
    if not cond:
        fail = 1
lanes = json.load(open(os.path.join(run, "lanes.json")))
iso = lanes["isolation"]
ok(iso.get("allow_unisolated") is True, "G2 seeded — lanes.json records the override")
ok(iso.get("allow_unisolated_reason") == "operator accepts risk for the regression control",
   "G2 seeded — lanes.json records the override reason")
lane = lanes["lanes"][0]
out = open(os.path.join(run, "deepseek-v4-pro", "out.md"), "rb").read()
sani = open(os.path.join(run, "deepseek-v4-pro", "out.sanitized.md"), "rb").read()
ok(sani == out, "G4 null — sanitized copy is byte-identical to the original")
ok(lane["self_identified"] is False, "G4 null — a clean lane is not flagged")
sys.exit(fail)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── T526 (D-f): grade subcommand — blinding + family exclusion enforced ────
# The grade workflow is mechanical, not the dispatcher's memory: seal-key
# (hash-only, never overwritten), anonymize (letters from out.sanitized.md,
# map sealed + hashed, never printed), submit (G3 refusal of a same-family
# grader at the boundary, refusals recorded, key-tamper refusal, duplicates /
# unknown letters / non-canonical graders refused), status (state without the
# map), unseal (refuses while incomplete / map tampered / key tampered;
# --force records a deliberate early unseal; counted scores exclude family
# grades). Unit arms call the module functions; one end-to-end arm runs the
# real CLI on a fabricated run (no dispatch, no credentials).
echo ""
echo "  T526 — grade workflow unit arms (fabricated run, no dispatch)"
python3 - "$BAKEOFF" <<'PYEOF'
import contextlib, importlib.machinery, importlib.util, io, json, os, sys, tempfile
bakeoff = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("bakeoff", bakeoff)
spec = importlib.util.spec_from_loader("bakeoff", loader)
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)

fail = 0
def ok(cond, msg):
    global fail
    print(("    PASS" if cond else "    FAIL") + ": " + msg)
    if not cond:
        fail = 1

def die_ok(fn, *args):
    """Assert fn refuses via die() (SystemExit) — the mechanical gate fired."""
    try:
        fn(*args)
    except SystemExit:
        return True
    return False

def make_run(tag, lanes, with_lanes=True):
    base = tempfile.mkdtemp(prefix="t526-" + tag + "-")
    run = os.path.join(base, "run")
    os.makedirs(run)
    if with_lanes:
        doc = {"run": tag, "brief": "t526 brief", "roster": "t526",
               "prompt_sha256": "t526" * 8, "lanes": lanes}
        json.dump(doc, open(os.path.join(run, "lanes.json"), "w"), indent=1)
    for l in lanes:
        d = os.path.join(run, l["label"])
        os.makedirs(d)
        out = "DELIVERABLE-OUTPUT\n"
        sani = ("REDACTED " if l.get("self_identified") else "") + out
        open(os.path.join(d, "out.md"), "w").write(out)
        open(os.path.join(d, "out.sanitized.md"), "w").write(sani)
    return base, run

LANES = [
    {"family": "deepseek", "label": "deepseek-v4-pro", "status": "ok",
     "self_identified": False},
    {"family": "deepseek", "label": "deepseek-v4-flash", "status": "ok",
     "self_identified": False},
    {"family": "claude", "label": "claude-opus-5", "status": "ok",
     "self_identified": True},
]
EXPECTED_MAP = {"A": "deepseek-v4-pro", "B": "deepseek-v4-flash",
                "C": "claude-opus-5"}

keydir = tempfile.mkdtemp(prefix="t526-key-")
key = os.path.join(keydir, "T526-key.md")
open(key, "w").write("RUBRIC-TOP-SECRET-30pts\n")

# ── seal-key ──────────────────────────────────────────────────────
base, run = make_run("seal", LANES)
ok(die_ok(b.grade_seal_key, run, os.path.join(keydir, "missing.md")),
   "seal-key refuses a missing key file")
ok(b.grade_seal_key(run, key) == 0, "seal-key records the key hash")
seal_txt = open(os.path.join(run, "grade", "seal.json")).read()
ok("RUBRIC-TOP-SECRET" not in seal_txt,
   "seal-key never stores the key text — only its hash")
seal = json.loads(seal_txt)
ok(len(seal["key_sha256"]) == 64, "seal-key records a full sha256")
ok(b.grade_seal_key(run, key) == 0,
   "seal-key re-seal with the SAME key is idempotent")
key2 = os.path.join(keydir, "T526-key-2.md")
open(key2, "w").write("RUBRIC-DIFFERENT\n")
ok(die_ok(b.grade_seal_key, run, key2),
   "seal-key refuses a DIFFERENT key over an existing seal (never overwrite)")
nobase, norun = make_run("nolan", [], with_lanes=False)
ok(die_ok(b.grade_seal_key, norun, key),
   "seal-key refuses a run with no lanes.json (G5: no dispatch record, no grading)")

# ── anonymize ─────────────────────────────────────────────────────
base2, run2 = make_run("anon-noseal", LANES)
ok(die_ok(b.grade_anonymize, run2),
   "anonymize refuses before the key is sealed (T447: key predates the outputs)")
b.grade_seal_key(run2, key)
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = b.grade_anonymize(run2)
ok(rc == 0, "anonymize builds the blind inputs after sealing")
for label in ("deepseek-v4-pro", "deepseek-v4-flash", "claude-opus-5"):
    ok(label not in buf.getvalue(),
       "anonymize stdout never reveals lane %s (map sealed)" % label)
map_doc = json.load(open(os.path.join(run2, "grade", "lanes-map.sealed.json")))
ok(map_doc == EXPECTED_MAP,
   "anonymize letter map matches the deterministic name-hash shuffle (A=pro B=flash C=opus)")
rec = json.load(open(os.path.join(run2, "grade", "seal-record.json")))
ok(rec["map_sha256"] == b._sha256_file(
    os.path.join(run2, "grade", "lanes-map.sealed.json")),
   "anonymize seals the map hash")
ok(rec["self_identified_letters"] == ["C"],
   "anonymize flags the self-identified lane in the seal record (G4 data point)")
ok(open(os.path.join(run2, "grade", "C.md")).read() == "REDACTED DELIVERABLE-OUTPUT\n",
   "anonymize builds blind artifacts from out.sanitized.md (G4: sanitizer before grading)")
ok(open(os.path.join(run2, "claude-opus-5", "out.md")).read() == "DELIVERABLE-OUTPUT\n",
   "anonymize never modifies the lane's original out.md (evidence stays verbatim)")
ok(die_ok(b.grade_anonymize, run2),
   "anonymize refuses when already anonymized (never overwrite)")

# ── submit ────────────────────────────────────────────────────────
base3, run3 = make_run("submit", LANES)
b.grade_seal_key(run3, key)
b.grade_anonymize(run3)
gd3 = os.path.join(run3, "grade")
ok(die_ok(b.grade_submit, run3, "claude-opus-5", "C", "28", None)
   and "G3" in open(os.path.join(gd3, "refusals.jsonl")).read(),
   "submit refuses a same-family grade (claude grader, claude lane) naming G3")
ok(die_ok(b.grade_submit, run3, "deepseek-v4-pro", "A", "30", None)
   and "self-grade" in open(os.path.join(gd3, "refusals.jsonl")).read(),
   "submit refuses a self-grade as a same-family grade")
ok(not os.path.exists(os.path.join(gd3, "grades.jsonl")),
   "refused grades are never recorded in grades.jsonl")
b.grade_submit(run3, "deepseek-v4-flash", "C",
               '{"correctness": 9, "clarity": 2}',
               '{"null_ctrl": "pass", "seeded_ctrl": "pass"}')
lines = [json.loads(l) for l in open(os.path.join(gd3, "grades.jsonl"))
         if l.strip()]
ok(len(lines) == 1 and lines[0]["total"] == 11
   and lines[0]["lane"] == "claude-opus-5"
   and lines[0]["is_family"] is False,
   "submit records a cross-family grade with a mechanical total (9+2)")
ok(lines[0]["controls"] == {"null_ctrl": "pass", "seeded_ctrl": "pass"},
   "submit records the grader-validity controls verbatim")
ok(die_ok(b.grade_submit, run3, "deepseek-v4-flash", "C", "10", None),
   "submit refuses a duplicate (grader, artifact) — submitted grades are immutable")
ok(die_ok(b.grade_submit, run3, "deepseek-v4-flash", "Z", "10", None),
   "submit refuses an unknown artifact letter")
ok(die_ok(b.grade_submit, run3, "not-a-model", "B", "10", None),
   "submit refuses a non-canonical grader label")
ok(die_ok(b.grade_submit, run3, "deepseek-v4-flash", "B", "not-json", None),
   "submit refuses non-JSON --scores")
base3b, run3b = make_run("submit-noanon", LANES)
b.grade_seal_key(run3b, key)
ok(die_ok(b.grade_submit, run3b, "deepseek-v4-flash", "C", "10", None),
   "submit refuses when the run is not anonymized (grading must be blind)")
base3c, run3c = make_run("submit-noseal", LANES)
ok(die_ok(b.grade_submit, run3c, "deepseek-v4-flash", "C", "10", None),
   "submit refuses when no key is sealed (T316: the key must predate grading)")
base3d, run3d = make_run("submit-tamper", LANES)
b.grade_seal_key(run3d, key)
open(key, "a").write("EDITED\n")
ok(die_ok(b.grade_submit, run3d, "deepseek-v4-flash", "C", "10", None),
   "submit refuses when the key file no longer matches the seal (T447)")
open(key, "w").write("RUBRIC-TOP-SECRET-30pts\n")

# ── status: state without the map ─────────────────────────────────
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    b.grade_status(run3)
sout = buf.getvalue()
ok("letters=3" in sout and "graded_letters=1/3" in sout,
   "status reports letters and completeness without the map")
ok("A=deepseek-v4-pro" not in sout and "B=deepseek-v4-flash" not in sout
   and "C=claude-opus-5" not in sout,
   "status never prints the sealed map (letter->lane associations stay sealed)")
ok("refusals=2" in sout,
   "status reports the G3 refusals count (enforcement evidence)")

# ── unseal ────────────────────────────────────────────────────────
ok(die_ok(b.grade_unseal, run3, None),
   "unseal refuses while artifacts remain ungraded (map opens only after every score)")
b.grade_submit(run3, "claude-opus-5", "A", "26", None)
b.grade_submit(run3, "claude-opus-5", "B", "24", None)
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = b.grade_unseal(run3, None)
ok(rc == 0, "unseal succeeds once every artifact has a grade")
uout = buf.getvalue()
ok("A=deepseek-v4-pro" in uout and "B=deepseek-v4-flash" in uout
   and "C=claude-opus-5" in uout, "unseal reveals the map")
ok("mean=" in uout and "n=1" in uout,
   "unseal reports per-lane counted totals with denominators")
udoc = json.load(open(os.path.join(run3, "grade", "unseal.json")))
ok(udoc["counted_grades"] == 3 and udoc["family_grades"] == 0,
   "unseal record: 3 counted grades, 0 family grades (G3 held at submission)")
base4, run4 = make_run("tamper-map", LANES)
b.grade_seal_key(run4, key)
b.grade_anonymize(run4)
json.dump({"A": "tampered", "B": "deepseek-v4-flash", "C": "claude-opus-5"},
          open(os.path.join(run4, "grade", "lanes-map.sealed.json"), "w"), indent=1)
b.grade_submit(run4, "deepseek-v4-flash", "C", "10", None)
b.grade_submit(run4, "claude-opus-5", "A", "10", None)
b.grade_submit(run4, "claude-opus-5", "B", "10", None)
ok(die_ok(b.grade_unseal, run4, None),
   "unseal refuses when the sealed map was edited after anonymization (hash mismatch)")
base5, run5 = make_run("tamper-key", LANES)
b.grade_seal_key(run5, key)
b.grade_anonymize(run5)
b.grade_submit(run5, "deepseek-v4-flash", "C", "10", None)
b.grade_submit(run5, "claude-opus-5", "A", "10", None)
b.grade_submit(run5, "claude-opus-5", "B", "10", None)
open(key, "a").write("EDITED\n")
ok(die_ok(b.grade_unseal, run5, None),
   "unseal refuses when the key was edited after sealing (round is void)")
open(key, "w").write("RUBRIC-TOP-SECRET-30pts\n")
base6, run6 = make_run("force", LANES)
b.grade_seal_key(run6, key)
b.grade_anonymize(run6)
b.grade_submit(run6, "claude-opus-5", "A", "26", None)
buf = io.StringIO()
with contextlib.redirect_stdout(buf):
    rc = b.grade_unseal(run6, "lane DNF'd at dispatch")
ok(rc == 0, "unseal --force <reason> closes an incomplete round deliberately")
udoc6 = json.load(open(os.path.join(run6, "grade", "unseal.json")))
ok(udoc6["forced"] is True
   and udoc6["force_reason"] == "lane DNF'd at dispatch",
   "the forced early unseal records its reason in unseal.json")
ok("ungraded_letters=" in buf.getvalue(),
   "the forced unseal reports the ungraded letters with the reason")

sys.exit(fail)
PYEOF
if [ $? -ne 0 ]; then FAIL=1; fi

# ── T526 end-to-end: the real CLI on a fabricated run (no dispatch) ───────
echo ""
echo "  T526 e2e — blind grading workflow through the real CLI"
E2E="$WORK/t526-e2e"
mkdir -p "$E2E/run/deepseek-v4-pro" "$E2E/run/deepseek-v4-flash" "$E2E/run/claude-opus-5"
cat > "$E2E/run/lanes.json" <<'EOF'
{"run": "t526-e2e", "brief": "e2e", "prompt_sha256": "e2e", "lanes": [
  {"family": "deepseek", "label": "deepseek-v4-pro", "status": "ok", "self_identified": false},
  {"family": "deepseek", "label": "deepseek-v4-flash", "status": "ok", "self_identified": false},
  {"family": "claude", "label": "claude-opus-5", "status": "ok", "self_identified": false}]}
EOF
for l in deepseek-v4-pro deepseek-v4-flash claude-opus-5; do
    printf 'ANSWER-%s\n' "$l" > "$E2E/run/$l/out.md"
    printf 'ANSWER-%s\n' "$l" > "$E2E/run/$l/out.sanitized.md"
done
printf 'E2E-RUBRIC\n' > "$E2E/key.md"

set +e
"$BAKEOFF" grade "$E2E/run" seal-key "$E2E/key.md" >/dev/null 2>&1
RC=$?
"$BAKEOFF" grade "$E2E/run" anonymize >/dev/null 2>&1
RC=$((RC + $?))
# the family submission must be refused with exit 2 and never recorded
"$BAKEOFF" grade "$E2E/run" submit --grader claude-opus-5 --artifact C --scores 28 >/dev/null 2>&1
FAM_RC=$?
"$BAKEOFF" grade "$E2E/run" submit --grader deepseek-v4-flash --artifact C --scores 28 >/dev/null 2>&1
RC=$((RC + $?))
"$BAKEOFF" grade "$E2E/run" submit --grader claude-opus-5 --artifact A --scores 25 >/dev/null 2>&1
RC=$((RC + $?))
"$BAKEOFF" grade "$E2E/run" submit --grader claude-opus-5 --artifact B --scores 26 >/dev/null 2>&1
RC=$((RC + $?))
UNSEAL_OUT="$("$BAKEOFF" grade "$E2E/run" unseal 2>/dev/null)"
UNSEAL_RC=$?
set -e
if [ "$RC" -eq 0 ] && [ "$FAM_RC" -eq 2 ] && [ "$UNSEAL_RC" -eq 0 ]; then
    echo "    PASS: seal-key + anonymize + 3 cross-family submits + unseal exit 0; family submit refused with exit 2"
else
    echo "    FAIL: e2e workflow (rc=$RC fam_rc=$FAM_RC unseal_rc=$UNSEAL_RC)"
    FAIL=1
fi
if printf '%s' "$UNSEAL_OUT" | grep -q "A=deepseek-v4-pro" \
   && printf '%s' "$UNSEAL_OUT" | grep -q "C=claude-opus-5"; then
    echo "    PASS: unseal reveals the map on stdout"
else
    echo "    FAIL: unseal did not reveal the expected map"
    FAIL=1
fi
if [ -f "$E2E/run/grade/grades.jsonl" ] \
   && [ "$(wc -l < "$E2E/run/grade/grades.jsonl")" -eq 3 ]; then
    echo "    PASS: exactly 3 grades recorded (the family grade was refused, never recorded)"
else
    echo "    FAIL: expected exactly 3 recorded grades"
    FAIL=1
fi

cleanup
trap - EXIT INT TERM HUP

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-bakeoff-gates: all controls passed ==="
else
    echo "=== regression-bakeoff-gates: FAILURES ===" >&2
    exit 1
fi
