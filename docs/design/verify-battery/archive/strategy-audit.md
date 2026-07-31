# verify-battery strategy audit — pass 0

```
Auditor:  Opus 5 / T133 (fresh seat; milestone channel not read, per brief)
Date:     2026-07-31
Subject:  docs/design/verify-battery/pass0/strategy.md (Fable/Navigator, PROPOSED)
Inputs:   pass0/spec.md · pass0/spec-audit.md · the tracked register and evidence tree
Status:   NEEDS-FIX — 2 blockers, 3 critical, 5 must-fix, 3 should-fix, 2 could-fix
Verdict:  NEEDS-FIX
```

## Executive summary

The *plan* is good. Phase structure, gate placement, the critical path, and
especially the two independence rules (V-11 dispatched blind and off the
critical path; at least one fixture authored by a non-implementer) are real
improvements on the spec, not restatements of it. Pulling V-1 forward as a P0
long-pole head start is the right call. §4's falsification list is honest. If
the findings below are fixed, this strategy is ready to dispatch.

The failure is not in the planning; it is in the **verification of inherited
facts**. Standing assumption §0.1 lets the strategy plan against "the spec as
it will read after the B/C/M revision," treating the pass-0 audit's finding
list as sufficient. It is not. Three of the spec's calibration anchors —
I8's 24 states, A3's 2×2 pin census, and I5's 3×2 target — are stale,
mislabeled, or contested in the tracked register, and the pass-0 spec audit
caught none of them. The strategy then writes precise "starting positions for
the V-2 reviser" that carry each defect forward intact, and makes them
acceptance gates at V-10.

The consequence is specific and severe: **following this strategy verbatim
builds an I8 that fails correct artifacts and passes buffer-aliased ones** —
a sensitivity inversion, the exact opposite of what A4 exists to guarantee.

Two structural findings follow from the same root: the strategy's execution
substrate is assumed rather than checked. `docs/infra/sprint.md`, whose
checkpoint machinery the header claims as its process, was **retired
2026-07-28**; and the kanban rows for this audit (T133) and for V-1 (T134) do
not exist, so §0.2's registration assumption is already false for the strategy's
own critical-path task.

Not REDO: no phase, gate, or dependency edge needs to move. The fixes are
additions to V-2's charter and corrections to three calibration targets.

---

## 1. Findings — graded

### Blockers

