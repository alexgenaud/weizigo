#!/usr/bin/env bash
# regression-runner-host-guard.sh — RETIRED (T821, 2026-08-24).
#
# This script tested the T362/T711 declared-tenant host-pressure guard:
# `tools/runner`'s `host_total // 8` floor, its tenant add-back
# (WEIZIGO_HOST_TENANT_RESERVATION_MB), and the largest-member kill.  T821
# (docs/infra/host/ram-policy.md) DELETES that entire mechanism — 16 of 20
# recorded kills were futile and 0 of 20 were both necessary and effective
# (ram-policy.md §1-§2).  `--host-mem-floor-mb` no longer exists as a
# decision (kept as an accepted-but-inert flag purely so the many OTHER
# regression scripts that pass `--no-host-guard`/`--host-mem-floor-mb` to
# isolate from this guard while testing something else keep working
# unmodified); `_select_host_guard_victim` is deleted outright
# (tests/unit/test_runner.py's arm is now a deletion check); the tenant
# add-back this script's null control depended on is gone with it.
#
# What replaced it: the new arbiter (tools/runner --arbiter-admit/-preview/
# -release/-status) does declared-need admission before a lane is spawned,
# and a kernel-signalled L3 alarm (never a kill) is the new backstop.  Its
# controls live in tools/regression-arbiter.sh (T821): real co-launch,
# futile-kill (now structurally impossible — asserted directly), effective
# overrun-stop, refusal-at-admission, and a null control.
#
# This script cannot be repaired into passing: its null control asserts
# the guard does NOT fire on a declared tenant, but there is no floor left
# to fire.  Retired per the T821 brief's own instruction ("must still pass
# or be explicitly retired with a reason") rather than deleted outright —
# see findings/T821-arbiter.json for the full disposition and
# docs/infra/host/ram-policy.md §6 for the itemized deletion list this
# retirement follows.  Exits 0 (retired, not failing).

echo "=== regression-runner-host-guard: RETIRED (T821, 2026-08-24) ==="
echo "  the T362/T711 floor + tenant add-back this script tested is DELETED"
echo "  (docs/infra/host/ram-policy.md); see tools/regression-arbiter.sh for"
echo "  the arbiter's own controls."
exit 0
