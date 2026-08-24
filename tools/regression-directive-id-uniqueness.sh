#!/usr/bin/env bash
# regression-directive-id-uniqueness.sh — T758 controls for directive-ID uniqueness
#
# Defect (T758, 2026-08-23): a THIRD D041 landed 2026-08-23T01:57:43Z after
# T545's lock→read→modify→write fix.  T545 made the directive counter
# race-safe, but it never made the counter AUTHORITATIVE: `managent tell`
# mints `D{sys_directive_next}` where `sys_directive_next` is loaded from
# `_sys.directive_next` in tasks.json — a DIFFERENT file from the ledger
# (docs/infra/managent/directives.jsonl).  A direct store write / restore of
# tasks.json rolls the counter back (observed 55→21, 34→21) while the ledger
# keeps its max id (D079 today), so the next `tell` re-mints an id the
# ledger already holds.  The fix mints from max(counter, ledger_max + 1) and
# adds a uniqueness backstop at the append chokepoint (appendDirective).
#
# Controls (scratch store + scratch ledger only — never the live kanban):
#   1. seeded  counter == an id already in the ledger (the observed leak) →
#              `tell` mints a FRESH id, the ledger keeps no two lines sharing
#              an id.  RED before the fix: D041 is written a second time.
#   2. seeded  counter far BELOW the ledger max → `tell` mints past the max
#              (self-heals), no duplicate.  RED before the fix: mints D001.
#   3. seeded  the ack path (the second writer on the ledger) preserves every
#              id exactly once — the invariant holds across BOTH write paths.
#
# Invariant asserted: no two lines in directives.jsonl share an id, after
# either writer (append via `tell`, rewrite via `inbox --ack`).
#
# Task: T758 · Role: worker · Identifier: deepseek-v4-pro/T758 · Date: 2026-08-23

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/.."
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"

# ── binary resolution ────────────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ]; then
    echo "SKIP: no managent binary found — build with 'zig build' (zig-out/bin/managent) or deploy"
    exit 0
fi
if ! "$MG" help 2>&1 | grep -q "tell <target>"; then
    echo "SKIP: $MG does not carry 'tell' — rebuild from src/managent/main.zig"
    exit 0
fi

# T445: /tmp/weizigo decays (tmp sweeps, reboots). Create it, and REFUSE to
# run if scratch creation fails — an empty scratch var once sent fixtures into
# the LIVE repo (2026-08-18 incident).
weizigo_scratch_repo directive-id-uniqueness WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t758@test
git config user.name T758
echo base > README.md
mkdir -p docs/infra/managent
STORE="$WORK/docs/infra/managent/tasks.json"
LEDGER="$WORK/docs/infra/managent/directives.jsonl"
export MANAGENT_STORE="$STORE"
unset WEIZIGO_AGENT_DEPTH

# ── seed: a dispatchable row TSEED + a directive counter of $1 ────────────
seed_store() {
    python3 - "$STORE" "$1" <<'PYEOF'
import json, sys
p, n = sys.argv[1], int(sys.argv[2])
d = {"_sys": {"next_id": 9000, "directive_next": n, "assertion_next": 1, "closes": 0, "duty_migrated": True}}
d["TSEED"] = {"status": "dispatchable", "agent": None, "model": None,
              "bundle": "untracked/TSEED-test.md", "set": "A", "holds": [], "needs": [], "caps": [],
              "added": "2026-08-23T00:00:00Z", "claimed": None, "done": None, "dispatched": None,
              "dispatched_to": None, "note": None, "verdict": None, "verdict_note": None,
              "claim_count": 0, "duty": False, "due_after": 0, "last_chunk_closes": 0,
              "last_chunk_ts": None, "last_chunk_verdict": None, "last_chunk_findings": None,
              "acceptance": None, "skip_acceptance_reason": None, "amendments": [], "epitaph": None}
json.dump(d, open(p, "w"))
PYEOF
}

# ── write a ledger fixture verbatim (scratch only) ────────────────────────
write_ledger() { printf '%s\n' "$1" > "$LEDGER"; }

# ── helper: prints UNIQUE, or DUP:<comma ids> and exits 1 ─────────────────
unique_ids() {
    python3 - "$1" <<'PYEOF'
import json, sys
from collections import Counter
ids = [json.loads(l)["id"] for l in open(sys.argv[1]) if l.strip()]
c = Counter(ids)
dups = sorted(i for i, n in c.items() if n > 1)
if dups:
    print("DUP:" + ",".join(dups))
    sys.exit(1)
print("UNIQUE")
PYEOF
}

