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
#
# Task: T542 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-20

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

cleanup
trap - EXIT INT TERM HUP

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-bakeoff-gates: all controls passed ==="
else
    echo "=== regression-bakeoff-gates: FAILURES ===" >&2
    exit 1
fi
