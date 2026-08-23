#!/usr/bin/env bash
# regression-subagent-resident-gate.sh — controls for the resident-aware
# memory-budget dispatch gate (T713, test-first).
#
# T626/T700/T715 kill chain, dispatch side: the resident MLX/Ollama model
# server (ollama runner --mlx-engine, ~15–20 GB RSS) is a NAMED tenant that
# reduces the memory budget the fleet may spend.  The runner's host guard
# (T711) already stops reading the tenant as an emergency; what remains is
# the DISPATCH side: when the model server is resident, the dispatcher
# (bin/subagent — the launch chokepoint) must know the reduced budget and
# size concurrent memory-heavy lanes accordingly, instead of launching a
# local model lane that pushes the host toward OOM — where the runner's
# guard would have to kill a running lane (fratricide).  Cloud-API lanes
# (deepseek / claude / pi-openrouter / :cloud ollama tags) keep a small
# local RSS and dispatch freely.  List-wait is acceptable (a refused
# dispatch leaves the row dispatchable and nothing is killed); killing a
# running lane is not (operator intent).
#
# Gate semantics under test (spec of record until T713's own notes amend):
#   * a lane is memory-heavy iff provider=ollama AND the tag is LOCAL
#     (no `:cloud` suffix);
#   * the gate is ACTIVE only when a resident model server is present —
#     declared via WEIZIGO_HOST_TENANT_RESERVATION_MB (> 0) or auto-detected
#     (`ollama runner --mlx-engine` RSS > 0).  No tenant ⇒ no reduced budget
#     ⇒ the gate is inactive (the runner's host guard still enforces the
#     2026-07-29 panic floor on real pressure);
#   * active gate admits a memory-heavy lane iff
#     available_memory >= lane_cost + margin, where lane_cost defaults to
#     16384 MB (one 27b MLX model) and margin is 2048 MB.  available_memory
#     is the system-wide reading (WEIZIGO_HOST_MEM_AVAIL_MB injects it, the
#     same hook tools/runner uses — the floor is never tested by exhausting
#     the host);
#   * an unavailable reading ⇒ gate inert (cannot measure = cannot refuse,
#     the runner guard's stance);
#   * --override-memory-gate=<reason> is the recorded escape (the
#     --allow-unisolated spirit): a human who has checked the host may
#     launch anyway, loudly.
#
# All fixtures are synthetic and deterministic: every arm injects the
# reading/tenant (never the live host's memory state), the target is the
# AGENTS.md FILE branch (no untracked/ bundle, nothing spawned — dry-run
# only), and no live repo file is written.
#
# Controls:
#   A null         cloud-API lanes dispatch FREELY under qwen-resident
#                  pressure (deepseek / claude / pi / :cloud ollama tag).
#   B seeded       a memory-heavy local lane is REFUSED under the same
#                  pressure, naming list-wait.  RED against HEAD (no gate);
#                  GREEN after T713.
#   C null         the same memory-heavy lane is ADMITTED when the reduced
#                  budget fits (ample injected avail), and the diagnostic
#                  reports the reduced budget (total − tenant).
#   D null         no resident tenant ⇒ gate INACTIVE even under red avail
#                  (the check is for the resident-model-server case).
#   E null         unmeasurable reading ⇒ gate INERT (runner-guard stance).
#   F boundary     avail == lane_cost + margin ⇒ admitted (>=, not >).
#   G escape       --override-memory-gate=<reason> launches anyway, loudly.
#   H class        qwen3.8:27b-mlx:cloud is a CLOUD lane (free under
#                  pressure) — the :cloud suffix is what decides, not the
#                  model name.
#
# Task: T713 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
SUBAGENT="$ROOT/bin/subagent"
TARGET="$ROOT/AGENTS.md"          # file branch — no untracked/ bundle needed
# T527: clear inherited depth — a depth-3 leaf running this suite would see
# every dry-run REFUSED at the cap (correct in production, noise here).
unset WEIZIGO_AGENT_DEPTH
FAIL=0

