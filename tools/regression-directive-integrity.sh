#!/usr/bin/env bash
# regression-directive-integrity.sh — T399 controls for JSON write-site escaping
#
# Two fleet incidents on 2026-08-06, one defect class:
#   Incident 1 (control channel): `managent tell` wrote a multi-line --note
#     into docs/infra/managent/directives.jsonl verbatim; the record broke
#     across physical lines, readDirectives skipped all of them silently,
#     and `inbox` said "-- no pending directives --".  Write said OK, read
#     said nothing, nobody was told.
#   Incident 2 (the kanban store): `managent amend` wrote a note containing
#     `"` characters raw into tasks.json; the amendment terminated its own
#     JSON string early, tasks.json became unparseable, and EVERY managent
#     invocation crashed until the store was repaired by hand.
#
# The fix (T399): one writeJsonString helper (`"` `\` `\n` `\r` `\t` and
# control bytes as \uXXXX) used by every JSON writer in src/managent/, a
# re-parse round-trip check at the write site (refuse to write an unreadable
# record), a reader warning for corrupt ledger lines, and an audit finding
# when the directive ledger does not round-trip.
#
# Controls (all against a scratch store — never the live kanban):
#   seeded   tell with a genuinely multi-line note (real \n) → every
#            non-empty ledger line parses, inbox shows the directive, the
#            newlines survive as real newlines in the delivered value.
#   seeded   tell with a note containing `"`, `\`, a tab, and a trailing
#            newline → all round-trip byte-exactly.
#   seeded   the ack path is a SECOND writer on the same ledger; acking a
#            directive whose note contains `"` must not corrupt the ledger
#            (parsed values are re-emitted — they must be re-escaped).
#   seeded   store path: amend with `"` in the note (Incident 2) keeps
#            tasks.json parseable and the amendment round-trips; dispatch
#            --note with a newline; done --skip-acceptance with a
#            multi-clause quoted reason; ping --note with a newline.
#   null     a single-line note still round-trips (no regression).
#   seeded   a deliberately corrupted ledger line → the reader warns on
#            stderr, still delivers the good records, and `audit` reports
#            the corrupted ledger as a FIX finding.
#
# RED before the fix: the multi-line tell control and the quoted amend
# control both fail against the 2026-08-06 binary (verified by T399).
#
# Task: T399 · Role: worker · Identifier: T399 · Date: 2026-08-06

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$HERE/.."
FAIL=0

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

# ── scratch repo + kanban store ──────────────────────────────────────────
WORK="$(mktemp -d /tmp/weizigo/directive-integrity-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t399@test
git config user.name T399
echo base > README.md
mkdir -p docs/infra/managent untracked
printf 'untracked/\n' > .gitignore
git add -A
git commit -qm base

STORE="$WORK/docs/infra/managent/tasks.json"
DIRECTIVES="$WORK/docs/infra/managent/directives.jsonl"
export MANAGENT_STORE="$STORE"
unset WEIZIGO_AGENT_DEPTH

# One in_progress task record (bare "KEY":{...} pair): $1=id
rec_inprog() {
    printf '"%s":{"status":"in_progress","agent":"t399","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}
# One dispatchable task record: $1=id
rec_disp() {
    printf '"%s":{"status":"dispatchable","agent":null,"bundle":"untracked/%s-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":0}' "$1" "$1"
}
# One done task record: $1=id
rec_done() {
    printf '"%s":{"status":"done","agent":"t399","model":"deepseek-v4-flash","bundle":"untracked/%s-bundle.md","set":"G","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":"2026-08-01T00:05:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$1"
}
seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
}

# ── helper: assert every non-empty line of a .jsonl parses as JSON ──────
# $1 = file · prints "OK <n>" or "CORRUPT <n>/<bad>" · returns 0/1
jsonl_clean() {
    python3 - "$1" <<'PYEOF'
import json, sys
lines = [l for l in open(sys.argv[1], encoding='utf-8') if l.strip()]
bad = []
for i, l in enumerate(lines, 1):
    try:
        json.loads(l)
    except Exception as e:
        bad.append((i, str(e)))
if bad:
    print(f"CORRUPT: {len(bad)}/{len(lines)} lines unparseable (first: line {bad[0][0]} {bad[0][1]})")
    sys.exit(1)
print(f"OK {len(lines)}")
PYEOF
}

# ── helper: reset the directive ledger (scratch store only) ─────────────
reset_directives() {
    : > "$DIRECTIVES"
}

echo "=== directive-integrity regression ==="