# ── helper: assert the ledger holds id $2 exactly $3 times ────────────────
id_count_ok() {
    python3 - "$LEDGER" "$1" "$2" <<'PYEOF'
import json, sys
from collections import Counter
ledger, want_id, want_n = sys.argv[1], sys.argv[2], int(sys.argv[3])
ids = [json.loads(l)["id"] for l in open(ledger) if l.strip()]
c = Counter(ids)
assert c.get(want_id, 0) == want_n, f"{want_id} x{c.get(want_id, 0)} (want {want_n}); {dict(c)}"
PYEOF
}

D041='{"id":"D041","target":"TOLD","directive":"amend","note":"pre-existing","from":"seed","ts":"2026-08-23T00:00:00Z","read":false}'

echo "=== directive-id-uniqueness regression (T758) ==="

# ── 1. seeded: counter == an id already in the ledger (the observed leak) ──
echo "  1. stale counter equal to an existing id → mint a fresh id, no duplicate"
seed_store 41
write_ledger "$D041"
OUT=$("$MG" tell TSEED amend --note "uniqueness-arm1" 2>&1); RC=$?
U=$(unique_ids "$LEDGER") || true
FRESH=FAIL
id_count_ok D041 1 && id_count_ok D042 1 && FRESH=PASS
if [ "$RC" -eq 0 ] && [ "$U" = "UNIQUE" ] && [ "$FRESH" = "PASS" ]; then
    echo "    PASS: D041 once, D042 minted fresh, ledger unique"
else
    echo "    FAIL: RC=$RC unique='$U' fresh=$FRESH"
    echo "    tell output: $OUT" | sed 's/^/      /'
    sed 's/^/      | /' "$LEDGER"
    FAIL=1
fi

# ── 2. seeded: counter far BELOW the ledger max → self-heal past the max ───
echo "  2. stale counter below the ledger max → mint past the max (self-heal)"
seed_store 1
write_ledger "$D041"
OUT=$("$MG" tell TSEED amend --note "uniqueness-arm2" 2>&1); RC=$?
U=$(unique_ids "$LEDGER") || true
FRESH=FAIL
id_count_ok D041 1 && id_count_ok D042 1 && FRESH=PASS
# The counter must have healed: D001 (the stale counter's next id) must NOT
# have been minted — only ids past the ledger max are fresh.
if [ "$RC" -eq 0 ] && [ "$U" = "UNIQUE" ] && [ "$FRESH" = "PASS" ] \
   && ! grep -q '"id":"D001"' "$LEDGER"; then
    echo "    PASS: minted D042 (past max), not D001; ledger unique"
else
    echo "    FAIL: RC=$RC unique='$U' fresh=$FRESH (D001 present: $(grep -c '"id":"D001"' "$LEDGER" || true))"
    echo "    tell output: $OUT" | sed 's/^/      /'
    sed 's/^/      | /' "$LEDGER"
    FAIL=1
fi

# ── 3. seeded: the ack path (second writer) preserves every id once ────────
echo "  3. ack rewrite (second writer) keeps every id exactly once"
seed_store 42
write_ledger "$D041"
"$MG" tell TSEED amend --note "uniqueness-arm3-a" >/dev/null 2>&1
"$MG" tell TSEED amend --note "uniqueness-arm3-b" >/dev/null 2>&1
ACKED=$("$MG" inbox --all --ack 2>&1 | grep -o 'acked [0-9]* directive' || true)
U=$(unique_ids "$LEDGER") || true
KEPT=FAIL
id_count_ok D041 1 && id_count_ok D042 1 && id_count_ok D043 1 && KEPT=PASS
if [ "$ACKED" = "acked 3 directive" ] && [ "$U" = "UNIQUE" ] && [ "$KEPT" = "PASS" ]; then
    echo "    PASS: ack re-serialised 3 records, every id preserved once"
else
    echo "    FAIL: acked='$ACKED' unique='$U' kept=$KEPT"
    sed 's/^/      | /' "$LEDGER"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-directive-id-uniqueness: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-directive-id-uniqueness: FAILURES ==="
    exit 1
fi