# Fixture constants (gate spec above).
TENANT_MB=8000          # declared-tenant reservation (T714 vocabulary)
TOTAL_MB=49152          # injected host total (48 GB)
COST_MB=16384           # default lane cost (one 27b MLX model)
MARGIN_MB=2048          # gate margin
THRESHOLD_MB=$((COST_MB + MARGIN_MB))   # 18432
AVAIL_RED_MB=100        # qwen-resident pressure (red reading)
AVAIL_TIGHT_MB=9000     # below the threshold → refuse
AVAIL_AMPLE_MB=25000    # above the threshold → admit

echo "=== subagent resident-aware memory gate regression ==="

# ── A. cloud-API lanes dispatch freely under qwen-resident pressure ───────
# The brief's headline: cloud-API lanes (small local RSS) dispatch freely.
# deepseek, claude, pi/openrouter and :cloud ollama tags must ALL print a
# dry-run command (exit 0) while avail=100 MB with a declared 8000 MB tenant
# would refuse a local-model lane.
echo "  A. cloud-API lanes dispatch freely under qwen-resident pressure"

cloud_ok() {
    local name="$1"; shift
    local out
    out=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
          WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
          "$SUBAGENT" "$@" --dry-run 2>&1)
    local rc=$?
    if [ "$rc" -eq 0 ] && echo "$out" | grep -q "tools/runner"; then
        echo "    PASS: $name dispatches freely (rc=0)"
    else
        echo "    FAIL: $name rc=$rc — expected free dispatch under red avail"
        echo "$out" | sed 's/^/    | /' | head -4
        FAIL=1
    fi
}

cloud_ok "deepseek (--dsflash)" --provider deepseek "$TARGET" --dsflash
cloud_ok "claude (claude-fable-5)" --provider claude "$TARGET" --model claude-fable-5
cloud_ok "pi (stealth/ox-alpha)" --provider pi "$TARGET" --model stealth/ox-alpha
cloud_ok "ollama :cloud tag (glm-5.2:cloud)" --provider ollama "$TARGET" --model glm-5.2:cloud

# ── B. seeded: memory-heavy local lane REFUSED under pressure (list-wait) ─
# A local qwen lane under qwen-resident pressure must be REFUSED with the
# list-wait directive — launching it would push the host toward OOM, where
# the runner's guard would have to kill a running lane.  RED against HEAD.
echo "  B. seeded: local-model lane refused under qwen-resident pressure (list-wait)"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "REFUSED" \
   && echo "$OUT" | grep -q "T713" \
   && echo "$OUT" | grep -qi "list-wait"; then
    echo "    PASS: refused (rc=$RC) with REFUSED/T713/list-wait"
else
    echo "    FAIL (RED expected today): rc=$RC; expected refusal with REFUSED/T713/list-wait"
    echo "$OUT" | sed 's/^/    | /' | head -6
    FAIL=1
fi

# ── C. null: the same lane is ADMITTED when the reduced budget fits ───────
# avail 25000 MB ≥ 18432 MB → admitted; the diagnostic must report the
# reduced budget (total 49152 − tenant 8000 = 41152 MB).
echo "  C. null: local-model lane admitted when the reduced budget fits"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_AMPLE_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      WEIZIGO_HOST_TOTAL_MB="$TOTAL_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
C_OK=1
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: rc=$RC — expected admit"
    echo "$OUT" | sed 's/^/    | /' | head -4
    C_OK=0
fi
if ! echo "$OUT" | grep -q "ollama launch pi --model qwen3.8:27b-mlx"; then
    echo "    FAIL: dry-run command for the local lane missing"
    C_OK=0
fi
if ! echo "$OUT" | grep -q "reduced to 41152 MB"; then
    echo "    FAIL: diagnostic does not report the reduced budget (41152 MB = 49152 − 8000)"
    echo "$OUT" | sed 's/^/    | /' | head -4
    C_OK=0
fi
[ "$C_OK" -eq 1 ] && echo "    PASS: admitted; reduced budget 41152 MB reported"

