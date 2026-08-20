# Pass 1 — the registered ladder (Fable's ratification condition, T551)

Phases and gate instruments are fixed by `docs/infra/sprint.md`. One row per phase, one
row per gate, gate on a different model from the phase it audits.

| # | phase | deliverable | gate instrument | status |
|---|---|---|---|---|
| 0 | brief review | `00-brief-review.md` | — (adjudication) | **DONE** `T551` fable: SPEND-WITH-EDITS |
| 1 | spec (7-lane tournament) | `01-spec-<lane>.md` ×7 | peer grading, G3/G4 | dispatching |
| 2 | consolidation | `01-spec.md` | Fable, fresh instance, anonymized | after 1 |
| 3 | audit | `01-spec-audit-<lane>.md` | all lanes, findings dispositioned | after 2 |
| 4 | research / residual check | per-family session measurement | — | after 3 |
| 5 | scope + acceptance tests | `02-scope.md`, `03-test.md` | tests reviewed without implementation | after 4 |
| 6 | plan | `05-plan.md` | document review | after 5 |
| 7 | build (red → green) | the verb + controls | independent re-implementation, different model | after 6 |
| 8 | verify + smoke | suite, claimlint | numbers audit | after 7 |
| 9 | accept | `08-accept.md` + absorb + perf stats + commit | numbers audit | bookend |

**Cannibalization is the deliverable, not the verb.** Pass 1 closes only when
`tools/runner:1505` and the normal-exit path both call the new verb and the old code is
deleted.

**Recording rule per phase:** a coarse grade per model (great / good / average / bad /
terrible) plus one sentence of nuance. No dimension schema up front; dimensions are
proposed only once observations suggest them.

## Fable's rulings carried forward (T551)

- **Pass order: pass-1-first affirmed** — process ownership before state consolidation.
- **The escape mechanism is measured, not open**: the Claude console harness starts every
  tool command in a new session; zig creates none (`std/process.zig:397`). Escapees are
  session leaders, so only descendant enumeration can reach them.
- **Residual check owed**: the measurement covers `claude -p`. One `ps -o pid,ppid,pgid` +
  `getsid` check per other console family (DeepSeek CLI, ollama-subagent) before the
  seeded controls are finalized. macOS `ps -o sess` prints 0 and is useless.
- **Non-goal for pass 1**: a SIGKILLed runner reaps nothing. That is `T548`'s sweep and
  later the supervisor's held handles.
- **Footnote, not a blocker**: Fable both authors a lane and holds final authority
  (operator ruling) — recorded, and used as the benchmark other models are compared to.
