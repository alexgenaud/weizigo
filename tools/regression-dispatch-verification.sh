#!/usr/bin/env bash
# regression-dispatch-verification.sh — T411 controls for the dispatchers' work verification
#
# T513 (F4, 2026-08-20): re-pinned to HEAD. The regression runs the COMMITTED
# dispatch contract (bin/subagent, bin/ollama-subagent, tools/dispatch_verify.py
# extracted from HEAD into scratch), not the live working-tree file, so a live
# uncommitted edit cannot pass this gate against a contract the commit did
# not record. The substrate the contract depends on (managent, claimlint — the
# T485 done-gate) is symlinked into the scratch repo root. Arms 7/8/9 were
# reconciled with the T485 done-gate: a closing task's OWN malformed findings is
# now caught by the done-gate (refusing the close), so the dispatch-verify
# findings parse is exercised as the PRIMARY defense via BARE-FILE dispatches
# (no kanban row, no done-gate). Arm 10 asserts the sole-owner invariant (F4):
# every heal assertion record carries healed_by=dispatcher — the dispatcher
# is the one automatic heal-reopen owner in any shipped script.
#
# T408's kimi incident (2026-08-07): dispatched a four-command kanban bundle,
# got exactly "OK.", and the agent executed NOTHING. The row stayed
# `dispatchable`. It was caught only because the probe asserted on STORE
# STATE rather than on the reply — had it trusted the response, as almost
# every dispatch in this project does, it would have recorded a pass.
#
# These controls make the fix permanent. A reply is a claim; a changed
# file, a store row, or a computed value is evidence. The dispatchers now
# inject a random nonce into the prompt, capture the worker's stdout, and
# after the worker returns verify: (1) the nonce is echoed, (2) every
# declared deliverable exists, (3) the kanban row left `dispatchable`.
# The worker's text is trusted in neither direction.
#
#   seeded     a stub worker that prints "OK." and does nothing — the exact
#              incident, reproduced mechanically. The dispatcher MUST fail
#              it (rc != 0, "verification FAILED", row still open), and the
#              perf ledger must record verified=fail. Run through BOTH
#              dispatchers (subagent and ollama-subagent), because the
#              verification lives in two scripts sharing one module.
#              RED RUN (pre-T411 tooling, recorded in the T411 session,
#              2026-08-07): the same stub returned rc=0 and the row stayed
#              dispatchable — the bug, shown red before the fix.
#   seeded 2   a stub that DOES the work (claims, writes + commits the
#              deliverable, closes the row) but reports failure (verdict
#              fail-found): the dispatcher must believe the side effects,
#              not the text — rc=0, report says so.
#   null       an honest stub: rc=0, nonce echoed, deliverables present,
#              row closed pass, perf ledger records verified=pass, and the
#              verification phase adds no measurable latency (< 1000 ms,
#              measured and printed).
#
# All fixtures are synthetic and run in a scratch git repo under
# /tmp/weizigo — never the live repo. The kanban is a scratch store
# (MANAGENT_STORE), the model ledger is a scratch file (WEIZIGO_MODEL_PERF).
# The live kanban, docs/infra/model-perf.md and every tracked file are
# untouched.
#
# Task: T411 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-07

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
MG="$ROOT/bin/managent"
CLAIMLINT="$ROOT/bin/weizigo-claimlint"
FAIL=0

# F4/T513 — re-pin to HEAD: the regression runs the COMMITTED dispatch
# contract (bin/subagent, bin/ollama-subagent, tools/dispatch_verify.py
# extracted from HEAD), not the live working-tree file. A live uncommitted
# edit can no longer make this gate pass spuriously against a contract the
# commit did not record. The substrate the contract depends on — managent
# and weizigo-claimlint (the T485 done-gate) — is NOT under test here; the
# deployed binaries are symlinked into the scratch repo root so the
# committed done-gate can run (it invokes `bin/weizigo-claimlint` relative
# to the repo root it walks from CWD).

# The scratch dir lives under /tmp/weizigo (disposable outputs); this script
# is also T411's acceptance gate, so it must not depend on the operator having
# created it.
mkdir -p /tmp/weizigo

