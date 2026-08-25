# S11 STATUS — the only progress surface

**A phase is complete when its single final document exists in `docs/` and carries a grade here.**
`—` not started · `QUEUED` registered, deliberately not yet dispatched · `ACTIVE` a worker is executing it right now ·
`ARMS` arms landed, ungraded · `GRADED` audited · `ACCEPTED` reconciled, final document written.
Anything short of ACCEPTED is incomplete.

## stream1-design — ideal design, blind to the repository

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T857 | oxalpha | **ARMS** — landed; blindness verified objectively (names no file that exists here) |
| arm B (untracked) | T859 | deepseek-v4-pro | **ARMS** — landed |
| reconciliation | T865 | deepseek-v4-flash | **ACCEPTED** — `stream1-design/design.md` committed, 435 lines, reconciled from both arms; §5 chooses each difference with a reason, §6/§7 carry both arms' costs forward |
| grade | T897 | claude-sonnet-5 | **GRADED** — 2026-08-24, `stream1-design/GRADE.md`, verdict *accepted with amendments* (4, each sentence-scale: N/A-clause ambiguity, missing surface-enumeration procedure, prose-surface inspection gap, +1) |
| **`stream1-design/design.md`** | T865 | dsflash | **ACCEPTED** (document written; grade recorded in the row above) |

## stream2-whatis — what exists, blind to stream1

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T858 | deepseek-v4-pro | **ARMS** — landed, all citations resolve |
| arm B (untracked) | T860 | oxalpha | **ARMS** — landed (27,743 B); closed on evidence by the seat, worker skipped nonce and close |
| arm C (untracked) | T869 | claude-sonnet-5 | **ARMS** — landed 2026-08-24, blind third pass; 9 mechanisms cited, blind spots named; closed on evidence by the seat (worker died before close); **absorbed into whatis.md rev 2 by T896 — 8 new union sites, 1 overlap (R2)** |
| audit of A+B | T866 | glm-5.2 | **ACCEPTED** — `stream2-whatis/whatis.md` committed, 259 lines; every cited `file:line` opened and marked confirmed / misread / drifted / unverifiable; **rev 2 (T896) grows the file to 406 lines with the arm-C absorption** |
| **absorb arm C** | T896 | deepseek-v4-flash | **ACCEPTED** — rev 2 of `whatis.md` committed with every arm-C assertion dispositioned; union recounted with provenance; fourth-pass question answered yes |
| **census, not a 4th arm** | T898 | claude-sonnet-5 | **ACCEPTED** — `stream2-whatis/census-method.md` committed + `tools/emission-census.py` (wired into `zig build test`); denominator: 6,004 emission points in full scope / 1,477 on product surfaces (154/35 files); null + seeded-defect controls PASS; coverage of the 3-arm union: 16.0% (full) / 57.1% (product surfaces); **verdict: no 4th blind arm — classify what is enumerated** |
| grade | — | — | **QUEUED** — no grading row registered yet for the what-is stream |
| **`stream2-whatis/whatis.md`** | T866 + T896 | glm + deepseek-v4-flash | **ACCEPTED** (revision 2, arm C absorbed) — three arms absorbed; seat grading pending |
| **`stream2-whatis/census-method.md`** | T898 | claude-sonnet-5 | **ACCEPTED** — the sprint's denominator; seat grading pending |

## stream2b-green — zero red, honestly

| item | owner | model | state |
|---|---|---|---|
| classification (delete / fix-test / fix-code) | T870 | claude-opus-5 | **ACCEPTED** — committed at `stream2b-green/classification.md`; DELETE 11 / FIX-TEST 21 / FIX-CODE 10 over 88 scripts (denominator corrected from 86); three DELETE verdicts re-verified at source by the seat 2026-08-24 |
| delete wave | T872 | deepseek-v4-pro | **ACCEPTED** — 2026-08-24, all 11 DELETE verdicts executed in 5 commits, **net −488 lines**; superset rule held with one ambient exclusion named; **four evidence-backed corrections to the classification** (below). Was **ACTIVE** — re-dispatched 2026-08-24 evening after the first wall was found too short (one full sweep costs ~20 min; the brief demanded two plus 11 gated commits inside 45 min). Five commits landed. Baseline sweep preserved and reused; see the green-up sweep contract |
| fix-test wave | T873 | — | **QUEUED** — the delete wave has closed; this is next out |
| fix-code wave | T874 | deepseek-v4-flash | **QUEUED** — R5 (cmdAgent use-after-free) landed; R4/R7/V3/V4/V10 queued. Its minimax lane was killed mid-flight 2026-08-25 when Ollama's weekly limit ran out; the row was reopened and unpinned, and re-drew to dsflash. |

## stream3-compare — converges 1 and 2

| item | state |
|---|---|
| **`stream3-compare/comparison.md`** — should-be vs what-is, both directions | — |
| **`stream3-compare/decisions.md`** — keep / adopt / simplify / delete, each with a reason | — |

