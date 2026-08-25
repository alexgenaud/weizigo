#!/usr/bin/env bash
# regression-finishparallel-partition.sh — T932 controls for the finishParallel
# round-robin partition change.
#
# T930 measured the production finishParallel at 5.1x (18 cores) because its
# contiguous chunking is load-imbalanced: the work list is built deepest-first
# and per-root cost is correlated with list position, so the expensive roots
# pile onto one thread (3.34x busiest-thread imbalance at 18 threads; the wall
# is set by the busiest thread).  T932 changes the partition to round-robin
# (root i -> thread i % nt), which T930 measured at 11.5x (16 cores).  This
# regression guards the two properties a partition change must not weaken:
#
#   null control (determinism)   single-threaded and parallel produce
#                                byte-identical finisher counts on the same
#                                root set.  Per-root solves are independent in
#                                writes-off mode (the journal is empty), so the
#                                partition must not change node counts, values,
#                                or the validation verdicts.
#
#   seeded-defect control        a deliberately imbalanced partition
#                                (RETRO_PARTITION=contig, the legacy chunking)
#                                must be detectable by the per-thread node-count
#                                imbalance ratio — otherwise the regression
#                                cannot tell the 5.1x partition from the 11.5x
#                                one and is not guarding anything.
#
# The instrument is the PRODUCTION binary: src/retro.zig is built here and
# driven with RETRO_3X3=1 RETRO_PARALLEL=1 at a small goban (622 orbit reps,
# ~0.3 s/run) so the control is fast enough for `zig build test`.  The
# per-thread node-count line is emitted by finishParallel itself (stderr), so
# the control exercises the shipped code, not a copy of it.
#
# Measured 3x3 @ 3 threads (622 roots, 315,484 nodes):
#   round-robin   per-thread nodes [88099, 117708, 109677]  max/mean = 1.12
#   contiguous    per-thread nodes [170282,  77519,  67683]  max/mean = 1.62
# The 1.40 threshold sits halfway between them with ~0.2 of margin each side.
#
# Task: T932 · Worker: deepseek-v4-pro · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
FAIL=0
IMBALANCE_THRESHOLD="1.40"

note() { echo "$*"; }
pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

