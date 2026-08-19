#!/usr/bin/env bash
# tools/fleet-cooldown.sh — set, clear, or report the fleet-keeper cooldown flag.
#
# The graceful stop for the fleet keeper (T496): `on` writes the flag and
# the keeper dispatches nothing more (running workers finish, nothing new
# starts); `off` clears it; `status` reports it.  One command for the human
# and the Orchestrator.  The Orchestrator's shutdown sequence is:
#   tools/fleet-cooldown.sh on  →  wait for in_progress to drain  →
#   kill the keeper loop  →  commit.
#
# The flag is a FILE (untracked/fleet-keeper.cooldown), not a store/engine
# change — no managent edit, works for both the human and the Orchestrator.
#
# Env:
#   FLEET_ROOT   working dir for untracked/ (default = this repo); set to a
#                scratch dir in tests.
#
# Usage:
#   tools/fleet-cooldown.sh on|off|status
#
# Task: T496 · Model: glm-5.2 · Date: 2026-08-19

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
FLEET_ROOT="${FLEET_ROOT:-$ROOT}"
DIR="$FLEET_ROOT/untracked"
FLAG="$DIR/fleet-keeper.cooldown"

ACTION="${1:-}"
case "$ACTION" in
  on)
    mkdir -p "$DIR" 2>/dev/null || true
    : > "$FLAG"
    echo "fleet cooldown set — no new dispatches"
    ;;
  off)
    rm -f "$FLAG" 2>/dev/null || true
    echo "fleet cooldown cleared"
    ;;
  status)
    if [ -e "$FLAG" ]; then
      echo "fleet cooldown: ON"
    else
      echo "fleet cooldown: off"
    fi
    ;;
  *)
    cat <<EOF >&2
usage: tools/fleet-cooldown.sh on|off|status
  on      set the cooldown flag (keeper dispatches nothing more)
  off     clear the flag (keeper resumes dispatching)
  status  report the flag
EOF
    exit 1
    ;;
esac