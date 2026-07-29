# ADR-0018: ADR-0015 confirmed by unanimous three-seat blind review — F2 remains orphaned; the finisher remedy is a new task, not a brackets-off regen

Status: **accepted — the human's ruling on `QA-018-RULING`** (2026-07-29).
Confirms ADR-0015; does not overturn it. ADRs are append-only: ADR-0015 and
ADR-0017 are **not** edited.
Date: 2026-07-29
Supersedes: the **"to be challenged, not ratified"** status line of ADR-0015
(`docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`). The
challenge was made (EXP-10 → ADR-0017) and failed; an independent three-seat
blind review then confirmed the ruling. ADR-0015's *substance* — ADR-0010's
"brackets hold under ANY arrival history" is refuted as stated — stands
unchanged and is now **ratified**, not merely unchallenged.
Relates to: ADR-0015 (ruling of record — confirmed), ADR-0017 (the failed
refutation), ADR-0010 (the bracket mechanism whose justification is
undischarged), ADR-0009 (the honesty clause), ADR-0013 (Track A/B),
`QA-018`, `QA-019`, `GLOBAL.F2`, `GLOBAL.F3`, `GLOBAL.ADR0015-BURDEN`,
`GLOBAL.CERTCORE`, `QA-026` (the candidate remedy direction).
Evidence: `docs/evidence/QA-018/review-a-glm/report.md`,
`docs/evidence/QA-018/review-b-deepseek/report.md`,
`docs/evidence/QA-018/review-c-kimi-k27/report.md` (+ each seat's
`PROVENANCE.md`); messages
`untracked/msg/milestone-01-ko-reframe/027-glm-review-to-all.md`,
`028-deepseek-review-to-all.md`, `029-kimi-review-to-all.md`;
`untracked/msg/milestone-01-ko-reframe/026-fable-to-orchestrator.md`
(the calibration answer key).

## The ruling

**ADR-0015 stands, confirmed.** The three-seat blind review
(`QA-018-REVIEW-A` GLM-5.2 fresh worker, `-B` DeepSeek Pro, `-C` Kimi-k2.7
console separate from the EXP-8 worker) returned **unanimously** that
ADR-0017's "refutation failed" verdict is **SOUND** and ADR-0015 **STANDS**
(seats A and C: "STANDS"; seat B: "STANDS, strengthened"). No seat found an
exemption argument Fable missed; each seat independently exhibited the
candidate exemption shapes (family disjointness / ban-set emptiness) and
showed why each fails — the finisher's search-path arrival histories are
structurally identical to real PSK-legal game lines from the same root
(`src/retro.zig:575-577`, `:642-655`, `:542-548`).

**F2 remains orphaned.** The bracket-guided finisher's soundness premise
(ADR-0010: brackets "hold under ANY arrival history") is undischarged.
Every shipped ko-sensitive value rests on it. This ADR does not rehabilitate
F2; it records that the orphan is **confirmed**, not merely un-refuted.

## Calibration — the review's own quality gate, passed unanimously

The panel protocol planted two further candidate exemption arguments as
calibration cases, **both WRONG** (answer key in msg 026, lodged with the
Orchestrator and the user):

- **Defence 6 (MTD self-verification).** Wrong: root convergence certifies
  *self-consistency*, not *correctness* — all probes consult the same bracket
  tables, so a wrong cut is coherently wrong across probes. All three seats
  convicted it with this mechanism.
- **Defence 7 (the `bracket_fail` gate).** Wrong: it checks only the *root*
  value against the *root's own* bracket (`src/retro.zig:1122-1124`), so
  interior cut errors that leave the root inside its (often wide) bracket are
  invisible; and it is circular (the root value is computed *with* the cuts
  whose premise the bracket asserts). All three seats convicted it.

**All three seats convicted both planted defences.** No seat blessed a
planted flaw. A unanimous verdict that also unanimously catches the
calibration is the strongest review result the protocol can return.

## The remedy is a new task — not a brackets-off regen

A brackets-off regen is **not** the remedy and must not be spent on to close
F2/F3. ADR-0017 finding 2 (Fable, msg 025) showed that all generation modes
read **CERTCORE-dependent certified seeds**; an empty-fingerprint pass clears
`fpDisjoint` under deps, so a brackets-off rebuild does not escape the bracket
cut by construction — it inherits the same undischarged premise through its
seeds. All three review seats independently re-derived this.

The candidate remedy direction is **`QA-026`**: under a fixed-value long-cycle
verdict, the existing L/H `converge` machinery is reusable with loops **pinned
to the tie value** instead of shipping a bracket — i.e. a finisher that does
not rely on the "ANY arrival history" premise at all. That is **design work to
be scoped**, not a foregone conclusion: it depends on `QA-023` (the
fixed-value-cycle Markovian claim, whose computational half EXP-2B is in
flight), and it must not reintroduce score-on-cycle (`GLOBAL.R2`) or the
reply-trap (`GLOBAL.RPLY-TRAP`). The remedy-design task is registered
separately (`docs/infra/dispatch/F2-REMEDY.md`).

## Consequences

1. **`GLOBAL.F2` / `QA-018`: orphaned and confirmed.** The row stays
   CLAIMED-and-orphaned; the burden on ADR-0010 remains undischarged and is
   now confirmed undischargeable *as stated*. The `CLAIMS.md` owner updates
   the rows to cite this ADR.
2. **No brackets-off regen to close F2/F3.** It does not escape the premise;
   spending a machine-week on it would not settle F2/F3. (A brackets-off run
   for *other* purposes — e.g. measuring the definitional floor — is a
   separate question and not foreclosed here.)
3. **Remedy design is a new task** (`F2-REMEDY`): scope a sound finisher that
   does not depend on the falsified premise, with `QA-026` (tie-pinned loops)
   as the leading candidate and `QA-023` / `GLOBAL.R2` / `GLOBAL.RPLY-TRAP` as
   the constraints. Not a regen.
4. **Track A (`memo_writes=false`) does not escape this** (ADR-0017 finding 2,
   confirmed by all seats). The orphan is not a writes-on/writes-off
   distinction; it is a bracket premise distinction.
5. **Per-board epistemic independence holds.** This ruling is justified at
   3×2 / 3×3; it does not transfer to 4×4 by assertion (ADR-0016). The
   orphan's *scope* (which shipped values rest on the premise) is a separate
   computation, not re-litigated here.