WORK=$(mktemp -d -t weizigo-finishparallel-partition-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

echo "=== regression-finishparallel-partition (T932) ==="

# ── build the production binary (the instrument under test) ──────────
BIN="$WORK/retro"
if ! zig build-exe -O ReleaseSafe -femit-bin="$BIN" "$ROOT/src/retro.zig" 2>"$WORK/build.log"; then
    echo "FATAL: src/retro.zig failed to build"
    cat "$WORK/build.log"
    exit 1
fi

# run_case <name> <threads> [contig]
# Runs 3x3 writes-off, captures stderr to $WORK/<name>.err.  Checkpoint/out go
# to the scratch dir (never data/).  A non-zero exit is recorded into the err
# file so the arms below fail loudly rather than silently.
run_case() {
    local name="$1" threads="$2" part="${3:-rr}"
    local rc=0
    if [ "$part" = contig ]; then
        RETRO_3X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS="$threads" \
            RETRO_SOUND=1 RETRO_PARALLEL_PROGRESS=0 RETRO_PARTITION=contig \
            RETRO_PARALLEL_CKPT="$WORK/$name.ckpt" RETRO_PARALLEL_OUT="$WORK/$name.wzo" \
            "$BIN" 2>"$WORK/$name.err" || rc=$?
    else
        RETRO_3X3=1 RETRO_PARALLEL=1 RETRO_PARALLEL_THREADS="$threads" \
            RETRO_SOUND=1 RETRO_PARALLEL_PROGRESS=0 \
            RETRO_PARALLEL_CKPT="$WORK/$name.ckpt" RETRO_PARALLEL_OUT="$WORK/$name.wzo" \
            "$BIN" 2>"$WORK/$name.err" || rc=$?
    fi
    [ "$rc" -ne 0 ] && echo "RUN FAILED (exit $rc)" >>"$WORK/$name.err"
}

# summary <name> — deterministic finisher summary fields (no wall time)
summary() {
    grep '^finishParallel: solved=' "$WORK/$1.err" \
        | sed -E 's/^finishParallel: (solved=[0-9]+ filled=[0-9]+ skipped=[0-9]+ single-ko=[0-9]+ nodes=[0-9]+).*/\1/'
}

# validate <name> — the post-finisher validation line
validate() {
    grep '^validate:' "$WORK/$1.err"
}

# thread_nodes <name> — one integer per line (per-thread node counts)
thread_nodes() {
    grep '^finishParallel: thread ' "$WORK/$1.err" | sed -E 's/.*nodes=([0-9]+)/\1/'
}

# ── Arm 1: null control — serial == parallel, byte-for-byte ──────────
run_case null-serial-1 1
run_case null-serial-2 1
run_case null-par-1 4
run_case null-par-2 4

S1=$(summary null-serial-1); S2=$(summary null-serial-2)
P1=$(summary null-par-1); P2=$(summary null-par-2)

if [ -z "$S1" ] || [ -z "$P1" ]; then
    fail "finisher produced no summary line (binary failed?)"
    sed 's/^/      /' "$WORK/null-serial-1.err" "$WORK/null-par-1.err"
elif [ "$S1" = "$S2" ] && [ "$S1" = "$P1" ] && [ "$S1" = "$P2" ]; then
    pass "byte-identical across 2 serial + 2 parallel runs: $S1"
else
    fail "finisher counts diverge: serial1=[$S1] serial2=[$S2] par1=[$P1] par2=[$P2]"
fi

if echo "$S1" | grep -qE 'solved=[1-9]'; then
    pass "finisher solved > 0 roots (no vacuous pass)"
else
    fail "finisher solved 0 roots — the control ran no work"
fi

for n in null-serial-1 null-serial-2 null-par-1 null-par-2; do
    if validate "$n" | grep -q 'bracket-fails=0 orbit-clashes=0 symmetry=PASS unfilled=0'; then
        pass "$n: validate clean (bracket-fails=0 orbit-clashes=0 symmetry=PASS unfilled=0)"
    else
        fail "$n: validate not clean: $(validate "$n")"
    fi
done

# ── Arm 2: seeded-defect control — imbalanced partition is detectable ─
run_case balanced 3 rr
run_case imbalanced 3 contig

bal_ratio=$(thread_nodes balanced | awk '{s+=$1; if($1>m)m=$1} END{if(NR==0){print "nan"; exit} printf "%.3f", m/(s/NR)}')
imb_ratio=$(thread_nodes imbalanced | awk '{s+=$1; if($1>m)m=$1} END{if(NR==0){print "nan"; exit} printf "%.3f", m/(s/NR)}')

if [ "$bal_ratio" = nan ] || [ "$imb_ratio" = nan ]; then
    fail "no per-thread node counts reported (finishParallel diagnostic missing?)"
elif awk "BEGIN{exit !($bal_ratio <= $IMBALANCE_THRESHOLD)}"; then
    pass "round-robin balanced: max/mean=${bal_ratio} <= ${IMBALANCE_THRESHOLD}"
else
    fail "round-robin imbalanced: max/mean=${bal_ratio} (want <= ${IMBALANCE_THRESHOLD})"
fi

if [ "$bal_ratio" = nan ] || [ "$imb_ratio" = nan ]; then
    :
elif awk "BEGIN{exit !($imb_ratio > $IMBALANCE_THRESHOLD)}"; then
    pass "seeded contiguous partition DETECTED: max/mean=${imb_ratio} > ${IMBALANCE_THRESHOLD}"
else
    fail "contiguous partition NOT detected: max/mean=${imb_ratio} (want > ${IMBALANCE_THRESHOLD})"
fi

echo ""
if [ "$FAIL" -ne 0 ]; then
    echo "RESULT: FAIL"
    exit 1
fi
echo "RESULT: PASS"
exit 0
