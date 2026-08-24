#!/usr/bin/env bash
# regression-managent-attribution.sh — T544 controls for the model-attribution
# write path.  The census measured 79% of closed rows with a null `model`
# field (the keeper's least-data picker reads `model`, so it was computing over
# a fifth of the data).  Root cause: `claim`/`done` recorded `agent` (who did
# the work) but never `model` (the attribution field); `model` was only set at
# add/suggest when --model was passed.  The fix: any close/claim/dispatch that
# names the model writes BOTH fields, and a close with no name is refused
# unless --model-unknown <reason> declares the gap explicitly.  Backfill
# provenance (`model_source`) must round-trip the store so a backfilled value
# is never mistaken for a first-hand one.
#
# Controls (synthetic, scratch repo under /tmp/weizigo, MANAGENT_STORE points
# at a scratch kanban — the live kanban is never touched):
#   1. claim --agent X records BOTH agent and model (RED pre-fix: model null)
#   2. done --agent X records BOTH agent and model (RED pre-fix: model null)
#   3. done with no agent/model/--model-unknown -> REJECTED (silent null)
#   4. done --model-unknown <reason> records model="unattributed" + reason
#      (RED pre-fix: flag ignored, model left null)
#   5. done --agent <bogus> -> REJECTED naming the canonical list
#   6. an already-attributed row is untouched by a plain close
#   7. model_source/model_unknown_reason round-trip a store write
#      (RED pre-fix: serializeState dropped the fields)
#
# Task: T544 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="${MANAGENT_BIN:-$PROJECT/bin/managent}"
FAIL=0

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"

weizigo_scratch_repo managent-attribution WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t544@test
git config user.name T544
mkdir -p docs/infra/managent
STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Byte-identity guard: the live kanban must not be mutated
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"
LIVE_HASH=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

seed() {  # $1 = JSON body of one or more task records (no trailing comma)
    printf '{\n  %s,\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' "$1" > "$STORE"
}

# $1=id $2=status $3=agent-or-null $4=model-or-null (a literal "null" word or a quoted string)
rec() {
    printf '"%s":{"status":"%s","agent":%s,"model":%s,"bundle":"untracked/%s-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":"2026-08-01T00:00:01Z","done":null,"dispatched":null,"dispatched_to":null,"note":null,"verdict":null,"verdict_note":null,"impression":null,"impression_waiver":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1}' "$1" "$2" "$3" "$4" "$1"
}

echo "=== managent attribution regression (T544) ==="