# ── D. null: no tenant ⇒ gate INACTIVE even under red avail ───────────────
# The check is for the resident-model-server case.  avail is injected (so
# no auto-detection runs) and no tenant is declared ⇒ gate inactive ⇒ the
# local lane dispatches freely; the runner's host guard still enforces the
# panic floor on a real launch.
echo "  D. null: no resident tenant ⇒ gate inactive under red avail"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ollama launch pi --model qwen3.8:27b-mlx"; then
    echo "    PASS: dispatched freely (no tenant = no reduced budget = gate inactive)"
else
    echo "    FAIL: rc=$RC — expected free dispatch with no declared tenant"
    echo "$OUT" | sed 's/^/    | /' | head -4
    FAIL=1
fi

# ── E. null: unmeasurable reading ⇒ gate INERT ────────────────────────────
# WEIZIGO_HOST_MEM_UNAVAIL=1 forces the reading to None: cannot measure =
# cannot refuse (the runner guard's stance).
echo "  E. null: unmeasurable reading ⇒ gate inert"
OUT=$(WEIZIGO_HOST_MEM_UNAVAIL=1 \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ollama launch pi --model qwen3.8:27b-mlx"; then
    echo "    PASS: dispatched freely (cannot measure = cannot refuse)"
else
    echo "    FAIL: rc=$RC — expected inert gate"
    echo "$OUT" | sed 's/^/    | /' | head -4
    FAIL=1
fi

# ── F. boundary: avail == lane_cost + margin ⇒ admitted (>=, not >) ───────
echo "  F. boundary: avail exactly at lane_cost + margin ⇒ admitted"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$THRESHOLD_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "ollama launch pi --model qwen3.8:27b-mlx"; then
    echo "    PASS: admitted at the exact threshold ($THRESHOLD_MB MB)"
else
    echo "    FAIL: rc=$RC — expected admit at avail == threshold"
    echo "$OUT" | sed 's/^/    | /' | head -4
    FAIL=1
fi

# ── G. escape: --override-memory-gate=<reason> launches anyway, loudly ────
echo "  G. escape: recorded override launches anyway under pressure"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx \
      --override-memory-gate="checked the host by hand; model already warm" --dry-run 2>&1)
RC=$?
G_OK=1
if [ "$RC" -ne 0 ]; then
    echo "    FAIL: rc=$RC — expected launch with override"
    echo "$OUT" | sed 's/^/    | /' | head -4
    G_OK=0
fi
if ! echo "$OUT" | grep -qi "OVERRIDDEN"; then
    echo "    FAIL: override not announced loudly"
    G_OK=0
fi
if ! echo "$OUT" | grep -q "checked the host by hand"; then
    echo "    FAIL: override reason not echoed"
    G_OK=0
fi
[ "$G_OK" -eq 1 ] && echo "    PASS: override launches and echoes the reason loudly"

# ── H. class: :cloud suffix ⇒ cloud lane, free under pressure ─────────────
echo "  H. class: qwen3.8:27b-mlx:cloud is a cloud lane (free under pressure)"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx:cloud --dry-run 2>&1)
RC=$?
if [ "$RC" -eq 0 ] && echo "$OUT" | grep -q "tools/runner"; then
    echo "    PASS: :cloud variant dispatches freely"
else
    echo "    FAIL: rc=$RC — expected free dispatch for the :cloud tag"
    echo "$OUT" | sed 's/^/    | /' | head -4
    FAIL=1
fi

# ── G2. bare --override-memory-gate (no reason) must refuse, not bypass ───
echo "  G2. seeded: --override-memory-gate without a reason refuses"
OUT=$(WEIZIGO_HOST_MEM_AVAIL_MB="$AVAIL_RED_MB" \
      WEIZIGO_HOST_TENANT_RESERVATION_MB="$TENANT_MB" \
      "$SUBAGENT" --provider ollama "$TARGET" --model qwen3.8:27b-mlx \
      --override-memory-gate --dry-run 2>&1)
RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -qi "requires a reason"; then
    echo "    PASS: refused the bare flag, naming the reason requirement"
else
    echo "    FAIL: rc=$RC — bare override must refuse with 'requires a reason'"
    echo "$OUT" | sed 's/^/    | /' | head -4
    FAIL=1
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-subagent-resident-gate: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-subagent-resident-gate: FAILURES (control B/G2 are the expected-red until T713 lands) ==="
    exit 1
fi
