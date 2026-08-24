#!/usr/bin/env bash
# regression-one-dispatch-path.sh — T862 controls: one dispatch path
# (session + identity), and the auto-close safety net that was silent.
#
# Two defects, one cause: lanes are constructed differently, so some lanes
# lose measurement (Defect 1 — no session/transcript handle) and some lose
# their safety net (Defect 2 — the auto-close never fired for lanes
# dispatched with --arbiter-id, whose identity comes from MANAGENT_TASK_ID).
#
# Defect 2 (the net): a worker that exited 0 without closing its row left
# the row open — measured 40+ hand-closes in one day.  The old gate was
# `if ret == 0 and args.task_id:`; lanes dispatched with --arbiter-id have
# args.task_id is None (identity from the env), so the block never ran and
# NOTHING SAID SO.  The fix (T862 §1): the net uses the ONE resolved
# `task_identity` (--task-id OR MANAGENT_TASK_ID); §3 it closes on EVIDENCE
# (exit 0 + every declared deliverable present) and says so when it
# declines; §4 it waives the impression by name and records the close was
# automatic (no fabricated verdict, no fabricated impression); and it
# REFUSES to close when a declared deliverable is absent (a real failure,
# not a protocol slip).
#
# Defect 1 (the handle): the runner side — every lane records a session
# handle (session_path) when --session is passed, or declares itself
# unmeasurable with a stated reason (session_reason) when not.  The
# lane-CONSTRUCTION fix (attaching --session to the pi/openrouter lane)
# lives in bin/subagent, out of this task's deliverables; recorded as
# follow-up in findings.  These arms pin the runner half: a blank cell is
# never silently blank.
#
# Controls (test-first, per the standing tooling rule):
#
#   A. net fires on env identity (--arbiter-id lane): a stub worker that
#      claims, writes+commits the deliverable, sleeps past the T390
#      claim-to-done window, and exits 0 WITHOUT closing → the net CLOSES
#      the row automatically and says so.  (RED before: the row stayed open
#      with no log line — the old `args.task_id` gate was None.)
#   B. net REFUSES on missing deliverable: a stub that claims and exits 0
#      but does NOT produce the declared deliverable → the net DECLINES
#      loudly (a log line names the missing file) and the row stays open.
#      A net that closes everything is the worse failure.
#   C. no fabrication: the auto-closed row's store record carries an
#      impression_waiver (named), NO impression, and a verdict_note that
#      records the close was automatic — no invented verdict/impression.
#   D. net not needed when the worker closed: a stub that closes the row
#      itself then exits 0 → the net reports "already closed by the worker"
#      and does not double-close (no spurious exit 1).
#   E. degraded run declines out loud: a run with NO task identity → the
#      net says so and declines (never the old silent skip).
#   F. lane WITH --session records a handle (session_path); lane WITHOUT
#      --session declares itself unmeasurable (session_reason).  The
#      runner never leaves a blank cell.
#
# Everything runs in a scratch repo under /tmp/weizigo — the live kanban,
# live untracked/ and the live repo are never touched.  The claimlint
# floor is untouched by design (no doc or claim changes).
#
# Task: T862 · Role: worker · Model: glm-5.2 · Date: 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
RUNNER="$PROJECT/tools/runner"
MG="$PROJECT/bin/managent"
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

weizigo_scratch_repo t862-one-dispatch-path WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t862@test
git config user.name T862
echo base > README.md
mkdir -p docs/infra/managent untracked bin findings docs/epistemic
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

# ── managent + claimlint substrate in scratch (the done-gate needs both) ──
# managent done runs `bin/weizigo-claimlint c7 --json` from the repo root it
# walks from CWD (the scratch repo), and checks deliverables via git in that
# same root — exactly as regression-dispatch.sh provisions them.
CL="$PROJECT/bin/weizigo-claimlint"
[ -x "$CL" ] || CL="$PROJECT/zig-out/bin/weizigo-claimlint"
ln -sf "$MG" bin/managent
ln -sf "$CL" bin/weizigo-claimlint
printf '# minimal scratch claims register (T862 regression)\n' > docs/epistemic/CLAIMS.md

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export REAL_MG="$MG"

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

row_status() {  # $1=id — status word from `managent show`'s second line
    "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
}

