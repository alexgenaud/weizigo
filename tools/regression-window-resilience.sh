#!/usr/bin/env bash
# regression-window-resilience.sh — T628 + T677 controls: the fleet must
# survive a provider 5-hour rolling-window limit without (a) starting
# doomed lanes, (b) scoring the deaths as model failures, or (c) sitting
# idle past the reset — AND (T677) must never arm a family cooldown from
# anything but a terminal RUN RECORD of a lane of that family.
#
# Defect 1 (2026-08-22 12:47Z): five claude lanes (T615/T616/T617/T621/T622)
# died of "You've hit your session limit · resets 3pm (Europe/Oslo)".
# Nothing parsed the reset, nothing stopped re-dispatch into the dead
# window, the deaths scored verified=fail in the ladder, and the fleet sat
# idle past the 13:00Z reset until a human asked (T612's outage row set).
#
# Defect 2 (T677, 2026-08-22 ~21:30Z): the watcher's log-grep fallback
# armed a CLAUDE cooldown from a LIVE DEEPSEEK lane (T653) whose log merely
# QUOTED the provider's limit template (its brief told it to read
# wall-canary-preregistration.md, which quotes "You've hit your session
# limit · resets <time> (Europe/Oslo)" — and the same quoted doc carries
# "tokens: no reading", which the failure-evidence regex matched within
# 400 bytes).  The reset "<time>" did not parse → 6h fallback → armed
# against the wrong family, from a living lane, on a documentation string;
# and because the fallback anchored on the live log's moving mtime, the
# lockout extended itself on every dispatch.
#
# The fix (T677) is the same architectural correction T625/T630 applied to
# the refusal classifier, applied here:
#   1. a cooldown arms ONLY from a run record showing a provider-limit
#      death of THAT family (T628 stamp / T629 killed_by=provider-limit);
#      the worker log is never read;
#   2. a lane with no terminal record (no exit/end — still running) is not
#      a death and arms nothing;
#   3. an unparseable reset arms a SHORT death-anchored fallback (30 min,
#      WEIZIGO_WINDOW_FALLBACK_SECONDS) and the existing watch() nudge +
#      one-lane probe re-checks the provider — verify, don't assume a
#      six-hour lockout;
#   4. bin/dispatch carries a deliberate recorded override,
#      --override-window-cooldown=<reason>, appended to
#      untracked/fleet-window-overrides.jsonl.
#
# Controls (hermetic — scratch repo under /tmp/weizigo, scratch
# MANAGENT_STORE / WEIZIGO_MODEL_PERF / WEIZIGO_DISPATCH_HEALS; the live
# kanban and ledger are never touched):
#   A1  seeded  a genuine claude provider-limit death recorded as
#               killed_by=provider-limit + "resets 3pm (Europe/Oslo)"
#               parses the reset and arms claude until 13:00Z
#               (RED on 2026-08-22 code: 6h fallback instead of the parse)
#   A2  seeded  the T628 stamp (provider_reset_epoch) is authoritative
#   A3  seeded  watch() schedules the nudge at reset and probes after
#   A4  seeded  dispatch refuses claude in cooldown (reset named),
#               deepseek unaffected
#   A5  seeded  provider-limit death reopens as provider-outage, never
#               verified=fail (the dispatch_verify D021 classifier — the
#               row-reopen arm of T628, kept verbatim)
#   B1  seeded  THE T677 CASE: a live deepseek lane (record with no
#               exit/end) whose log quotes the limit template → NO claude
#               cooldown, claude dispatch proceeds (RED on 2026-08-22
#               code: whole family refused — quoted)
#   B2  null    a transcript that merely QUOTES a limit message triggers
#               nothing (no run record at all)
#   B3  null    empty records+logs → no cooldown, SPEND, dispatch proceeds
#   C1  anticipation  near-exhausted meter refuses an over-budget claude
#               lane at dispatch with an honest reason; deepseek unaffected
#   C2  seeded  a claude lane that died of a WATCHDOG kill (record
#               killed_by=watchdog, log quoting a limit message) → NO
#               cooldown (RED on 2026-08-22 code: the log armed it)
#   C3  seeded  a claude lane that died of a WALL kill (exit 124,
#               killed_by=wall, log quoting a limit message) → NO cooldown
#   C4  seeded  a DEEPSEEK lane that died of provider-limit → NO claude
#               cooldown (family from the record's model, never proximity)
#   D1  seeded  an unparseable reset → fallback cooldown (death-anchored,
#               fallback=True, horizon 1800s) and the dispatch refusal
#               says so and names the override
#   D2  seeded  --override-window-cooldown=<reason> records the reason
#               and proceeds; a bare flag without a reason is refused
#   F1  seeded  (T736) the BUDGET refusal has the same recorded override:
#               --override-window-budget=<reason> (kind=budget in the same
#               jsonl), the refusal names the override path, a bare flag
#               without a reason is refused, and the budget flag NEVER
#               bypasses the cooldown gate
#
# Test-first (T628/T677): against the 2026-08-22 code the B1/C2/C3/D1/D2
# arms FAIL (quote the red), the null arms pass, and after the fix all
# arms pass.
#
# Task: T677 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../tools/lib/scratch-repo.sh"   # T873: weizigo_reset_census for direct store writes
ROOT="$(cd "$HERE/.." && pwd)"
DISPATCH="$ROOT/bin/dispatch"
MG=""
if [ -x "$ROOT/zig-out/bin/managent" ]; then
    MG="$ROOT/zig-out/bin/managent"
