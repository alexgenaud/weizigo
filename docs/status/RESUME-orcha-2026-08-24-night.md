# RESUME — orchestration seat, written 2026-08-24 night for a fresh claude-opus-5

Written to be sufficient on its own. The outgoing seat (`claude-fable-5`, T871) stood down
near its context boundary after ruling on the recovery plan, absorbing the four in-flight
rows, and dispatching the green-up. This file supersedes `RESUME-orcha-2026-08-24-evening.md`
for seat state; that file's §1–§5 (the existential diagnosis and the ratified plan) still
stand and are worth reading.

## 1. The ruling this seat was asked for

**The recovery plan is ratified with one amendment.** The diagnosis (broken tooling verified
by itself) predicted the seat's first hour: `reap` reported three healthy workers as orphans
and offered to close them (OPEN.md B57/B58). The amendment, binding on green-up: the
counter-measures guard code contamination but not **data contamination** — a record any
process can overwrite is not evidence. `untracked/runs/<id>.json` is overwritten by a
worker's own test invocations run under its task id, which is what blinded reap.
**Green-up's target list therefore includes single-writer (or append-only) run records, and
`tools/facts` must state each fact's provenance and read UNKNOWN where its source is
overwritable.** T867's tool currently reads clobberable inputs; honest but not yet trusted.

## 2. In flight and queued — the seat is the serializer

| row | model | state |
|---|---|---|
| T872 — green-up delete wave (11 DELETE verdicts) | deepseek-v4-pro | **RUNNING**, dispatched 2026-08-24 ~17:20Z |
| T873 — fix-test wave (21 entries) | unassigned | queued; **do not dispatch until T872 closes** (shared change-log, shared suite) |
| T874 — fix-code wave (10 entries, ends with ratchet deletion if zero red) | unassigned | queued behind T873 |
| T875 — C3 evidence triage (the 42 unbacked PROVEN claims) | unassigned | **HELD for the operator's explicit go** — registered only |

On T872's close, hold it to its own brief's four acceptance conditions (change-log entries,
superset rule with before/after sweep counts, `zig build test` end-to-end, net-negative
lines) — not to its report. Then dispatch T873. The `needs` field is NOT set on these rows
(suggest-minted); the serialization is enforced by the seat, and each brief carries a
stop-if-early instruction.

## 3. Closed and absorbed this evening (verification methods stated)

- **T861** (module-test contract): 72 `test … covers` declarations live (its own findings
  say 73 — off-by-one in the self-report, recorded); the pre-commit gate now SELECTS suites
  from outside the fast pool and refuses new failures outside the known-red baseline.
  Verified by four production commits passing through it and by source inspection.
- **T867** (`tools/facts`): stdlib-only confirmed by import inspection; its 3-arm regression
  passes; its ROWS reading matched an independent direct-store read exactly. Carry the §1
  provenance caveat.
- **T869** (blind third what-is pass, arm C): worker died before close; findings committed
  by the seat (labelled T869) and the row closed pass on evidence. Blindness held.
- **T870** (green-up classification): DELETE 11 / FIX-TEST 21 / FIX-CODE 10 over 88 scripts
  (denominator corrected from 86). The seat re-verified three DELETE verdicts at source
  (orcha-acceptance AC3 unconditional pass; runner-host-guard self-declared RETIRED; argus
  claimlint-green regexes match labels claimlint no longer prints). Accepted; committed.

## 4. Traps, freshly earned

- **Never `reap --close` on the bare run record's testimony.** Check the process table for
  a live `tools/runner --arbiter-id <task>` first. A worker that runs tests clobbers its
  own bare record (B57); reap then reads a dead test-script pid. T870 read BACKED only
  because a classify-only worker runs no tests.
- A file held by an in_progress row can only be committed with `MANAGENT_TASK_ID=<row>`
  labelling; the close gate's printed remedy is correct.
- New citations of `untracked/`/`/tmp` paths in committed docs fail the commit (C10-NEW);
  name volatile evidence by description, not path.
- `managent suggest` still drops `holds=` from the row (B24) — declare holds in the bundle
  header anyway and enforce conflicts by hand.

## 5. Standing state

- **Race W is RESOLVED** (OPEN.md A1): Section A as committed; Section B the committed
  hybrid stands, verified clause-by-clause against all three lanes. Performance verdict
  separate. Race protocol v2.1 amendments are §4b of
  `docs/status/landmark-waypoints-seed-2026-08-23.md` (odd panels; split = merge guidance;
  seat adjudicates stalls from primary sources; two verdicts per race; no self-judging;
  second readings get the field only).
- **The 42 unbacked PROVEN claims: recovery, not demotion** (operator ruling). Nothing has
  been recovered, re-run, or demoted yet; T875 is the registered first step and waits for
  his go. Do not strip statuses.
- **Both ox-alpha retractions stand** (nonce check read its own prompt; provider 429s
  recorded as clean empty runs). Do not infer model quality from empty runs.
- **AGENTS.md carries the no-deferral ruling** (2026-08-24): weigh, recommend, defend with
  doubts; fetch missing facts; never hand back a decision. It binds this seat first.
- Caps: 2 rows/model, 5/family, 10 concurrent, no expectation of approaching them; one
  model per family for important findings; **Fable reserved**; fleet keeper stays paused —
  one dispatcher, this seat.
- Operator decisions still open: OPEN.md A2 (rate-band vs budget-meter retirement), A3
  (sealed complementarity inputs), A4 (API-key pattern security review), T875 go.

## 6. Before believing any status

`bin/managent reap` (with the §4 caution) — then: repo points at itself, `core.worktree`
unset, HEAD file count >2000 (2688 at handover), `.gitignore` 46 lines, last author
`alex@genaud.net`. Re-verify after every commit.

## 7. How to talk to the operator

`docs/infra/discuss.md` governs: recap in human words, exactly one decision per ask, then
stop. **Never a structured question widget.** Propose, choose, argue; he ratifies or
corrects. Hand this seat to a successor before your context is 90% spent, with a resume
written like this one.
