#!/usr/bin/env bash
# regression-subagent-resident-gate.sh — RETIRED (T821, 2026-08-24).
#
# This script tested the T713 resident-aware memory gate: bin/subagent
# refused a LOCAL ollama lane (provider ollama, non-:cloud tag) only when a
# resident model server was present and the host reported less than
# lane_cost (16384 MB) + margin (2048 MB) available; every cloud-API lane
# dispatched freely, unchecked.  T821 (docs/infra/host/ram-policy.md)
# DELETES that gate (§6 items 8-9: MEMORY_GATE_MARGIN_MB,
# LOCAL_LANE_COST_DEFAULT_MB, _lane_is_memory_heavy, _memory_gate_verdict)
# and replaces it with declared-need ADMISSION for EVERY lane — cloud
# lanes now declare a small per-provider default too, and the resident
# model's charge is the docs/infra/model-registry.md figure (18432 MB), a
# registry declaration, never a `ps`/`WEIZIGO_HOST_TENANT_RESERVATION_MB`
# sample or override.  `--override-memory-gate` is renamed
# `--override-admission` (ram-policy.md §6 item 10: keep the escape hatch,
# rename it for the new semantics).
#
# This script cannot be repaired into passing: its controls assert
# per-provider special-casing (control A "cloud lanes dispatch freely
# under pressure", control D "no tenant = gate inactive") that no longer
# exists by design — every lane is checked now, uniformly, by
# tools/runner's one arbiter, not by bin/subagent re-implementing the
# arithmetic.  Retired per the T821 brief's own instruction ("must still
# pass or be explicitly retired with a reason") rather than deleted
# outright — see findings/T821-arbiter.json for the full disposition and
# tests/unit/test_subagent.py's T821 addendum for the unit-level
# replacement coverage (TestDeclaredRamMb, TestLaneIsMemoryHeavyRemoved).
# Exits 0 (retired, not failing).

echo "=== regression-subagent-resident-gate: RETIRED (T821, 2026-08-24) ==="
echo "  the T713 local-model-only gate this script tested is DELETED"
echo "  (docs/infra/host/ram-policy.md); every lane now declares a need and"
echo "  goes through tools/runner's one arbiter — see"
echo "  tools/regression-arbiter.sh and tests/unit/test_subagent.py."
exit 0
