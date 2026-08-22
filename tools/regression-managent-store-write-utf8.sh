#!/usr/bin/env bash
# regression-managent-store-write-utf8.sh
# T587 regression: the store WRITE path must not mangle multi-byte UTF-8.
#
# Symptom under test (2026-08-22): `managent done T556` re-serialized
# docs/infra/managent/tasks.json and a multi-byte char in a note/acceptance
# lost its leading byte (em-dash e2 80 94 -> 80 94), producing invalid JSON
# (`Expecting ',' delimiter`) that crashed `status --json` and emptied
# watch-fleet. This is the WRITE-path sibling of the T569 display truncation;
# T569 fixed the three display sites (hb.command[0..40], ls.note[0..80],
# ls.note[0..max_note]) but the write serializer was the suspected missing
# fourth site.
#
# Diagnosis result (T587): the store serializer is byte-correct — writeJsonString
# emits every byte >= 0x20 verbatim and only escapes ", \, control bytes, so a
# valid multi-byte note passes through unaltered; serializeState builds into a
# growable ArrayList (no fixed-size note buffer exists to slice); and the
# T399 write-site guard re-parses the buffer and refuses to write if it is
# invalid JSON. The corruption was NOT reproduced from the committed write path
# (single-process, 270-row live-store copy, and 80-process stress all preserved
# --/->/é byte-exactly). This regression locks the invariant in: a note and
# acceptance carrying — (e2 80 94), -> (e2 86 92) and é (c3 a9) survive every
# mutating verb byte-exact, and the store is valid JSON after each write.
#
# Arms (scratch store only — never the live kanban):
#   A. `add` writes a note + bundle acceptance carrying the three multi-byte
#      chars; store is valid JSON and the bytes are exact.
#   B. `claim`, `dispatch --note`, `set` each re-serialize the store; after
#      every mutating verb the store is valid JSON and the note bytes are
#      still present exactly.
#   C. `done` (blocked verdict — skips deliverable/absorption/acceptance gates)
#      re-serializes a second row whose note carries the chars; valid JSON +
#      exact bytes after; `amend` then re-serializes again.
#   D. `status --json` round-trip parses the written store cleanly.
#
# Usage:  tools/regression-managent-store-write-utf8.sh [--build]
#   --build: rebuild managent from source + deploy before testing

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

if [ "${1:-}" = "--build" ]; then
    echo "  rebuilding managent (guarded, ReleaseSafe) and deploying..."
    (cd "$PROJECT" && "$PROJECT/tools/runner" --no-prepend-zig -- zig build -Doptimize=ReleaseSafe 2>&1)
    "$PROJECT/tools/deploy.sh" "$PROJECT/zig-out/bin/managent" "$MG"
fi

