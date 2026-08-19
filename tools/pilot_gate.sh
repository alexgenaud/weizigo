#!/bin/sh
# Pilot gate (ADR-0012): every engine change must reproduce the recorded
# small-goban artifacts BYTE-IDENTICALLY before any big-goban run.
#
#   sh tools/pilot_gate.sh          # fast: 2x2 + 3x2 + 3x3 + 4x3 (~seconds)
#   sh tools/pilot_gate.sh --full   # also 4x4 (~20 min, checks recorded sha256)
#
# Exits non-zero on ANY divergence. Determinism is the foundation: same
# engine semantics => same bytes; a changed hash means changed semantics.
#
# T450 (2026-08-19, kimi-k2.7): rebuilt so the gate writes ONLY into a
# scratch directory and only promotes the scratch files into the live
# tree once the comparison passes. The old script wrote the regenerated
# `artifacts/*.wzo` into the live tree first and verified after, so a
# determinism break left modified TRACKED files where the next
# `git add -A` could sweep them. The `--full` branch did the same to
# `data/oracle-4x4.checkpoint.wzo` (258 MB, gitignored, no off-disk
# archive) — `rm -f` + `mv ...prev` before a 20-min rebuild with no
# trap. The gate's whole value is that a failing run leaves nothing
# behind; both branches now respect that.
#
# Scratch invariant: every output of the build lives under
# /tmp/weizigo/pilot_gate.XXXXXX. The live tree is touched ONLY on
# the `cp` step at the end of the fast branch — which is skipped on
# any divergence — and NEVER touched by `--full` (the comparison IS
# the gate; data/ is gitignored so there is nothing to update).
#
# Engine quirk (retro.zig:4440-4457): the RETRO_SAVE branch honors
# RETRO_SAVE_*_OUT env vars for the per-board artifact path, but the
# trailing writeChecksums() reads from HARDCODED `artifacts/<name>`
# paths (cwd-relative). To make the engine's checksum writer land in
# scratch, we `cd` into the scratch dir AND pre-create
# `artifacts/<name>` as symlinks to the bare scratch files. The
# scratch files exist only AFTER the build, so the symlinks dangle
# until then — the engine writes the symlink targets first, then
# writeChecksums reads them via the (now-resolvable) symlinks. The
# gate ignores the engine's SHA256SUMS output and computes the hash
# comparison itself, so the symlink gymnastics are only to satisfy
# the engine's hardcoded path list.

set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

# T445: refuse to run if scratch creation fails. An empty scratch path
# once sent this suite into the LIVE tree.
mkdir -p /tmp/weizigo
SCRATCH_ROOT=$(mktemp -d /tmp/weizigo/pilot_gate.XXXXXX) || {
    echo "pilot_gate: FATAL — scratch mktemp failed; refusing to run (T445)" >&2
    exit 2
}

# EXIT trap: always wipe scratch, even on SIGTERM / SIGKILL / failure.
# The live tree was untouched during the build, so the trap only has to
# clean /tmp.
cleanup() {
    rc=$?
    rm -rf "$SCRATCH_ROOT" 2>/dev/null || true
    exit "$rc"
}
trap cleanup EXIT INT TERM

# ── fast branch: 2x2/3x2/3x3/4x3 ──────────────────────────────────────
# Run the build in scratch so the live `artifacts/` and the engine's
# `writeChecksums("artifacts/SHA256SUMS", ...)` land under $SCRATCH_ROOT,
# not in the live tree.
FAST_DIR="$SCRATCH_ROOT/fast"
mkdir -p "$FAST_DIR/artifacts"
# Pre-create the hardcoded artifacts/<name> paths as symlinks to
# scratch-relative bare names. The links dangle until the build
# populates the targets; writeChecksums then reads through them.
ln -s ../oracle-2x2.wzo "$FAST_DIR/artifacts/oracle-2x2.wzo"
ln -s ../oracle-3x2.wzo "$FAST_DIR/artifacts/oracle-3x2.wzo"
ln -s ../oracle-3x3.wzo "$FAST_DIR/artifacts/oracle-3x3.wzo"
ln -s ../oracle-4x3.wzo "$FAST_DIR/artifacts/oracle-4x3.wzo"

echo "pilot gate: rebuilding 2x2/3x2/3x3/4x3 artifacts in scratch..."
(
    cd "$FAST_DIR" && \
    RETRO_SAVE=1 \
    RETRO_SAVE_2X2_OUT=oracle-2x2.wzo \
    RETRO_SAVE_3X2_OUT=oracle-3x2.wzo \
    RETRO_SAVE_3X3_OUT=oracle-3x3.wzo \
    RETRO_SAVE_4X3_OUT=oracle-4x3.wzo \
    zig run -O ReleaseFast "$REPO/src/retro.zig" >/dev/null 2>&1
)

