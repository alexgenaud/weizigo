# Argus spec audit 1 — DSPro/T161

```
Auditor:   DSPro/T161 · Model: DeepSeek-v4-Pro · Date: 2026-07-31
Scope:     docs/infra/argus/pass0/spec.md (PROPOSED, revision 1)
           against untracked/msg/milestone-01-ko-reframe/067-dabir-to-orchestrator.md
Instrument: document review, fresh seat (sprint.md @ 45deb10:147)
Hygiene:   per DELEGATOR.md rule 5 — auditor knows less than author.
           No channel access beyond 067. No prior Argus context.
           Every finding cites file+line against the current text.
           Acceptance criteria cited by slug.
```

## 1. Scope and method

Read the spec end-to-end. Verified every commit-pinned line reference against
the text at `45deb10`. Cross-checked the spec's baselines against live tool
output at HEAD (0af7c3a). Read msg 067 to confirm the spec faithfully captures
the human's request. Read sprint.md rev 4, DELEGATOR.md, AUDITOR.md, and
ORCHESTRATOR.md for process alignment. Inspected `managent liveness`,
`managent audit`, `bin/weizigo-claimlint`, `du -sh untracked/`, and
`.gitignore` to verify mechanical claims.

## 2. Fidelity to source (067)

The spec captures and materially improves on msg 067:

| 067 says | spec says | assessment |
|---|---|---|
| `claimlint-green` = exit 0? | NOT boolean — record C1a/C1b/C2/C6/calibration separately, baseline-relative | **correct refinement.** `claimlint` exits 1 today (10 C1a, 13 C2); a boolean check is permanently red. R9's baseline-relative design is the right fix |
| `artifact-loadable` = can engine load .wzo? | load set is a design decision; first run sets it; run budget is a design question | **correct.** The spec doesn't pretend to know which artifacts are "active" |
| `stale-in-progress` > 24h | `managent liveness` + `managent show` per task; §7.2 explains the timestamp gap | **correct.** `managent liveness` exists (verified: exits 0, "no in_progress tasks") |
| log + summary | R7 (append-only, machine-parseable), R8 (recomputable, denominators) | **correct and strengthened.** 067 said "append-only"; the spec adds mechanical proof |
| Two modes | R5 (one invocation, one mode), R12 (coverage denominator) | **correct.** The spec pins down what 067 left vague |

The spec also adds what 067 didn't: the counter-risk (§1.1), acceptance criteria
(A1–A7), the module decomposition, and the falsification conditions (§8). All
are appropriate for a sprint spec under sprint.md rev 4.

## 3. Requirement audit

Each requirement checked for testability, consistency with the rest of the
spec, and alignment with sprint.md.

| req | verdict | note |
|---|---|---|
| **R1** — exactly one Argus seat | PASS | mirrors Orcha's singleton pattern. Testable by convention |
| **R2** — authority none | PASS | advisory-only is clear. A5 proves read-only; A6 proves findings route through Orcha |
| **R3** — write allowlist | PASS | two paths explicit; forbidden verbs enumerated. `managent liveness`/`why`/`inbox` are forward refs to verbs that exist or will exist — `liveness` confirmed working at HEAD. The allowlist-as-paths-and-verbs pattern is stronger than "read-only" as an adjective |
| **R4** — cheap fast tier | PASS | the role is defined by cheapness, not by a specific instance |
| **R5** — one invocation, one mode | PASS | prevents trust-blending. Testable |
| **R6** — evidence per finding | PASS | directly addresses the RV2-1 phantom. `unverified` grade + summary exclusion is well-specified |
| **R7** — append-only log | PASS | one finding per line, fixed field order, machine-parseable. A3 proves it mechanically |
| **R8** — recomputable summary | PASS | A4 proves it. Denominators required — directly applies standing rules 3 and 6 |
| **R9** — baseline-relative | PASS | prevents perpetual-red. Baselines dated, cite-setting run. See finding S1 below |
| **R10** — registry in git | PASS | durable process knowledge. Correct separation from ephemeral log |
| **R11** — two-citation growth rule | PASS | prevents speculative checklist bloat |
| **R12** — coverage denominator | PASS | "I read 41 of 312 files" is interpretable; "I walked the project" is not. See finding S2 |
| **R13** — prod-driven pacing | PASS | no cron mechanism exists; spec is honest about this |
| **R14** — findings route through Orcha | PASS | Argus proposes, never registers. A6 tests the consumer end |

