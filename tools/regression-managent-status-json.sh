#!/usr/bin/env bash
# regression-managent-status-json.sh
# T516 regression test: `status --json` carries `added` and `claim_count`
#
# F7: `status --json` omitted `added` and `claim_count`, forcing the keeper
# to shell out to `show` for two fields the dashboard wants inline. This
# script asserts both fields are present and correct in the JSON view.
#
# Arms (scratch store only — never the live kanban):
#   1. a claimed task exposes `added` (the seeded timestamp) and
#      `claim_count` == 1 in `status --json`.
#   2. an unclaimed (dispatchable, claim_count=0) task exposes `added` and
#      `claim_count` == 0.
#   3. a task claimed twice (claim_count=2) exposes `claim_count` == 2.
#   4. byte-identity guard: the scratch tasks.json is unchanged after the
#      read-only `status --json` run (status must never mutate the store).
#
# Usage:  tools/regression-managent-status-json.sh [--build]
#   --build: rebuild managent from source before testing
#
# Must be RED against the pre-T516 binary (fields absent) before the fix
# lands, and GREEN after.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
. "$PROJECT/tools/lib/scratch-repo.sh"   # T873: weizigo_reset_census for direct store writes

FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

if [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary (build with 'zig build') — T516 needs it"
    exit 0
fi

mkdir -p /tmp/weizigo
TMPDIR="$(mktemp -d /tmp/weizigo/managent-status-json-XXXXXX)" || { echo "regression-managent-status-json.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$TMPDIR"' EXIT

mkdir -p "$TMPDIR/docs/infra/managent" "$TMPDIR/untracked"
git init "$TMPDIR" 2>/dev/null
git -C "$TMPDIR" config user.email "test@test" 2>/dev/null
git -C "$TMPDIR" config user.name "test" 2>/dev/null

# Minimal claimlint + register so the done-gate (if invoked) has somewhere
# to land. Not exercised by these arms, but the binary may probe for it.
GATE_CL="$PROJECT/zig-out/bin/weizigo-claimlint"
[ -x "$GATE_CL" ] || GATE_CL="$PROJECT/bin/weizigo-claimlint"
if [ -x "$GATE_CL" ]; then
    mkdir -p "$TMPDIR/bin" "$TMPDIR/docs/epistemic"
    cp "$GATE_CL" "$TMPDIR/bin/weizigo-claimlint"
    cat > "$TMPDIR/docs/epistemic/CLAIMS.md" <<'CLAIMS_EOF'
# scratch register — T516 control

## 2. The register

| ID | legacy | goban | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate | tree |
|---|---|---|---|---|---|---|---|---|---|---|
CLAIMS_EOF
fi

# Seed two tasks: T700 (claimed once) and T701 (dispatchable, never claimed).
# claim_count is the per-row count of how many times the row was claimed.
mkdir -p "$TMPDIR/untracked"
echo "# T700 — claimed once" > "$TMPDIR/untracked/T700-bundle.md"
echo "# T701 — dispatchable" > "$TMPDIR/untracked/T701-bundle.md"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T700": {
    "status": "in_progress",
    "agent": "glm-5.2",
    "model": "glm-5.2",
    "bundle": "untracked/T700-bundle.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-20T10:49:14Z",
    "claimed": "2026-08-20T11:24:02Z",
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "verdict": null,
    "verdict_note": null,
    "claim_count": 1
  },
  "T701": {
    "status": "dispatchable",
    "agent": null,
    "model": null,
    "bundle": "untracked/T701-bundle.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-20T10:49:14Z",
    "claimed": null,
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "verdict": null,
    "verdict_note": null,
    "claim_count": 0
  },
  "_sys": {
    "next_id": 701,
    "directive_next": 1
  }
}
JSONEOF
weizigo_reset_census "$TMPDIR/docs/infra/managent/tasks.json"   # T873: direct write bypasses the S10 census

# Snapshot the store for the byte-identity guard (arm 4).
STORE_BEFORE="$(cat "$TMPDIR/docs/infra/managent/tasks.json")"

echo ""
echo "  T516 regression: status --json added/claim_count"

# ── Arm 1: claimed task exposes added + claim_count==1 ───────────────────
echo "        1. claimed task exposes added + claim_count==1"

STATUS_JSON=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
if ! python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
t = by_id.get("T700")
fails = []
if t is None:
    print("           FAIL: T700 missing from status --json")
    sys.exit(1)
if "added" not in t:
    fails.append("added field absent (got %r)" % sorted(t.keys()))
elif t["added"] != "2026-08-20T10:49:14Z":
    fails.append("added=%r, expected '2026-08-20T10:49:14Z'" % t.get("added"))