# A stale depth stamp from a worker-run suite would make the dispatchers
# refuse (depth cap). The regression simulates the human console.
unset WEIZIGO_AGENT_DEPTH || true

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to run
# if scratch creation fails — an empty scratch var once sent this suite's arms
# into the LIVE repo (2026-08-18 incident: live kanban wiped, claimlint.zig and
# CLAIMS.md clobbered by fixtures). cd "" succeeds silently; never rely on it.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/t411-dispatch-verify-XXXXXX)" || { echo "regression-dispatch-verification.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t411@test
git config user.name T411
echo base > README.md
mkdir -p docs untracked docs/infra/managent findings bin tools docs/epistemic
printf 'untracked/\n' > .gitignore
# T513: the committed T485 done-gate runs `bin/weizigo-claimlint c7 --json`, which
# reads docs/epistemic/CLAIMS.md relative to the scratch repo root. A minimal
# register (no §2) parses to an empty register; c7 then scans findings/ only,
# so the done-gate is faithful to the committed contract without dragging
# the live register (and its 200+ evidence paths) into scratch.
printf '# minimal scratch claims register (T513 regression)\n' > docs/epistemic/CLAIMS.md
git add README.md .gitignore docs/epistemic/CLAIMS.md
git commit -qm base

# F4/T513 — extract the COMMITTED dispatch contract from HEAD into scratch.
# $ROOT/bin/subagent computes ROOT from its own location, so placing it at
# $WORK/bin/subagent makes it import $WORK/tools/dispatch_verify.py (also
# extracted from HEAD) and resolve real_root=$WORK (so heal_dispatch reaches
# $WORK/bin/managent via the symlink below). The substrate (managent,
# claimlint) is symlinked, not extracted — it is not the contract under test.
git -C "$ROOT" show HEAD:bin/subagent > "$WORK/bin/subagent"           || { echo "FATAL: HEAD:bin/subagent extract failed" >&2; exit 2; }
git -C "$ROOT" show HEAD:bin/ollama-subagent > "$WORK/bin/ollama-subagent" || { echo "FATAL: HEAD:bin/ollama-subagent extract failed" >&2; exit 2; }
git -C "$ROOT" show HEAD:tools/dispatch_verify.py > "$WORK/tools/dispatch_verify.py" || { echo "FATAL: HEAD:tools/dispatch_verify.py extract failed" >&2; exit 2; }
chmod +x "$WORK/bin/subagent" "$WORK/bin/ollama-subagent"
# Substrate symlinks: the committed contract calls `bin/managent` (heal) and
# `bin/weizigo-claimlint` (the T485 done-gate) relative to the repo root it
# walks from CWD; both must resolve inside $WORK so the scratch repo is a
# faithful host for the committed contract.
ln -s "$MG" "$WORK/bin/managent"
ln -s "$CLAIMLINT" "$WORK/bin/weizigo-claimlint"
SUBAGENT="$WORK/bin/subagent"
OLLAMA_SUBAGENT="$WORK/bin/ollama-subagent"

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
# T477: the dispatcher's heal writes an assertion record here (scratch, never
# the live docs/infra/dispatch-heals.jsonl).
export WEIZIGO_DISPATCH_HEALS="$WORK/dispatch-heals.jsonl"
export REAL_MG="$MG"

# ── stub worker: a faithful fake agent ─────────────────────────────────────
# It parses the task ID, model, deliverable path and nonce OUT OF THE PROMPT
# it receives, exactly as a real agent would have to. Modes:
#   lazy    prints "OK." and exits 0, executing nothing (the kimi incident)
#   fail    does the work but reports failure (verdict fail-found)
#   honest  does the work and reports success
cat > "$WORK/stub.py" <<'STUBEOF'
#!/usr/bin/env python3
import json, os, re, subprocess, sys, time

prompt = sys.argv[-1]
mode = os.environ.get("STUB_MODE", "lazy")
mg = os.environ["REAL_MG"]

nonce = re.search(r"NONCE-[0-9a-f]{16}", prompt).group(0)