if [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary (build with 'zig build') — T587 needs it"
    exit 0
fi

mkdir -p /tmp/weizigo
TMPDIR="$(mktemp -d /tmp/weizigo/managent-store-write-utf8-XXXXXX)" || { echo "regression-managent-store-write-utf8.sh: FATAL — scratch mktemp failed; refusing to run (T445)" >&2; exit 2; }
trap 'rm -rf "$TMPDIR"' EXIT

# Scratch repo (repo_root) with the store inside it. git is initialized so
# the binary's git probes (done deliverable check, isLiveStore) behave.
mkdir -p "$TMPDIR/docs/infra/managent" "$TMPDIR/untracked"
git init -q "$TMPDIR"
git -C "$TMPDIR" config user.email "t587@test"
git -C "$TMPDIR" config user.name "T587"

STORE="$TMPDIR/docs/infra/managent/tasks.json"
export MANAGENT_STORE="$STORE"

# Bundles: T700's acceptance carries the three chars (it never runs in these
# arms — blocked verdict and set/claim/dispatch skip acceptance); T701 has no
# deliverables/acceptance so the done gate has nothing to refuse.
cat > "$TMPDIR/untracked/T700-bundle.md" <<'BEOF'
<!--managent set=A acceptance=printf 'ok — → é'-->
# T700 — store-write UTF-8 control (add/claim/dispatch/set arms)
BEOF
cat > "$TMPDIR/untracked/T701-bundle.md" <<'BEOF'
<!--managent set=A-->
# T701 — store-write UTF-8 control (done/amend arm)
BEOF

# Assert the three multi-byte sequences are present byte-exactly in a field.
# $1 = store path, $2 = task id, $3 = field name (note|acceptance|...)
field_has_exact_bytes() {
    python3 - "$1" "$2" "$3" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
v = d[sys.argv[2]].get(sys.argv[3]) or ""
for name, seq in (("em-dash", b"\xe2\x80\x94"), ("arrow", b"\xe2\x86\x92"), ("e-acute", b"\xc3\xa9")):
    if seq not in v.encode():
        sys.exit(f"FAIL: {name} bytes {seq.hex()} missing from {sys.argv[3]} {v!r}")
print(f"      PASS: {sys.argv[3]} carries the three multi-byte chars byte-exact ({v!r})")
PYEOF
    return $?
}

store_valid_json() { # $1 = json store path
    python3 -m json.tool "$1" >/dev/null 2>&1 || {
        echo "      FAIL: store is not valid JSON after the write"
        FAIL=1
        return 1
    }
    echo "      PASS: store valid JSON (python3 -m json.tool)"
}

echo ""
echo "  T587 regression: store write must not mangle multi-byte UTF-8"

# ── Arm A: add writes note + acceptance with the three chars ──────────────
echo "    A. add writes a multi-byte note and acceptance"
NOTE="note — dash, → arrow, é acc"
ADD_OUT=$(cd "$TMPDIR" && "$MG" add T700 --note "$NOTE" 2>&1)
echo "       add: $(echo "$ADD_OUT" | head -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T700 note
field_has_exact_bytes "$STORE" T700 acceptance

# ── Arm B: claim / dispatch --note / set re-serialize byte-exactly ────────
echo "    B. claim / dispatch --note / set re-serialize byte-exactly"

CLAIM_OUT=$(cd "$TMPDIR" && "$MG" claim T700 --agent deepseek-v4-pro 2>&1)
echo "       claim: $(echo "$CLAIM_OUT" | head -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T700 note

DISPATCH_OUT=$(cd "$TMPDIR" && "$MG" dispatch T700 --to deepseek-v4-pro --note "dispatch — → é" 2>&1)
echo "       dispatch: $(echo "$DISPATCH_OUT" | head -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T700 note

SET_OUT=$(cd "$TMPDIR" && "$MG" set T700 B 2>&1)
echo "       set: $(echo "$SET_OUT" | head -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T700 note
field_has_exact_bytes "$STORE" T700 acceptance

# ── Arm C: done (blocked) + amend re-serialize a second multi-byte row ────
echo "    C. done (blocked) + amend re-serialize a second multi-byte row"
ADD2_OUT=$(cd "$TMPDIR" && "$MG" add T701 --note "done — → é" 2>&1)
echo "       add T701: $(echo "$ADD2_OUT" | head -1)"
(cd "$TMPDIR" && "$MG" claim T701 --agent deepseek-v4-pro >/dev/null 2>&1)
DONE_OUT=$(cd "$TMPDIR" && "$MG" done T701 --agent deepseek-v4-pro --status blocked \
    --note "blocked — → é" \
    --impression-waiver "no model ran — operator test" --force 2>&1)
echo "       done: $(echo "$DONE_OUT" | tail -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T701 note

AMEND_OUT=$(cd "$TMPDIR" && "$MG" amend T701 --verdict pass-with-findings --note "amended — → é" 2>&1)
echo "       amend: $(echo "$AMEND_OUT" | head -1)"
store_valid_json "$STORE"
field_has_exact_bytes "$STORE" T701 note

# ── Arm D: status --json round-trip parses the written store ──────────────
echo "    D. status --json round-trip parses the written store"
JSON_OUT=$(cd "$TMPDIR" && "$MG" status --json 2>/dev/null)
python3 - "$JSON_OUT" <<'PYEOF'
import json, sys
rows = json.loads(sys.argv[1])
by_id = {r["id"]: r for r in rows}
if "T700" not in by_id or "T701" not in by_id:
    sys.exit("FAIL: status --json missing T700/T701")
assert by_id["T701"]["status"] == "done", f"T701 status {by_id['T701']['status']!r}"
print("      PASS: status --json parsed the written store (T700 + T701 present)")
PYEOF
store_valid_json "$STORE"

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T587: ALL CHECKS PASS"
else
    echo "  T587: SOME CHECKS FAILED"
fi
exit "$FAIL"
