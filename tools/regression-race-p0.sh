#!/usr/bin/env bash
# regression-race-p0.sh — controls for the grand-race P0 gate (T529)
#
# The P0 gate (tools/race-p0-verify.sh) decides whether the grand race and the
# aspect races may start: it verifies the sealed answer keys and packets, the
# frozen fixture stores, the roster, and — the G2 substance — that no answer-key
# material is reachable from the run root the lanes see.
#
# An instrument's first reading counts only after a null control and a seeded
# control (orient principle 4). The gate carries both in --self-test:
#
#   null    a byte-identical copy of a fixture store, with mtimes rewritten,
#           still matches its content seal — the honest case is not a FAIL.
#   null    a run root holding fixtures and no key is not flagged.
#   seeded  one flipped byte in a fixture is caught.
#   seeded  a key.txt planted in a run root is caught — the T452 breach, which
#           at rest is one `cp -r packets/*` away, because the five aspect keys
#           sit beside the fixtures they answer.
#   seeded  a lane whose own transcript shows it reading an answer key is caught.
#   null    a packet BRIEF that names the key path is not counted as a lane
#           action — the epistemic MANIFEST names every key path verbatim, so
#           counting the brief would red-light every honest run.
#   demo    the MANIFEST's own `tar` seal diverges on that same identical copy.
#           That is the defect the content seal routes around: a tar stream
#           carries mtimes and the path prefix, so it cannot tell "copied" from
#           "tampered", and it red-lights the honest case. Recorded as a
#           control so a future edit that reverts to tar hashing fails here.
#
# This wrapper additionally asserts the gate is red-first: it must NO-GO when
# the seal file disagrees with the store, not only GO when it agrees.
#
# FRESH-CLONE SAFE.  The sealed packets live under untracked/, so a fresh clone
# has neither them nor the epoch roster.  The controls above are self-contained
# (the gate synthesizes a store when the real one is absent) and always run; the
# two live-tree arms SKIP LOUDLY rather than fail, because a suite arm that
# needs an untracked input is an arm that quietly stops running.

set -uo pipefail
cd "$(dirname "$0")/.."

fails=0

echo "=== regression-race-p0: gate controls ==="
if ! python3 tools/race-p0-verify.sh --self-test; then
    echo "FAIL: race-p0-verify --self-test did not pass"
    fails=$((fails + 1))
fi

PACKETS=untracked/race-aspects/packets
ROSTER=docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/roster-2026-08-20b.txt
if [ ! -d "$PACKETS" ] || [ ! -f "$ROSTER" ]; then
    echo
    echo "SKIP  live-tree arms: $PACKETS or $ROSTER absent (both untracked)."
    echo "      The controls above ran; the sealed-tree GO/NO-GO arms need the"
    echo "      race packets, which exist only on a host that holds them."
    echo
    if [ "$fails" -eq 0 ]; then
        echo "=== regression-race-p0: CONTROLS PASSED (live-tree arms skipped) ==="
        exit 0
    fi
    echo "=== regression-race-p0: $fails FAILURE(S) ==="
    exit 1
fi

echo
echo "=== regression-race-p0: red-first — a wrong seal must NO-GO ==="
SEALS=docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0-fixtures.sha256
BACKUP="$(mktemp /tmp/race-p0-seals-XXXXXX)" || { echo "FATAL: mktemp failed"; exit 2; }
cp "$SEALS" "$BACKUP"
restore() { cp "$BACKUP" "$SEALS"; rm -f "$BACKUP"; }
trap restore EXIT

# Corrupt one recorded seal; the gate must refuse.
sed -e 's/^[0-9a-f]\{64\}\(  aspect-triage\)$/0000000000000000000000000000000000000000000000000000000000000000\1/' \
    "$BACKUP" > "$SEALS"
if python3 tools/race-p0-verify.sh --roster "$ROSTER" >/dev/null 2>&1; then
    echo "FAIL: gate said GO with a corrupted fixture seal"
    fails=$((fails + 1))
else
    echo "PASS  seeded: a corrupted fixture seal makes the gate NO-GO"
fi
restore
trap - EXIT

echo
echo "=== regression-race-p0: null — the live tree is GO ==="
if python3 tools/race-p0-verify.sh --roster "$ROSTER" >/dev/null 2>&1; then
    echo "PASS  null: the sealed tree with the epoch 2026-08-20b roster is GO"
else
    echo "FAIL: the live sealed tree did not pass the gate"
    fails=$((fails + 1))
fi

echo
if [ "$fails" -eq 0 ]; then
    echo "=== regression-race-p0: ALL CONTROLS PASSED ==="
    exit 0
fi
echo "=== regression-race-p0: $fails FAILURE(S) ==="
exit 1
