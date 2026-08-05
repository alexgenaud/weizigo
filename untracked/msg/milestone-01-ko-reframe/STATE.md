# STATE — crash-recovery anchor

**Read this first. Overwritten in place; always current.**
Last updated: **2026-08-05, end of the Fable 5 Orcha session** (operator-corrected seat
attribution; session delta in `docs/status/handover-orcha-2026-08-05.md`).
Resume: `bin/managent resume`, then this file, then your row's brief. Nothing else.

---

## 1. Where things stand

**The 4×4 artifact is structurally complete. Its values are verified for Bellman residual and
key agreement at full scale, and not yet for closure or cycle containment.** That is the honest
sentence; do not shorten it to "solved".

G3b pass0 ran and delivered ten rows. Established at 4×4, each behind an instrument licensed
with a null control **and** a seeded defect shown to fire:

- **0 Bellman violations / 95,677,624** entries
- **0 key mismatches / 99,133,036** entries
- **0 move-set mismatches at every rung**, including 4×3 (0 / 643,378) and at ko-active states

**G3b is NOT discharged and no claim was promoted.** `pass0/accept.md` §6 carries the ruling.
Two pass conditions had been tabled as PASS with no denominator; their real 4×4 evidence was a
22-entry sample (0.00002%). Four gaps remain, registered as **T363** in cost order: full 4×4
closure run (minutes), 4×3 retroactive rung for I4 and key-agreement, I5 at 4×3/4×4 with the
owed memory breakdown, M8/M10 mutant assertions.

Spec is **Rev 5**, plan is **Rev 5**, both RATIFIED. 4×3 is ladder rung 4: **no 4×4 reading
counts until that check has passed at 4×3.**

## 2. Rules that cost the most to learn — obey these

1. **Run the instrument; do not read the document.** `sprint.md:93` — document review has found
   zero of this project's real defects. Every defect found on 2026-08-04 came from running
   something: parsing an artifact header, dry-running a dispatch, sampling a stuck process.
2. **A pass condition without a denominator is not a pass.** This is how a 22-entry sample got
   tabled as PASS at 4×4.
3. **Every instrument needs a null control and a seeded-defect control before its first reading
   counts.** A comparison never shown to fail is not evidence.
4. **Verify a finding's `file:line` before accepting it.** One audit finding was substantively
   right and cited a blank line.
5. **Floors move down only, by the Orchestrator, on evidence of a committed fix**
   (`docs/infra/roles/ARGUS.md:97-100`). Never widen a floor to admit a citation — rescue the
   file into tracked evidence and re-point instead. Eleven dangling paths were checked on
   2026-08-04 and every one was already gone from disk.
6. **Commit, then `zig build deploy`, then `sh tools/smoke.sh` with zero STALE — every time.**
   Deploy staleness is a hard suite failure again since T337 wired the check.
7. **Verify a leg with `zig test src/<f>.zig --test-filter <tag>` (one flag per test — the
   filter is a SUBSTRING match, so a `\|` alternation string matches nothing and passes
   vacuously; assert the reported test count), never unfiltered.** The unfiltered form pulls
   the full import graph and drags in `qa023_brute_2x2`'s explosive smoke test. It now fails
   fast on a 20M-node budget (T360); **do not raise the budget.** (`zig build test` accepts no
   filter in this build.zig — the previous wording here prescribed a command that does not run.)
8. **One writer per file, declared as `holds=`.** `holdsConflict` refuses a claim only against an
   **in-progress** holder (`src/managent/main.zig`), so declaring the hold is what mechanizes it.
9. **Commit through `tools/git-commit-mine <paths> -m <msg>`**, never `git add -A`.
10. **Declare both findings deliverables** on every row: `findings/<id>-<slug>.json` **and**
    `findings/<id>-context.json`. They are different artifacts.
11. **`managent dispatch --to` records bookkeeping and spawns nothing.** Launch with
    `bin/ollama-subagent <id> --model <tag>:cloud` or `bin/subagent <id> --dspro`. The `:cloud`
    suffix is load-bearing — bare tags do not resolve.
12. **Never ask a model to introspect its identity** (2/2 wrong). An agent *told* its identity
    echoes it reliably (4/4). `unknown/T999` is an untold agent, not a lying one.
13. **Poll `bin/managent inbox <id> --ack` at every checkpoint.** The operator is no longer the
    relay. A console that does not poll blocks for hours on a directive it never read.

## 3. In flight and owed

