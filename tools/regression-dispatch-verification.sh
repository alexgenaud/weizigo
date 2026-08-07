#!/usr/bin/env bash
# regression-dispatch-verification.sh — T411 controls for the dispatchers' work verification
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
SUBAGENT="$ROOT/bin/subagent"
OLLAMA_SUBAGENT="$ROOT/bin/ollama-subagent"
MG="$ROOT/bin/managent"
FAIL=0

# A stale depth stamp from a worker-run suite would make the dispatchers
# refuse (depth cap). The regression simulates the human console.
unset WEIZIGO_AGENT_DEPTH || true

WORK="$(mktemp -d /tmp/weizigo/t411-dispatch-verify-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t411@test
git config user.name T411
echo base > README.md
mkdir -p docs untracked docs/infra/managent
printf 'untracked/\n' > .gitignore
git add README.md .gitignore
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
export WEIZIGO_MODEL_PERF="$WORK/perf-ledger.txt"
export REAL_MG="$MG"

# ── stub worker: a faithful fake agent ─────────────────────────────────────
# It parses the task ID, model, deliverable path and nonce OUT OF THE PROMPT
# it receives, exactly as a real agent would have to. Modes:
#   lazy    prints "OK." and exits 0, executing nothing (the kimi incident)
#   fail    does the work but reports failure (verdict fail-found)
#   honest  does the work and reports success
cat > "$WORK/stub.py" <<'STUBEOF'
#!/usr/bin/env python3
import os, re, subprocess, sys, time

prompt = sys.argv[-1]
mode = os.environ.get("STUB_MODE", "lazy")
mg = os.environ["REAL_MG"]

nonce = re.search(r"NONCE-[0-9a-f]{16}", prompt).group(0)
task = re.search(r"managent (?:claim|done) (T\d+)", prompt).group(1)
model = re.search(r"managent claim \S+ --agent (\S+)", prompt).group(1)
dl = re.search(r"^  - (\S+)$", prompt, re.M).group(1)

if mode == "lazy":
    print("OK.")
    sys.exit(0)

subprocess.run([mg, "claim", task, "--agent", model], check=True)
with open(dl, "w") as f:
    f.write("T411 stub deliverable\n")
subprocess.run(["git", "add", "--", dl], check=True)
subprocess.run(["git", "commit", "-qm", "T411 stub deliverable"], check=True)
# A real worker takes minutes; managent's claim-to-done gate (T390) demands
# a gap > 10 s. Sleep so the stub's lifecycle is honest, not forced.
time.sleep(11)

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
OUT=$(STUB_MODE=lazy "$SUBAGENT" T998 --dsflash \
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

# ── seeded control 2: work done, failure reported — believe the side effects
echo "  3. seeded: stub does the work but reports failure (fail-found)"
OUT=$(STUB_MODE=fail "$SUBAGENT" T999 --dsflash \
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
OUT=$(STUB_MODE=honest "$SUBAGENT" T1000 --dsflash \
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

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-dispatch-verification: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-dispatch-verification: FAILURES ==="
    exit 1
fi