| # | grade | what |
|---|---|---|
| **SB1** | **BLOCKER** | **I8's fixture polarity is inverted; the strategy dispatches V-8 to assert a withdrawn fact.** Spec I8 is "the 24 known 2×2 fixpoint-vs-truncation **mismatch** states," catching "semantic drift." The register says the opposite. `Opus/T102` proved all 24 are an artifact of a successor-buffer aliasing defect in `brute_value_2x2` (`src/exp4_solve.zig:555-594`): "mismatches, 172 non-terminals: EXP-4 as committed 24 → **this audit 0**" (`docs/audits/audit-2x2-mismatch-2026-07-30.md:1-30`). `T103`'s standing fixture locks in the corrected relationship — "0 mismatches, all 24 states at ±4 from both evaluators" (`docs/evidence/QA-026/calibration-2x2-mismatch.py:7-16`). T125's brief states it plainly: "All 24 EXP-4 2×2 'mismatches' were an artifact of the *checker*… fixpoint and truncation agree on all 172 reachable non-terminal 2×2 states" (`docs/infra/dispatch/T125-basicko-tie-and-aliasing.md:26-30`). The strategy's V-2 starting position — "locate the 24 truncation-gap states in a file the battery loads" — locates them without noticing the sign flip. An I8 built this way **fails every correct artifact and passes an aliased one**. Note the root cause is upstream and also unfixed: `ADR-0020` (ACCEPTED 2026-07-30, same day as T102's audit) still reads "the 24 known 2×2 fixpoint-vs-truncation mismatch states become a standing calibration fixture" (`docs/decisions/ADR-0020-loopy-game-fixpoint-semantics.md:47-49,62-63`) and has not been amended. **Fix:** V-2 restates I8 as a *regression* fixture (the 24 states must **agree**, gap = 0 at 2×2), cites T102/T103 rather than ADR-0020 alone, and the strategy adds a P0 note that ADR-0020's clause needs an amendment through the human. |
| **SB2** | **BLOCKER** | **A3's calibration numbers are mislabeled and internally contested; V-10 gates on them with no reconciliation task.** V-10's deliverable includes "committed numbers reproduced (A3)". A3's first target is `2×2 pin census L==H=2220, pin_T=298, pin_L=34, pin_H=34`. Those are **3×2** numbers, not 2×2: `docs/evidence/QA-026/exp4-solve-2026-07-29.stdout:96` reads "# **3×2** pin census: L==H=2220 pin_T=298 pin_L=34 pin_H=34", as does `docs/research/newrule-2x2-3x2-2026-07-28.md:91`. Worse, the register holds a **second, corrected** 3×2 pin census: "Corrected 3x2 census `2232/322/34/34` replaces the buggy `948/1532/142/0`" (`docs/epistemic/CLAIMS.md:557`, QA-023; repeated at 452, 547, 560), post-dating the `fixpoint_kernel` White-branch fix verified by two independent seats. So the same quantity has two committed values (2220/298 from EXP-4's solver, 2232/322 from the corrected kernel), and A3 pins the earlier one under the wrong goban label. A battery calibrated to A3 as written runs 2×2, looks for 3×2 numbers, and fails at V-10 for a reason that has nothing to do with the instrument. This is precisely the trap A3's own rationale names ("a tool that cannot reproduce a committed number is not measuring the same thing"). **Fix:** add a V-2 starting position requiring every A3 target to be re-verified against the register and cited by `file:line`, with the 2220-vs-2232 divergence either resolved or carried explicitly as two labelled targets under distinct semantics. Cheapest route: fold the check into V-1's charter, which is already a P0 ANALYSIS task with no holds. |

### Critical

| # | grade | what |
|---|---|---|
| **SC1** | **CRITICAL** | **V-1's and V-9's calibration inputs do not exist.** V-1's deliverable lists calibration targets "(3×2 max SCC = 1,676; **Wave 1 SCC-2x2**)"; V-9 carries a dispatch note "prefer **whoever ran Wave 1's SCC tasks**." There is no such task and no such person. `Wave 1` in the roadmap is "F2+F3-4×4 writes-off regen — single artifact… F2+F3 auditor + bracket containment," and it is **blocked on the D3-4×3 pilot GO** (`docs/epistemic/boards/4x4/EPISTEMIC.md:412-417`). No SCC task appears in Wave 0, 1, 2 or 3; `SCC-2x2` and the spec's "Wave 1 5a/5b" appear nowhere in the repo outside the verify-battery documents themselves. The actual SCC precedent is the `2B-2` / `2B-FIX-KO` lineage — `docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout:107` ("# SCCs: total = 947, non-trivial (size >= 2) = 1, max size = 1676") and `docs/infra/dispatch/2B-FIX-KO.md`, which is also where the `index`/`lowlink` slip the spec cites actually happened. V-1 is the first task on the critical path to G1; an unobtainable calibration input there stalls the gate. **Fix:** replace both references with the 2B-2/2B-FIX-KO evidence paths. |
| **SC2** | **CRITICAL** | **I5's 3×2 calibration pins the wrong quantity, and the right one is a three-way open discrepancy — so §4's I5 falsifier is pre-tripped by a known cause.** I5 tests `KO_SENSITIVE ⊆ cycle-**reachable**`. V-1's target is "3×2 max SCC = 1,676", which is *cycle-**involved*** — stable across every source, and not the set I5 checks. Cycle-reachable at 3×2 has **three** committed values: **1,724** (`docs/evidence/QA-023/PROVENANCE-census-3x2-2026-07-29.md:70`), **1,704** (`ko-fix-rerun-2026-07-29.stdout:133`; `census-3x2-2026-07-29.md:15`), and **1,678** (measured under the corrected ko rule with a single true root — `docs/infra/dispatch/F1-SEEDROOTS.md:10`, "versus the 2,622 / 5,668 / 60 / 1,676 / 1,704 currently published"). The cause is documented: "36 empty-goban-with-a-ko-point **phantoms** are inside V and the cycle-reachable set" (`census-3x2-2026-07-29.md:26-28`). The task that was to reconcile this, `F1-SEEDROOTS`, **is not registered** (`managent show F1-SEEDROOTS` → not found). Consequence: §4's falsifier "I5 contradicts stored `KO_SENSITIVE` at 3×2 → escalate to the human immediately (both sides are committed)" will fire on an already-known, already-open discrepancy and be reported as a larger-than-sprint finding. **Fix:** V-1 states the phantom-exclusion convention and pins cycle-reachable explicitly; the strategy either adds a P0 dependency on registering the F1-SEEDROOTS reconciliation, or declares I5's 3×2 containment check deferred with the 1,724/1,704/1,678 spread named in the brief so no seat rediscovers it as news. |
| **SC3** | **CRITICAL** | **The `holds` column is not registerable as written, and the way it fails breaks the V-11 independence claim.** `managent` `holds` is "space-separated **file paths** (relative to repo root) that need exclusive write access" (`docs/infra/managent/spec.md:71`). The strategy's holds are not paths: V-10 holds "fixture files, `docs/evidence/BATTERY/`"; V-11 holds "one new file under `docs/evidence/BATTERY/`"; V-13 holds "evidence dir". Three tasks nominally hold one directory, and V-10 and V-11 are *required to run concurrently* — the strategy's load-bearing claim is that "V-11 is off the critical path **by construction**." Under exclusive-write holds on a shared path that construction collapses. (`docs/infra/managent/spec.md:465` adds a second bite: a `done` task whose `holds` paths are absent from `git ls-files` is flagged, so placeholder paths do not survive `managent audit` either.) **Fix:** enumerate one concrete file path per task before dispatch — e.g. `docs/evidence/BATTERY/fixtures-<invariant>.md`, `docs/evidence/BATTERY/reimpl-<invariant>.md`, `docs/evidence/BATTERY/fleet-<date>.md`. This is mechanical, but it must happen at registration, not at execution. |