# F4/T513 — bare-file dispatch: no kanban row, no `managent claim/done`, no
# T485 done-gate. The dispatch_verify findings parse is the PRIMARY defense
# here, so the T488 malformed/missing/valid findings cases are exercised via
# bare-file (the T-ID path's done-gate now short-circuits a closing task's
# own malformed findings, making the old T488 arms impossible). The
# deliverable path is handed in by the harness (it is not in the bare-file
# prompt); the harness writes it via STUB_DELIVERABLE.
if "managent claim" not in prompt:
    dl = os.environ["STUB_DELIVERABLE"]
    os.makedirs(os.path.dirname(dl) or ".", exist_ok=True)
    if mode == "badfindings":
        content = "{ this is not valid JSON "
    elif mode == "missingkeys":
        content = json.dumps({"task_id": "T-bare", "date": "2026-08-20"})
    else:  # goodfindings
        content = json.dumps({
            "task_id": "T-bare", "date": "2026-08-20",
            "model": "deepseek-v4-flash", "claims": [],
            "notes": "T513 stub: valid findings record (bare-file)",
        })
    with open(dl, "w") as f:
        f.write(content)
    print(nonce + " bare complete")
    sys.exit(0)

task = re.search(r"managent (?:claim|done) (T\d+)", prompt).group(1)
model = re.search(r"managent claim \S+ --agent (\S+)", prompt).group(1)
dl = re.search(r"^  - (\S+)$", prompt, re.M).group(1)

if mode == "lazy":
    print("OK.")
    sys.exit(0)

if mode == "refused":
    # T538: provider refused before the worker could claim (HTTP 429 at
    # connect time).  The worker never read the brief; the 429 block lives in
    # the seeded worker log (untracked/log/t<id>.log), written by tools/runner
    # in production and seeded directly by the harness here.
    sys.exit(1)

subprocess.run([mg, "claim", task, "--agent", model], check=True)

if mode == "refused_claim":
    # T538: the worker claimed (row -> in_progress), then the provider refused
    # on a later call — exit 1, row left in_progress, heal must fire with an
    # unreached marker in the heal assertion record.
    sys.exit(1)

# T477 seeded wound: the worker claimed, then died (timeout/crash, rc=124)
# before doing any work. The row is left in_progress under a dead console —
# the exact state T448/T450/T452/T466/T475 sat in until a human noticed.
if mode == "die":
    sys.exit(124)

# T488/T513: findings-deliverable modes now run as BARE-FILE dispatches
# (see the bare-file block at the top). This T-ID branch is retained only for
# the legacy `badfindings`/`missingkeys`/`goodfindings` STUB_MODE values that
# arrive here on a T-ID prompt — the harness no longer sends them, but a
# stub should never crash on an unexpected combination, so fall through to
# the bare-file-equivalent T-ID path below instead of duplicating it.
if mode in ("badfindings", "missingkeys", "goodfindings"):
    # unreachable from the harness after T513; kept as a guard so a future
    # caller that does pass a T-ID + findings mode gets a loud failure
    # rather than a silent claim/done cycle that the done-gate muddies.
    raise SystemExit("stub: T-ID + findings mode %r is retired (use bare-file)" % mode)

with open(dl, "w") as f:
    f.write("T411 stub deliverable\n")
subprocess.run(["git", "add", "--", dl], check=True)
subprocess.run(["git", "commit", "-qm", "T411 stub deliverable"], check=True)
# A real worker takes minutes; managent's claim-to-done gate (T390) demands
# a gap > 10 s. Sleep so the stub's lifecycle is honest, not forced.
time.sleep(11)

# T477 second null: the worker closes the row honestly (done --status pass,
# deliverable committed) then destroys the deliverable in the working tree.
# The dispatcher must fail verification on the DELIVERABLE (filesystem check),
# not on rc, and must NOT heal — a done row with a missing deliverable is a
# claim to investigate, not a mess to tidy.
if mode == "sabotage":
    subprocess.run([mg, "done", task, "--agent", model, "--status", "pass"], check=True)
    os.unlink(dl)
    print(nonce + " task complete")
    sys.exit(0)

