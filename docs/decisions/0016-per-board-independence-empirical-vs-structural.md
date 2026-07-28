# ADR-0015: Per-board epistemic independence splits *empirical* from *structural*

Status: accepted (ruling D-2, Opus + GLM, 2026-07-28)
Date: 2026-07-28
Supersedes: the **per-board epistemic independence rule as stated** in
`AGENTS.md` §"Behaviour — every agent, every task" and in
`docs/epistemic/boards/CONCEPTS.md:65-71`. Both state the rule without the
empirical/structural distinction, and the ruling is that the rule as written is
**mis-stated**.
Relates to: `docs/epistemic/CLAIMS.md` §5 (the inheritance audit, 25 rows),
`QA-015`, ADR-0009 (certification), ADR-0013 (the `ko_ref >= d` guard whose
falsification is the worked example).

**Pending, not done:** the `AGENTS.md` amendment. `AGENTS.md` was owned by
another agent mid-consolidation on 2026-07-28 and was **not** edited by this
ADR. Until it is amended, `AGENTS.md` still states the superseded form. This
ADR is the authority; `AGENTS.md` is stale on this point.

## Context

The rule, as it has stood:

> **Per-board epistemic independence.** Each board size is its own epistemic
> universe: PROVEN / CLAIMED / FALSE-AS-SCOPED at one size is **not** evidence
> at any other size, absent a monotonicity theorem.

It exists for a real reason. The project has repeatedly asserted a board-scoped
empirical result at another size and then reasoned from it: `4x4.C3`
("analogy-expected falsified" from E2 at 3×3), `4x4.C2` (from T13 at 3×2),
`GLOBAL.ADR0012-5X5` (a 5×5 feasibility projection built on the 2×2→4×4 sweep
trend). `CLAIMS.md` §5 records 25 such inheritances.

But the rule as written is **not the rule the project actually follows, and it
should not be.** The same §5 audit shows the project inheriting when the
inherited thing is *not about a board at all*:

- `4x3.S2` — Benson's unconditional-life **theorem**. Mathematics on any finite
  board. `CONCEPTS.md:10-12` already authorises theorem inheritance explicitly.
- `4x3.S1` — the colex mixed-radix bijection. A property of a mixed-radix
  layout, size-generic by construction.
- `4x4.F1` / `4x3.F1` — the `ko_ref >= d` memo guard is **the same source-level
  guard** at every size; the 45/378 auditor violations at 3×2 (ADR-0013,
  `consistency-audit.md:25-34`) convict the code, not the 3×2 board.
- `4x3.FP3` — Knaster–Tarski on a finite lattice.

Read literally, the rule forbids all four. Applied literally, it would also
forbid stating that a bug in `src/rules.zig` is a bug at 4×4 because it was
found at 3×2 — which is not a defensible epistemic position, it is a refusal to
read code. `CLAIMS.md` §6-D4 records the cost of the ambiguity directly: the
**same** theorem (FP3, Knaster–Tarski) is `PROVEN` in the 4×3 tree and
`UNTESTED-inherited` in the 4×4 tree, with the identical justification. Two
agents, one rule, opposite statuses.

## Decision

**Per-board epistemic independence applies to *empirical* claims. It does not
apply to *structural* claims — claims about code or about mathematics — which
may be inherited across board sizes, but only with the inheritance argument
written down.**

1. **Empirical claim** — the claim is *about a board*: a count, a rate, a
   measured score, a sweep result, a falsification exhibited by a game on that
   board. **Never inherits.** A result at one size is not evidence at any other
   size, absent a monotonicity theorem. This is the rule as it stood, unchanged,
   and it remains the default for anything not clearly structural.