### Must-fix

| # | grade | what |
|---|---|---|
| **SM1** | **MUST** | **The claimed process is retired.** The header reads "Process: sprint checkpoints (spec → strategy → acceptance) per `docs/infra/sprint.md`." That file's first line is "**Sprint — RETIRED 2026-07-28**", and it redirects to `DELEGATOR.md` / `DELEGATEE.md` as the live equivalents (`docs/infra/sprint.md:1-9`). The spec at least qualified this ("un-retirement **proposed** in channel msg 062"); the strategy drops the qualifier and asserts the machinery. The whole G1/G2/G3 scaffold therefore rests on a retired process whose un-retirement is unratified. **Fix:** either state the gates as human-ratification points under the delegation regime (they work fine as such — nothing in G1–G3 needs sprint machinery), or make the sprint un-retirement an explicit G1 agenda item alongside the M7 policy. |
| **SM2** | **MUST** | **T133 and T134 are not in the kanban; §0.2 is already false for V-1.** Standing assumption §0.2 is "Every task is registered in `bin/managent`." Commit `b6c012a` states it registered "T132 (oracle-v2 strategy audit), T133 (verify-battery strategy audit), T134 (V-1 I5 feasibility memo). Fix `_sys.next_id`." The live state (`docs/infra/managent/tasks.json`) contains **T130, T131, T132 only** — this audit is running as T133 with no row, and V-1/T134 does not exist. `_sys.next_id` is **132**, below the highest allocated ID, so the next `--auto` mint collides; the advertised fix did not take. `managent audit` reports only a stale-binary warning and does not detect commit-claims-registration divergence. **Fix (execution substrate, flag to the human):** register T133/T134, correct `next_id`. Worth noting for the strategy proper: §2's parallelism plan is expressed entirely in managent primitives, so an unverified substrate is a planning risk, not just hygiene. |
| **SM3** | **MUST** | **V-11's blindness has no enforcement mechanism** — the strategy's own Q2, which it poses without answering. "No battery source in the brief's READS" is not enforcement: the re-implementer clones the repo, and `src/vb_*.zig` will be sitting there. `DELEGATOR.md:12` specifies `READS: the minimum` as a scoping principle, not an access control. **Fix:** enforce by chronology or isolation, not honour — dispatch V-11 at G2 and require its deliverable committed **before V-6's first commit** (which the dependency graph already permits, since V-11 needs only spec + schema), or run it in a git worktree pinned to the pre-P2 commit. Add `caps=independence:has-not-read-src/vb_*` to the row (`docs/infra/managent/spec.md:73` supports the token). |
| **SM4** | **MUST** | **The sixty-cell matrix is never enumerated and never assigned** — the strategy's own Q5, also unanswered. V-13's deliverable is "all five gobans × in-scope artifacts," which is not "a dozen verification questions × five gobans." Without the matrix, V-13's output cannot be mapped to cells, the sprint's headline claim ("sixty cells filled") is unauditable, and spec §7's completeness falsifier ("the invariant set is found to be missing something the fleet then trips over") cannot be evaluated at all. The spec's own audit graded this only COULD (O2); at strategy level it is load-bearing, because V-13 is the deliverable. **Fix:** make the matrix a named V-2 or V-4 deliverable, ratified at G1 or G2 — before V-13 is written, not before it dispatches. |
| **SM5** | **MUST** | **C3's hash-pin mechanism does not cover A2's scope.** The strategy resolves C3 with "T126's `SHA256SUMS` entry is the source of truth." That file has exactly one 4×4 entry — `data/oracle-4x4-basicko-tie-area.wzo` (`artifacts/SHA256SUMS:5`) — so it disambiguates "v1" only by omission, and the other two 4×4 artifacts in `data/` (`oracle-4x4.checkpoint.wzo`, `oracle-4x4-parallel.checkpoint.wzo`) have **no committed hash**. That contradicts the strategy's own M1–M5 starting position, "A2 scope (`data/` + `artifacts/`, **enumerated**)". It also matters semantically: `basicko-tie-area` is the T113 ADR-0020 artifact that PROGRESS.md says "does **not** inherit this defect," while `oracle-4x4.checkpoint.wzo` is the PSK checkpoint whose ko-sensitive columns are untrustworthy (`docs/epistemic/PROGRESS.md:144-155`). If "v1" is the former, A4 requires the project's current best 4×4 artifact to fail — defensible, but it must be said out loud. **Fix:** V-2 names v1 by path and SHA explicitly rather than by reference, and states the in-scope artifact list with a hash for each or an explicit "unhashed, in scope" marker. |