seed_task() {  # $1=id  $2=deliverable
    printf '<!--managent set=C type=infra deliverables=%s holds=-->\n# %s — T862 regression bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$2" "$1" \
        > "untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}

# stub that does the work but FORGETS to close (the net's job): claim,
# write+commit a conforming findings JSON deliverable, sleep past the T390
# claim-to-done window, exit 0.  NO managent done.
cat > "$WORK/stub-works.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, subprocess, time, sys, json
mg = os.environ["REAL_MG"]; task = os.environ["MANAGENT_TASK_ID"]
model = os.environ.get("PI_MODEL", "glm-5.2"); dl = os.environ["DELIVERABLE"]
subprocess.run([mg, "claim", task, "--agent", model], check=True)
os.makedirs(os.path.dirname(dl) or ".", exist_ok=True)
with open(dl, "w") as f:
    json.dump({"task_id": task, "date": "2026-08-24", "model": model,
               "claims": [], "new_rows": [],
               "notes": "T862 stub-works — auto-close net test"}, f, indent=2)
subprocess.run(["git", "add", "--", dl], check=True)
subprocess.run(["git", "commit", "-qm", "T862 stub deliverable"], check=True)
time.sleep(11)  # past the T390 claim-to-done refusal window
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub-works.py"

# stub that claims and exits 0 but produces NO deliverable (the control).
cat > "$WORK/stub-missing.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, subprocess, time, sys
mg = os.environ["REAL_MG"]; task = os.environ["MANAGENT_TASK_ID"]
model = os.environ.get("PI_MODEL", "glm-5.2")
subprocess.run([mg, "claim", task, "--agent", model], check=True)
time.sleep(11)
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub-missing.py"

# stub that closes the row ITSELF then exits 0 (the net must not double-close).
cat > "$WORK/stub-closes.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, subprocess, time, sys, json
mg = os.environ["REAL_MG"]; task = os.environ["MANAGENT_TASK_ID"]
model = os.environ.get("PI_MODEL", "glm-5.2"); dl = os.environ["DELIVERABLE"]
subprocess.run([mg, "claim", task, "--agent", model], check=True)
os.makedirs(os.path.dirname(dl) or ".", exist_ok=True)
with open(dl, "w") as f:
    json.dump({"task_id": task, "date": "2026-08-24", "model": model,
               "claims": [], "new_rows": [],
               "notes": "T862 stub-closes — worker closes itself"}, f, indent=2)
subprocess.run(["git", "add", "--", dl], check=True)
subprocess.run(["git", "commit", "-qm", "T862 stub deliverable"], check=True)
time.sleep(11)
subprocess.run([mg, "done", task, "--agent", model, "--status", "pass",
                "--impression-waiver",
                "stub-closes itself (T862 regression)"], check=True)
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub-closes.py"

run_net() {  # $1=id  $2=stub  → stderr captured in $NET_OUT
    export MANAGENT_TASK_ID="$1" PI_MODEL=glm-5.2 DELIVERABLE="findings/$1-result.json"
    NET_OUT=$("$RUNNER" --no-prepend-zig --no-host-guard --max-wall 50 \
              --arbiter-id "$1" -- "$2" 2>&1 || true)
    unset MANAGENT_TASK_ID PI_MODEL DELIVERABLE
}

echo "=== regression-one-dispatch-path (T862) ==="

# ── A. net fires on env identity (--arbiter-id lane) ───────────────────────
echo "  A. env-identity lane: stub works, exits 0, no close → net CLOSES"
seed_task T8620 findings/T8620-result.json
run_net T8620 "$WORK/stub-works.py"
S=$(row_status T8620)
if [ "$S" = "done" ] && echo "$NET_OUT" | grep -q "auto-close net: CLOSED T8620"; then
    pass "row reached done; net logged the automatic close (env identity, --arbiter-id lane)"
else
    fail "row status='$S'; expected done + 'auto-close net: CLOSED T8620' log line"
    echo "$NET_OUT" | sed 's/^/    | /'
fi
# the net must name the deliverable count (evidence, not a guess)
if echo "$NET_OUT" | grep -q "all 1 declared deliverable(s) present"; then
    pass "net closed on evidence (named the 1 declared deliverable present)"
else
    fail "net did not name the deliverable count"
    echo "$NET_OUT" | grep -i "auto-close" | sed 's/^/    | /'
fi

# ── B. net REFUSES on missing deliverable ─────────────────────────────────
echo "  B. missing deliverable: stub exits 0, no deliverable → net DECLINES, row open"
seed_task T8621 findings/T8621-result.json
run_net T8621 "$WORK/stub-missing.py"
S=$(row_status T8621)
if [ "$S" = "in_progress" ] \
   && echo "$NET_OUT" | grep -q "auto-close net: DECLINED" \
   && echo "$NET_OUT" | grep -q "findings/T8621-result.json"; then
    pass "row stayed in_progress; net declined and named the missing deliverable"
else
    fail "row status='$S'; expected in_progress + DECLINED naming the missing file"
    echo "$NET_OUT" | grep -i "auto-close" | sed 's/^/    | /'
fi

# ── C. no fabrication: the auto-closed row's store record ──────────────────
echo "  C. no fabrication: closed row has impression_waiver (named), no impression, automatic note"
python3 - <<'PYEOF'
import json, sys
s = json.load(open("docs/infra/managent/tasks.json"))
r = s.get("T8620", {})
ok = True
if r.get("impression") not in (None, "", "null"):
    print(f"    FAIL: impression is {r.get('impression')!r} (fabricated)"); ok = False
iw = r.get("impression_waiver") or ""
if not iw or "auto-close" not in iw:
    print(f"    FAIL: impression_waiver missing/empty: {iw!r}"); ok = False
vn = r.get("verdict_note") or ""
if "automatic" not in vn and "auto-close" not in vn:
    print(f"    FAIL: verdict_note does not record the automatic close: {vn[:60]!r}"); ok = False
if r.get("verdict") != "pass":
    print(f"    FAIL: verdict is {r.get('verdict')!r} (expected pass — exit-0+deliverables evidence)"); ok = False
if ok:
    print("    PASS: impression waived by name, no fabricated impression, automatic note, pass on evidence")
else:
    sys.exit(1)
PYEOF
[ $? -ne 0 ] && FAIL=1

# ── D. net not needed when the worker closed ─────────────────────────────
echo "  D. worker closes itself: net reports 'not needed', no double-close, exit 0"
seed_task T8622 findings/T8622-result.json
run_net T8622 "$WORK/stub-closes.py"
S=$(row_status T8622)
if [ "$S" = "done" ] \
   && echo "$NET_OUT" | grep -q "auto-close net: not needed" \
   && ! echo "$NET_OUT" | grep -q "manage done FAILED"; then
    pass "row done by worker; net reported not-needed (no double-close, no spurious failure)"
else
    fail "row status='$S'; expected done + 'not needed' and no FAILED line"
    echo "$NET_OUT" | grep -i "auto-close\|FAILED" | sed 's/^/    | /'
fi

# ── E. degraded run declines out loud (no silent skip) ───────────────────
echo "  E. degraded (no identity): net declines with a reason, not silent"
rm -f untracked/runs/*.json
NET_OUT=$(env -u MANAGENT_TASK_ID "$RUNNER" --no-prepend-zig --no-host-guard \
          --max-wall 20 -- sh -c 'echo hi; sleep 0.2' 2>&1 || true)
if echo "$NET_OUT" | grep -q "auto-close net: declined" \
   && echo "$NET_OUT" | grep -q "no task identity"; then
    pass "degraded run: net said why it declined (no silent skip)"
else
    fail "degraded run: net did not log a decline reason"
    echo "$NET_OUT" | grep -i "auto-close\|no task identity" | sed 's/^/    | /'
fi

# ── F. lane handle: WITH --session records a path; WITHOUT declares unmeasurable ─
echo "  F. lane handle: --session → session_path set; no --session → session_reason set"
export MANAGENT_TASK_ID=T862F
# F1: a lane whose argv carries --session <path> records a session_path.
rm -f untracked/runs/T862F.json
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
    -- sh -c 'exit 0' --session "$WORK/sess-f1.jsonl" >/dev/null 2>&1 || true
SP=$(python3 -c 'import json;print(json.load(open("untracked/runs/T862F.json")).get("session_path") or "")' 2>/dev/null || true)
if [ -n "$SP" ] && echo "$SP" | grep -q "sess-f1.jsonl"; then
    pass "lane WITH --session recorded a session_path ($SP)"
else
    fail "lane WITH --session did not record a session_path (got '$SP')"
fi
# F2: a lane with NO --session declares itself unmeasurable (session_reason).
rm -f untracked/runs/T862F.json
"$RUNNER" --no-prepend-zig --no-host-guard --max-wall 20 \
    -- sh -c 'exit 0' >/dev/null 2>&1 || true
SR=$(python3 -c 'import json;print(json.load(open("untracked/runs/T862F.json")).get("session_reason") or "")' 2>/dev/null || true)
if [ -n "$SR" ]; then
    pass "lane WITHOUT --session declared unmeasurable (session_reason set)"
else
    fail "lane WITHOUT --session left a blank session_reason (the silent-blank defect)"
fi
unset MANAGENT_TASK_ID

# ── isolation: the suite wrote only to scratch ───────────────────────────
echo "  G. isolation: no fixture rows leaked into the live kanban"
LIVE="$PROJECT/docs/infra/managent/tasks.json"
LEAK=$(python3 -c '
import json,sys
try: s=json.load(open(sys.argv[1]))
except Exception: sys.exit(0)
fixtures={"T8620","T8621","T8622","T862F"}
leak=[k for k in s if k in fixtures]
print(",".join(leak) if leak else "")
' "$LIVE" 2>/dev/null || true)
if [ -z "$LEAK" ]; then
    pass "no T862* fixture rows in the live store"
else
    fail "fixture rows leaked into the live store: $LEAK"
fi

# -- H. D085: the nonce check is invocation-confounded ---------------------
# The Orchestrator's amendment (D085): is a model that appears to fail
# protocol compliance actually failing, or is it not being read the same
# way?  The nonce check is `nonce in stdout` (tools/dispatch_verify.py) -- a
# substring search over ALL stdout.  A JSON-mode lane (--mode json) echoes
# the prompt (which CARRIES the nonce) back to stdout, so the nonce appears
# whether or not the model wrote it; a non-JSON lane's stdout is only the
# model's reply.  This arm proves, on the REAL verify_dispatch code path, with
# the SAME model/task/row/deliverable, that the JSON invocation PASSES the
# nonce check from the harness echo alone, while the non-JSON invocation
# FAILS it on identical model behaviour.  Conclusion: the nonce check alone
# measures the HARNESS, not just the model -- a compliance race must gate its
# invocation before attributing 'unreliable protocol compliance' to a model.
echo "  H. D085: nonce check is invocation-confounded (JSON echo passes, bare fails)"
seed_task T8623 findings/T8623-result.json
export MANAGENT_STORE="$STORE" PI_MODEL=glm-5.2 T862_WORK="$WORK"
"$MG" claim T8623 --agent glm-5.2 >/dev/null 2>&1
printf '{"task_id":"T8623","date":"2026-08-24","model":"glm-5.2","claims":[],"new_rows":[]}\n' \
    > findings/T8623-result.json
git add findings/T8623-result.json; git commit -qm "T8623 confound deliverable"
sleep 11  # past the T390 claim-to-done window
"$MG" done T8623 --agent glm-5.2 --status pass \
    --impression-waiver "T862 confound setup" >/dev/null 2>&1
CONF=$(python3 - "$PROJECT" <<'PYEOF'
import sys, os
proj = sys.argv[1]
sys.path.insert(0, os.path.join(proj, "tools"))
import dispatch_verify as dv
store = os.environ["MANAGENT_STORE"]
root = os.environ["T862_WORK"]  # the scratch repo root ($WORK)
nonce = dv.generate_nonce()
prompt = dv.nonce_prompt_lines(nonce)  # carries VERIFY-NONCE: <nonce> ...
dl = ["findings/T8623-result.json"]
ec1, s1, _, _ = dv.verify_dispatch(root=root, task_id="T8623", model="glm-5.2",
    nonce=nonce, stdout=prompt + '{"content":""}', rc=0, deliverables=dl,
    store_env=store)
ec2, s2, _, _ = dv.verify_dispatch(root=root, task_id="T8623", model="glm-5.2",
    nonce=nonce, stdout="done", rc=0, deliverables=dl, store_env=store)
print(f"JSON-echo  -> exit {ec1} | {s1}")
print(f"non-JSON   -> exit {ec2} | {s2}")
print("CONFOUND_CONFIRMED" if (ec1 == 0 and ec2 != 0) else "CONFOUND_NOT_DEMONSTRATED")
PYEOF
)
echo "$CONF" | sed 's/^/    | /'
if echo "$CONF" | grep -q "CONFOUND_CONFIRMED"; then
    pass "nonce verdict differs by invocation (JSON echo passes, bare fails)"
else
    fail "nonce verdict did NOT differ by invocation (confound not demonstrated)"
    FAIL=1
fi
unset MANAGENT_STORE PI_MODEL T862_WORK

if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-one-dispatch-path: PASS ==="
else
    echo "=== regression-one-dispatch-path: FAIL ==="
fi
exit $FAIL