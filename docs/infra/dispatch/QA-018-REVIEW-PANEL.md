# QA-018-REVIEW panel protocol — three blind seats, zero shared writes

**Not a task.** This is the shared protocol for the three parallel seats
`QA-018-REVIEW-A`, `-B`, `-C`, created
2026-07-29 on the user's directive to run the review as a three-model
head-to-head. Each seat's dispatch brief points here. The **substance** of the
review — framing, the three 025 findings, read order, acceptance, Do-NOTs — is
`docs/infra/dispatch/QA-018-REVIEW.md` (the core brief) and applies verbatim
except where this protocol overrides it. The core brief's single-reviewer
deliverable spec is **superseded by §2 below** (it is collision-prone for a
panel: a verdict-named filename and one shared `PROVENANCE.md`).

## 1. Blindness (what makes three seats worth three runs)

- Seats run **concurrently and blind**: do not read the other seats' briefs,
  deliverable directories, or any milestone message numbered **026 or higher**.
  The core brief's read order (packet ends at message 025) is the whole packet.
- Do not coordinate, do not reconcile. If seats disagree, the disagreement is
  the signal; `QA-018-RULING` (the human) consumes all three verdicts raw.
- Each seat reports **solo**: no sub-delegation for the adjudication itself.

## 2. Write isolation (one writer per path — `AGENTS.md` rule)

Each seat writes **exactly two files**, both its own:

| seat | report (+ own `PROVENANCE.md` beside it) | message |
|---|---|---|
| A | `docs/evidence/QA-018/review-a/report.md` | `untracked/msg/milestone-01-ko-reframe/027-review-a-to-all.md` |
| B | `docs/evidence/QA-018/review-b/report.md` | `untracked/msg/milestone-01-ko-reframe/028-review-b-to-all.md` |
| C | `docs/evidence/QA-018/review-c/report.md` | `untracked/msg/milestone-01-ko-reframe/029-review-c-to-all.md` |

- Message numbers are **pre-assigned** (027/028/029) so the append-only
  numbering cannot race; use yours even if a lower number has not appeared yet.
- Everything else is **read-only**, per the core brief: no edits to
  `CLAIMS.md`, any ADR, `src/`, the core brief, this file, other seats' paths,
  `docs/status/*`, or the kanban files.
- **Kanban bookkeeping is serialized through the Orchestrator** (D-8): the
  Orchestrator records dispatch/claim/done for all three seats with
  `--agent <seat-model>`. Seats do **not** run `managent` themselves — three
  consoles writing `tasks.json` concurrently is the exact overwrite risk this
  panel exists to avoid. (Panel-specific deviation from `DELEGATEE.md`
  self-claim; D-8 authorizes it.)

## 3. Two additional defences to adjudicate (calibration, disclosed)

ADR-0017 adjudicates five defences of ADR-0010. Two further candidate
exemption arguments are listed below. **At least one is synthetic — planted as
a calibration case with a known flaw** (standing rule: every checker ships
with calibration; a reviewer who blesses a planted flaw has their WITHSTOOD
weight discounted accordingly). You are told this exists; you are not told
which. Adjudicate **both on the merits**, same grading as the core brief's
findings (SOUND / OVERSTATED / WRONG, with the specific flaw named and cited
if WRONG). The answer key is lodged with the Orchestrator and the user and is
revealed only after all three seats land.

- **Defence 6 (MTD self-verification).** The finisher's root driver
  (`ab_value_from_root`, `src/retro.zig:642-655`) runs repeated null-window
  probes until `lo == hi` converge. If an interior bracket cut returned a
  wrong value, successive probes would disagree and the driver would fail to
  converge — so root convergence itself certifies that no wrong cut
  influenced the returned root value; the search-path family needs no further
  exemption.
- **Defence 7 (the `bracket_fail` gate).** `runRoot` checks every solved root
  value against that root's own `[lo,hi]` (`src/retro.zig:1122-1124`,
  `bracket_fail` counter), and shipped generations report `bracket_fail = 0`.
  An unsound interior cut would push some root value outside its bracket, so
  the measured zero certifies the cuts were sound in practice, discharging
  ADR-0010's burden empirically.

## 4. Head-to-head reporting (the `model-perf.md` data point)

End your report with a `## Run stats` section: model id, console, wall-clock
time, cost if known, approximate context consumed, and whether anything in the
packet did not fit. The comparison consumer is `docs/infra/model-perf.md`
(owner: Orchestrator/user), not you — report the numbers, draw no cross-model
conclusions.

## 5. Independence roster (who may sit)

Barred from all seats: the agent that issued D-5 / ADR-0015, the agent that
(authored ADR-0017, the thing under review), and the **Orchestrator instance**
(role-barred by `ORCHESTRATOR.md` from ruling on claim semantics). Seat A's
Seat A's agent must therefore be a **fresh worker console**, not the Orchestrator's:
the core brief's line "the Orchestrator is also barred" is read as
barring the *role instance*, per the user's 2026-07-29 directive seating GLM
as a reviewer — the review is advisory input to the human ruling, not itself a
claim-semantics ruling. If the user intended a model-level bar, the
Orchestrator strikes seat A before dispatch.