### Should-fix

| # | grade | what |
|---|---|---|
| **SS1** | **SHOULD** | **M7 has two tracked precedents the strategy does not cite.** It calls the shared-code policy load-bearing and offers "the audit's Q5 answer is the guide" — but (a) `docs/infra/sprint.md:22` already carries a live tracked rule for standalone tools ("**Independent.** A standalone binary that does not import unrelated project modules"), adjacent rather than binding since the battery is `src/verify_battery.zig` and not `bin/weizigo-*`, and (b) T103's fixture is an existing worked example: "a standalone implementation **sharing no code** with the Zig solver or the Opus audit Python script — an independent third witness" (`docs/evidence/QA-026/calibration-2x2-mismatch.py:20-21`). Handing V-2 a precedent beats handing it a principle. |
| **SS2** | **SHOULD** | **§4 has no falsifier for "the battery is right and the spec's numbers are wrong."** Every entry in §4 assumes a defect in the artifact, the plan, or the instrument. SB1 and SB2 both land in the missing fourth case, and it is the one this strategy is least equipped to notice, because §0.1 grants the spec's calibration anchors the benefit of the doubt. Add it: *V-10 reproduces a number that disagrees with the register → the register entry is audited before the battery is.* |
| **SS3** | **SHOULD** | **V-14+ has no ID, no count, and no owner.** "V-14+ | MUTATION | register absorption: proposed rows → `CLAIMS.md`" is a placeholder standing in for the one step that makes the sprint's output real. Register absorption at this project has consistently been where scope is discovered (T123–T127 was five serial mutations). One row per goban, at minimum, with the `CLAIMS.md` hold made explicit — the strategy already knows they serialise. |