## 4. Acceptance criteria audit

| criterion | verdict | note |
|---|---|---|
| **A1** — known-bad calibration | PASS | three seeds, three violations, no slug flips. Sharp. M4 must design the scratch-copy mechanism |
| **A2** — mode-1 phantom rate | PASS | adjudicated by different seat. See finding S2 below |
| **A3** — append-only proved | PASS | exact byte prefix test is unambiguous |
| **A4** — summary reconciles | PASS | recomputation by independent seat is the right proof |
| **A5** — read-only proved | PASS | See finding S1 below |
| **A6** — consumer-load test | PASS | directly from sprint.md @ 45deb10:236-239. Tests the routing, not just the output |
| **A7** — cost reported | PASS | sensible: measure first, decide later |

## 5. Module decomposition audit

M1→M4 sequencing is sound. M2 blocks M3/M4 correctly — two agents improvising a
log grammar is the EXP-4→EXP-7 shape. The concurrency declarations (M1 ∥ M2)
are correct: M1 writes a new file (ARGUS.md), M2 writes under docs/infra/argus/.
No file conflict.

## 6. Commit-pinned line references — verification

Every `@ 45deb10` reference checked against `git show 45deb10:<path>`:

| reference | expected content | match |
|---|---|---|
| `sprint.md:44-48` | "whether a sprint needs external approval beyond the human is declared in spec.md" | ✓ |
| `sprint.md:147` | Spec audit = "Document review, fresh session" | ✓ |
| `sprint.md:216-217` | RV2-1 phantom rule — "cite file+line verified against current text" | ✓ |
| `sprint.md:236-239` | "The consumer-load test is non-negotiable" | ✓ |
| `ORCHESTRATOR.md:14,16` | cadence steps 2 (audit) and 4 (claimlint) | ✓ |
| `ORCHESTRATOR.md:17` | "A finding merely mentioned is a finding lost" | ✓ |
| `ORCHESTRATOR.md:28` | "git clean -x deletes it" | ✓ |
| `AUDITOR.md:27` | "cite those, don't re-derive them" | ✓ |
| `AUDITOR.md:1-31` | invocation, scope param, principles | ✓ (reasonable scope for "claim semantics") |

All line references resolve to the cited content. No phantom citations.

## 7. Baseline verification at HEAD

The spec's baselines were measured at `45deb10`. Verified at HEAD (0af7c3a):

| slug | baseline @ 45deb10 | HEAD | drift? |
|---|---|---|---|
| `claimlint-green` | C1a 10, C1b 0, C2 13, C6 0, cal PASS | 10, 0, 13, 0, PASS | none |
| `stale-in-progress` | 0 in_progress | 0 in_progress (`managent liveness` confirms) | none |
| `orphan-gate` | clean, exit 0 | clean, exit 0 | none |
| `ephemera-creep` | 494 MB, two >10 MB (both 246 MB) | 494 MB, two 246 MB (+ two tiny .wzo: 518B, 4.3K) | none |

No baseline drift. The spec's numbers are current.

## 8. Findings

### should

| id | grade | what | where |
|---|---|---|---|
| **S1** | should | **A5 mechanical test and gitignored paths.** `git status --porcelain` suppresses gitignored files. Since `untracked/` is in `.gitignore`, writes to the two allowlisted paths (`untracked/watchdog.md`, `untracked/watchdog-summary.md`) are invisible to the test, as are writes to any disallowed gitignored path. The test CAN catch modifications to tracked files and new files outside gitignored directories — but the most likely read-only violation (writing to a third gitignored path) passes undetected. M4 should supplement with a mechanism that snapshots `untracked/` before the run and diffs after (e.g., `find untracked/ -newer <marker> -type f`). The spec's criterion ("no new untracked path other than the two allowlisted files") is correct; the `git status --porcelain` suggestion doesn't implement it fully for gitignored paths. | §5 A5 |
| **S2** | should | **A2 single-sweep gate.** The decision rule ">half phantom → descope mode 1" is gated on one sweep's phantom rate. Spec §9 question 2 acknowledges the small-sample risk. A two-sweep minimum, or routing sweep output as *questions to Orcha* as the default (not the fallback) for pass0, would reduce the chance of a noisy sweep killing mode 1 or letting through a misleading one. Not blocking — the spec's self-awareness here is good, and the gate is reversible in pass1. | §5 A2, §9 q2 |

### could