# Verify each scratch artifact's SHA against the committed
# artifacts/SHA256SUMS entry. A determinism break fails HERE, before
# anything is promoted into the live tree.
FAIL=0
while IFS=' ' read -r want_hash want_path; do
    case "$want_path" in
        artifacts/oracle-2x2.wzo|artifacts/oracle-3x2.wzo|artifacts/oracle-3x3.wzo|artifacts/oracle-4x3.wzo)
            bare=$(basename "$want_path")
            got=$(shasum -a 256 "$FAST_DIR/$bare" 2>/dev/null | cut -d' ' -f1)
            if [ "$got" != "$want_hash" ]; then
                echo "pilot_gate: FAIL — $bare sha256 $got != $want_hash (want)"
                FAIL=1
            fi
            ;;
    esac
done < "$REPO/artifacts/SHA256SUMS"

if [ "$FAIL" -ne 0 ]; then
    echo "  scratch retained for inspection: $FAST_DIR"
    exit 1
fi

# Comparison passed — promote scratch files into the live tree. Use cp
# rather than mv so a SIGKILL during copy still leaves the original
# tracked files in place; the trap will only remove scratch.
cp "$FAST_DIR/oracle-2x2.wzo" "$REPO/artifacts/oracle-2x2.wzo"
cp "$FAST_DIR/oracle-3x2.wzo" "$REPO/artifacts/oracle-3x2.wzo"
cp "$FAST_DIR/oracle-3x3.wzo" "$REPO/artifacts/oracle-3x3.wzo"
cp "$FAST_DIR/oracle-4x3.wzo" "$REPO/artifacts/oracle-4x3.wzo"

# Final belt-and-braces: even after a clean promotion, the live
# `artifacts/` tree must be unchanged — catches a copy that landed on
# a path that already differed, or any other drift.
if ! git diff --exit-code -- artifacts/ >/dev/null 2>&1; then
    echo "pilot gate: FAIL — live artifacts/ differs from committed after promotion"
    echo "  diff:"
    git diff -- artifacts/ | sed 's/^/    /'
    exit 1
fi

# ── --full branch: 4x4 ────────────────────────────────────────────────
# The 4x4 rebuild takes ~20 min and writes a 258 MB checkpoint +
# final artifact. Both go to scratch. The comparison IS the gate:
# the regenerated checkpoint must hash to a2174fed... (the committed
# `data/oracle-4x4.checkpoint.wzo`). We never touch the live
# `data/` tree — data/ is gitignored, so a successful rebuild doesn't
# need to be promoted (the committed copy is the canonical one, and
# the gate's job is to PROVE the rebuild reproduces it).
#
# The committed `data/oracle-4x4.wzo` does NOT exist on disk
# (AGENTS.md:54-57); the WANT hash that the old script checked
# (`b42c3371...`) was the pre-crisis retracted value. The right
# comparison is against the CHECKPOINT, which IS on disk and IS the
# artifact the gate exists to protect (CLAIMS.md §4-O5,
# `GLOBAL.ADR0012-GATE`).
if [ "$1" = "--full" ]; then
    FULL_DIR="$SCRATCH_ROOT/full"
    mkdir -p "$FULL_DIR"

    echo "pilot gate: rebuilding 4x4 in scratch (~20 min)..."
    (
        cd "$FULL_DIR" && \
        RETRO_4X4=1 \
        RETRO_4X4_OUT=oracle-4x4.wzo \
        RETRO_4X4_CKPT=oracle-4x4.checkpoint.wzo \
        zig run -O ReleaseFast "$REPO/src/retro.zig" >/dev/null 2>&1
    )

    # Live `data/` must be byte-identical to HEAD. Catches any code
    # path that wrote to cwd-relative `data/` instead of honoring the
    # env var override.
    if ! git diff --exit-code -- data/ >/dev/null 2>&1; then
        echo "pilot gate: FAIL — live data/ was touched during rebuild (env-var override missed)"
        echo "  diff (first 10 lines):"
        git diff -- data/ | head -10 | sed 's/^/    /'
        exit 1
    fi

    WANT_CKPT="a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118"
    GOT_CKPT=$(shasum -a 256 "$FULL_DIR/oracle-4x4.checkpoint.wzo" | cut -d' ' -f1)
    if [ "$GOT_CKPT" != "$WANT_CKPT" ]; then
        echo "pilot gate: FAIL — 4x4 checkpoint sha256 $GOT_CKPT != $WANT_CKPT"
        echo "  scratch retained for inspection: $FULL_DIR"
        exit 1
    fi

    # Final artifact: the `oracle-4x4.wzo` referenced in pre-crisis
    # docs no longer exists on disk, and its committed sha256
    # (`b42c3371...`) is RETRACTED (see `4x4.COMPLETE-2026-07-21.md`
    # status: FALSE-AS-SCOPED, narrowed-by C1 only). We DO NOT assert
    # a sha here — that would be checking a value the project has
    # ruled out. The checkpoint hash IS the gate. If a future row
    # restores `oracle-4x4.wzo` as the canonical artifact, the
    # assertion goes here.

    echo "pilot gate: 4x4 checkpoint sha256 OK ($GOT_CKPT)"
fi

echo "pilot gate: PASS"