# ── 1. seeded: multi-line note (Incident 1) ──────────────────────────────
echo "  1. tell with a genuinely multi-line note → ledger parses, inbox delivers, newlines survive"
seed "$(rec_inprog TMULTI)"
reset_directives
OUT=$("$MG" tell TMULTI question --note $'para one\npara two\npara three' 2>&1); RC=$?
CLEAN=$(jsonl_clean "$DIRECTIVES") || true
NEWLINES=FAIL
python3 - "$DIRECTIVES" <<'PYEOF' && NEWLINES=PASS
import json, sys
rec = [json.loads(l) for l in open(sys.argv[1]) if l.strip()][0]
assert rec['target'] == 'TMULTI', rec
assert rec['note'] == 'para one\npara two\npara three', repr(rec['note'])
PYEOF
if [ "$RC" -eq 0 ] \
   && [ "$CLEAN" = "OK 1" ] \
   && echo "$OUT" | grep -q 'told TMULTI -> question' \
   && "$MG" inbox TMULTI 2>/dev/null | grep -q 'D001' \
   && [ "$NEWLINES" = "PASS" ]; then
    echo "    PASS: one logical record, one physical line, delivered with real newlines"
else
    echo "    FAIL: RC=$RC clean='$CLEAN' newlines=$NEWLINES"
    echo "    tell output: $OUT" | sed 's/^/      /'
    FAIL=1
fi

# ── 2. seeded: quotes / backslash / tab / trailing newline ───────────────
echo "  2. tell with \" backslash tab and trailing-newline → byte-exact round-trip"
seed "$(rec_inprog TWEIRD)"
reset_directives
"$MG" tell TWEIRD pause --note $'quote " inside, back\\slash, tab\there, and trailing\n' >/dev/null 2>&1
"$MG" tell TWEIRD resume --note 'plain single line' >/dev/null 2>&1
CLEAN=$(jsonl_clean "$DIRECTIVES") || true
RT=FAIL
python3 - "$DIRECTIVES" <<'PYEOF' && RT=PASS
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
expected = 'quote " inside, back\\slash, tab\there, and trailing\n'
assert any(r['note'] == expected for r in recs), [r.get('note') for r in recs]
PYEOF
if [ "$CLEAN" = "OK 2" ] && [ "$RT" = "PASS" ]; then
    echo "    PASS: quotes/backslash/tab/trailing-newline round-trip byte-exactly"
else
    echo "    FAIL: clean='$CLEAN' roundtrip=$RT"
    FAIL=1
fi

# ── 3. seeded: the ack path is a second writer on the same ledger ─────────
echo "  3. acking a directive whose note contains a quote does not corrupt the ledger"
reset_directives
"$MG" tell TWEIRD pause --note $'ack me: "quoted" note' >/dev/null 2>&1
"$MG" tell TWEIRD resume --note $'ack me too\nsecond line' >/dev/null 2>&1
ACKED=$("$MG" inbox --ack 2>&1 | grep -o 'acked [0-9]* directive' || true)
CLEAN=$(jsonl_clean "$DIRECTIVES") || true
READFLAG=FAIL
python3 - "$DIRECTIVES" <<'PYEOF' && READFLAG=PASS
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
assert all(r['read'] for r in recs), [r['id'] for r in recs if not r['read']]
PYEOF
if [ "$ACKED" = "acked 2 directive" ] && [ "$CLEAN" = "OK 2" ] && [ "$READFLAG" = "PASS" ]; then
    echo "    PASS: ack re-serialised 2 records, all parse, all read=true"
else
    echo "    FAIL: ack='$ACKED' clean='$CLEAN' readflag=$READFLAG"
    FAIL=1
fi

# ── 4. seeded: store path — amend with quotes (Incident 2) ───────────────
echo "  4. amend with \" in the note keeps tasks.json parseable and round-trips"
seed "$(rec_done TAMEND)"
OUT=$("$MG" amend TAMEND --verdict pass-with-findings --note 'line one - "If T2 holds exactly, canForceLife=false" - authored by ...' 2>&1); RC=$?
STORE_OK=FAIL
python3 - "$STORE" <<'PYEOF' && STORE_OK=PASS
import json, sys
d = json.load(open(sys.argv[1]))
am = d['TAMEND']['amendments'][0]
assert '"If T2 holds exactly, canForceLife=false"' in am, repr(am)
PYEOF
if [ "$RC" -eq 0 ] && [ "$STORE_OK" = "PASS" ]; then
    echo "    PASS: amendment with embedded quotes survives; store parses"
else
    echo "    FAIL: RC=$RC store=$STORE_OK"
    FAIL=1
fi

# ── 5. seeded: store path — dispatch --note with a newline ───────────────
echo "  5. dispatch --note with a newline round-trips in the store"
seed "$(rec_disp TDISP)"
OUT=$("$MG" dispatch TDISP --to deepseek-v4-flash --note $'first line\nsecond "quoted" line' 2>&1); RC=$?
STORE_OK=FAIL
python3 - "$STORE" <<'PYEOF' && STORE_OK=PASS
import json, sys
d = json.load(open(sys.argv[1]))
assert d['TDISP']['note'] == 'first line\nsecond "quoted" line', repr(d['TDISP']['note'])
assert d['TDISP']['dispatched_to'] == 'deepseek-v4-flash'
PYEOF
if [ "$RC" -eq 0 ] && [ "$STORE_OK" = "PASS" ]; then
    echo "    PASS: multi-line quoted dispatch note round-trips"
else
    echo "    FAIL: RC=$RC store=$STORE_OK"
    FAIL=1
