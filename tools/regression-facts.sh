#!/bin/sh
# regression-facts.sh — T867 controls for tools/facts (trusted bootstrap).
#
# Three arms, all in a disposable scratch dir created via mktemp — the
# live repo and live kanban are never read or written:
#
#   1. known-good:  a scratch store with four rows of known status/model
#                   composition plus a _sys meta key. tools/facts
#                   (MANAGENT_STORE=<scratch>, FACTS_SECTIONS=ROWS) must
#                   print the exact expected ROWS counts — the census
#                   reads the store, skips meta keys, and counts
#                   recorded models.
#   2. known-bad:   the SAME fixture with exactly ONE field changed
#                   (T9002 status in_progress -> done). Same command,
#                   same code path. facts must print the flipped counts
#                   — a positive control: a facts that echoed constants
#                   regardless of input would go red here.
#   3. missing store: facts must print store_error= and exit 0 — a
#                   reported fact, not a crash.
#
# Red-first (recorded in findings/T867-trusted-bootstrap-facts.json):
# arm 2 was run against a stub facts that echoed the good fixture's
# numbers regardless of input and went RED; the real tool goes green.
#
# T867 · deepseek-v4-flash · 2026-08-24

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

WORK=$(mktemp -d) || { echo "regression-facts: FATAL — mktemp failed"; exit 2; }
trap 'rm -rf "$WORK"' EXIT

GOOD="$WORK/good.json"
BAD="$WORK/bad.json"

# The two fixtures differ ONLY in T9002's status (in_progress -> done).
cat > "$GOOD" <<'EOF'
{
  "_sys": {"next_id": 9005},
  "T9001": {"status": "done",        "model": "deepseek-v4-flash"},
  "T9002": {"status": "in_progress", "model": null},
  "T9003": {"status": "blocked",     "model": "minimax-m3"},
  "T9004": {"status": "dispatchable"}
}
EOF
cat > "$BAD" <<'EOF'
{
  "_sys": {"next_id": 9005},
  "T9001": {"status": "done",        "model": "deepseek-v4-flash"},
  "T9002": {"status": "done",        "model": null},
  "T9003": {"status": "blocked",     "model": "minimax-m3"},
  "T9004": {"status": "dispatchable"}
}
EOF

FACTS="${FACTS_BIN:-$PROJECT/tools/facts}"
if [ ! -x "$FACTS" ]; then
    echo "FAIL: $FACTS missing or not executable"
    exit 1
fi
cd "$PROJECT" || exit 2   # facts resolves the repo root via git

expect() {
    arm="$1"; line="$2"; out="$3"
    if ! echo "$out" | grep -qx "$line"; then
        echo "FAIL $arm: expected line '$line'"
        echo "$out" | grep '^rows_' | sed 's/^/    /'
        FAIL=1
    fi
}

# ── arm 1: known-good fixture ─────────────────────────────────────────
GOOD_OUT=$(MANAGENT_STORE="$GOOD" FACTS_SECTIONS=ROWS "$FACTS" 2>&1)
for l in 'rows_total=4' 'rows_done=1' 'rows_in_progress=1' 'rows_dispatchable=1' \
         'rows_blocked=1' 'rows_failed=0' 'rows_other=0' 'rows_with_model=2' 'rows_with_agent=0'; do
    expect arm1 "$l" "$GOOD_OUT"
done
[ "$FAIL" -eq 0 ] && echo "PASS arm1: known-good fixture -> exact expected counts"

# ── arm 2: known-bad fixture (one status flipped) ─────────────────────
BAD_OUT=$(MANAGENT_STORE="$BAD" FACTS_SECTIONS=ROWS "$FACTS" 2>&1)
for l in 'rows_total=4' 'rows_done=2' 'rows_in_progress=0' 'rows_dispatchable=1' \
         'rows_blocked=1' 'rows_failed=0' 'rows_other=0' 'rows_with_model=2' 'rows_with_agent=0'; do
    expect arm2 "$l" "$BAD_OUT"
done
[ "$FAIL" -eq 0 ] && echo "PASS arm2: known-bad fixture (in_progress -> done) -> flipped counts, tool sees the difference"

# ── arm 3: missing store is a reported fact, not a crash ──────────────
MISSING_OUT=$(MANAGENT_STORE="$WORK/does-not-exist.json" FACTS_SECTIONS=ROWS "$FACTS" 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$MISSING_OUT" | grep -q '^store_error='; then
    echo "PASS arm3: missing store -> store_error= line, exit 0"
else
    echo "FAIL arm3: missing store rc=$RC, expected exit 0 with store_error= line"
    echo "$MISSING_OUT" | head -3 | sed 's/^/    /'
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "regression-facts: all controls passed"
    exit 0
fi
exit 1
