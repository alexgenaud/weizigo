#!/usr/bin/env bash
# regression-ram-declaration.sh
# T913 regression: bin/subagent declares RAM by EXPECTED WALL, not provider.
#
# Defect (T913, 2026-08-25): docs/infra/host/ram-policy.md (T806) measured
# what predicts a lane's peak RSS and found PROVIDER does not —
# §3.1: all providers converge (deepseek p95 3207, claude p95 3380,
# ollama-cloud p95 3184); ORC-GD-2's per-provider table is "confounded: it
# reads provider identity off a distribution whose shape is set by
# something else".  What predicts it is TIME ON TASK (§3.2: run duration
# separates the distribution monotonically in every quantile).  bin/subagent
# still keyed on provider — PROVIDER_RAM_MB_DEFAULT {claude: 1024,
# deepseek: 2816, pi: 1024} — and it cost us twice in ten minutes: T912
# (a 3x2 ko adjudication, --wall=10800) was dispatched to a claude lane,
# declared 1024 MB, capped at 1280, and killed twice (exit 124, RSS cap
# exceeded, at 242.8 s and 279.9 s).  Under the ratified rule its 10,800 s
# wall sits in the ≥ 1800 s band at 4608 MB and it would not have died.
#
# The ratified rule (ram-policy.md §3.2, applied verbatim):
#   expected wall     n    p95   default  (default = ceil(p95/256) x 256)
#   < 60 s            97    570   768
#   60-600 s         104   1626  1792
#   600-1800 s       119   2992  3072
#   >= 1800 s         45   4574  4608
# Boundary convention (T913 acceptance arm 2): a boundary value (60, 600,
# 1800) lands in the band it STARTS — exactly 60 s -> 1792, exactly 600 s
# -> 3072, exactly 1800 s -> 4608.  An explicit --ram-mb=N always wins
# (policy §3.3 override rule).  A resident local model (provider ollama,
# no :cloud tag) keeps the REGISTRY figure (18432) — a declaration about
# a MODEL, not a lane, untouched by this row.
#
# Arms:
#   1. incident regression: wall=10800 declares the TOP band (4608) — not
#      1024, the declaration that killed T912 twice.
#   2. provider neutrality: two providers with the same wall declare the
#      SAME figure (deepseek vs claude vs pi vs ollama-cloud).
#   3. boundary controls: exactly 60 / 600 / 1800 s land in the bands the
#      policy names (1792 / 3072 / 4608); just below each boundary is the
#      band below (768 / 1792 / 3072).
#   4. null control: an explicit --ram-mb=N still overrides; a resident
#      local model still declares its registry figure unchanged.
#   5. unit-level: the band arithmetic + provider neutrality asserted
#      directly against bin/subagent's functions (import, no subprocess).
#
# All dispatch arms run through the REAL path (bin/subagent --dry-run, the
# same launch chokepoint every lane uses) and parse --ram-mb N out of the
# printed command.  Environment guards for determinism:
#   WEIZIGO_AGENT_DEPTH=1       (this test may run inside a leaf console;
#                               depth 3 would refuse before the dry-run)
#   DEEPSEEK_API_KEY=dummy      (dry-run never uses it; the presence check
#                               would otherwise depend on the caller's env)
#   --override-admission=t913-regression        (admission preview may
#   --override-window-cooldown=t913-regression   refuse/cooldown on host
#                                                state; the declaration is
#                                                what this test asserts,
#                                                and dry-run records no
#                                                override anywhere)
#   WEIZIGO_OLLAMA_OFFERED      (T890 arm B: pin the host's served tags so
#                               an ollama dry-run cannot refuse on a tag
#                               the live host happens not to serve)
#
# Wired into build.zig by T913.  Task: T913 · Role: worker · Model:
# deepseek-v4-flash · Date: 2026-08-25.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
SUBAGENT="$PROJECT/bin/subagent"
TARGET="AGENTS.md"   # file-branch dispatch: no kanban, no bundle glob

FAIL=0

echo ""
echo "  T913 regression: RAM declared by wall, not provider"

# ── helpers ─────────────────────────────────────────────────────────────
# declared_ram <subagent args...> -> the --ram-mb N the dry-run command
# carries (the runner-side declaration; "" on any failure).
declared_ram() {
    WEIZIGO_AGENT_DEPTH=1 DEEPSEEK_API_KEY=dummy \
        "$SUBAGENT" "$@" --dry-run \
        --override-admission=t913-regression \
        --override-window-cooldown=t913-regression 2>/dev/null \
        | grep -oE -- "--ram-mb [0-9]+" | head -1 | awk '{print $2}'
}

expect_ram() {   # expect_ram <want> <label> <subagent args...>
    local want="$1" label="$2"; shift 2
    local got
    got=$(declared_ram "$@")
    if [ "$got" = "$want" ]; then
        echo "           PASS: $label -> $got"
    else
        echo "           FAIL: $label -> declared $got, want $want"
        FAIL=1
    fi
}

# ── Arm 1: the incident, twice — wall=10800 must declare the top band ─────
# T912 (a 3x2 ko adjudication, --wall=10800) was dispatched to a claude
# lane, declared 1024 MB, capped at 1280, and died twice (exit 124).  The
# pre-T913 code declares 1024 here — this arm is RED before the fix.
echo "        1. incident: wall=10800 declares the top band (4608), on every provider"
expect_ram 4608 "claude  wall=10800" --provider claude "$TARGET" --model claude-fable-5 --wall=10800
expect_ram 4608 "deepseek wall=10800" --provider deepseek "$TARGET" --dsflash --wall=10800
expect_ram 4608 "pi      wall=10800" --provider pi "$TARGET" --model stealth/ox-alpha --wall=10800
expect_ram 4608 "ollama-cloud wall=10800" --provider ollama "$TARGET" --model glm-5.2:cloud --wall=10800