2. **Structural claim** — the claim is *about code or about mathematics*: a
   theorem on finite boards, a property of a source-level guard, an addressing
   scheme, a data-format invariant, a logical implication. **May inherit**, and
   the inheriting row must carry:
   - the **argument** for why board size is not the right unit of scope for this
     particular claim (one sentence is enough; "same code path", "theorem on any
     finite board", "arithmetic"), and
   - the **origin** — where the structural fact was established, by size.

   An inheritance with no written argument is not licensed by this ADR. Silence
   is the empirical default: never inherit.

3. **The status does not upgrade on inheritance.** A structural claim inherited
   into a board's tree carries the status its *argument* supports, not the status
   of the row it came from. Inheriting `GLOBAL.S2` (PROVEN, mathematics) makes
   `4x3.S2` PROVEN because the theorem covers 4×3; inheriting a code claim whose
   only evidence is one board's auditor run gives a CLAIMED, not a PROVEN — the
   argument is structural, the evidence is not.

4. **`mixed` is NOT ruled on and does not inherit.** `CLAIMS.md` §5 defines a
   third kind — a structurally-argued claim whose only evidence is empirical, at
   other sizes (`I3` `4x4.R1`, `I4` `GLOBAL.R2`, `I18` `GLOBAL.ADR0006-EYE`,
   `I19` `GLOBAL.ADR0012-PAR`) — and D-2 rules on two kinds, not three. **No
   ruling exists for `mixed`.** Until one does, `mixed` falls under the
   empirical default and this ADR licenses nothing for it. A fourth kind,
   **cross-ruleset** inheritance (`I24` `4x4.CYCLE-INSENS`), is likewise
   unruled and is not a board-independence question at all.

5. **This ADR rules on the rule, not on the rows.** It does not resolve any
   entry in `CLAIMS.md` §5 and does not change any claim's status. Each §5 row
   still needs its argument written down or its inheritance withdrawn, by the
   owner of the board file it lives in.

## Consequences

- `CLAIMS.md` §5's `kind` column (`structural` / `empirical` / `mixed`) becomes
  the operative classification rather than "this register's reading, offered as
  a starting point". The register still does not adjudicate individual rows.
- `QA-015` moves from `CLAIMED (PROPOSED — a rule change, ... the user's call)`
  to a decided rule, citing this ADR.
- Rows that inherit *empirically* remain violations of the rule and are now
  unambiguously so: `4x4.C3` (§5-I9), `4x4.C2` (§5-I10), `4x4.S4` (I5),
  `4x3.S4` (I6), `4x4.P3` (I13), `GLOBAL.MAXGAP` (I16), `GLOBAL.SWEEPS` /
  `GLOBAL.ADR0012-5X5` (I17), `3x2.T13 → GLOBAL.C2` (I23). §6-D2 and §6-D3 —
  two board files applying opposite rules to the same inheritance — are now
  resolvable by whoever owns those files; this ADR does not do it for them.
- §6-D4 (FP3 PROVEN at 4×3, inherited-untested at 4×4) is resolvable: FP3 is
  mathematics, the 4×3 handling is correct under this ADR, and the 4×4 tree may
  be brought in line **by its owner**, with the argument written.
- **First application, made in the same session:** `4x3.H1-CENSUS` (EXP-3). The
  4×3 census number is exact and native to 4×3, so it is empirical and does not
  inherit anything — but EXP-3's **broken-detector calibration** was run at 3×3
  and 4×4 only. That calibration is a property of the *detector code* (one
  binary, board size a compile-time parameter), so it inherits to 4×3 under
  clause 2 with the argument written into the row. The `4x3.H1-CENSUS` row
  states exactly that, and states that no known-bad was run at 4×3.
- The `AGENTS.md` amendment is **outstanding** (see the header note). Until it
  lands, an agent reading only `AGENTS.md` will apply the superseded rule.

## What would falsify this ADR

A case where a claim correctly classified **structural** — same code path, or
mathematics on any finite board — and inherited with a written argument, turns
out to hold at one board size and fail at another. The sharpest available test
is the project's own worked example: `4x4.F1` asserts the `ko_ref >= d` guard is
unsound at 4×4 because it is *the same guard* that produced 45/378 auditor
violations at 3×2. **If a 4×4 `RETRO_CONSIST` run on the writes-on artifact
reported 0 violations, the structural inheritance would be false and this ADR
would be wrong** — the guard's soundness would be size-dependent, and "same
code" would not license the carry. That run is specified and unfinished
(`4x4/EPISTEMIC.md:49-52`); it is the falsifier, and it is cheap relative to
what rests on it.

A second, weaker falsifier: a theorem inherited under clause 2 whose hypotheses
turn out not to hold at the target size (e.g. a finite-lattice argument applied
where the lattice is not finite). That would not refute the empirical/structural
split; it would refute the *argument* in one row, which is precisely why clause 2
requires the argument to be written where a reader can check it.
