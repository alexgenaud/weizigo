# DIRECTION — completing epic-01-markovian on solid foundations

Role: Grand Auditor · Model: Claude Fable 5 · Date: 2026-08-02 · At HEAD `e714fd4`
Status: **ratified by the human, 2026-08-02**, in discussion following `GRAND-AUDIT.md`.
This document records project direction. The roadmap that decomposes it into tasks is a
follow-up deliverable and belongs to the next session's court.

---

## 1. The stance — doubt everything, reverify end-to-end

**Every claim in the register — all 282 rows, proofs and falsifications alike — is presumed
unverified until re-derived end-to-end inside the reconstructed chain.** The engine plays a
decent game of Go, which bounds how far A (axioms) and Z (conclusions) can be from truth — and
bounds nothing else. The register is not deleted: it is the map of what was once believed and
why. Every row will be re-derived under the new battery, demoted, or retired as irrelevant to
the theorem.

Reverification is not a re-audit of existing rows — that would only reverify the questions we
happened to ask. The requirement tree is built **top-down from Z**: state the theorem, derive
the lemmas it needs, then map old claims onto the tree. Old claims mapping nowhere are
retired; tree nodes with no claim are new work. Pulling the thread from both ends, made
mechanical.

## 2. The frame — an epic is a claim chain, not code

An epic is one epistemic journey from a specific A to a specific Z. The **kernel** (§4), the
**acceptance battery** (§5), claimlint, managent, and the runner are **epic-independent
infrastructure** — tools that any epic imports. What is epic-scoped is the theorem and its
claim tree.

Consequences:

- **Epic-01-markovian is unfinished, not failed.** Its Z was never proven. Reconstruction —
  written axioms, calibrated battery, kernel extraction, A–Z reverification — is *completing
  epic-01*, in place, in its existing directories. No new epic directory, no migration of
  claims/decisions/docs. (The audit measured 71% of commits as process bookkeeping; a reorg
  with no epistemic content would be pure ceremony.)
- **A new epic begins the day the axioms diverge** — a new state definition, a new A. It gets
  a fresh directory, fresh decisions/, a fresh claim tree, importing the kernel and battery as
  tools and epic-01's finished table as its first oracle.
- Several A′–Z′, A″–Z″ threads are welcome; they are sibling epics in a family sharing one
  kernel and one battery — not tangles inside one directory.

## 3. The theorem — epic-01 is strictly k=1

Epic-01's game is **Markovian with ko memory k=1**: the state is (position, side, ko, passes),
history lives in the state and nowhere else. The theorem to prove, stated as a working
hypothesis:

> For each goban size in {2×2, 3×2, 3×3, 4×4}, under ruleset R (to be written precisely in
> AXIOMS.md: area scoring, komi 0, basic ko, pass/termination rules, tie semantics), the table
> gives the exact game-theoretic fresh-start [L,H] bracket for every legal (position, side),
> with L==H where achieved — and explicit non-claims for everything else (no real-game PSK
> value, no cross-size inheritance).

**Axioms and conclusions are working, not stone.** Reverification may force adjusting A, Z, or
both; the evidence decides. Two standing rules make that safe rather than slippery:

- An axiom change is a **recorded event** (a dated entry in AXIOMS.md plus a register row),
  never a silent edit.
- The bar for any adjusted Z: **at least as good as today's 4×4 engine, fixed upon whatever is
  demonstrably better.**

The axioms document lives at `docs/epic-01-markovian/AXIOMS.md` (axioms are epic-scoped).
Every axiom carries a claim ID from birth. The MIGOS tie-semantics question — currently
absorbed under an explanation the register's own PROVEN row contradicts (GRAND-AUDIT §1d) —
is adjudicated in AXIOMS.md before any kernel code depends on it.

**Epic-02, in full:** a successor epic potentially might be **k=2+** — encoding bounded prior
ko cycles in the state, where epic-01 is strictly k=1. Nothing more is chartered here; it is
entered, if at all, only after epic-01's Z is proven, with its own A and its own directory.

## 4. The kernel — exactly one version of each generic function

