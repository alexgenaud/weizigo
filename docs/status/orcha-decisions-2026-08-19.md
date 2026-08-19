# Decisions — five open rulings, settled by the Orchestrator seat under delegation

**Date:** 2026-08-19 · **Seat:** ORCHA-flash (deepseek-v4-flash) · **Delegation:** operator's
2026-08-19 instruction — *"Make all best decisions. For each, explain why it's the best
decision. Otherwise you must PROVE to me why you cannot make the best decision."*

Every decision below names the alternatives considered, argues against them, and states why the
chosen one is best. Where a decision could not be made, the proof is stated.

---

## D1 — T443 storage policy: the directory taxonomy and naming convention, decided

**Decision: the storage model is the four-layer taxonomy we already have — `/tmp/weizigo/`
(scratch, periodic cleanup accepted), `untracked/` (host-local durable: comms, large artifacts,
in-progress bundles; not purged unless we purge it), `data/` (gitignored working oracle tables,
manifest-tracked), git-tracked directories (history, done deliberately). No external volume is
required — the T443 sheet's "volume" framing was its own invention, not the operator's.**

Why best: the operator's correction (2026-08-19) is the taxonomy itself: `/tmp/` is best for
ephemeral files we accept cleaning periodically; `untracked/` is not purged unless we purge it,
so it is the host-local durable layer; git-tracked dirs are stored in history, done
thoughtfully, diligently, and intentionally. The T443 draft's own census confirms the layers do
this work already: 44 `/tmp/weizigo`-referencing files are WRITE-only (zero read pre-existing
state); the real exposure was `data/` (1.7 GB, gitignored, one disk), and the nine same-disk
twins of `oracle-4x4-v2.wzo2` already live in `untracked/oracle-v2/` + `untracked/v02…v09/`.

**Naming convention, decided:** every artifact carries a `(goban, ruleset)` tag in its name
(standing rule: new rule → new file, never overwrite a `.wzo`); `data/` gets a tracked
`data/MANIFEST.json` (P2) with one row per file — path, bytes, sha256, builder commit, regen
cost + denominator — and every manifest row lists **every twin copy anywhere** (`data/`,
`untracked/`) with its sha256, so the manifest is the single inventory of where each artifact
lives. New `data/` files without a manifest row are refused in the same commit.

**The nine duplicates are kept, not consolidated.** They are the redundancy layer on a single
disk; consolidating them without an external copy destroys the only backup that exists. The
T443 sheet's "consolidate after P3 runs once" is superseded: with no external archive, the
untracked twins ARE the archive. The residual risk — one disk failing takes `data/` + `untracked/`
together — is accepted consciously under the operator's framing (untracked/ is durable by
convention, and git history is the deliberate layer).

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

No decision was left undecidable. P3 was the only candidate for a blocked item, and the
operator's correction removed the false premise: the T443 sheet's "external volume" was its own
invention, not a requirement — the storage decision is the four-layer taxonomy we already have,
made in D1. The two items previously framed as needing operator inputs (P3 volume path,
multi-writer ratification) are resolved: P3 by the taxonomy decision under the operator's
correction, multi-writer by decision under delegation.

*Recorded 2026-08-19 by ORCHA-flash. The operator may veto any decision; until then each is in
force. Absorption §13 implementation is dispatched as registered tasks in the order the spec
prescribes.*