if mode == "fail":
    subprocess.run([mg, "done", task, "--agent", model, "--status", "fail-found",
                    "--note", "T411 seeded: subject failed, work executed"], check=True)
    print(nonce + " work done but the subject failed")
    sys.exit(0)

subprocess.run([mg, "done", task, "--agent", model, "--status", "pass"], check=True)
print(nonce + " task complete")
sys.exit(0)
STUBEOF
chmod +x "$WORK/stub.py"

# ── synthetic tasks on the scratch kanban ─────────────────────────────────
seed_task() {  # $1=id  $2=deliverable
    printf '<!--managent set=A deliverables=%s-->\n# %s — T411 regression bundle\n' "$2" "$1" \
        > "$WORK/untracked/$1-bundle.md"
    "$MG" add "$1" >/dev/null 2>&1 || { echo "    FAIL: managent add $1"; FAIL=1; }
}
seed_task T998 docs/T998-result.txt
seed_task T999 docs/T999-result.txt
seed_task T1000 docs/T1000-result.txt
seed_task T1001 docs/T1001-result.txt
seed_task T1002 docs/T1002-result.txt
# T538: provider-refusal arms — the worker log (untracked/log/t<id>.log) is
# the classifier's evidence source; the harness seeds it directly (a stub run
# via --test-worker has no tools/runner to write one).
seed_task T1003 docs/T1003-result.txt
seed_task T1004 docs/T1004-result.txt
seed_task T1005 docs/T1005-result.txt
# T513: the findings arms (7/8/9) are BARE-FILE dispatches — no kanban row,
# no managent add. The bundle .md declares its findings deliverable and is
# passed to bin/subagent as the target path (not a T-ID).
seed_bare() {  # $1=slug  $2=deliverable
    printf '<!--managent deliverables=%s-->\n# T513-bare-%s — bare-file findings bundle\n' "$2" "$1" \
        > "$WORK/untracked/T513-bare-$1.md"
}
seed_bare bad       findings/T513-bare-bad.json
seed_bare missing   findings/T513-bare-missing.json
seed_bare good      findings/T513-bare-good.json
if [ "$FAIL" -ne 0 ]; then
    echo "=== regression-dispatch-verification: setup FAILED (managent add) ==="
    exit 1
fi

row_status() {  # $1=id — status word from `managent show`'s "<id>  <status>" line
    "$MG" show "$1" 2>/dev/null | awk 'NR==2 && NF>=2 {print $2}'
}

echo "=== dispatch-verification regression ==="

# ── seeded control 1: the lazy "OK." worker, via bin/subagent ────────────
echo "  1. seeded: lazy stub (prints OK., does nothing) is FAILED by bin/subagent"
OUT=$(STUB_MODE=lazy "$SUBAGENT" --provider deepseek T998 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "verification FAILED" \
   && echo "$OUT" | grep -q "never left dispatchable"; then
    echo "    PASS: dispatcher failed the lazy worker (rc=$RC, report names the open row)"
else
    echo "    FAIL: rc=$RC; expected 'verification FAILED' + 'never left dispatchable'"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ "$(row_status T998)" = "dispatchable" ]; then
    echo "    PASS: scratch row T998 still dispatchable (the kimi state)"
else
    echo "    FAIL: T998 status changed ($(row_status T998))"
    FAIL=1
fi
if grep -q "T998 deepseek-v4-flash report=incomplete verified=fail fail=row" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records T998 verified=fail fail=row"
else
    echo "    FAIL: perf ledger missing the T998 fail record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
# T477: the lazy worker never claimed (row is dispatchable, not in_progress),
# so the heal must NOT fire — a dispatchable row needs no reopening.
if ! echo "$OUT" | grep -q 'healed.*reopened'; then
    echo "    PASS: no heal line (lazy worker — row was dispatchable, not in_progress)"
else
    echo "    FAIL: heal fired on the lazy worker (row was dispatchable)"
    FAIL=1
fi

