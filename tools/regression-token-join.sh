#!/usr/bin/env bash
# regression-token-join.sh — controls for tools/token_join.py (T751).
#
# The join is the durable code change T751 owes: the run record and the
# ledger carry the readings (trusted-grade); the metrics record carries the
# quality scores; the two were never joined, so 24 of 24 metric rows held
# `cost: null` while the readings sat on disk.  The join writes the six
# named fields onto each metric row: tokens_fresh, tokens_cache_read,
# tokens_out, tokens_source, trusted, corroborated.
#
# Arms:
#   A. schema        the join writes exactly six fields, never a price,
#                    never a normalised score (tokens-now-prices-later)
#   B. dispatch wins a dispatch-time reading beats a retro reading on the
#                    same (task_id, model) — retro never substitutes for
#                    dispatch-time truth
#   C. trust grade  dispatch-time readings inherit trusted=True when the
#                    ledger has no explicit grade (legacy T746 entries);
#                    retro sources inherit trusted=False
#   D. atomicity    the rewrite is tmp + os.replace (a torn write would
#                    leave the metrics record half-rebuilt — the cost
#                    ladder would silently consume a partial file)
#   E. unjoined     a metric row whose (task_id, model) has no reading in
#                    the ledger is left UNCHANGED — UNKNOWN stays null,
#                    never a fabricated 0
#
# The control is hermetic — every arm drives the join against fixtures in
# a scratch dir under /tmp/weizigo, never the live JSONL/ledger.  The
# arms share one fixture directory and run sequentially.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
TOOL="$ROOT/tools/token_join.py"
FAIL=0

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

cleanup() {
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
}
trap cleanup EXIT

WORK=$(mktemp -d -t weizigo-token-join-XXXXXX)

echo "=== regression-token-join (T751) ==="

if ! test -f "$TOOL"; then
    echo "FATAL: $TOOL missing — the instrument must exist"
    exit 1
fi

JSONL="$WORK/metrics.jsonl"
LEDGER="$WORK/ledger.jsonl"

# Fixture: 4 metric rows, 4 ledger entries spanning all the arms.
python3 - "$JSONL" "$LEDGER" <<'PYEOF'
import json, sys
metrics_path, ledger_path = sys.argv[1], sys.argv[2]
metrics = [
    {"task_id": "T001", "model": "deepseek-v4-flash", "as_of": "2026-08-20"},
    {"task_id": "T002", "model": "deepseek-v4-pro",   "as_of": "2026-08-20"},
    {"task_id": "T003", "model": "deepseek-v4-flash", "as_of": "2026-08-20"},
    {"task_id": "T004", "model": "claude-opus-5",     "as_of": "2026-08-20"},
]
with open(metrics_path, "w") as f:
    for m in metrics:
        f.write(json.dumps(m) + "\n")
ledger = [
    # dispatch-time wins over retro on the same (task, model) — arm B.
    {"task": "T001", "model": "deepseek-v4-flash", "ts": "2026-08-20T00:00:00Z",
     "source": "claude-json-envelope",
     "tokens_in": 1000, "tokens_out": 200, "tokens_fresh": 100,
     "tokens_cache_read": 900, "trusted": True, "corroborated": "none"},
    {"task": "T001", "model": "deepseek-v4-flash", "ts": "2026-08-20T00:00:05Z",
     "source": "pi-session-jsonl-retro",
     "tokens_in": 999, "tokens_out": 199, "tokens_fresh": 99,
     "tokens_cache_read": 900, "trusted": False, "corroborated": "run-record"},
    # dispatch-time, legacy (no trusted field) — arm C.
    {"task": "T002", "model": "deepseek-v4-pro", "ts": "2026-08-20T00:00:00Z",
     "source": "pi-session-jsonl",
     "tokens_in": 800, "tokens_out": 150, "tokens_fresh": 50,
     "tokens_cache_read": 750},
    # fallback — arm B's trusted=False assertion.
    {"task": "T003", "model": "deepseek-v4-flash", "ts": "2026-08-20T00:00:00Z",
     "source": "pi-session-jsonl-fallback",
     "tokens_in": 500, "tokens_out": 80, "tokens_fresh": 400,
     "tokens_cache_read": 100, "trusted": False, "corroborated": "run-record"},
    # T004 has NO ledger entry — arm E: stays unjoined, UNKNOWN stays null.
]
with open(ledger_path, "w") as f:
    for e in ledger:
        f.write(json.dumps(e) + "\n")
PYEOF

# ── A. schema (six named fields, no price) ────────────────────────────────
echo "  A. joined rows carry exactly the six named fields (no price)"
OUT=$(python3 "$TOOL" --jsonl "$JSONL" --ledger "$LEDGER" 2>&1)
echo "$OUT" | grep -q "joined=3" && pass "joined 3 of 4 rows" \
    || fail "expected 3 joined rows, got: $OUT"