## stream4-fix — phases of the sprint pass

| phase | final document | state |
|---|---|---|
| phase1-spec | `stream4-fix/phase1-spec/spec.md` | — |
| phase2-research | `stream4-fix/phase2-research/research.md` | — |
| phase3-scope | `stream4-fix/phase3-scope/scope.md` | — |
| phase4-design | `stream4-fix/phase4-design/design.md` | — |
| phase5-pass-plan | `stream4-fix/phase5-pass-plan/plan.md` | — |
| phase6-build | `stream4-fix/phase6-build/build.md` | — |
| phase7-accept | `stream4-fix/phase7-accept/acceptance.md` | — |
| phase8-verify | `stream4-fix/phase8-verify/verify.md` | — |

Phases are used as appropriate; one that turns out to be unnecessary is struck with a reason rather
than left blank forever.

## Gates the seat enforces

- **No stream3 work until stream1 and stream2 are both ACCEPTED.** They must not meet before then.
- **No arm is graded by its own author.**
- **No acceptance test counts until it has been shown red** before the change that makes it green.
- **A pass that breaks a previously-green check is reverted, not argued.**
- **A phase whose final document exists but is ungraded is not progress** — it is a draft in the
  wrong directory.

## Baseline — three-arm union (stream2, T858/T860/T869; reconciled by T866, revised by T896)

Every figure carries a `file:line` citation in the arm, and the authors verified each resolves. The
reconciled numbers live in the stream's single final document, `stream2-whatis/whatis.md`, with their
arm-provenance. **A count from one arm is provisional and is labelled provisional here and in the final
document in the same edit that records it** (the rule the seat broke three times in one session,
2026-08-24).