| id | grade | what | where |
|---|---|---|---|
| **C1** | could | **File size vs. runtime memory.** §1 says the two 4×4 .wzo files are "246 MB each" (matches `ls -lh`: 246M). §4 says "The 4×4 loads are 258 MB each." If the 258 MB is runtime/decompressed size vs. 246 MB on disk, the spec should say so. If it's a typo, fix the number. Either way the discrepancy is confusing. | §1, §4 |
| **C2** | could | **Log growth.** R7's append-only log with ~10-minute cadence grows without bound. Not a pass0 concern (hours/days of operation), but the spec should note the rotation/gc question for pass1. | §3 R7 |
| **C3** | could | **Five seed slugs — coverage.** The spec's §9 question 4 asks whether these slugs cover the actual recurring issues or only the easy-to-mechanize ones. The question is well-posed and the answer is left for the human gate. Not a defect — the spec correctly defers this. | §9 q4 |

## 9. The spec's own questions (§9), answered

1. **§7.1 — untracked log.** Sufficient for pass0. The promotion rule (Orcha promotes findings into `docs/` when a slug establishes a process defect) is the right pattern. Losing the log to `git clean -x` costs pattern resolution (the "14 in a week" signal), not knowledge (the registry survives in git). The risk is real — if `git clean -x` runs mid-milestone, the log resets. Mitigation: `ORCHESTRATOR.md @ 45deb10:28` already warns Orcha about this, and the registry carries `first-seen` and `last-violation-date` per slug as a lossy backup.

2. **A2 — single-sweep gate.** Addressed in finding S2. The gate is coarse but correctible in pass1. The spec's acknowledgment of the risk in §9 is honest.

3. **R9 — baseline ratchet.** The spec says baselines are dated and cite the run that set them. This implies downward adjustment is possible (a new run sets a new baseline). The mechanism is: when an issue is fixed, the next Argus run records a new, lower value; the operator (human/Orcha) ratifies the new baseline. The spec doesn't need to prescribe the exact procedure — R9's "dated and cite the run" is sufficient, and the design phase can define the re-baselining trigger. The one-way-ratchet concern is real in practice (nobody remembers to re-baseline after a fix), but that's an operational discipline issue, not a spec gap.

4. **§4 — slug coverage.** The five slugs cover: claim integrity (`claimlint-green`), task liveness (`stale-in-progress`), artifact health (`artifact-loadable`), kanban consistency (`orphan-gate`), and storage hygiene (`ephemera-creep`). What's missing: model-performance drift (are cheap models regressing?), CLAIMS.md status staleness (CLAIMED rows that have been CLAIMED for months), and cross-document inconsistency (two docs saying different things about the same claim — the C6 check catches cite-tags in PROGRESS.md but not broader drift). These are legitimate pass1 additions, not pass0 omissions. The spec's R11 (two-citation growth rule) ensures they'll be added if they recur.

5. **R2/R12 — advisory under pressure.** The spec is correct to be silent. When Argus is right and the agent proceeds anyway, the finding is in the log and the summary; Orcha's cadence step 5 ("register what the turn revealed") picks it up. If the agent ignores Argus AND Orcha doesn't register, that's an Orcha defect, not an Argus one. The routing already exists.

6. **R12 — coverage denominator honesty.** "I read 41 of 312 files under `docs/`" is honest and falsifiable. The risk is that a cheap model miscounts files — but miscounting the denominator is itself a verifiable claim (any reader can `find docs/ -type f | wc -l`). A wrong denominator is less dangerous than no denominator.

7. **Tier B — wasted attention.** Wasted attention is NOT cheap in this project (the human is the dispatch mechanism), but the spec's argument is that Tier B is appropriate because (a) Argus cannot corrupt the register or kanban, (b) the A2 phantom-rate gate descopes mode 1 if the cheap model can't do judgment work, and (c) A6's consumer-load test ensures output is actionable before the human ever sees it. The combination of gates is stronger than any tier label. Tier B is correct.

## 10. Verdict

**PASS** — no blocker, critical, or must findings.

The spec is coherent, correctly cited, honest about its risks (§1.1, §8, §9),
and a faithful refinement of msg 067. The two should-level findings (S1:
gitignored-path detection for A5, S2: single-sweep phantom gate) are design-phase
concerns that M2/M4 can resolve without changing the spec. The could-level
findings are minor.

Recommended disposition: accept the spec as-is; carry S1 and S2 into
`strategy.md` as items for the design phase to address. The spec is ready for
the human gate (G1 per §7.1: the untracked-log decision).
