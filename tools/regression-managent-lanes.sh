#!/usr/bin/env bash
# regression-managent-lanes.sh — T716 controls: the T-ID ↔ findings census.
#
# The defect (T716): nine findings files (findings/T674, T679, T683, T685,
# T687, T690–T693) were graded in commits 8877a1d / 9e9cd28 yet had no row in
# any committed or working-tree tasks.json — the IDs were allocated (bundles
# written, next_id advanced) but the rows were clobbered by concurrent
# re-serialization before any commit captured them.  `managent lanes` is the
# instrument that makes that class visible (FORWARD: a findings file whose
# T-id has no live or archived row) and the mirror of it (REVERSE: a
# done/failed row whose declared findings deliverable never landed).
#
# Arms (all in a scratch repo under /tmp/weizigo; the REAL live store is
# read-only — its SHA-256 is snapshotted before and asserted byte-identical
# after):
#   A. forward known-bad: findings/T900-orphan.json with no row → `lanes`
#      exits 1 and names T900 as UNREGISTERED (the T716 class, RED).
#   B. backfill known-good: `lanes --backfill T900` mints a `done` row in ONE
#      write; `lanes` then exits 0 and no longer names T900 (the mechanism
#      that closes the gap).
#   C. reverse known-bad: a seeded `done` row whose bundle declares a findings
#      deliverable that never landed → `lanes` names it MISSING-FINDINGS
#      (flag-only; the row is NOT deleted — deleting a row is how evidence
#      dies).
#   D. null control: a clean store with no findings and no rows → exit 0, zero
#      unregistered, zero missing (specificity).
#   E. live store byte-identity: the REAL live store is untouched throughout.
#
# Task: T716 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-23

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

cleanup() { [ -n "${WORK:-}" ] && rm -rf "$WORK"; }
trap cleanup EXIT

# T849: scratch repo via the ONE isolated helper (unset GIT_DIR… before git
# init); safe to run outside the pre-commit hook. T445 refuse-on-failure is
# preserved by the helper.
. "$PROJECT/tools/lib/scratch-repo.sh"
weizigo_scratch_repo t716-lanes WORK   # T849: isolated scratch repo
cd "$WORK"
git config user.email t716@test
git config user.name T716
mkdir -p docs/infra/managent untracked bin findings
printf 'untracked/\n' > .gitignore
echo base > README.md
git add README.md .gitignore
git commit -qm base

# ── managent binary resolution ────────────────────────────────────────────
MG="${MANAGENT_BIN:-}"
if [ -z "$MG" ]; then
    if [ -x "$PROJECT/zig-out/bin/managent" ]; then
        MG="$PROJECT/zig-out/bin/managent"
    elif [ -x "$PROJECT/bin/managent" ]; then
        MG="$PROJECT/bin/managent"
    fi