# ── control 1: claim --agent records BOTH agent and model ─────────────────
echo "  1. claim --agent X records agent AND model (first-hand)"
seed "$(rec TA dispatchable null null)"
OUT=$("$MG" claim TA --agent deepseek-v4-pro 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && "$MG" show TA 2>/dev/null | grep -q 'model:    deepseek-v4-pro' \
   && "$MG" show TA 2>/dev/null | grep -q 'identifier: deepseek-v4-pro/TA'; then
    echo "    PASS: model and agent both recorded at claim"
else
    echo "    FAIL: claim did not record model: $OUT"
    "$MG" show TA 2>/dev/null | sed 's/^/      | /'
    FAIL=1
fi

# ── control 2: done --agent records BOTH agent and model ──────────────────
echo "  2. done --agent X records agent AND model (first-hand)"
seed "$(rec TB in_progress null null)"
OUT=$("$MG" done TB --agent glm-5.2 --status blocked --note "tb" --impression-waiver "test" 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && "$MG" show TB 2>/dev/null | grep -q 'model:    glm-5.2' \
   && "$MG" show TB 2>/dev/null | grep -q 'identifier: glm-5.2/TB'; then
    echo "    PASS: model and agent both recorded at close"
else
    echo "    FAIL: done did not record model: $OUT"
    "$MG" show TB 2>/dev/null | sed 's/^/      | /'
    FAIL=1
fi

# ── control 3: close with no attribution is refused ───────────────────────
echo "  3. done with no agent/model/--model-unknown is refused (no silent null)"
seed "$(rec TC in_progress null null)"
OUT=$("$MG" done TC --status blocked --note "tc" --impression-waiver "test" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q 'REJECTED: TC has no agent or model set'; then
    echo "    PASS: silent null refused"
else
    echo "    FAIL: expected refusal, got rc=$RC: $OUT"
    FAIL=1
fi

# ── control 4: --model-unknown records the gap explicitly ─────────────────
echo "  4. done --model-unknown <reason> records model=unattributed + reason"
seed "$(rec TD in_progress null null)"
OUT=$("$MG" done TD --model-unknown "operator close, no model ran" --status blocked --note "td" --impression-waiver "test" 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && "$MG" show TD 2>/dev/null | grep -q 'model:    unattributed' \
   && "$MG" show TD 2>/dev/null | grep -q 'model_unknown_reason: operator close, no model ran'; then
    echo "    PASS: unattributed recorded with reason"
else
    echo "    FAIL: --model-unknown not recorded: $OUT"
    "$MG" show TD 2>/dev/null | sed 's/^/      | /'
    FAIL=1
fi

# ── control 5: bogus label refused, naming the canonical list ─────────────
echo "  5. done --agent <bogus> is refused naming the canonical list"
seed "$(rec TE in_progress null null)"
OUT=$("$MG" done TE --agent not-a-model --status blocked --note "te" --impression-waiver "test" 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "is not a canonical model label" \
   && echo "$OUT" | grep -q 'canonical models:'; then
    echo "    PASS: bogus label refused with the canonical list"
else
    echo "    FAIL: bogus label not refused: $OUT"
    FAIL=1
fi

# ── control 6: already-attributed row untouched by a plain close ──────────
echo "  6. already-attributed row is untouched by a plain close"
seed "$(rec TF in_progress '"deepseek-v4-pro"' '"deepseek-v4-pro"')"
OUT=$("$MG" done TF --status blocked --note "tf" --impression-waiver "test" 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && "$MG" show TF 2>/dev/null | grep -q 'model:    deepseek-v4-pro'; then
    echo "    PASS: model unchanged"
else
    echo "    FAIL: close changed an attributed row: $OUT"
    "$MG" show TF 2>/dev/null | sed 's/^/      | /'
    FAIL=1
fi

# ── control 7: backfill provenance round-trips a store write ──────────────
echo "  7. model_source / model_unknown_reason survive a store write"
printf '{\n  "TG":{"status":"done","agent":null,"model":"unattributed-pre-T544","model_source":"unattributed-pre-T544","model_unknown_reason":"data predates T544","bundle":"untracked/TG-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-01T00:00:00Z","claimed":null,"done":"2026-08-02T00:00:00Z","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"impression":null,"impression_waiver":null,"acceptance":null,"skip_acceptance_reason":null,"claim_count":1},\n  "_sys": {"next_id": 9000, "directive_next": 1}\n}\n' > "$STORE"
# verdict is a store write on a done row: it re-reads and re-serializes the
# whole store, so a field serializeState does not know is silently dropped.
OUT=$("$MG" verdict TG pass --note "roundtrip" 2>&1); RC=$?
if [ "$RC" -eq 0 ] \
   && "$MG" show TG 2>/dev/null | grep -q 'model_source: unattributed-pre-T544' \
   && "$MG" show TG 2>/dev/null | grep -q 'model_unknown_reason: data predates T544'; then
    echo "    PASS: provenance fields round-trip the store"
else
    echo "    FAIL: provenance fields dropped by a store write: $OUT"
    "$MG" show TG 2>/dev/null | sed 's/^/      | /'
    FAIL=1
fi

# Byte-identity guard: the live kanban must not be mutated
LIVE_HASH2=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_HASH" != "$LIVE_HASH2" ]; then
    echo "  FATAL: the live kanban was mutated by this regression (T445). Restore it."
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T544: ALL CHECKS PASS"
else
    echo "  T544: SOME CHECKS FAILED"
fi
exit "$FAIL"