if "claim_count" not in t:
    fails.append("claim_count field absent (got %r)" % sorted(t.keys()))
elif t["claim_count"] != 1:
    fails.append("claim_count=%r, expected 1" % t.get("claim_count"))
if fails:
    for f in fails:
        print("           FAIL: " + f)
    sys.exit(1)
print("           PASS: T700 added + claim_count==1 present and correct")
PYEOF
then
    FAIL=1
fi

# ── Arm 2: dispatchable (unclaimed) task exposes added + claim_count==0 ──
echo "        2. dispatchable task exposes added + claim_count==0"

if ! python3 - "$STATUS_JSON" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
t = by_id.get("T701")
fails = []
if t is None:
    print("           FAIL: T701 missing from status --json")
    sys.exit(1)
if "added" not in t:
    fails.append("added field absent (got %r)" % sorted(t.keys()))
elif t["added"] != "2026-08-20T10:49:14Z":
    fails.append("added=%r, expected '2026-08-20T10:49:14Z'" % t.get("added"))
if "claim_count" not in t:
    fails.append("claim_count field absent (got %r)" % sorted(t.keys()))
elif t["claim_count"] != 0:
    fails.append("claim_count=%r, expected 0" % t.get("claim_count"))
if fails:
    for f in fails:
        print("           FAIL: " + f)
    sys.exit(1)
print("           PASS: T701 added + claim_count==0 present and correct")
PYEOF
then
    FAIL=1
fi

# ── Arm 3: a task claimed twice exposes claim_count==2 ──────────────────
echo "        3. re-claimed task exposes claim_count==2"

cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T702": {
    "status": "in_progress",
    "agent": "glm-5.2",
    "model": "glm-5.2",
    "bundle": "untracked/T702-bundle.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-20T10:49:14Z",
    "claimed": "2026-08-20T12:00:00Z",
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "verdict": null,
    "verdict_note": null,
    "claim_count": 2
  },
  "_sys": {
    "next_id": 702,
    "directive_next": 1
  }
}
JSONEOF
echo "# T702 — claimed twice" > "$TMPDIR/untracked/T702-bundle.md"
weizigo_reset_census "$TMPDIR/docs/infra/managent/tasks.json"   # T873: direct write bypasses the S10 census

STATUS_JSON2=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
if ! python3 - "$STATUS_JSON2" <<'PYEOF'
import sys, json
data = json.loads(sys.argv[1])
by_id = {d["id"]: d for d in data}
t = by_id.get("T702")
if t is None:
    print("           FAIL: T702 missing from status --json")
    sys.exit(1)
fails = []
if t.get("added") != "2026-08-20T10:49:14Z":
    fails.append("added=%r" % t.get("added"))
if t.get("claim_count") != 2:
    fails.append("claim_count=%r, expected 2" % t.get("claim_count"))
if fails:
    for f in fails:
        print("           FAIL: " + f)
    sys.exit(1)
print("           PASS: T702 claim_count==2 present and correct")
PYEOF
then
    FAIL=1
fi

# ── Arm 4: byte-identity guard — status --json never mutates the store ────
echo "        4. byte-identity guard — status --json does not mutate tasks.json"

# Re-seed the two-task store (arm 3 overwrote it) and run status --json again.
cat > "$TMPDIR/docs/infra/managent/tasks.json" <<'JSONEOF'
{
  "T700": {
    "status": "in_progress",
    "agent": "glm-5.2",
    "model": "glm-5.2",
    "bundle": "untracked/T700-bundle.md",
    "set": "A",
    "holds": [],
    "needs": [],
    "caps": [],
    "added": "2026-08-20T10:49:14Z",
    "claimed": "2026-08-20T11:24:02Z",
    "done": null,
    "dispatched": null,
    "dispatched_to": null,
    "note": null,
    "verdict": null,
    "verdict_note": null,
    "claim_count": 1
  },
  "_sys": {
    "next_id": 700,
    "directive_next": 1,
    "duty_migrated": true
  }
}
JSONEOF
weizigo_reset_census "$TMPDIR/docs/infra/managent/tasks.json"   # T873: direct write bypasses the S10 census
SNAP="$(cat "$TMPDIR/docs/infra/managent/tasks.json")"
(cd "$TMPDIR" && "$MG" status --json 2>/dev/null) >/dev/null
AFTER="$(cat "$TMPDIR/docs/infra/managent/tasks.json")"
if [ "$SNAP" = "$AFTER" ]; then
    echo "           PASS: tasks.json byte-identical after status --json"
else
    echo "           FAIL: tasks.json was mutated by status --json"
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T516: ALL CHECKS PASS"
else
    echo "  T516: SOME CHECKS FAILED"
fi
exit "$FAIL"