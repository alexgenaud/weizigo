#!/usr/bin/env bash
# regression-task-id-archive.sh — T770 controls for task-ID mint vs archive
#
# Defect (T770, 2026-08-23): `managent add --auto` mints `T{sys_next_id}`
# where the counter lives in tasks.json — a DIFFERENT file from the archive
# (docs/infra/managent/archive.json).  Four rows (T761–T763, T765) were
# retired minutes after registration, and the next `add --auto` minted T765
# AGAIN — a live row colliding with the archived T765.  A retired id is a
# reference forever; re-minting it silently rebinds every citation of the
# retired row.  The fix mints from max(next_id, live-max+1, archive-max+1)
# and adds a backstop: registering an id already in tasks.json OR archive.json
# is refused (add previously checked live only).
#
# Controls (scratch store + scratch archive only — never the live kanban):
#   1. null       normal sequential mints unchanged (no archive).
#   2. seeded     retire the top row, roll the counter back below the retired
#                 id, `add --auto` → minted id EXCEEDS the retired id; the
#                 retired id is not re-minted.  RED before the fix: T9001 is
#                 minted a second time over the archived T9001.
#   3. seeded     explicit `add T<retired-id>` → refused, naming the archive.
#                 RED before the fix: the freed-by-retirement id registers
#                 silently.
#
# Task: T770 · Role: worker · Identifier: deepseek-v4-pro/T770 · Date: 2026-08-23

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

# T445: /tmp/weizigo decays.  Create it, and REFUSE to run if scratch creation
# fails — an empty scratch var once sent fixtures into the LIVE repo.
mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/task-id-archive-XXXXXX)" || { echo "regression-task-id-archive.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
git config user.email t770@test
git config user.name T770
echo base > README.md
mkdir -p untracked docs/infra/managent
printf 'untracked/\n' > .gitignore
STORE="$WORK/docs/infra/managent/tasks.json"
ARCHIVE="$WORK/docs/infra/managent/archive.json"
export MANAGENT_STORE="$STORE"
unset WEIZIGO_AGENT_DEPTH

# ── seed: a store with only the _sys counters (no rows) ───────────────────
seed_store() {
    python3 - "$STORE" "$1" <<'PYEOF'
import json, sys
p, n = sys.argv[1], int(sys.argv[2])
d = {"_sys": {"next_id": n, "directive_next": 1, "assertion_next": 1, "closes": 0, "duty_migrated": True}}
json.dump(d, open(p, "w"))
PYEOF
}

# ── write a minimal add-able bundle (valid landmark, T682 gate) ───────────
make_bundle() {  # $1 = slug
    cat > "untracked/$1-bundle.md" <<EOF
<!--managent set=A deliverables=docs/x.md-->
# $1 — test

**Landmark:** advances \`L4 (the ledger is clean)\` — a test.
EOF
}

# ── helper: assert live store holds exactly the T-ids in $@ ───────────────
live_ids_are() {
    python3 - "$STORE" "$@" <<'PYEOF'
import json, sys
store = sys.argv[1]
want = sorted(sys.argv[2:])
d = json.load(open(store))
got = sorted(k for k in d if k.startswith("T") and k != "_sys")
assert got == want, "live T-ids %r != expected %r" % (got, want)
PYEOF
}

# ── helper: assert the archive holds the T-id $1 (and not $2) ─────────────
archive_holds() {
    python3 - "$ARCHIVE" "$1" "${2:-}" <<'PYEOF'
import json, sys
p, want = sys.argv[1], sys.argv[2]
d = json.load(open(p))
assert want in d, "archive missing %s (keys: %r)" % (want, sorted(k for k in d if k.startswith("T")))
if len(sys.argv) > 3 and sys.argv[3]:
    assert sys.argv[3] not in d, "archive should NOT hold %s" % sys.argv[3]
PYEOF
}

echo "=== task-id-mint-archive regression (T770) ==="

# ── 1. null: normal sequential mints unchanged ────────────────────────────
echo "  1. null: normal sequential mints unchanged (empty archive)"
seed_store 9000
make_bundle nullA
make_bundle nullB
"$MG" add --auto --bundle untracked/nullA-bundle.md >/dev/null 2>&1
"$MG" add --auto --bundle untracked/nullB-bundle.md >/dev/null 2>&1
if live_ids_are T9000 T9001; then
    NID=$(python3 -c "import json;print(json.load(open('$STORE'))['_sys']['next_id'])")
    if [ "$NID" = "9002" ]; then
        echo "    PASS: T9000,T9001 minted, next_id 9002"
    else
        echo "    FAIL: next_id=$NID (expected 9002)"; FAIL=1
    fi
else
    echo "    FAIL: null arm — expected live T9000,T9001"; FAIL=1
fi

# ── 2. seeded: retire a top row, roll counter back, add --auto ────────────
echo "  2. seeded: retire top row + stale counter → mint exceeds the retired id"
seed_store 9000
make_bundle topA
make_bundle topB
make_bundle topC
"$MG" add --auto --bundle untracked/topA-bundle.md >/dev/null 2>&1   # T9000
"$MG" add --auto --bundle untracked/topB-bundle.md >/dev/null 2>&1   # T9001
"$MG" retire T9001 --note "top row retired" >/dev/null 2>&1
if archive_holds T9001; then
    echo "    (retire moved T9001 to the archive)"
else
    echo "    FAIL: retire did not archive T9001"; FAIL=1
fi
# Simulate the observed store rollback: next_id falls back below the retired
# id.  RED before the fix mints T9001 again over the archived row.
python3 - "$STORE" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
d["_sys"]["next_id"] = 9001
json.dump(d, open(sys.argv[1], "w"))
PYEOF
"$MG" add --auto --bundle untracked/topC-bundle.md >/dev/null 2>&1
if live_ids_are T9000 T9002 && archive_holds T9001 T9002; then
    echo "    PASS: minted T9002 (> archived T9001), retired id not re-minted"
else
    echo "    FAIL: arm 2 — retired id re-minted or mint did not exceed it"
    python3 - "$STORE" "$ARCHIVE" <<'PYEOF'
import json, sys
live = json.load(open(sys.argv[1])); arc = json.load(open(sys.argv[2]))
print("      live  T-ids:", sorted(k for k in live if k.startswith("T")))
print("      archive T-ids:", sorted(k for k in arc if k.startswith("T")))
PYEOF
    FAIL=1
fi

# ── 3. seeded: explicit add of a retired id → refused naming the archive ──
echo "  3. seeded: explicit add of a retired id → refused, naming the archive"
make_bundle reuse
OUT=$("$MG" add T9001 --bundle "untracked/reuse-bundle.md" 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "archive"; then
    echo "    PASS: add T9001 refused (rc=$RC) naming the archive"
else
    echo "    FAIL: rc=$RC; expected refusal naming the archive"; echo "$OUT" | sed 's/^/    | /'
    FAIL=1
fi
# the refused row must NOT have been registered
if live_ids_are T9000 T9002; then
    echo "    PASS: refused row not registered"
else
    echo "    FAIL: refused T9001 row was registered"; FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-task-id-archive: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-task-id-archive: FAILURES ==="
    exit 1
fi
