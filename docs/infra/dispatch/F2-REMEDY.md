<!--managent set=A caps=reasoning:sustained-->
# F2-REMEDY — design a sound finisher that does not depend on the falsified bracket premise

**Opened by:** ADR-0018 (2026-07-29), which confirmed `GLOBAL.F2` orphaned.
**Bears on:** `GLOBAL.F2`, `QA-018`, `QA-026`, `GLOBAL.R2`, `GLOBAL.RPLY-TRAP`,
`QA-023`, ADR-0010, ADR-0015, ADR-0018. **Does NOT close F2** — this is a
design task, not a proof; F2 stays CLAIMED-and-orphaned until a remedy is
*implemented and audited*.

**KIND:** ANALYSIS — writes exactly one new design doc, modifies nothing
shared, parallelises without limit.

## The framing, which the design must carry

`GLOBAL.F2` (the bracket-guided finisher is sound) is **orphaned and
confirmed** (ADR-0018, unanimous three-seat review): ADR-0010's premise that
the `[L,H]` bracket "holds under ANY arrival history" is refuted as stated —
for an empty-board root the finisher's own search path *is* a real game line,
so the falsifying histories lie inside the family the bracket claims to cover.
Every shipped ko-sensitive value rests on this undischarged premise.

**A brackets-off regen is not the remedy.** ADR-0017 finding 2 (confirmed by
all three review seats) showed every generation mode reads CERTCORE-dependent
certified seeds; an empty-fingerprint pass clears `fpDisjoint` under deps, so a
brackets-off rebuild inherits the same premise through its seeds. Spending a
machine-week on it would not settle F2/F3. (A brackets-off run for *other*
purposes — e.g. measuring the definitional floor — is a separate question and
not foreclosed here.)

## The candidate direction

**`QA-026`: under a fixed-value long-cycle verdict, the existing L/H `converge`
machinery is reusable with loops pinned to the tie value instead of shipping a
bracket** — a finisher that does not rely on the "ANY arrival history" premise
at all. The design must work this out concretely: the data representation, the
fixpoint operator, how certified seeds are produced without the bracket cut,
and how the result is consumed by `Session.choose` and the arena.

## Constraints (hard — the design must address each)

1. **Depends on `QA-023`.** The fixed-value-cycle Markovian claim is the
   foundation; its computational half (`EXP-2B`) is in flight. **Scope the
   design contingently:** "if QA-023 holds → this approach; if QA-023 falls at
   3×2 → the remedy is X instead." Do not assert QA-023.
2. **Must not reintroduce score-on-cycle (`GLOBAL.R2`)** — which is provably as
   hard as PSK. A tie-pinned loop must be a *constant* verdict, not a function
   of which board repeated.
3. **Must not fall into the reply-trap (`GLOBAL.RPLY-TRAP`)** — the cycle
   terminal must not drag the full history back into the memo key.
4. **Per-board epistemic independence (ADR-0016).** A design argued at one size
   does not transfer; say what is structural (may inherit, with the argument)
   vs empirical (never inherits).
5. **Cost/tractability.** The whole project's premise is tractability; a
   remedy that is PSK-hard is no remedy. Cost the method, or make costing it
   the first deliverable.

## Read order

1. `docs/infra/dispatch/README.md`, `AGENTS.md`, `DELEGATEE.md`.
2. `docs/decisions/0018-bracket-cut-confirmed-unanimous-review-f2-remedy-is-new-task.md`
   (the ruling that opens this task) and `0015` (the ruling of record).
3. `docs/decisions/0010-bracket-guided-finishing.md` and `0009-retrograde-value-iteration.md`
   (the machinery to reuse / the honesty clause).
4. `docs/epistemic/roadmap-2026-07-28.md` §2–§3 (`QA-023`/`QA-026`/`GLOBAL.R2`/
   `GLOBAL.RPLY-TRAP`) and `docs/research/ruleset-options.md` §RETRO_CYCLE.
5. `src/retro.zig` **read-only** — `converge`, `Exact`, `saveArtifact`,
   `CERTCORE` / `fpDisjoint` (`:542-577`, `:642-655`, `:995-1025`,
   `:1085-1135`, `:2395-2415`). Do not edit.

## Acceptance

A design document that delivers, each tagged CLAIMED/PROVEN-as-scoped:

- **The approach** — the data representation, fixpoint operator, and seed
  production, concretely enough to implement.
- **The soundness argument, or its honest absence.** If the remedy is sound by
  theorem, state the theorem. If it is sound-in-practice, say so and name the
  falsifier. A design that claims soundness without the argument is the
  ADR-0010 failure repeated.
- **The QA-023 contingency** — what happens to the design if QA-023 falls.
- **The R2 / RPLY-TRAP check** — why the tie-pinned loop is a constant verdict
  and why the key stays history-free.
- **Cost** — wall/RAM estimate, or a costing plan as the first deliverable.
- **The falsifier** — what measurement would show the remedy unsound; a design
  with no falsifier is decoration.
- **A one-line headline** of the form: *"The sound finisher is <approach>;
  soundness <proven-by/claimed-pending>; cost ~<X>; falsifier <Y>."*

## Deliverable

- `docs/research/f2-remedy-design-2026-07-29.md` — the design, every claim
  tagged, every number cited with its denominator.
- A one-line status for the `CLAIMS.md` owner (`GLOBAL.F2` orphan status, and a
  new `GLOBAL.F2-REMEDY` row if the design warrants one). **Do not edit
  `CLAIMS.md`** or any ADR.

## Do NOT

- Do not edit `src/retro.zig` or any engine file — read-only design.
- Do not edit `CLAIMS.md`, ADR-0010/0015/0017/0018, or `data/`/`artifacts/`.
- Do not assert QA-023, and do not assert the remedy is sound without the
  argument — that is the exact error ADR-0018 exists to prevent recurring.
- Do not propose a brackets-off regen as the remedy. It is foreclosed above.
- Do not generalize across board sizes without the ADR-0016 argument.