The kernel is the minimal set of production modules that everything — engine, solver,
batteries, experiments, all goban sizes — imports and nothing reimplements:

1. **Board + colex indexing**
2. **Rules** — legality, capture, Benson, area scoring, and **the one ko/state-key function**
   (today the ko rule exists only as ~14 divergent copies and no production implementation;
   that duplication is the confirmed root cause of T178, T193, T265)
3. **State encoding** — (position, side, ko, passes) → key, written once, with the
   producer/consumer key-agreement invariant (T267) as its test
4. **Solver core** — the retrograde Bellman update (today living under the experiment name
   `exp6_solve.zig` while serving as de facto production)
5. **Artifact I/O** — wzo2 read/write

"Rebuild" means **extraction with teeth**, not a blank page: `rules.zig` largely survives;
each kernel function is written once, TDD, headed by its prose spec sentence and claim ID.

**Epic-01's existing implementations are demoted to oracle** — the duplication doctrine
applied at scale: one production implementation; the 14 ko copies, exp4/5/6/7, the brute
forcers, and the existing artifacts become frozen differential fixtures — never edited, never
trusted, always run against. Every disagreement between kernel and fixture is a finding to
adjudicate: either an epic-01 bug (catalog it) or a kernel bug (the oracle earning its keep).
Independent re-implementation plus differential comparison is the only mechanism that has ever
found a real defect in this project; this makes it permanent.

## 5. The plan — five phases, gates mechanized from day one

- **Phase 0 — theorem and axioms.** AXIOMS.md written; requirement tree derived top-down from
  Z; old register rows mapped onto it; MIGOS/tie adjudicated. Deliverable: the theorem
  statement and the tree of lemmas it needs.
- **Phase 1 — acceptance battery before code.** The battery is built and **calibrated on
  known-defective inputs first**: every historical defect (T178/T193/T265 key mismatches,
  incompleteness, inversion violations, the stubbed battery) becomes a seeded known-bad
  control. The current `0c3366f0` artifact is a certified-defective calibration input — the
  battery must fail it; a battery that passes an artifact known to be broken is itself broken.
- **Phase 2 — kernel extraction.** One function, one owner; ko and state-key first. All
  harnesses wired into `zig build test`; nothing green that doesn't run.
- **Phase 3 — A–Z reverification.** Ladder 2×2 → 3×2 → 3×3 (anchor reconciled honestly) →
  4×4. Kernel vs fixtures differentially at every rung; every register row re-derived,
  demoted, or retired against the requirement tree.
- **Phase 4 — the swap.** Kernel becomes production; epic-01 legacy code frozen into its
  fixture role; `src/` gains the engine/experiment boundary.

**Standing policy, from the audit's clearest lesson (prose rules rotted; coded rules held):**
every gate in this plan is mechanized — a hook, a lint check, a battery run — from the day it
is declared. A rule that stays prose is a rule we have chosen to re-learn.

## 6. The court

- **Orchestrator** — continuous, mechanical, largely background; tolerant of session
  clears/refreshes (which requires the resume surface to be *generated* from tasks.json +
  STATE.md, per GRAND-AUDIT prescription 3, not hand-refreshed).
- **Auditor** — ephemeral, spun per verification gate, discarded after. Ephemerality is a
  feature: a fresh context with no shared session history is more independent, not less.
- **Sprint worker managers + phase workers** — dispatched as today via managent.
- **Dabir** — optional but defined: the human-facing conversational seat, real-time overview
  while the rest of the court works in the background. Defined-and-dark beats
  improvised-and-unregistered (the audit found two seats operating with no registry entry).

Model allocation stays a runtime decision by the human (standing rule: briefs never name a
model).

## 7. Quality commitments (all phases)

DRY enforced by the kernel (one implementation per function); TDD for all new code; every
instrument carries a null control and a seeded-defect control before its first reading counts;
tests that print must assert; controls that can't run must fail loudly, not pass vacuously;
claims born with the code (test cites claim ID, claim cites test); numbers cite their run and
state their denominator; evidence committed under `docs/evidence/` or the claim is not proven.

When we reliably know what we know — what is solved and what is not — the gaps become
improvable. Not before.