### Could-fix

| # | grade | what |
|---|---|---|
| **SO1** | **COULD** | Deliverable paths mix conventions: V-1 is `docs/design/verify-battery/pass1/i5-feasibility.md` (repo-relative), V-3/V-4/V-5 are `pass1/spec-audit.md` (directory-relative). Since `holds` and `OWNS` both take repo-relative paths, use those throughout. |
| **SO2** | **COULD** | Inherited unit slip worth catching in V-2: spec I7 says v1's DTT is "uniformly 255 across all **43,046,721 slots**." 43,046,721 = 3^16 is the dense *position* count; the compact slot count is 99,133,036 (`docs/research/newrule-4x4-2026-07-28.md:99,185`). R3 makes denominators load-bearing, so the two should not be conflated in the invariant that reports one. (255 is also the defined `DTT_FAR` sentinel — `docs/research/f2-remedy-design-2026-07-29.md:206` — so I7's defect signature is *uniformity including terminals*, not the value itself. Worth stating precisely for the implementer.) |

---

## 2. Answers to the strategy's five questions (§5)

### Q1: V-1 before V-2 puts the long-pole memo on the critical path to G1. Right, or should V-2 close B2 with a conditional and let V-1 land during P1?

**V-1 first is right — keep it, and widen its charter.** The reasoning in §1 is
sound: B2 and C2 are exactly the two findings V-2 cannot honestly close without
a costed memory plan, and `DELEGATOR.md:33` makes this a standing rule ("Cost
the method before specifying it. If you cannot, make costing it the **first
deliverable**"). A conditional close would be the retirement of a blocker by
promise.

The cost is also small in the right direction: V-1 is ANALYSIS with no holds,
so it parallelises without limit (`ROLES.md:74`), and it is the only P0 task
that can absorb more scope without lengthening the path. So put SB2's number
re-verification and SC2's cycle-reachable reconciliation there rather than
inventing new P0 tasks.

One correction to the framing: V-1 is described as running "**now**". It cannot
— T134 does not exist (SM2), and its two stated calibration targets do not
exist either (SC1). V-1 is currently blocked on facts, not on tasks.

### Q2: Is V-11's blindness enforceable given the briefs are tracked in the same repo the re-implementer clones? What must its READS exclude?

**Not as written — see SM3.** READS is a scoping convention, not a sandbox, and
the strategy's own rule ("a re-implementer who has seen the battery's source is
not independent") is exactly the standard that an honour-system READS cannot
meet. Enforce it structurally:

1. **Chronology first.** Dispatch V-11 at G2 and require its deliverable
   committed before V-6's first commit. Then the source does not exist to be
   read, and blindness is a fact about the repo rather than a claim about a
   seat. The dependency graph already allows this — V-11 needs only the
   ratified spec and schema.
2. **Worktree if chronology slips.** Pin V-11 to the pre-P2 commit.
3. **READS must exclude:** `src/vb_*.zig`, `src/verify_battery.zig`, the V-4/V-5
   design and audit documents, all V-7/V-8/V-9 lane deliverables and reviews,
   and V-10's fixture files. **READS must include:** the ratified spec, the
   ratified schema, and the goban/artifact under test — nothing else.
4. **Declare it in the row:** `caps=independence:has-not-read-src/vb_*`, so the
   constraint is machine-visible rather than prose in a brief.

The QA-023 precedent supports the strong reading: the kernel audit found the
defect because the auditor "reproduced all three evidence lines from scratch in
Python, **no Zig imported**" (`CLAIMS.md:557`).

### Q3: Does the two-exit-class scheme survive the I5-at-3×2 scenario, where the artifact and the battery may *both* be right and the committed census wrong?

**No. Two classes are one short, and SC2 shows the missing class is the likely
one.** *artifact-bad* and *battery-bad* jointly assume the register is correct.
The 3×2 cycle-reachable spread (1,724 / 1,704 / 1,678, cause documented as 36
phantom states, reconciliation task unregistered) is a case where the artifact
is fine, the battery is fine, and the **committed number** is wrong — and it is
not a hypothetical, it is the state of the repo today.

Add a third class: **reference-bad** — the invariant computed cleanly and
disagrees with a committed figure, so the register entry is what goes to audit.
It needs its own exit code, because its handling is genuinely different: not a
build failure, not a harness failure, but a claim-review trigger. This pairs
with SS2 and makes the strategy's own §4 escalation ("escalate to the human
immediately") actionable rather than alarming — the human gets "reference
disputed, here is the spread" instead of "the sprint may be broken."

Note this also improves the *good* case. R6 demands non-zero exit on failure;
three classes let the fleet run distinguish sixty green cells from
fifty-eight green cells and two disputed references, which is the distinction
the epistemic tree actually needs.

### Q4: Is Orcha's dispatch pacing sufficient for the project-wide two-heavy-runs cap, or does it need a runner-level semaphore?

**Sufficient for this sprint; name the failure mode and prefer the cheap
tooling if it is one command.** The cap is cross-sprint by construction —
oracle-v2's strategy declares the same shared meter ("at most **two** 4×4-scale
invocations at once", `docs/design/oracle-v2/pass0/strategy.md:142`), so the two
documents agree and no contradiction needs resolving.

Against tooling: the runner already enforces the thing that actually killed the
host — 4 GB RSS SIGKILL per process. The 2026-07-29 kernel panic was one
12.5 GB compile, not three well-behaved 3 GB runs. A semaphore would add a
shared-state file and a lock to a project that has already spent tasks on
managent concurrency bugs (T108, T122).

For tooling: dispatch pacing is a human in a loop, and the loop's failure mode
is silent — two seats claiming heavy work minutes apart, neither aware. If
`tools/runner` can take a `flock`-guarded slot count in a few lines, it is
worth it; `sprint.md:16` already establishes `flock` as the project's idiom for
exactly this. Do not block the sprint on building it.

What the strategy *must* add either way: the cap is currently unowned. Say
which role holds it and what a seat does when it wants a heavy run and cannot
see the global count — the spec's O4 asked this and the answer is still
missing. "The human enforces it" is an acceptable answer; an unstated one is
not.

### Q5: Does V-13's matrix cover the dozen questions × five gobans, and where is that matrix enumerated before V-13 dispatches?

**It does not, and it is enumerated nowhere.** See SM4. "All five gobans ×
in-scope artifacts" is an artifact sweep; "a dozen verification questions ×
five gobans" is an epistemic sweep. They are different shapes, and the second
one is the sprint's stated purpose.

Concretely, twelve invariants after the B/C/M additions (I1–I9 + I10 TIE +
I11 move-set + I12 range) is suspiciously close to "roughly a dozen
verification questions" — but the spec's dozen are *epistemic-tree cells*, not
invariants, and nobody has yet written down that they coincide. If they do, say
so and the matrix is nearly free. If they do not, the gap between "twelve
invariants pass" and "twelve cells are settled" is the whole sprint's
deliverable and it is currently unplanned.

Enumerate it at V-2 (as spec content, ratified at G1) or V-4 (as schema
content, ratified at G2). Not later: the matrix determines which fields the
result schema must carry for a cell to be markable, and G2 freezes the schema
for the sprint.

---

## 3. Phase-by-phase assessment

| phase | grade | notes |
|---|---|---|
| P0 | **NEEDS-FIX** | Right shape, right sequencing (Q1). V-1's charter must absorb SB2 and SC2; its calibration targets must be replaced (SC1). V-2's starting-position list must add I8 polarity (SB1), A3 re-verification (SB2), v1 identification by value not reference (SM5), and the cell matrix (SM4). |
| G1 | **PASS** with additions | Correctly identifies M7 and S1 as human-decision items. Add the sprint un-retirement (SM1) and the cell matrix (SM4) to the agenda. |
| P1 | **PASS** | V-4/V-5 correctly scoped; the "M4's design does not wait here" note is the right consequence of S4. |
| G2 | **PASS** | Schema freeze is the correct gate. It is also the deadline for V-11's dispatch (SM3) and for the matrix, if it lands at V-4 rather than V-2. |
| P2 | **NEEDS-FIX** | Lane split is clean and the holds are genuine disjoint source files. The adversarial-review preference for V-8/V-9 is well-argued and matches `DELEGATOR.md:43-49`. But V-8 owns I8, which is currently specified backwards (SB1). |
| P3 | **NEEDS-FIX** | Both independence rules are the best content in the document. Both are undermined by unregisterable holds (SC3) and unenforceable blindness (SM3). V-10 additionally gates on numbers that do not reconcile (SB2). |
| G3 | **PASS** | "Running it early converts sixty cheap runs into sixty rumors" is the correct gate rationale, correctly placed. |
| P4 | **NEEDS-FIX** | RSS-metered concurrency is right (Q4) and cross-sprint-consistent. V-13's matrix is unenumerated (SM4); V-14+ is a placeholder (SS3). |
| §3 cross-sprint | **PASS** | Verified against oracle-v2's strategy: the shared RSS meter and the `src/gtp.zig` hold (`oracle-v2/pass0/strategy.md:142,146`) agree with what this document claims. The schema-anticipates-brackets argument is sound. |
| §4 falsifiers | **NEEDS-FIX** | Honest and specific, but missing the reference-bad case (SS2, Q3), and the I5-at-3×2 entry is already tripped (SC2). |

## 4. Required changes before dispatch

1. **Restate I8 as a regression fixture** — the 24 states must agree, gap = 0 at 2×2; cite T102/T103; flag ADR-0020's clause for amendment (SB1).
2. **Re-verify every A3 target against the register by `file:line`**; resolve or explicitly split 2220/298 vs 2232/322, and correct the 2×2/3×2 label (SB2).
3. **Replace the Wave 1 SCC references** with the 2B-2 / 2B-FIX-KO evidence paths, in both V-1's targets and V-9's dispatch note (SC1).
4. **Pin I5's calibration to cycle-reachable with the phantom convention stated**, and name the 1,724/1,704/1,678 spread in the brief; register the F1-SEEDROOTS reconciliation or declare 3×2 containment deferred (SC2).
5. **Enumerate one concrete file path per task in `holds`**, so V-10/V-11/V-13 are genuinely concurrent (SC3).
6. **Restate the process** under the delegation regime, or put the sprint un-retirement on G1's agenda (SM1).
7. **Register T133 and T134; correct `_sys.next_id`** (SM2 — execution substrate; for the human).
8. **Enforce V-11's blindness structurally** — commit-before-V-6, or worktree, plus the `independence:` cap and an explicit READS exclusion list (SM3).
9. **Make the sixty-cell matrix a named deliverable** at V-2 or V-4, ratified at G1 or G2 (SM4).
10. **Name v1 by path and SHA-256 inline**, and enumerate in-scope artifacts with hash-or-marker (SM5).
11. **Add a third exit class, `reference-bad`**, and the matching §4 falsifier (Q3, SS2).
12. **Assign the RSS cap to a role**, and say what a seat does when it cannot see the global count (Q4).

Items 1–5 are prerequisites for dispatching V-1 and V-2. Items 6–12 can land in
the same V-2 revision but do not block V-1.

## 5. Verdict

**NEEDS-FIX.**

The plan is sound and mostly ready. Its phase boundaries, gates, critical path,
and independence rules would survive an adversarial read; the decision to front-
load V-1 is correct and well-argued, and the cross-sprint coordination checks
out against oracle-v2's strategy.

What fails is inherited-fact verification. Standing assumption §0.1 treats the
pass-0 spec audit's finding list as a complete account of what the spec gets
wrong, and it is not: three calibration anchors are stale, mislabeled, or
contested in the tracked register, and one of them (I8) would produce an
instrument that is sensitive in the wrong direction — passing the aliased
artifacts A4 exists to catch. A verification battery calibrated against
unverified numbers is the sprint's own thesis turned against it.

The strategy anticipated the shape of this in §4: "**V-3 returns REDO:** the
completeness-gaps-only premise collapses; strategy withdrawn, not patched." The
premise does not collapse — the architecture is fine and no structural finding
has emerged — but it does not hold in the form §0.1 states it. Adopt the twelve
changes above, widen V-1's charter to cover the numbers rather than only the
memory budget, and this strategy is dispatchable without a second pass.