# ── Arm 2: provider neutrality — same wall, same figure ───────────────────
# The brief's headline assertion: two providers with the same wall declare
# the SAME figure.  Pre-T913: claude 1024 vs deepseek 2816 at the same
# wall — the confound §3.1 measured.
echo "        2. provider neutrality: same wall -> same figure"
CLAUD=$(declared_ram --provider claude "$TARGET" --model claude-fable-5 --wall=600)
DSFL=$(declared_ram --provider deepseek "$TARGET" --dsflash --wall=600)
if [ -n "$CLAUD" ] && [ "$CLAUD" = "$DSFL" ] && [ "$CLAUD" = "3072" ]; then
    echo "           PASS: claude=$CLAUD deepseek=$DSFL (wall=600 -> 3072)"
else
    echo "           FAIL: claude=$CLAUD deepseek=$DSFL at wall=600 — provider still shapes the declaration"
    FAIL=1
fi

# ── Arm 3: boundary controls — exactly 60/600/1800 land in their band ─────
echo "        3. boundaries: 60/600/1800 land in the band they START"
expect_ram 1792 "exactly  60 s" --provider claude "$TARGET" --model claude-fable-5 --wall=60
expect_ram 3072 "exactly 600 s" --provider claude "$TARGET" --model claude-fable-5 --wall=600
expect_ram 4608 "exactly 1800 s" --provider claude "$TARGET" --model claude-fable-5 --wall=1800
echo "           . just below each boundary is the band below"
expect_ram 768  "       59 s" --provider claude "$TARGET" --model claude-fable-5 --wall=59
expect_ram 1792 "      599 s" --provider claude "$TARGET" --model claude-fable-5 --wall=599
expect_ram 3072 "     1799 s" --provider claude "$TARGET" --model claude-fable-5 --wall=1799

# ── Arm 4: null controls ─────────────────────────────────────────────────
echo "        4. null: explicit --ram-mb=N wins; resident model keeps its registry figure"
expect_ram 1234 "--ram-mb=1234 beats wall=10800" --provider claude "$TARGET" --model claude-fable-5 --wall=10800 --ram-mb=1234
expect_ram 18432 "resident qwen3.8:27b-mlx (wall=10800)" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --wall=10800
expect_ram 18432 "resident qwen3.8:27b-mlx (wall=30)" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --wall=30

# ── Arm 5: unit-level — the band arithmetic and provider neutrality ───────
# Direct against bin/subagent's functions (import; no subprocess).  RED
# pre-fix: _wall_band_ram_mb does not exist and _declared_ram_mb takes no
# wall argument.
echo "        5. unit: band arithmetic + provider neutrality (import)"
UNIT=$(python3 - "$PROJECT/bin/subagent" <<'PYEOF' 2>&1 || true
import importlib.machinery, types, sys
path = sys.argv[1]
loader = importlib.machinery.SourceFileLoader("subagent", path)
m = types.ModuleType("subagent")
m.__file__ = path
loader.exec_module(m)

fails = []
def check(name, got, want):
    if got != want:
        fails.append("%s: got %r want %r" % (name, got, want))

# band arithmetic; boundary values (60/600/1800) belong to the band they start
for wall, want in [(0, 768), (59, 768), (60, 1792), (599, 1792), (600, 3072),
                   (1799, 3072), (1800, 4608), (1801, 4608), (10800, 4608)]:
    check("band(%d)" % wall, m._wall_band_ram_mb(wall), want)

# provider neutrality: same wall -> same figure across every provider
for wall in (30, 60, 600, 1800, 10800):
    figs = {m._declared_ram_mb("deepseek", None, {}, wall),
            m._declared_ram_mb("claude", "claude-opus-5", {}, wall),
            m._declared_ram_mb("pi", "stealth/ox-alpha", {}, wall),
            m._declared_ram_mb("ollama", "glm-5.2:cloud", {}, wall)}
    if len(figs) != 1:
        fails.append("provider-neutral at wall %d: %r" % (wall, sorted(figs)))

# resident local model keeps the registry figure — a model declaration
check("resident@10800", m._declared_ram_mb("ollama", "qwen3.8:27b-mlx", {}, 10800), m.RESIDENT_MODEL_RAM_MB)
check("resident@30", m._declared_ram_mb("ollama", "qwen3.8:27b-mlx", {}, 30), m.RESIDENT_MODEL_RAM_MB)

# explicit --ram-mb still wins
check("override", m._declared_ram_mb("claude", "claude-opus-5", {"ram-mb": "1234"}, 10800), 1234)

if fails:
    sys.stderr.write("\n".join("           " + f for f in fails) + "\n")
    sys.exit(1)
print("ok")
PYEOF
)
if echo "$UNIT" | grep -q "^ok$"; then
    echo "           PASS: all unit checks"
else
    echo "           FAIL: unit checks"
    echo "$UNIT" | sed 's/^/    | /'
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "  T913: ALL CHECKS PASS"
else
    echo "  T913: SOME CHECKS FAILED"
fi
exit "$FAIL"
