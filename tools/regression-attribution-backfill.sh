#!/usr/bin/env bash
# regression-attribution-backfill.sh — T544 controls for
# tools/attribution-backfill.py.  The tool repairs the `model` field on closed
# rows from three sources (run-record > perf-ledger > agent) and marks rows
# with no source as unattributed-pre-T544 (explicit, never a silent null).
# A wrong stored model contradicted by an external source is corrected with
# model_source="conflict:<old>-><new>"; a genuine external conflict (run and
# perf disagree) leaves the row alone and is reported, never guessed.
#
# Controls (hermetic fixture under /tmp/weizigo; the live kanban is untouched):
#   1. two recoverable rows (agent-field / run-record) are filled, sources
#      recorded
#   2. one unrecoverable row is marked unattributed-pre-T544 (not left null)
#   3. a store-wrong row (model=flash, agent+run=fable) is corrected with a
#      conflict recorded in model_source
#   4. an already-attributed row is untouched
#   5. a genuine external conflict (run != perf) leaves the row unchanged and
#      is reported (no value chosen)
#   6. a second run is a no-op (idempotent)
#
# Task: T544 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-22

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
TOOL="$PROJECT/tools/attribution-backfill.py"
FAIL=0

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/attribution-backfill-XXXXXX)" || { echo "regression-attribution-backfill.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
mkdir -p untracked/runs docs/infra/managent

STORE="$WORK/docs/infra/managent/tasks.json"
PERF="$WORK/perf.md"
RUNS="$WORK/untracked/runs"

# Sources: TA recoverable from perf-ledger; TB recoverable from run-record;
# TC unrecoverable; TD store-wrong; TE already-attributed; TF external conflict.
cat > "$PERF" <<'PERF_EOF'
dispatch-verify 2026-08-01 TA deepseek-v4-pro report=success verified=pass
dispatch-verify 2026-08-01 TF deepseek-v4-flash report=success verified=pass
PERF_EOF
printf '%s\n' '{"command": "pi --provider deepseek --model glm-5.2 -p x"}' > "$RUNS/TB.json"
printf '%s\n' '{"command": "claude -p x --model claude-fable-5"}' > "$RUNS/TD.json"
printf '%s\n' '{"command": "pi --provider deepseek --model deepseek-v4-pro -p x"}' > "$RUNS/TF.json"

rec() {  # $1=id  $2=agent-or-null  $3=model-or-null
    printf '"%s":{"status":"done","agent":%s,"model":%s,"bundle":"u","set":"A","holds":[],"needs":[],"caps":[],"added":"x","claimed":null,"done":"x","dispatched":null,"dispatched_to":null,"note":null,"verdict":"pass","verdict_note":null,"claim_count":1}' "$1" "$2" "$3"
}

printf '{\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  %s,\n  "_sys": {"next_id": 9000}\n}\n' \
    "$(rec TA '"deepseek-v4-pro"' null)" \
    "$(rec TB null null)" \
    "$(rec TC null null)" \
    "$(rec TD '"claude-fable-5"' '"deepseek-v4-flash"')" \
    "$(rec TE '"deepseek-v4-pro"' '"deepseek-v4-pro"')" \
    "$(rec TF null null)" > "$STORE"

echo "=== attribution-backfill regression (T544) ==="

DRY=$(python3 "$TOOL" --store "$STORE" --perf "$PERF" --runs "$RUNS" 2>&1)

# ── control 1: two recoverable rows filled with sources ───────────────────
echo "  1. two recoverable rows filled with sources recorded"
if echo "$DRY" | grep -q 'TA: model null -> "deepseek-v4-pro"  \[source: perf-ledger\]' \
   && echo "$DRY" | grep -q 'TB: model null -> "glm-5.2"  \[source: run-record\]'; then
    echo "    PASS: TA (perf-ledger) and TB (run-record) filled"
else
    echo "    FAIL: recoverable rows not filled with sources"
    echo "$DRY" | sed 's/^/      | /'
    FAIL=1
fi

# ── control 2: unrecoverable row marked explicitly ────────────────────────
echo "  2. unrecoverable row marked unattributed-pre-T544 (not left null)"
if echo "$DRY" | grep -q 'TC: model null -> "unattributed-pre-T544"'; then
    echo "    PASS: TC marked unattributed-pre-T544"
else
    echo "    FAIL: TC not marked unattributed"
    FAIL=1
fi

# ── control 3: store-wrong row corrected with conflict recorded ───────────
echo "  3. store-wrong row corrected with a conflict recorded"
if echo "$DRY" | grep -q 'TD: model "deepseek-v4-flash" -> "claude-fable-5"  \[source: conflict:deepseek-v4-flash->claude-fable-5\]'; then
    echo "    PASS: TD corrected, conflict in model_source"
else
    echo "    FAIL: TD not corrected with conflict source"
    FAIL=1
fi

# ── control 4: already-attributed row untouched ───────────────────────────
echo "  4. already-attributed row untouched"
if ! echo "$DRY" | grep -q 'TE:'; then
    echo "    PASS: TE not in the diff"
else
    echo "    FAIL: TE was modified"
    FAIL=1
fi

# ── control 5: genuine external conflict — no value chosen ────────────────
echo "  5. genuine external conflict (run != perf) leaves the row, reported"
if echo "$DRY" | grep -q 'TF: CONFLICT (no value chosen)' \
   && ! echo "$DRY" | grep -q 'TF: model null ->'; then
    echo "    PASS: TF reported as conflict, no value chosen"
else
    echo "    FAIL: TF conflict not handled as no-value"
    FAIL=1
fi

# ── write + idempotency ───────────────────────────────────────────────────
echo "  6. --write applies, and a second run is a no-op"
python3 "$TOOL" --store "$STORE" --perf "$PERF" --runs "$RUNS" --write >/dev/null 2>&1
# TA backfilled from perf-ledger, model_source recorded; TD corrected.
TA_MODEL=$(python3 -c "import json;print(json.load(open('$STORE'))['TA']['model'])")
TA_SRC=$(python3 -c "import json;print(json.load(open('$STORE'))['TA']['model_source'])")
TC_MODEL=$(python3 -c "import json;print(json.load(open('$STORE'))['TC']['model'])")
TD_MODEL=$(python3 -c "import json;print(json.load(open('$STORE'))['TD']['model'])")
TF_MODEL=$(python3 -c "import json,sys;print(json.load(open('$STORE'))['TF'].get('model'))")
SECOND=$(python3 "$TOOL" --store "$STORE" --perf "$PERF" --runs "$RUNS" 2>&1)
# Idempotent: no pending write remains (no "-> " line); the TF conflict is
# persistent (still reported) but is not a pending modification.
if [ "$TA_MODEL" = "deepseek-v4-pro" ] && [ "$TA_SRC" = "perf-ledger" ] \
   && [ "$TC_MODEL" = "unattributed-pre-T544" ] \
   && [ "$TD_MODEL" = "claude-fable-5" ] \
   && [ "$TF_MODEL" = "None" ] \
   && ! echo "$SECOND" | grep -q ' -> ' \
   && echo "$SECOND" | grep -q 'TF: CONFLICT (no value chosen)'; then
    echo "    PASS: write applied, sources recorded, idempotent"
else
    echo "    FAIL: write/idempotency: TA_model=$TA_MODEL TA_src=$TA_SRC TC=$TC_MODEL TD=$TD_MODEL TF=$TF_MODEL"
    echo "$SECOND" | sed 's/^/      | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T544 backfill: ALL CHECKS PASS"
else
    echo "  T544 backfill: SOME CHECKS FAILED"
fi
exit "$FAIL"