fi
if [ -z "$MG" ] || [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary found (build with 'zig build')"
    exit 0
fi
ln -sf "$MG" bin/managent

STORE="$WORK/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"
LIVE_STORE="$PROJECT/docs/infra/managent/tasks.json"
LIVE_BEFORE=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

# write a findings file (the worker's deliverable)
write_findings() { # $1 path-within-findings  $2 task_id
    local fp="findings/$1"
    python3 - "$fp" "$2" <<'PY'
import json, sys
fp, tid = sys.argv[1], sys.argv[2]
json.dump({"task_id": tid, "date": "2026-08-23", "model": "deepseek-v4-flash",
           "claims": [], "new_rows": []}, open(fp, "w"), indent=1)
PY
}

# write a bundle with a declared findings deliverable
write_bundle() { # $1 id  $2 findings-path (or "" for none)
    local id="$1" fp="$2"
    if [ -n "$fp" ]; then
        printf '<!--managent set=A deliverables=%s-->\n# %s bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$fp" "$id" > "untracked/$id.md"
    else
        printf '<!--managent set=A deliverables=-->\n# %s bundle\n**Landmark:** none directly; unblocks regression fixture\n' "$id" > "untracked/$id.md"
    fi
}

# seed a minimal done row directly into the scratch store (python edits the
# JSON so the census's reverse arm sees a closed row without running the
# full add/claim/done gate, which needs claimlint in the scratch repo).
seed_done_row() { # $1 id  $2 bundle-rel
    python3 - "$STORE" "$1" "$2" <<'PY'
import json, sys
store, tid, bundle = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    d = json.load(open(store))
except Exception:
    d = {}
d["_sys"] = d.get("_sys", {})
d["_sys"]["next_id"] = int(tid[1:]) + 1
d[tid] = {
    "status": "done", "bundle": bundle, "set": "A",
    "holds": [], "needs": [], "caps": [], "candidates": [],
    "assign_reasons": [], "shape_reasons": [], "scope_targets": [],
    "amendments": [],
    "added": "2026-08-23T00:00:00Z", "done": "2026-08-23T00:00:00Z",
    "verdict": "pass", "claim_count": 0, "duty": False, "due_after": 5,
    "last_chunk_closes": 0,
}
json.dump(d, open(store, "w"), indent=1)
PY
}

echo "=== regression-managent-lanes (T716) ==="

# ── A. forward known-bad: findings with no row ─────────────────────────────
echo "  A. orphaned findings file (T900) with no row — lanes must go RED"
: > "$STORE"
write_findings "T900-orphan.json" "T900"
set +e
OUT=$(bin/managent lanes 2>/dev/null)
RC=$?
set -e
if [ "$RC" -eq 1 ]; then
    pass "lanes exit 1 on an unregistered finding (the T716 gate fires)"
else
    fail "lanes exit $RC on an unregistered finding (expected 1); output: $OUT"
fi
if echo "$OUT" | grep -q "UNREGISTERED  T900  (findings/T900-orphan.json)"; then
    pass "T900 named as UNREGISTERED with its findings path"
else
    fail "T900 not named as UNREGISTERED; output: $OUT"
fi

# ── B. backfill known-good: mint+close in one write ────────────────────────
echo "  B. lanes --backfill T900 mints a done row and clears the orphan"
set +e
OUT=$(bin/managent lanes --backfill T900 2>/dev/null)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "minted+closed 1 row"; then
    pass "backfill minted+closed T900 (exit 0)"
else
    fail "backfill exit $RC (expected 0) or wrong summary; output: $OUT"
fi
STATUS=$(python3 - "$STORE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("T900", {}).get("status", ""))
PY
)
if [ "$STATUS" = "done" ]; then
    pass "T900 row now exists with status done"
else
    fail "T900 row status is '$STATUS' (expected done)"
fi
set +e
OUT=$(bin/managent lanes 2>/dev/null)
RC=$?
set -e
if [ "$RC" -eq 0 ]; then
    pass "lanes exit 0 after backfill (no unregistered findings remain)"
else
    fail "lanes exit $RC after backfill (expected 0); output: $OUT"
fi

# ── C. reverse known-bad: done row whose findings never landed ─────────────
echo "  C. done row (T901) whose declared findings deliverable never landed"
write_bundle "T901" "findings/T901-never.json"
seed_done_row "T901" "untracked/T901.md"
set +e
OUT=$(bin/managent lanes 2>/dev/null)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "MISSING-FINDINGS  T901  (findings/T901-never.json)"; then
    pass "T901 flagged MISSING-FINDINGS (flag-only, exit 0)"
else
    fail "T901 not flagged MISSING-FINDINGS (exit $RC); output: $OUT"
fi
# the row must survive the census (flag, do not delete)
STILL=$(python3 - "$STORE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
print(d.get("T901", {}).get("status", ""))
PY
)
if [ "$STILL" = "done" ]; then
    pass "T901 row left intact (the census never deletes a row)"
else
    fail "T901 row was mutated by the census (status '$STILL'; expected done)"
fi

# ── D. null control: clean store, no findings, no rows ─────────────────────
echo "  D. null control: a clean store is GREEN"
rm -f findings/T900-orphan.json
python3 - "$STORE" <<'PY'
import json, sys
json.dump({"_sys": {"next_id": 950}}, open(sys.argv[1], "w"), indent=1)
PY
set +e
OUT=$(bin/managent lanes 2>/dev/null)
RC=$?
set -e
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "lanes: 0 unregistered finding(s), 0 missing-finding row(s)"; then
    pass "lanes GREEN on a clean store (0 unregistered, 0 missing)"
else
    fail "lanes not clean on a null store (exit $RC); output: $OUT"
fi

# ── E. live store byte-identity guard ──────────────────────────────────────
echo "  E. real live store untouched"
LIVE_AFTER=$(shasum -a 256 "$LIVE_STORE" | cut -d' ' -f1)
if [ "$LIVE_BEFORE" = "$LIVE_AFTER" ]; then
    pass "REAL live store byte-identical throughout (sha256 $LIVE_AFTER)"
else
    fail "REAL live store MUTATED by the regression (sha256 $LIVE_BEFORE → $LIVE_AFTER)"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "regression-managent-lanes: ALL CONTROLS PASSED"
else
    echo "regression-managent-lanes: $FAIL FAILURE(S)"
fi
exit "$FAIL"