# ── seeded control 1b: the same lazy worker via bin/ollama-subagent ───────
# The verification lives in two scripts sharing one module; prove both
# scripts are wired (a lazy worker slipping through one of them is the same
# defect with a different front door).
echo "  2. seeded: lazy stub is FAILED by bin/ollama-subagent too"
OUT=$(STUB_MODE=lazy "$OLLAMA_SUBAGENT" T998 --model glm-5.2:cloud \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "verification FAILED" \
   && echo "$OUT" | grep -q "never left dispatchable"; then
    echo "    PASS: ollama-subagent failed the lazy worker (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected 'verification FAILED' + 'never left dispatchable'"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi

# ── seeded control 1c (T477): the heal fires through the ollama front door ─
# ollama-subagent execs bin/subagent --provider ollama, so the heal (which
# lives in the shared dispatch_verify module, invoked from bin/subagent)
# runs on both front doors. Prove it, cheaply: a die stub via ollama-subagent.
echo "  2b. seeded: die stub is HEALED by bin/ollama-subagent too"
OUT=$(STUB_MODE=die "$OLLAMA_SUBAGENT" T1001 --model glm-5.2:cloud \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
# T1001 was healed back to dispatchable by arm 5; the die stub claims it
# again then exits 124, so the heal must fire a second time.
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'healed.*reopened T1001'; then
    echo "    PASS: ollama-subagent healed the dead worker (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected heal line for T1001 via ollama-subagent"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ "$(row_status T1001)" = "dispatchable" ]; then
    echo "    PASS: T1001 back to dispatchable (healed via ollama-subagent)"
else
    echo "    FAIL: T1001 status is $(row_status T1001), expected dispatchable"
    FAIL=1
fi

# ── seeded control 2: work done, failure reported — believe the side effects
echo "  3. seeded: stub does the work but reports failure (fail-found)"
OUT=$(STUB_MODE=fail "$SUBAGENT" --provider deepseek T999 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q "reported failure (verdict fail-found)" \
   && echo "$OUT" | grep -q "verification PASSED" \
   && echo "$OUT" | grep -q "believing the work, not the text"; then
    echo "    PASS: dispatcher believed the side effects over the failure text (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected PASSED + 'believing the work, not the text'"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ -f "$WORK/docs/T999-result.txt" ]; then
    echo "    PASS: T999 deliverable exists (written by the stub)"
else
    echo "    FAIL: T999 deliverable missing"
    FAIL=1
fi
if grep -q "T999 deepseek-v4-flash report=failure-fail-found verified=pass" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records T999 verified=pass"
else
    echo "    FAIL: perf ledger missing the T999 pass record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

# ── null control: an honest worker passes with no added friction ──────────
echo "  4. null: honest stub passes; nonce echoed; latency measured"
OUT=$(STUB_MODE=honest "$SUBAGENT" --provider deepseek T1000 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q "worker reported success; side effects verified — verification PASSED"; then
    echo "    PASS: honest worker verified (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected PASSED"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if echo "$OUT" | grep -q "NONCE-[0-9a-f]\{16\} task complete"; then
    echo "    PASS: nonce echoed in the worker's reply"
else
    echo "    FAIL: nonce not echoed"
    FAIL=1
fi
if [ -f "$WORK/docs/T1000-result.txt" ]; then
    echo "    PASS: T1000 deliverable exists"
else
    echo "    FAIL: T1000 deliverable missing"
    FAIL=1
fi
if grep -q "T1000 deepseek-v4-flash report=success verified=pass" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records T1000 verified=pass"
else
    echo "    FAIL: perf ledger missing the T1000 pass record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
VERIFY_MS=$(echo "$OUT" | sed -n 's/.*verification phase took \([0-9]*\) ms.*/\1/p' | head -1)
if [ -n "$VERIFY_MS" ] && [ "$VERIFY_MS" -lt 1000 ]; then
    echo "    PASS: verification phase ${VERIFY_MS} ms (< 1000 ms — no measurable latency on the honest path)"
else
    echo "    FAIL: verification phase '${VERIFY_MS:-unreadable}' ms (expected < 1000)"
    FAIL=1
fi
# T477 null control: an honest worker that succeeded must NOT be healed.
if ! echo "$OUT" | grep -q 'healed.*reopened'; then
    echo "    PASS: no heal line (honest worker succeeded)"
else
    echo "    FAIL: heal fired on a successful worker"
    FAIL=1
fi

# ── seeded control 3 (T477): the worker died (rc=124) leaving the row ───
# in_progress — the dispatcher must FAIL it AND heal it (reopen, assertion,
# one line). This is the wound the task exists to heal: every one of T448,
# T450, T452, T466, T475 sat claimed by a dead console until a human noticed.
echo "  5. seeded: die stub (claims then exits 124) is FAILED and HEALED by bin/subagent"
OUT=$(STUB_MODE=die "$SUBAGENT" --provider deepseek T1001 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q "verification FAILED"; then
    echo "    PASS: dispatcher failed the dead worker (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected verification FAILED"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if echo "$OUT" | grep -q 'healed.*reopened T1001'; then
    echo "    PASS: heal line printed (dispatcher reopened T1001)"
else
    echo "    FAIL: no heal line for T1001"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ "$(row_status T1001)" = "dispatchable" ]; then
    echo "    PASS: T1001 back to dispatchable (healed)"
else
    echo "    FAIL: T1001 status is $(row_status T1001), expected dispatchable"
    FAIL=1
fi
# The assertion record: model, exit code, wall time, healed_by=dispatcher.
HEALREC=$(grep '"task_id": "T1001"' "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null)
if [ -n "$HEALREC" ] \
   && echo "$HEALREC" | grep -q '"model": "deepseek-v4-flash"' \
   && echo "$HEALREC" | grep -q '"exit_code": 124' \
   && echo "$HEALREC" | grep -q '"wall_seconds"' \
   && echo "$HEALREC" | grep -q '"healed_by": "dispatcher"'; then
    echo "    PASS: assertion record written (model, rc=124, wall_seconds, healed_by=dispatcher)"
else
    echo "    FAIL: assertion record missing/incomplete for T1001"
    echo "$HEALREC" | sed 's/^/    | /'
    FAIL=1
fi
if grep -q 'T1001 deepseek-v4-flash report=incomplete verified=fail fail=row' "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records T1001 verified=fail fail=row (the wound, recorded)"
else
    echo "    FAIL: perf ledger missing the T1001 fail record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

# ── second null (T477): deliverable failure, not rc → task untouched, no heal
# A worker that reported success (done --status pass) but whose deliverable is
# missing must stay exactly as it is — reopening it would erase the evidence.
echo "  6. null: sabotage stub (done --status pass, then deletes deliverable) fails on the deliverable; NO heal"
OUT=$(STUB_MODE=sabotage "$SUBAGENT" --provider deepseek T1002 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'deliverable(s) missing'; then
    echo "    PASS: dispatcher failed on the deliverable (rc=$RC, not on rc)"
else
    echo "    FAIL: rc=$RC; expected 'deliverable(s) missing'"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if ! echo "$OUT" | grep -q 'healed.*reopened'; then
    echo "    PASS: no heal line (deliverable failure is not the heal case)"
else
    echo "    FAIL: heal fired on a deliverable failure"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ "$(row_status T1002)" = "done" ]; then
    echo "    PASS: T1002 still done (untouched — a claim to investigate, not a mess to tidy)"
else
    echo "    FAIL: T1002 status is $(row_status T1002), expected done (untouched)"
    FAIL=1
fi
if ! grep -q '"task_id": "T1002"' "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null; then
    echo "    PASS: no assertion record for T1002 (heal did not fire)"
else
    echo "    FAIL: assertion record written for T1002 (heal should not have fired)"
    FAIL=1
fi

# ── seeded control 4 (T488/T513): a findings deliverable that EXISTS but ──
# is invalid JSON must fail the dispatch-verify findings parse. These run as
# BARE-FILE dispatches (no kanban row): the T485 done-gate now short-circuits
# a closing task's OWN malformed findings, so the dispatch-verify findings
# check is the PRIMARY defense only where the done-gate does not run. This
# isolates the T488 feature from the T485 gate rather than encoding a contract
# the done-gate repealed.
echo "  7. seeded: invalid-JSON findings deliverable fails the verify (bare-file, T488/T513)"
OUT=$(STUB_MODE=badfindings STUB_DELIVERABLE=findings/T513-bare-bad.json \
        "$SUBAGENT" --provider deepseek untracked/T513-bare-bad.md --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "malformed findings deliverable(s): findings/T513-bare-bad.json"; then
    echo "    PASS: dispatcher failed the malformed findings deliverable (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected 'malformed findings deliverable(s)' naming the file"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if grep -q "deepseek-v4-flash report=bare verified=fail fail=findings" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records the bare-file findings-fail"
else
    echo "    FAIL: perf ledger missing the bare-file findings-fail record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
# A bare-file dispatch has no kanban row, so there is nothing to heal.
if ! echo "$OUT" | grep -q 'healed.*reopened'; then
    echo "    PASS: no heal line (bare-file dispatch — no kanban row to reopen)"
else
    echo "    FAIL: heal fired on a bare-file dispatch"
    FAIL=1
fi

# ── seeded control 5 (T488/T513): valid JSON but missing required keys fails
# (bare-file, as above).
echo "  8. seeded: findings deliverable missing required keys fails the verify (bare-file, T488/T513)"
OUT=$(STUB_MODE=missingkeys STUB_DELIVERABLE=findings/T513-bare-missing.json \
        "$SUBAGENT" --provider deepseek untracked/T513-bare-missing.md --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "malformed findings deliverable(s): findings/T513-bare-missing.json"; then
    echo "    PASS: dispatcher failed the key-missing findings deliverable (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected malformed-findings refusal naming the file"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi

# ── null (T488/T513): a VALID findings deliverable must pass (bare-file).
echo "  9. null: a VALID findings deliverable passes (bare-file, T488/T513)"
OUT=$(STUB_MODE=goodfindings STUB_DELIVERABLE=findings/T513-bare-good.json \
        "$SUBAGENT" --provider deepseek untracked/T513-bare-good.md --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] \
   && echo "$OUT" | grep -q "verification PASSED (bare-file dispatch"; then
    echo "    PASS: valid findings deliverable verified (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected PASSED on a valid findings deliverable"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
if [ -f "$WORK/findings/T513-bare-good.json" ]; then
    echo "    PASS: valid findings deliverable exists"
else
    echo "    FAIL: valid findings deliverable missing"
    FAIL=1
fi
if grep -q "deepseek-v4-flash report=bare verified=pass" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: perf ledger records the bare-file pass"
else
    echo "    FAIL: perf ledger missing the bare-file pass record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

# ── sole owner (F4/T513): the dispatcher is the ONE automatic heal-reopen ─
# owner. Every assertion record the regression produced (arms 2b and 5 each
# healed T1001 back to dispatchable) must carry healed_by=dispatcher — a
# second owner would write a different value, and a second owner is the
# defect F4 names. The heals log is the census of who reopens.
echo "  10. sole owner (F4/T513): every heal record is healed_by=dispatcher (no second owner)"
TOTAL=$(grep -c '"task_id"' "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null || echo 0)
DISP=$(grep -c '"healed_by": "dispatcher"' "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null || echo 0)
if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" -eq "$DISP" ]; then
    echo "    PASS: all $TOTAL heal record(s) are healed_by=dispatcher (the dispatcher is the sole owner)"
else
    echo "    FAIL: $DISP/$TOTAL heal record(s) are healed_by=dispatcher — a second owner is present"
    cat "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

# ── seeded control 6 (T538): a 429 worker log is provider refusal, not a ─
# model failure.  The model never saw the brief, so the ledger must record
# verified=unreached reason=provider-429 (NOT verified=fail).
echo "  11. seeded: a 429 worker log is classified unreached (not a model failure)"
mkdir -p "$WORK/untracked/log"
cat > "$WORK/untracked/log/t1003.log" <<'LOGEOF'
[runner] argv = ollama launch pi --model glm-5.2:cloud -y -- -p 'Follow untracked/T1003-x.md'
[runner] task identity: T1003 (source: MANAGENT_TASK_ID)
429: {"message":"you (test) have reached your session usage limit, upgrade: https://ollama.com/upgrade","type":"api_error","param":null,"code":null}
Error: exit status 1
LOGEOF
OUT=$(STUB_MODE=refused "$SUBAGENT" --provider deepseek T1003 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && grep -q "T1003 deepseek-v4-flash report=incomplete verified=unreached reason=provider-429" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: 429 log classified unreached (rc=$RC), reason=provider-429"
else
    echo "    FAIL: rc=$RC; expected verified=unreached reason=provider-429"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
if grep -q "T1003 .* verified=fail" "$WEIZIGO_MODEL_PERF"; then
    echo "    FAIL: T1003 recorded verified=fail (a provider refusal is not a model failure)"
    FAIL=1
else
    echo "    PASS: T1003 has no verified=fail line"
fi
if ! echo "$OUT" | grep -q 'healed.*reopened T1003'; then
    echo "    PASS: no heal (row was dispatchable — the worker never claimed)"
else
    echo "    FAIL: heal fired on an unclaimed 429 refusal"
    FAIL=1
fi

# ── seeded control 7 (T538): a clean log + no claim is a GENUINE failure —
# still verified=fail.  The distinction must not launder real failures.
echo "  12. seeded: a genuine failure with a clean log is still verified=fail"
cat > "$WORK/untracked/log/t1004.log" <<'LOGEOF'
[runner] argv = ollama launch pi --model glm-5.2:cloud -y -- -p 'Follow untracked/T1004-x.md'
[runner] task identity: T1004 (source: MANAGENT_TASK_ID)
Launching Pi...
LOGEOF
OUT=$(STUB_MODE=refused "$SUBAGENT" --provider deepseek T1004 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && grep -q "T1004 deepseek-v4-flash report=incomplete verified=fail fail=row" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: clean log + no claim is still verified=fail fail=row (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected verified=fail fail=row"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi
if grep -q "T1004 .* verified=unreached" "$WEIZIGO_MODEL_PERF"; then
    echo "    FAIL: T1004 laundered as unreached (the provider was fine)"
    FAIL=1
else
    echo "    PASS: T1004 not laundered as unreached"
fi

# ── seeded control 8 (T538): a claimed-then-refused worker heals with an ─
# unreached marker, so the heal log distinguishes a lane-down heal from an
# ordinary dispatcher heal (T536's keeper backoff wants to tell them apart).
echo "  13. seeded: a claimed-then-refused worker heals with an unreached marker"
cat > "$WORK/untracked/log/t1005.log" <<'LOGEOF'
[runner] argv = ollama launch pi --model glm-5.2:cloud -y -- -p 'Follow untracked/T1005-x.md'
[runner] task identity: T1005 (source: MANAGENT_TASK_ID)
429: {"message":"you (test) have reached your session usage limit","type":"api_error","param":null,"code":null}
Error: exit status 1
LOGEOF
OUT=$(STUB_MODE=refused_claim "$SUBAGENT" --provider deepseek T1005 --dsflash \
        --test-root="$WORK" --test-worker="$WORK/stub.py" 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'healed.*reopened T1005'; then
    echo "    PASS: claimed-then-refused worker healed (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected heal for T1005"
    echo "$OUT" | sed 's/^/    | /' | tail -12
    FAIL=1
fi
HEALREC=$(grep '"task_id": "T1005"' "$WEIZIGO_DISPATCH_HEALS" 2>/dev/null)
if [ -n "$HEALREC" ] \
   && echo "$HEALREC" | grep -q '"unreached": "provider-429"' \
   && echo "$HEALREC" | grep -q '"healed_by": "dispatcher"'; then
    echo "    PASS: heal record carries unreached=provider-429 (distinct event)"
else
    echo "    FAIL: heal record missing the unreached marker for T1005"
    echo "$HEALREC" | sed 's/^/    | /'
    FAIL=1
fi
if grep -q "T1005 deepseek-v4-flash report=incomplete verified=unreached reason=provider-429" "$WEIZIGO_MODEL_PERF"; then
    echo "    PASS: T1005 perf line records unreached"
else
    echo "    FAIL: T1005 perf line missing the unreached record"
    cat "$WEIZIGO_MODEL_PERF" 2>/dev/null | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-dispatch-verification: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-dispatch-verification: FAILURES ==="
    exit 1
fi