elif [ -x "$ROOT/bin/managent" ]; then
    MG="$ROOT/bin/managent"
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy"
    exit 0
fi
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t677-window-XXXXXX)" || { echo "regression-window-resilience.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t677@test
git config user.name T677
echo base > README.md
mkdir -p docs/infra/managent untracked/log untracked/runs findings
printf 'untracked/\n' > .gitignore
git add -A
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"
export ROOT WORK STORE
unset WEIZIGO_AGENT_DEPTH || true

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# ── scratch-store row seeds (the shapes the live store uses) ─────────────
rec_disp() {
    printf '"%s":{"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}
rec_inprog() {
    printf '"%s":{"status":"in_progress","agent":"t628","model":"claude-sonnet-5","bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}
seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
    weizigo_reset_census "$STORE"   # T873: direct write bypasses the S10 census
}
mkbundle() {  # $1 = task id — title gate (T505) needs a <40-char title
    cat > "untracked/$1-bundle.md" <<EOF
<!--managent set=A deliverables=findings/$1.json-->
# $1 — window resilience seeded
**Landmark:** advances \`L1 (dispatch tooling)\` — fixture

Seeded fixture bundle for the T628/T677 window-resilience regression.
EOF
}
# clear previous arms' fixtures (each arm seeds its own)
clear_fixtures() {
    rm -f untracked/log/t*.log untracked/runs/*.json untracked/fleet-window.json \
          untracked/fleet-window-overrides.jsonl
}

echo "=== regression-window-resilience (T628 + T677) ==="

# ── A1. seeded: genuine claude death, killed_by + parseable reset text ───
# A record in the T629 vocabulary (killed_by=provider-limit) with the
# provider's "resets 3pm (Europe/Oslo)" in provider_reset_text: the
# watcher parses the reset (13:00Z in CEST) and arms claude until then.
echo "  A1. seeded: killed_by=provider-limit + 'resets 3pm (Europe/Oslo)' -> cooldown until 13:00Z"
clear_fixtures
seed "$(rec_disp T6771)"
python3 - <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
RESET = 1787403600  # 2026-08-22T13:00:00Z
NOW = 1787402820    # 2026-08-22T12:47:00Z (the incident clock)
death_end = "2026-08-22T12:47:46Z"
rec = {
    "task": "T6771", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 991, "start_epoch": NOW - 600, "wall": 300,
    "end": death_end, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6771.json"), "w") as f:
    json.dump(rec, f)
cds = window_policy.family_cooldown(os.environ["WORK"], now=NOW)
c = cds.get("claude")
ok = c is not None and c.get("until") == RESET and not c.get("fallback")
print("    cooldowns=%s" % cds)
print("    claude until %s (expected %s) fallback=%s — %s"
      % (c and c.get("until"), RESET, c and c.get("fallback"), "PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: killed_by record + reset text arms claude until the parsed reset"
else
    echo "    FAIL: killed_by record did not arm claude to the parsed reset (2026-08-22 code: 6h fallback)"
    FAIL=1
fi

# ── A2. seeded: the T628 stamp (provider_reset_epoch) is authoritative ───
echo "  A2. seeded: T628 stamp provider_reset_epoch arms claude until the stamp"
clear_fixtures
seed "$(rec_disp T6772)"
python3 - <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
NOW = 1787402820
FUTURE = 1787410000  # a stamped reset in the future
rec = {
    "task": "T6772", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 992, "start_epoch": NOW - 600, "wall": 300,
    "end": "2026-08-22T12:47:46Z", "exit": 1, "killed_by": "provider-limit",
    "provider_limit": "claude-session",
    "provider_reset_epoch": FUTURE,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6772.json"), "w") as f:
    json.dump(rec, f)
cds = window_policy.family_cooldown(os.environ["WORK"], now=NOW)
c = cds.get("claude")
ok = c is not None and c.get("until") == FUTURE
print("    claude until %s (expected stamp %s) — %s" % (c and c.get("until"), FUTURE, "PASS" if ok else "FAIL"))
sys.exit(0 if ok else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: stamp epoch is authoritative"
else
    echo "    FAIL: stamp epoch ignored or wrong"
    FAIL=1
fi

# ── A3. seeded: watch() schedules the nudge at reset, probes after ───────
echo "  A3. seeded: watch() schedules the nudge at reset+jitter and enters probe mode after"
clear_fixtures
seed "$(rec_disp T6773)"
python3 - <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
NOW = 1787402820
FUTURE = 1787403600  # 13:00Z
rec = {
    "task": "T6773", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 993, "start_epoch": NOW - 600, "wall": 300,
    "end": "2026-08-22T12:47:46Z", "exit": 1, "killed_by": "provider-limit",
    "provider_reset_epoch": FUTURE,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6773.json"), "w") as f:
    json.dump(rec, f)
ev1 = window_policy.watch(os.environ["WORK"], now=NOW, jitter_max=0)
st = window_policy.load_state(os.environ["WORK"]).get("claude") or {}
nudged_ok = st.get("nudge_at") == FUTURE and not st.get("nudged")
ev2 = window_policy.watch(os.environ["WORK"], now=FUTURE, jitter_max=0)
st2 = window_policy.load_state(os.environ["WORK"]).get("claude") or {}
probe_ok = st2.get("nudged") is True and st2.get("probe_until") is not None
# T873/R19: effective_cap was retired by T766 (cf7fc68, the predictive
# window-budget gate is gone). The probe mechanism survives; assert probe
# state via the surviving API instead of the retired cap-sizing.
probe_active_ok = window_policy.probe_active("claude", os.environ["WORK"], now=FUTURE)
print("    armed events: %s" % ev1)
print("    reset events: %s" % ev2)
print("    nudge_at ok=%s probe ok=%s probe_active=%s" % (nudged_ok, probe_ok, probe_active_ok))
sys.exit(0 if (nudged_ok and probe_ok and probe_active_ok) else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: nudge scheduled at reset, fired at reset+jitter, probe active"
else
    echo "    FAIL: nudge/probe state machine wrong"
    FAIL=1
fi

# ── A4. seeded: dispatch refuses claude in cooldown, deepseek unaffected ─
echo "  A4. seeded: window cooldown (stamped future reset) -> claude refused at dispatch, deepseek proceeds"
clear_fixtures
seed "$(rec_disp T6774)"
mkbundle T6774
FUTURE=$(python3 -c "import time; print(int(time.time()) + 7200)")
python3 - "$FUTURE" <<'PYEOF'
import json, os, sys
future = int(sys.argv[1])
rec = {
    "task": "T6774", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 998, "start_epoch": future - 600, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_limit": "claude-session",
    "provider_reset_epoch": future,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6774.json"), "w") as f:
    json.dump(rec, f)
PYEOF
OUT=$(cd "$WORK" && "$DISPATCH" T6774 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
DOUT=$(cd "$WORK" && "$DISPATCH" T6774 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
DRC=$?
if [ "$CRC" -eq 1 ] && printf '%s' "$OUT" | grep -qi 'REFUSED' \
   && printf '%s' "$OUT" | grep -qi 'cooldown' \
   && printf '%s' "$OUT" | grep -q 'resets 3pm' \
   && [ "$DRC" -eq 0 ] && printf '%s' "$DOUT" | grep -q 'dry-run T6774'; then
    echo "    PASS: claude refused (cooldown, reset named); deepseek unaffected"
else
    echo "    FAIL: claude_rc=$CRC deepseek_rc=$DRC; expected claude REFUSED (cooldown, reset) and deepseek dry-run rc=0"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi

# ── A5. seeded: provider-limit death reopens as provider-outage, never ───
# a model failure (T628 acceptance clause, kept verbatim: the D021
# classifier + the dispatcher's sole-owner heal).
if [ -f "$ROOT/untracked/log/t617.log" ]; then
    echo "  A5. seeded: provider-limit death reopens as provider-outage (never verified=fail)"
    clear_fixtures
    seed "$(rec_inprog T6775)"
    cp "$ROOT/untracked/log/t617.log" untracked/log/t6775.log
    python3 - "$STORE" <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import dispatch_verify  # noqa: E402
root = os.environ["WORK"]
store = os.environ["STORE"]
nonce = "NONCE-" + "0" * 16
code, summary, details, perf = dispatch_verify.verify_dispatch(
    root=root, task_id="T6775", model="claude-sonnet-5", nonce=nonce,
    stdout="", rc=1, store_env=store, deliverables=[])
dispatch_verify.record_perf(root, perf)
healed, line = dispatch_verify.heal_dispatch(
    root=root, real_root=os.environ["ROOT"], task_id="T6775",
    model="claude-sonnet-5", rc=1, wall_seconds=540.0, store_env=store)
rows = json.load(open(store))
status = rows["T6775"]["status"]
ok = (perf[3] == "unreached" and perf[4] == "provider-429"
      and healed and status == "dispatchable")
sys.exit(0 if ok else 1)
PYEOF
    if [ $? -eq 0 ] && ! grep -q "T6775.*verified=fail" "$WEIZIGO_MODEL_PERF" \
       && grep -q "T6775.*verified=unreached reason=provider-429" "$WEIZIGO_MODEL_PERF"; then
        echo "    PASS: classified unreached provider-429, row reopened to dispatchable, no fail row"
    else
        echo "    FAIL: classification/heal/ledger wrong"
        cat "$WEIZIGO_MODEL_PERF" | sed 's/^/      | /'
        FAIL=1
    fi
else
    echo "  SKIP A5: real t617 fixture log absent (fresh clone)"
fi

# ── B1. seeded (T677 headline): live deepseek lane quoting the limit ─────
# template arms NO claude cooldown.  Uses the REAL t653 log (a deepseek
# lane that is still running and quotes wall-canary-preregistration.md)
# plus a live run record (no exit/end).  RED on 2026-08-22 code — the
# whole claude family was refused — quoted in findings/T677-*.json.
if [ -f "$ROOT/untracked/log/t653.log" ]; then
    echo "  B1. seeded: live deepseek lane (no terminal record) quoting the limit template -> no claude cooldown"
    clear_fixtures
    seed "$(rec_disp T6776)"
    mkbundle T6776
    cp "$ROOT/untracked/log/t653.log" untracked/log/t653.log
    python3 - <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
# a LIVE lane: the runner has not finalized it — no exit, no end
rec = {
    "task": "T653", "attempt": 1, "model": "deepseek-v4-pro",
    "pid": 6688, "start_epoch": 1787428921, "wall": 5400,
    "start": "2026-08-22T20:02:01Z", "end": None, "exit": None,
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "T653.json"), "w") as f:
    json.dump(rec, f)
cds = window_policy.family_cooldown(os.environ["WORK"])
print("    cooldowns=%s" % cds)
sys.exit(0 if cds.get("claude") is None else 1)
PYEOF
    PYOK=$?
    OUT=$(cd "$WORK" && "$DISPATCH" T6776 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
    CRC=$?
    if [ "$PYOK" -eq 0 ] && [ "$CRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'dry-run T6776'; then
        echo "    PASS: no cooldown from a live lane's log quote; claude dispatch proceeds"
    else
        echo "    FAIL: pyok=$PYOK claude_rc=$CRC — the live deepseek log armed a claude cooldown (the T677 defect)"
        printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
        FAIL=1
    fi
else
    echo "  SKIP B1: real t653 fixture log absent (fresh clone)"
fi

# ── B2. null: a transcript that merely QUOTES a limit message triggers ───
# nothing.  (No run record at all — the quote sits in a worker log that
# the watcher must never read.)
echo "  B2. null: quoted limit message, no run record -> nothing armed"
clear_fixtures
python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
quote = ("I read the T628 brief, which mentions the provider message "
         "'You've hit your session limit · resets 3pm (Europe/Oslo)' in prose. "
         "That is a quote from a document, not my terminal state. "
         "[verify] worker exited rc=1 verification FAILED\n")
open(os.path.join(os.environ["WORK"], "untracked", "log", "t6777.log"), "w").write(quote)
cds = window_policy.family_cooldown(os.environ["WORK"], now=1787402820)
print("    cooldowns -> %s" % cds)
sys.exit(0 if not cds else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: quote alone triggers nothing (null stays red)"
else
    echo "    FAIL: a quoted limit message armed the cooldown — the null control must stay red"
    FAIL=1
fi

# ── B3. null: empty store → nothing armed; dispatch proceeds unchanged ───
echo "  B3. null: empty records+logs → no cooldown, SPEND level, dispatch dry-runs unchanged"
clear_fixtures
seed "$(rec_disp T6778)"
mkbundle T6778
python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
# T873/R19: meter_level was retired by T766 (cf7fc68). The appetite
# meter (HARD-OFF/CONSERVE/SPEND) is gone; regulation is COOLDOWN-only.
cds = window_policy.family_cooldown(os.environ["WORK"], now=1787402820)
print("    cooldowns=%s" % (cds,))
sys.exit(0 if not cds else 1)
PYEOF
PYOK=$?
OUT=$(cd "$WORK" && "$DISPATCH" T6778 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
DOUT=$(cd "$WORK" && "$DISPATCH" T6778 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
DRC=$?
if [ "$PYOK" -eq 0 ] && [ "$CRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'dry-run T6778' \
   && [ "$DRC" -eq 0 ] && printf '%s' "$DOUT" | grep -q 'dry-run T6778'; then
    echo "    PASS: nothing armed; claude and deepseek dry-runs proceed unchanged"
else
    echo "    FAIL: pyok=$PYOK claude_rc=$CRC deepseek_rc=$DRC; expected empty cooldowns + both dry-runs rc=0"
    FAIL=1
fi

# ── C1. anticipation: near-exhausted meter refuses an over-budget claude ─
# lane at dispatch with an honest reason; a deepseek lane is unaffected.
echo "  C1. retired budget gate (T766): near-exhausted meter no longer refuses; claude proceeds, deepseek proceeds"
clear_fixtures
seed "$(rec_disp T6779)"
mkbundle T6779
NOWEPOCH=$(python3 -c "import time; print(int(time.time()))")
python3 - "$NOWEPOCH" <<'PYEOF'
import json, os, sys
now = int(sys.argv[1])
for i, ti in enumerate((3000, 3000)):
    tid = "T679%d" % (i + 1)
    rec = {
        "task": tid, "attempt": 1, "model": "claude-sonnet-5",
        "pid": 999, "start_epoch": now - 600, "wall": 300,
        "end": None, "exit": 0,
        "tokens_in": ti, "tokens_out": 400,
        "tokens_fresh": 10, "tokens_cache_read": ti - 10,
        "tokens_source": "claude-json-envelope",
    }
    with open(os.path.join(os.environ["WORK"], "untracked", "runs", tid + ".json"), "w") as f:
        json.dump(rec, f)
PYEOF
OUT=$(cd "$WORK" && WEIZIGO_WINDOW_BUDGET_CLAUDE=5000 "$DISPATCH" T6779 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
DOUT=$(cd "$WORK" && WEIZIGO_WINDOW_BUDGET_CLAUDE=5000 "$DISPATCH" T6779 deepseek-v4-flash --test-root="$WORK" --dry-run 2>&1)
DRC=$?
# T873/R19: T766 (cf7fc68) retired the predictive window-budget gate —
# WEIZIGO_WINDOW_BUDGET_CLAUDE is no longer read, so a near-exhausted meter
# must NOT refuse. Both lanes dry-run through, the honest post-T766 behavior.
if [ "$CRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'dry-run T6779' \
   && [ "$DRC" -eq 0 ] && printf '%s' "$DOUT" | grep -q 'dry-run T6779'; then
    echo "    PASS: retired budget gate does not refuse (claude rc=0, deepseek rc=0)"
else
    echo "    FAIL: claude_rc=$CRC deepseek_rc=$DRC; expected both dry-runs rc=0 (budget gate retired by T766)"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi

# ── C2. seeded: a claude lane that died of a WATCHDOG kill → no cooldown ─
# The T616 shape: the record says watchdog; the LOG quotes a limit message.
# The record is the terminal truth (T677): a wall/watchdog kill is not a
# provider-limit death, whatever the log says.  RED on 2026-08-22 code
# (the log armed it).
echo "  C2. seeded: claude watchdog-killed lane (record killed_by=watchdog, log quotes limit) -> no cooldown"
clear_fixtures
seed "$(rec_disp T6791)"
python3 - <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
now = int(time.time())
rec = {
    "task": "T6791", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 994, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": None,
    "killed": "progress timeout 600s (10'00) — no [progress] for 600s",
    "killed_by": "watchdog",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6791.json"), "w") as f:
    json.dump(rec, f)
log = ("provider message: 'You've hit your session limit · resets 3pm (Europe/Oslo)' "
       "was quoted in the brief.\n[verify] worker exited rc=1 verification FAILED\n")
open(os.path.join(os.environ["WORK"], "untracked", "log", "t6791.log"), "w").write(log)
cds = window_policy.family_cooldown(os.environ["WORK"])
print("    cooldowns=%s" % cds)
sys.exit(0 if cds.get("claude") is None else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: watchdog-killed lane arms nothing (record wins over log)"
else
    echo "    FAIL: a watchdog-killed lane armed the cooldown from its log — the record must win"
    FAIL=1
fi

# ── C3. seeded: a claude lane that died of a WALL kill → no cooldown ─────
echo "  C3. seeded: claude wall-killed lane (exit 124, killed_by=wall, log quotes limit) -> no cooldown"
clear_fixtures
seed "$(rec_disp T6792)"
python3 - <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
now = int(time.time())
rec = {
    "task": "T6792", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 995, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": 124, "killed_by": "wall",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6792.json"), "w") as f:
    json.dump(rec, f)
log = ("provider message: 'You've hit your session limit · resets 3pm (Europe/Oslo)' "
       "was quoted in the brief.\n[verify] worker exited rc=1 verification FAILED\n")
open(os.path.join(os.environ["WORK"], "untracked", "log", "t6792.log"), "w").write(log)
cds = window_policy.family_cooldown(os.environ["WORK"])
print("    cooldowns=%s" % cds)
sys.exit(0 if cds.get("claude") is None else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: wall-killed lane arms nothing"
else
    echo "    FAIL: a wall-killed lane armed the cooldown from its log"
    FAIL=1
fi

# ── C4. seeded: a DEEPSEEK provider-limit death → no claude cooldown ─────
# Family comes from the dying record's own model field (T677 defect a),
# never from proximity or from what the log happens to contain.
echo "  C4. seeded: deepseek provider-limit death -> no claude cooldown (family from the record)"
clear_fixtures
seed "$(rec_disp T6793)"
python3 - <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
now = int(time.time())
rec = {
    "task": "T6793", "attempt": 1, "model": "deepseek-v4-pro",
    "pid": 996, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_epoch": now + 3600,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6793.json"), "w") as f:
    json.dump(rec, f)
cds = window_policy.family_cooldown(os.environ["WORK"])
print("    cooldowns=%s" % cds)
# the deepseek death may arm family 'other' (inert — dispatch gates only
# claude); what it must NEVER arm is claude.
sys.exit(0 if cds.get("claude") is None else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: deepseek death does not arm claude"
else
    echo "    FAIL: a deepseek death armed the claude cooldown — attribution is broken"
    FAIL=1
fi

# ── D1. seeded: unparseable reset → death-anchored fallback + probe ──────
# The provider template "resets <time> (Europe/Oslo)" (what T653's log
# quoted) does not parse.  The 2026-08-22 code armed a 6h fallback from
# NOW (sliding — the self-extension).  T677: arm for the short fallback
# horizon anchored to the DEATH (stable, no self-extension) and let the
# watch() nudge + one-lane probe verify the provider instead of assuming
# a six-hour lockout.
echo "  D1. seeded: unparseable reset -> fallback cooldown (death-anchored, 1800s)"
clear_fixtures
seed "$(rec_disp T6794)"
python3 - <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
NOW = 1787402820
DEATH = NOW - 300
rec = {
    "task": "T6794", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 997, "start_epoch": DEATH - 300, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_text": "resets <time> (Europe/Oslo)",  # the unparseable template
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6794.json"), "w") as f:
    json.dump(rec, f)
# anchor: end missing -> start_epoch+wall = DEATH (start_epoch = DEATH - 300, wall = 300)
cds = window_policy.family_cooldown(os.environ["WORK"], now=NOW)
c = cds.get("claude")
fb = window_policy.fallback_cooldown_seconds()
ok = (c is not None and c.get("fallback") is True
      and c.get("until") == DEATH + fb)
print("    fallback_seconds=%s until=%s death+fb=%s fallback=%s — %s"
      % (fb, c and c.get("until"), DEATH + fb, c and c.get("fallback"), "PASS" if ok else "FAIL"))
# the fallback does not slide: re-deriving at a later now keeps the same until
cds2 = window_policy.family_cooldown(os.environ["WORK"], now=NOW + 900)
c2 = cds2.get("claude")
stable = c2 is not None and c2.get("until") == c.get("until")
print("    re-derived at now+900s keeps until %s (stable=%s)" % (c2 and c2.get("until"), stable))
sys.exit(0 if (ok and stable) else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS: fallback cooldown death-anchored, stable, horizon 1800s"
else
    echo "    FAIL: fallback cooldown wrong (2026-08-22 code: 6h sliding from now)"
    FAIL=1
fi

# ── D2. seeded: the recorded override on bin/dispatch ────────────────────
# A deliberate escape hatch in the --allow-unisolated spirit: reason-
# required, appended to untracked/fleet-window-overrides.jsonl, loud.
echo "  D2. seeded: --override-window-cooldown=<reason> records the reason and proceeds"
clear_fixtures
seed "$(rec_disp T6795)"
mkbundle T6795
python3 - <<'PYEOF'
import json, os, sys, time
sys.path.insert(0, os.environ["ROOT"] + "/tools")
now = int(time.time())
rec = {
    "task": "T6795", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 990, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_text": "resets <time> (Europe/Oslo)",  # unparseable -> fallback active
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6795.json"), "w") as f:
    json.dump(rec, f)
PYEOF
# (a) without the override the fallback cooldown refuses, naming the probe
OUT=$(cd "$WORK" && "$DISPATCH" T6795 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
if [ "$CRC" -eq 1 ] && printf '%s' "$OUT" | grep -qi 'REFUSED' \
   && printf '%s' "$OUT" | grep -qi 'cooldown' \
   && printf '%s' "$OUT" | grep -qi 'fallback'; then
    echo "    PASS(a): fallback cooldown refuses with the fallback wording"
else
    echo "    FAIL(a): claude_rc=$CRC — expected REFUSED naming the fallback; got:"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi
# (b) with the override, dispatch proceeds (dry-run) and warns loudly
OV=$(cd "$WORK" && "$DISPATCH" T6795 claude-sonnet-5 --test-root="$WORK" --dry-run \
    --override-window-cooldown="operator checked provider dashboard manually" 2>&1)
OVRC=$?
if [ "$OVRC" -eq 0 ] && printf '%s' "$OV" | grep -q 'dry-run T6795' \
   && printf '%s' "$OV" | grep -qi 'OVERRIDDEN'; then
    echo "    PASS(b): override proceeds (dry-run) with a loud warning"
else
    echo "    FAIL(b): override_rc=$OVRC — expected dry-run rc=0 + OVERRIDDEN warning; got:"
    printf '%s' "$OV" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi
# (c) the record is append-only with the reason (recorded by window_policy;
# a dry-run does not write — the decision is only recorded when it executes)
python3 - <<'PYEOF'
import json, os, sys
sys.path.insert(0, os.environ["ROOT"] + "/tools")
import window_policy  # noqa: E402
root = os.environ["WORK"]
cds = window_policy.family_cooldown(root)
c = cds.get("claude") or {}
p = window_policy.record_override(root, "T6795", "claude", c,
                                  "operator checked provider dashboard manually")
lines = open(p).read().splitlines()
ok = len(lines) == 1
if ok:
    rec = json.loads(lines[0])
    ok = rec["reason"] == "operator checked provider dashboard manually" \
         and rec["family"] == "claude" and rec["task"] == "T6795"
print("    override record: %s" % (lines[0] if lines else "(none)"))
sys.exit(0 if ok else 1)
PYEOF
if [ $? -eq 0 ]; then
    echo "    PASS(c): override recorded append-only with the reason"
else
    echo "    FAIL(c): override record missing or wrong"
    FAIL=1
fi
# (d) a bare flag without a reason is refused (reason-required)
OUT=$(cd "$WORK" && "$DISPATCH" T6795 claude-sonnet-5 --test-root="$WORK" --dry-run --override-window-cooldown 2>&1)
DRC=$?
if [ "$DRC" -eq 1 ] && printf '%s' "$OUT" | grep -qi 'requires a reason'; then
    echo "    PASS(d): bare override flag without a reason is refused"
else
    echo "    FAIL(d): bare override rc=$DRC — expected usage refusal naming the reason requirement"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -4
    FAIL=1
fi

# ── F1. (T766): the predictive window-budget gate is RETIRED ──────────
# T766 (cf7fc68) deleted the T736 token-budget meter from window_policy.py
# and removed --override-window-budget handling from bin/dispatch. This arm
# validates the retirement: (a) a near-exhausted meter no longer refuses a
# claude dispatch; (b) --override-window-budget is no longer a recognized
# flag (dispatch refuses with a usage/unknown-argument error, not a budget
# verdict); (c) the cooldown gate T766 KEPT still refuses a claude lane in
# cooldown on its own — the two are independent and the cooldown stands.
echo "  F1. retired budget gate (T766): no refusal, override flag gone, cooldown stands"
clear_fixtures
seed "$(rec_disp T7361)"
mkbundle T7361
NOWEPOCH=$(python3 -c "import time; print(int(time.time()))")
python3 - "$NOWEPOCH" <<'PYEOF'
import json, os, sys
now = int(sys.argv[1])
for i, ti in enumerate((3000, 3000)):
    tid = "T736%d" % (i + 1)
    rec = {
        "task": tid, "attempt": 1, "model": "claude-sonnet-5",
        "pid": 999, "start_epoch": now - 600, "wall": 300,
        "end": None, "exit": 0,
        "tokens_in": ti, "tokens_out": 400,
        "tokens_fresh": 10, "tokens_cache_read": ti - 10,
        "tokens_source": "claude-json-envelope",
    }
    with open(os.path.join(os.environ["WORK"], "untracked", "runs", tid + ".json"), "w") as f:
        json.dump(rec, f)
PYEOF
# (a) the budget gate no longer refuses — claude dry-runs through even with
#     a near-exhausted meter and WEIZIGO_WINDOW_BUDGET_CLAUDE set.
OUT=$(cd "$WORK" && WEIZIGO_WINDOW_BUDGET_CLAUDE=5000 "$DISPATCH" T7361 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
if [ "$CRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'dry-run T7361'    && ! printf '%s' "$OUT" | grep -qi 'window budget'; then
    echo "    PASS(a): retired budget gate does not refuse (claude dry-run rc=0, no budget verdict)"
else
    echo "    FAIL(a): claude_rc=$CRC — expected dry-run rc=0 with no budget refusal (gate retired by T766); got:"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi
# (b) --override-window-budget is no longer a recognized flag.
OVR=$(cd "$WORK" && "$DISPATCH" T7361 claude-sonnet-5 --test-root="$WORK" --dry-run \
    --override-window-budget="operator checked" 2>&1)
OVRRC=$?
if [ "$OVRRC" -ne 0 ] && printf '%s' "$OVR" | grep -qi 'usage\|unknown\|unrecognized\|override-window-budget'; then
    echo "    PASS(b): --override-window-budget is no longer recognized (rc=$OVRRC)"
else
    echo "    FAIL(b): override rc=$OVRRC — expected the flag to be rejected (removed by T766); got:"
    printf '%s' "$OVR" | sed 's/^/      claude | /' | tail -4
    FAIL=1
fi
# (c) the cooldown gate T766 kept still refuses a claude lane in cooldown,
#     independent of the retired budget gate.
clear_fixtures
seed "$(rec_disp T7362)"
mkbundle T7362
python3 - <<'PYEOF'
import json, os, sys, time
now = int(time.time())
rec = {
    "task": "T7362", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 988, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_epoch": now + 7200,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t7362.json"), "w") as f:
    json.dump(rec, f)
PYEOF
OUT=$(cd "$WORK" && "$DISPATCH" T7362 claude-sonnet-5 --test-root="$WORK" --dry-run 2>&1)
CRC=$?
if [ "$CRC" -eq 1 ] && printf '%s' "$OUT" | grep -qi 'REFUSED' \
   && printf '%s' "$OUT" | grep -qi 'cooldown'; then
    echo "    PASS(c): cooldown gate still refuses a claude lane in cooldown (stands without the budget gate)"
else
    echo "    FAIL(c): claude_rc=$CRC — expected REFUSED (cooldown); got:"
    printf '%s' "$OUT" | sed 's/^/      claude | /' | tail -6
    FAIL=1
fi

# ── E1. seeded (D040/T612): the cooldown is ENFORCED at bin/subagent ──
# — the real launch chokepoint.  Tonight's probe lane went around
# bin/dispatch via subagent; a gate only in dispatch is advisory.  A
# cooldown active at the record level refuses a claude subagent launch,
# and the same reason-required override proceeds.
echo "  E1. seeded: window cooldown enforced at bin/subagent (the real chokepoint), override proceeds"
clear_fixtures
seed "$(rec_disp T6796)"
mkbundle T6796
SUBAGENT="$ROOT/bin/subagent"
python3 - <<'PYEOF'
import json, os, sys, time
now = int(time.time())
rec = {
    "task": "T6796", "attempt": 1, "model": "claude-sonnet-5",
    "pid": 989, "start_epoch": now - 600, "wall": 300,
    "end": None, "exit": 1, "killed_by": "provider-limit",
    "provider_reset_epoch": now + 7200,
    "provider_reset_text": "resets 3pm (Europe/Oslo)",
}
with open(os.path.join(os.environ["WORK"], "untracked", "runs", "t6796.json"), "w") as f:
    json.dump(rec, f)
PYEOF
# (a) subagent refuses a claude launch during the cooldown
OUT=$(cd "$WORK" && "$SUBAGENT" --provider claude --model claude-sonnet-5 --wall 60 --dry-run --test-root="$WORK" T6796 2>&1)
SRC=$?
if [ "$SRC" -eq 1 ] && printf '%s' "$OUT" | grep -qi 'REFUSED' \
   && printf '%s' "$OUT" | grep -qi 'cooldown' \
   && printf '%s' "$OUT" | grep -qi 'ENFORCED at subagent'; then
    echo "    PASS(a): subagent refuses a claude launch during the cooldown (enforcement at the chokepoint)"
else
    echo "    FAIL(a): subagent_rc=$SRC — expected REFUSED (cooldown, ENFORCED at subagent); got:"
    printf '%s' "$OUT" | sed 's/^/      subagent | /' | tail -6
    FAIL=1
fi
# (b) the recorded override proceeds (dry-run, loud warning)
OUT=$(cd "$WORK" && "$SUBAGENT" --provider claude --model claude-sonnet-5 --wall 60 --dry-run --test-root="$WORK" --override-window-cooldown="operator checked the provider dashboard" T6796 2>&1)
SRC=$?
if [ "$SRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'claude -p' \
   && printf '%s' "$OUT" | grep -qi 'OVERRIDDEN'; then
    echo "    PASS(b): override proceeds through subagent with the loud warning"
else
    echo "    FAIL(b): subagent_rc=$SRC — expected dry-run rc=0 (claude -p line) + OVERRIDDEN; got:"
    printf '%s' "$OUT" | sed 's/^/      subagent | /' | tail -6
    FAIL=1
fi
# (c) deepseek is unaffected during the claude cooldown (family attribution)
OUT=$(cd "$WORK" && "$SUBAGENT" --provider deepseek --dspro --wall 60 --dry-run --test-root="$WORK" T6796 2>&1)
SRC=$?
if [ "$SRC" -eq 0 ] && printf '%s' "$OUT" | grep -q 'pi --provider deepseek'; then
    echo "    PASS(c): deepseek subagent launch unaffected by the claude cooldown"
else
    echo "    FAIL(c): subagent_rc=$SRC — deepseek should proceed; got:"
    printf '%s' "$OUT" | sed 's/^/      subagent | /' | tail -6
    FAIL=1
fi

# ── cleanup + verdict ─────────────────────────────────────────────────────
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-window-resilience: all controls passed ==="
    exit 0
else
    echo "=== regression-window-resilience: FAILURES (see above) ==="
    exit 1
fi
