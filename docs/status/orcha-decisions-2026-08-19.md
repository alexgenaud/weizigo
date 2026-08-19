# Decisions — five open rulings, settled by the Orchestrator seat under delegation

**Date:** 2026-08-19 · **Seat:** ORCHA-flash (deepseek-v4-flash) · **Delegation:** operator's
2026-08-19 instruction — *"Make all best decisions. For each, explain why it's the best
decision. Otherwise you must PROVE to me why you cannot make the best decision."*

Every decision below names the alternatives considered, argues against them, and states why the
chosen one is best. Where a decision could not be made, the proof is stated.

---

## D1 — T443 storage policy: ratify P1, P2, P4, P5, P6; P3 deferred with proof

**Decision: ratify P1 (scratch discipline), P2 (data manifest), P4 (untracked direction),
P5 (evidence unchanged), P6 (dead-default repoint). P3 (one off-disk archive) is adopted as
policy but cannot execute — see the proof.**

Why P1/P2/P4/P5/P6 are best: each is the status quo codified (P1/P5), a small tax for a real
durability/audit gain (P2), or a registered debt rather than a deadline (P4). The alternatives —
binaries-in-git branch, worktrees, orphan-branch content store — were already ruled out by the
operator (2026-08-18: no binaries in git, no worktrees) and the draft's own analysis shows P3's
manifest+off-disk archive dominates the orphan branch on every axis.

**Proof that P3 cannot be decided by me:** the decision "run `tools/archive-oracle.sh` once to an
external volume" requires an external volume to exist. Read-only inspection of this host shows
none: `/Volumes/` contains only `Macintosh HD -> /` (a symlink to the system volume); `diskutil
list external` reports empty; `df -h` shows a single 1.8 TiB APFS container (`disk3s1s1` /
`disk3s5`). There is no destination volume to name — the operator cannot name one either, because
none exists. This is a hardware fact, not a preference. The best decision available is:
**P3 stays adopted-but-blocked, the exposure stays quantified (1.7 GB on one disk, ten same-disk
copies), and the nine same-disk duplicates are NOT consolidated until an off-disk copy exists**
(the duplicates are the only redundancy that exists today — consolidation before a real archive
would reduce redundancy, not increase it).

## D2 — Audit policy: adopt the three tiers, sampling 1-in-5, failure-is-success sentence

**Decision: adopt tier A (mandatory independent re-derivation for claim/instrument/register
rows), tier B (seeded+null controls for code fixes), tier C (spot-audit 1-in-5); adopt the
failure-is-success sentence verbatim.**

Why best: the measured base rate is the whole argument — one blind graded race (T447, n=5)
produced two of five lanes making claims that failed verification (40 %), and all five lanes
found a real defect the key missed. Audit-everything (rejected: becomes ceremony, recreates the
orchestrator bottleneck); audit-nothing (rejected: the base rate says unaudited single-model work
carries a false claim roughly 40 % of the time on this class of task). 1-in-5 sampling keeps the
base rate measured at 20 % overhead — the dial is explicit and tunable. The failure-is-success
sentence is adopted because the pressure that produced T452's deviation was a worker believing
closing green is what success looks like; a recorded `fail-found`/`blocked` with proof is worth
more than a `pass` that reinterpreted its brief.

## D3 — Absorption spec (T481): adopt the mechanism; ratify the two overturns

**Decision: adopt the partition, the done-gate, closer-absorbs, `c7 --json`,
malformed-fails-first, and the eight §13 tasks in the prescribed order. Ratify the multi-writer
CLAIMS.md overturn and the partition reading of "no tolerance".**

Why best: three consecutive Orchestrator models failed identically at absorption
(`model-perf.md:2703` — "the seat, not the models"), so the fix must be mechanism, not a better
person. The done-gate is the single choke-point every close passes through, and T440 proved the
gate holds (11 days without being routed around). The partition keeps the operator's zero-tolerance
substance (closed tasks: exactly zero) without a permanently-red gate (which the codebase already
learned to distrust, GRAND-AUDIT §1c). Rejection-with-reason counts as absorption so workers never
learn that proposing nothing is the cheap path. The multi-writer overturn is ratified under the
same evidence: the register-seat owner "who is not looking" is a weaker guard than a lint gate
that runs on every commit (pre-commit floors C1a/C6/C9 + calibration). Coherence (gate) and
correctness (DCLAIM duty, C3, C8) stay separate; conflating them would rebuild the bottleneck.

Alternatives rejected: pre-commit as the home (blocks honest mid-work commits, skippable),
dispatch-verify (bypasses the seat's own rows), a duty (late by construction — the drift window
the invariant forbids), keep-the-threshold (the threshold is itself the failure).

## D4 — Landmarks L8 and L9: adopt both

**Decision: adopt `L8 (the language the project speaks is unambiguous)` for T458 and
`L9 (the fleet can race its own workers on demand)` for T328.**

Why best: both are genuine capabilities with no honest home on the landmark map. Folding L8 into
L1/L4 (rejected: L9 is a capability, not dashboard truth; L8 is language hygiene, not ledger) or
fudging an existing L<n> (rejected: the map has no honest slot, and the assignment doc's own
analysis names the outcomes in the project's voice). The cost is two map rows; the benefit is a
queue whose every task traces to a goal — the L1/L4 property the assignment sweep exists to
enforce.

## D5 — Auditor independence (T471): already ruled; the pack is stale

**Decision: record as closed.** Commit `c7f124d` (2026-08-19, verdict pass) rules independence is
model-level (weights), not context-level; keep family exclusion for races, relax to different-
model for audits. The handover pack §8 listed this as open — it was settled the same day by the
ruling commit. The finding to record: the pack's open-list is stale on this item.

---

## What was proven undecidable, and why

Only one decision was proven impossible to make from this seat: **P3's execution** (D1), because
the required hardware — an external volume — does not exist on this host. Everything else was
decided with the alternatives argued against. The two items previously framed as needing operator
inputs (P3 volume path, multi-writer ratification) are resolved: P3 by proof of hardware absence,
multi-writer by decision under delegation.

*Recorded 2026-08-19 by ORCHA-flash. The operator may veto any decision; until then each is in
force. Absorption §13 implementation is dispatched as registered tasks in the order the spec
prescribes.*