| Row | What | State |
|---|---|---|
| T363 | G3b completion — the four gaps to discharge | **in progress** (deepseek-v4-flash whole-sprint console; first sprint-manager trial) |
| T328 | Bake-off harness dry-run (races item 1) | in progress |
| T366 | Old vs new 4×4 engine kifu, milestone M3 (re-registration of dead T361) | in progress |
| T367 | Race packet authoring + key sealing (races item 2) | dispatched, awaiting claim |
| STANDING-ABSORB | Tier 0 absorb pass | **done 2026-08-05** (C7 4→0, commit 044d9b2) |
| T354 | Register triage + C3 ratchet | dispatched (unblocked by absorb close) |
| T368 | `managent standing` trigger markers dead since T356's rename — re-couple + regression | dispatchable (set C) |
| T357 | Ollama concurrency measurement | **requires a QUIET fleet** — first row when the fleet drains |
| T350/T351/T352/T353, T362, T364 | managent robustness; runner rows | hold while fleet is hot (they edit tooling live consoles execute) |
| T358 | Scaling census — hold until the machine is quiet; it rebuilds artifacts | dispatchable, frontier-held |
| T348 | DISCHARGE — **do not claim until T363 closes and Orcha rules** | blocked in practice |

## 4. Gates, as of now

`C1a ORPHANED` 10 · `C1b STALE-NEGATION` 0 · `C2 DEAD-LINKS` 14 · `C6 MISCITED` 0 ·
`C7 UNABSORBED` 0 · `C9 UNMAPPED` 0 · calibration PASS — all at floor.
**`C3 UNBACKED` = 76 of 100 PROVEN rows have no committed evidence.** Report-only, which is why
it grew unnoticed. T354 proposes the ratchet.

## 5. Operator rulings, 2026-08-04/05

- **Orcha delegates sprints to consoles; it does not manage their internals.** Orcha's output is
  the delegation package and the set plan.
- **Archive, never delete.** Rows leaving the live register move to `archives/` in full with a
  one-line epitaph. Because nothing is destroyed, agents may move without per-item approval.
- **IDs and names coexist**; a name never replaces an ID. Spell out an ID's meaning at least
  once per session when writing to the operator.
- **Fable: hand over before 90% of 200 k and use sparingly.** The 200 k line is a **cost**
  boundary, not capacity — the window reaches 1 M. Mechanism undocumented; do not restate as fact.
- **4×3 is ladder rung 4** (spec Rev 5), for transposition coverage and as the 5×4 rehearsal.
- **8192 MB authorised** for the I5 runs. Host has 48 GB and took an OOM kernel panic at 12.5 GB.
- **deepseek-v4-flash is the default for ALL new dispatches until 2026-08-12** (worker rows and
  sprint consoles); at expiry, re-rule on the week's ledger — `model-perf.md` §Model versions.
- **Concurrency:** the five-agent ceiling is the Ollama pool only; no DeepSeek limit known
  (operator, 2026-08-05: six DeepSeek + five Ollama + several Claude simultaneously is fine).
  Real constraints are sets, `holds=`, and host RAM.
- Decisions that cannot be delegated: `docs/infra/human-decisions.md`.

## 6. Epitaphs — do not re-open these

- **PSK solving** — abandoned 2026-07-24; intractable and not real Go. Committed residue
  (including a 4×4 "+2") is untrustworthy; the certified L/H core is sound.
- **MIGOS +2 as an anchor** — a different cycle-resolution rule, i.e. a different game (T274).
  Ours is +1. Comparing across rulesets produced a false acceptance failure.
- **The 716-gap escalation** — the *check* was wrong, not the solver (T287). L<H is the honest
  output where the state does not determine the value (axiom E3).
- **`CODE.WZO2-INCOMPLETE`** — FALSE-AS-SCOPED. The "missing 6.77M entries" were 131,068
  genuinely unreachable single-colour gobans; the original figure overstated 51.7×.
- **Credential stripping for subagents** — rejected 2026-08-03; solves nothing on a single-user
  host.
- **The mkdir store mutex** — replaced by `flock(2)` after it wedged the fleet for eight hours.
  `std.process.exit` skips `defer`; the kernel releases an flock on death. Do not reintroduce a
  filesystem mutex.

## 7. Seats

| seat | status |
|---|---|
| Orchestrator | handover to Opus 5 pending — Fable 5 held it 2026-08-05 (Opus 5 before that, 2026-08-04/05) |
| Sprint consoles | seated per package, closed when the package closes |
| Auditor | ephemeral, spun per gate (DIRECTION §6) |
| Fable | available for high value-per-token work only; never cheap audits |

**Governing documents:** `docs/audits/2026-08-02-grand-audit/DIRECTION.md` + Amendments 1–2 ·
`docs/epic-01-markovian/PHASES.md` · `docs/infra/sprint.md` · `docs/infra/human-decisions.md`.
When the kanban and DIRECTION disagree, DIRECTION wins and the kanban is the bug.