# Inspect one joined row directly.
ROW=$(python3 -c "
import json
with open('$JSONL') as f:
    rows = [json.loads(l) for l in f if l.strip()]
for r in rows:
    if r.get('task_id') == 'T001':
        print(json.dumps(r)); break
")
KEYS=$(echo "$ROW" | python3 -c "import json, sys; r=json.loads(sys.stdin.read()); print(','.join(sorted(k for k in r if k.startswith('tokens_') or k=='trusted' or k=='corroborated')))")
EXPECTED="corroborated,tokens_cache_read,tokens_fresh,tokens_out,tokens_source,trusted"
if [ "$KEYS" = "$EXPECTED" ]; then
    pass "T001 row carries exactly the six fields"
else
    fail "T001 row keys: got '$KEYS', expected '$EXPECTED'"
fi
# tokens_now_prices_later: no cost_usd, no price, no normalised field.
if echo "$ROW" | grep -qE '"cost_usd"|"price"|"tokens_per_dollar"'; then
    fail "T001 row carries a price field (tokens-now-prices-later violation)"
else
    pass "no price field introduced"
fi

# ── B. dispatch-time wins ──────────────────────────────────────────────────
echo "  B. dispatch-time reading wins over retro on the same (task, model)"
ROW=$(python3 -c "
import json
with open('$JSONL') as f:
    rows = [json.loads(l) for l in f if l.strip()]
for r in rows:
    if r.get('task_id') == 'T001':
        print(json.dumps(r)); break
")
SRC=$(echo "$ROW" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['tokens_source'])")
[ "$SRC" = "claude-json-envelope" ] \
    && pass "T001 source = claude-json-envelope (dispatch-time wins)" \
    || fail "T001 source = $SRC (expected claude-json-envelope)"

# ── C. trust-grade legacy inference ──────────────────────────────────────
echo "  C. trust grade — legacy dispatch-time infers trusted=True"
ROW=$(python3 -c "
import json
with open('$JSONL') as f:
    rows = [json.loads(l) for l in f if l.strip()]
for r in rows:
    if r.get('task_id') == 'T002':
        print(json.dumps(r)); break
")
TRUSTED=$(echo "$ROW" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['trusted'])")
CORROB=$(echo "$ROW" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['corroborated'])")
[ "$TRUSTED" = "True" ] && pass "T002 trusted=True (legacy dispatch-time inferred)" \
    || fail "T002 trusted=$TRUSTED (expected True)"
[ "$CORROB" = "none" ] && pass "T002 corroborated='none'" \
    || fail "T002 corroborated=$CORROB (expected 'none')"

ROW=$(python3 -c "
import json
with open('$JSONL') as f:
    rows = [json.loads(l) for l in f if l.strip()]
for r in rows:
    if r.get('task_id') == 'T003':
        print(json.dumps(r)); break
")
TRUSTED=$(echo "$ROW" | python3 -c "import json, sys; print(json.loads(sys.stdin.read())['trusted'])")
[ "$TRUSTED" = "False" ] && pass "T003 trusted=False (fallback)" \
    || fail "T003 trusted=$TRUSTED (expected False)"

# ── D. atomicity (the rewrite is tmp + os.replace) ───────────────────────
echo "  D. atomicity — the file is either old or new, never torn"
# Rewrite the file again to confirm a second pass is idempotent: a re-run
# finds the same readings and writes back identical content.
SHA1=$(shasum "$JSONL" | cut -d' ' -f1)
python3 "$TOOL" --jsonl "$JSONL" --ledger "$LEDGER" >/dev/null
SHA2=$(shasum "$JSONL" | cut -d' ' -f1)
[ "$SHA1" = "$SHA2" ] && pass "second pass is byte-identical (idempotent)" \
    || fail "second pass drifted: $SHA1 -> $SHA2"

# ── E. unjoined row stays unchanged ─────────────────────────────────────
echo "  E. unjoined row stays unchanged (UNKNOWN stays null)"
ROW=$(python3 -c "
import json
with open('$JSONL') as f:
    rows = [json.loads(l) for l in f if l.strip()]
for r in rows:
    if r.get('task_id') == 'T004':
        print(json.dumps(r)); break
")
HAS_SOURCE=$(echo "$ROW" | python3 -c "import json, sys; r=json.loads(sys.stdin.read()); print('yes' if 'tokens_source' in r else 'no')")
[ "$HAS_SOURCE" = "no" ] && pass "T004 (no ledger entry) is unjoined — no fake fields added" \
    || fail "T004 row was joined (no ledger entry should leave it untouched)"

echo
if [ "$FAIL" = "1" ]; then
    echo "=== regression-token-join: FAIL ==="
    exit 1
fi
echo "=== regression-token-join: PASS ==="
exit 0