| # | count | value | found by |
|---|---|---|---|
| 1 | reporting surfaces inventoried | **68** (verb/mode enumeration; arm A's 30 is a behaviour-differs lens, kept in whatis.md §1; arm C contributed no count) | 1 arm (B) — provisional |
| 2 | surfaces emitting a value where the honest answer is "cannot determine" | **≥15** (floor: 6A + 6B + 3C, pairwise disjoint — zero sites found by 2+ arms) | 1 arm each — provisional |
| 3 | checks that cannot fail under any input | **10** (floor: 4A + 4B + 2C, disjoint) + **8** unwired-by-build scripts (B only, a distinct category) | 1 arm each — provisional |
| 4 | places that reinterpret unrecognised input as valid | **9** (floor: R1/R3 A, R4–R8 B, R9 C, and R2 — the unknown-flag drop — found by all three arms) | R2: 3 arms; the other 8: 1 arm each — provisional |
| 5 | jobs with more than one implementation | **14** (floor: 12 single-arm + J1/J6 found by A and B) | 12: 1 arm; 2: 2 arms — provisional |
| 6 | stated blind spots in the method | three arms + the audit all state theirs (A 6, B 7, C 6 in its method statement); the audit's consolidated list is whatis.md §6 | n/a — honesty statements, not defect counts |

Two entries stand out and are recorded here so they are not lost in a long document:

- **A standing trigger that can never fire.** Its condition needs a prior value greater than zero, but
  the state parser drops the key that would hold it, so the prior always reads zero after any other
  store write. It is **self-documented in the source** as unable to fire.
- **`managent done --verdict` silently defaults to `pass`.** An unrecognised flag is dropped, so a close
  that meant to record a qualified verdict records an unqualified one. This is the defect the outgoing
  seat hit on its own close, now located at a line.

## Superseded baseline note

Measured 2026-08-24 by a full sweep of every regression script: **23 of 86 fail**. Three carry the
store-census fixture signature; two prior enumerations of that class were both incomplete. Stream2's
final document must turn this into three counts: surfaces that emit a value where the honest answer is
"cannot determine", checks that cannot fail under any input, and places that reinterpret unrecognised
input as something valid.

## Absorption note — work that predates this plan

`T857` and `T858` were dispatched before this hierarchy existed and declare their outputs under
`docs/status/`. Those outputs are **arms, not final documents.** On close, the seat relocates them to
the untracked arm directory and grades them against the acceptance conditions above rather than the
looser briefs they ran under. Their content is informative; their placement is not the plan.

## Honesty note on this file, 2026-08-24

This surface twice misreported its own state within a single session: it carried the label `RUN`, which
can be read as already-run, running, or to-be-run; and it showed two arms as in-flight after both had
closed. Recorded here rather than quietly corrected, because a progress surface that lies is the exact
defect S11 exists to remove, and the sprint's own status file was an instance of it. **The rule now:
every label states a fact about the present, and the file is corrected at the moment a row closes —
not at the next convenient edit.**

## Correction to the baseline, 2026-08-24

The figure of **6** above was arm A's, recorded by the seat as "the baseline" **before arm B landed**.
Arm B independently also found 6 — and **cites a completely disjoint set of sites.** So the floor is
**at least 12**, and two independent passes finding non-overlapping halves is evidence a third would find
more. Arm B additionally found a class arm A missed entirely: **8 checks wired to no gate**, which can
fail but for nobody who would notice.

Recorded plainly because it is the third time in one session this seat reported a number as settled
before it was: the ambiguous `RUN` label, the two stale arm rows, and now this. **The rule that follows
and binds the seat: a count from one source is provisional until a second source corroborates it, and it
must be labelled provisional in the same edit that records it.**

## Correction to the baseline, 2026-08-24 (arm C landed)

The prediction in the first correction — "two independent passes finding non-overlapping halves is
evidence a third would find more" — was **confirmed by arm C (T869, claude-sonnet-5)**. Arm C found 9
mechanisms; 8 were new to the union, and its single overlap was R2, the one mechanism A and B already
shared. The union is now **≥15 dishonest surfaces / 10 cannot-fail checks / 9 reinterpretation sites /
14 shared jobs**, and **45 of the 48 distinct sites were found by exactly one arm** (whatis.md §9).
Arm C's method rotation (anti-pattern grep) found things the entrypoint-driven passes missed, so a
fourth pass **is** warranted — scoped to the named blind spots (engine-side tooling, full shell reads,
live reproduction of the `could`-grade argus findings), not another general census.

## Stream status as the seat reads it, 2026-08-24 evening

Answering the operator's question directly, in his own stream names:

| stream | his name | where it actually is |
|---|---|---|
| stream1-design | **ideal** | **document done, grade owed.** `design.md` is committed and reconciled from both blind arms. Nobody has graded it. One dispatch from ACCEPTED-and-graded. |
| stream2-whatis | **whatis-1** | **document done at rev 1, known incomplete.** It audits two of three arms; the third (sonnet, blind) is being absorbed now by T896. Grade owed after that. |
| stream2b-green | **green-tests-and-simplify** | **running.** Classification ACCEPTED. Delete wave T872 active, five commits in. Fix-test T873 and fix-code T874 queued behind it, serial, seat-enforced. |
| — | **whatis-2** | **not started, not registered.** It is the round-2 re-measurement that reads the green-up's change-log; it cannot begin until the three waves close, which is why the change-log is an acceptance condition of each wave. |
| stream3 + stream4 | **reconciliation-fix** | **not started, correctly.** Gated: no stream3 work until stream1 and stream2 are both ACCEPTED, and neither is graded yet. |

**The honest summary: the two analysis streams are each one grading dispatch from done, and have
been for a day.** The bottleneck is not the models and is not the work — it is that nobody
dispatched the grades. That is a seat failure, recorded here rather than in a conversation.

**This file was wrong again when the operator asked.** It showed both final documents as `—` (not
started) while both were committed and had been for a day, and it showed grades as "awaiting
dispatch" without anyone owning that dispatch. That is the third time this surface has misreported
its own state, in a sprint whose entire purpose is that surfaces should not do that. The rule
already written above — *every label states a fact about the present, and the file is corrected at
the moment a row closes* — was not followed, because nothing enforces it. **A row to make the
sprint surface derive its state rather than remember it is owed and not yet written.**

## The delete wave's four corrections to the classification, 2026-08-24

The brief invited override with evidence — *"a classification is a decision, not a fact"* — and the
wave used it four times. These are recorded here because they change later waves' work:

1. **V2 was wrong, and correcting it prevented fabricated debt.** The classification said battery
   I11 (move-set consistency) was *"genuinely uncovered"* and that a claims-register row was owed
   for the gap. It is not uncovered: `src/vb_i11.zig` already covers battery-vs-solver move-set
   agreement with null and seeded-defect controls, exhaustive to 4×3 plus a 50k 4×4 sample, and is
   wired into `zig build test`. Deleting the stub revealed **no** gap. **No claims-register row is
   owed** — had the wave followed the classification, we would have registered a debt that does not
   exist.
2. **R25 was incomplete.** `regression-managent-holds.sh` had a second red cause besides the
   deploy-freshness arm. Deleting the arm was still correct; the script stays red for T539's reason.
3. **R27 was not confirmed, and this is the green-up working.** The classification predicted
   `regression-managent-integrity.sh` would pass outright once the deploy arm went. It does not — it
   now fails at arm 3, which **the redundant check had been masking**. Deleting a vacuous check
   *revealed a real failure that was hidden behind it.* That is the whole thesis of this stream,
   demonstrated.
4. **V8 partially:** the `CLAIMLINT_FLOOR` attribute is deliberately kept (doctor and sweep consume
   it), with its stale figure handed forward to a fix-code wave rather than silently corrected.

**On the superset rule:** one script gave two disagreeing readings across the sweep because
`bin/subagent` was being edited by another row mid-run. The wave named the ambient input and
excluded it explicitly rather than quietly, which is what the sweep contract requires. That is a
*third* instance of the ambient-dependence class the contract was written for.