fi

# ── 6. seeded: store path — done --skip-acceptance with a nasty reason ───
echo "  6. done --skip-acceptance with a multi-clause quoted reason round-trips"
seed "$(rec_inprog TSKIP)"
OUT=$("$MG" done TSKIP --skip-acceptance $'env broken, "quoted" clause, back\\slash, and a tab\there' 2>&1); RC=$?
STORE_OK=FAIL
python3 - "$STORE" <<'PYEOF' && STORE_OK=PASS
import json, sys
d = json.load(open(sys.argv[1]))
assert d['TSKIP']['status'] == 'done'
assert d['TSKIP']['skip_acceptance_reason'] == 'env broken, "quoted" clause, back\\slash, and a tab\there', repr(d['TSKIP']['skip_acceptance_reason'])
PYEOF
if [ "$RC" -eq 0 ] && [ "$STORE_OK" = "PASS" ]; then
    echo "    PASS: skip-acceptance reason round-trips; task closed"
else
    echo "    FAIL: RC=$RC store=$STORE_OK"
    FAIL=1
fi

# ── 7. seeded: ping --note with a newline (heartbeat writer) ─────────────
echo "  7. ping --note with a newline → heartbeat.jsonl parses line-by-line"
"$MG" ping --note $'hb note\nwith newline and "quotes"' >/dev/null 2>&1
CLEAN=$(jsonl_clean "$WORK/untracked/heartbeat.jsonl") || true
if [ "$CLEAN" = "OK 1" ]; then
    echo "    PASS: heartbeat record stays one parseable line"
else
    echo "    FAIL: clean='$CLEAN'"
    FAIL=1
fi

# ── 8. null control: single-line note still round-trips ──────────────────
echo "  8. null control: single-line note round-trips (no regression)"
seed "$(rec_inprog TNULL)"
reset_directives
"$MG" tell TNULL question --note 'ordinary single-line note' >/dev/null 2>&1
CLEAN=$(jsonl_clean "$DIRECTIVES") || true
RT=FAIL
python3 - "$DIRECTIVES" <<'PYEOF' && RT=PASS
import json, sys
recs = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
match = [r for r in recs if r.get('target') == 'TNULL']
assert len(match) == 1 and match[0]['note'] == 'ordinary single-line note', repr(match)
PYEOF
if [ "$CLEAN" = "OK 1" ] && [ "$RT" = "PASS" ]; then
    echo "    PASS: ordinary note unaffected"
else
    echo "    FAIL: clean='$CLEAN' roundtrip=$RT"
    FAIL=1
fi

# ── 9. seeded: corrupted ledger line → reader warns, good records deliver ─
echo "  9. corrupted ledger line → reader warns on stderr, good records still deliver, audit reports it"
seed "$(rec_inprog TCORRUPT)"
reset_directives
"$MG" tell TCORRUPT question --note 'good record' >/dev/null 2>&1
# Deliberately corrupt the ledger: append a garbage line (the Incident-1 shape).
# The good D001 is first; the garbage is the corruption the reader must skip.
printf 'this-line-is-not-json-at-all\n' >> "$DIRECTIVES"
WARN=$("$MG" inbox TCORRUPT 2>&1 >/dev/null | grep -o 'unparseable or malformed directive record' || true)
DELIVERED=$("$MG" inbox TCORRUPT 2>/dev/null | grep -c 'D001' || true)
AUDIT=$("$MG" audit 2>/dev/null | grep -c 'directives.jsonl: 1 unparseable' || true)
if [ "$WARN" != "" ] && [ "$DELIVERED" -ge 1 ] && [ "$AUDIT" -ge 1 ]; then
    echo "    PASS: warn='$WARN' delivered=$DELIVERED audit_findings=$AUDIT"
else
    echo "    FAIL: warn='$WARN' delivered=$DELIVERED audit=$AUDIT"
    FAIL=1
fi

# ── 10. seeded: purge to an empty store stays valid (latent `{` bug) ────
# The T399 round-trip guard caught a pre-existing serializer bug: with zero
# task records the `_sys` block was prefixed by `,` making the whole store
# `{,"...` — invalid JSON.  A bare purge that removes the last task used to
# write an unreadable store silently.
echo "  10. purge removing the last task leaves a parseable store (no leading comma)"
seed "$(rec_done TPURGE)"
OUT=$("$MG" purge 2>&1); RC=$?
STORE_OK=FAIL
python3 - "$STORE" <<'PYEOF' && STORE_OK=PASS
import json, sys
d = json.load(open(sys.argv[1]))
assert list(d.keys()) == ['_sys'], list(d.keys())
assert d['_sys']['next_id'] > 0
PYEOF
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q 'purged 1 task' && [ "$STORE_OK" = "PASS" ]; then
    echo "    PASS: empty store parses with only _sys"
else
    echo "    FAIL: RC=$RC store=$STORE_OK"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "directive-integrity: ALL PASS"
else
    echo "directive-integrity: $FAIL FAILURE(S)"
fi
exit "$FAIL"
