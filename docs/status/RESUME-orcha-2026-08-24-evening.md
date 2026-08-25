# RESUME — orchestration seat, written 2026-08-24 evening for a Fable seat

Written to be sufficient on its own. The outgoing seat (`claude-opus-5`) stands down to **read-only
advisor and document writer** on committing this: it dispatches nothing, claims nothing, closes nothing.

---

## 1. The existential question, answered honestly

The operator's words, and they are the thing to hold: *"I am in constant shock this week by the
effort-to-result ratio approaching infinity."* And his diagnosis, which is correct: *"the problem with
the tooling is that we are using the same broken tooling to fix the tooling. Wet spaghetti will never fix
an iron hammer and nails."*

**The measured indictment of this seat's day:** +28,761 net lines, **164 files created against one
deleted**, eleven new tools and scripts added to a system whose diagnosis was *too many moving parts*.
Motion without progress.

**The mechanism of the loop, precisely:** every fix accepted today was verified by the instrument it
fixed — except one. The rate column, checked by hand (6465 ÷ 122 = 53.0). That is the only fix worth
staking anything on. The store guard was audited with its own tests and was breaking three others. The
compliance check verified itself by reading its own prompt back. The progress file reporting on the work
lied twice while reporting on the work that was fixing lying reports.

**The rule that follows, and it binds the seat first: no instrument's repair is accepted on that
instrument's own testimony.** Hand-verified or independently cross-checked, or it does not count.

## 2. What is genuinely fixed, and how it was verified

Trust these only because the verification method is stated; re-check anything you rely on.

| fixed | verification |
|---|---|
| commit gate refused ~2 of every 3 commits (SIGPIPE inverting a passing check) | red 2-of-3, green 10-of-10, seeded-defect control proving the new idiom is not vacuous |
| repo git identity was a test fixture's — 680 of 1,415 commits misattributed | identity restored; the leak reproduced deliberately against a throwaway repo, then shown prevented |
| the task store could silently shrink (59 tasks once vanished) | census row-count and digest matched the live store exactly; `orient` silent on a healthy store; seeded revert still refuses the write and alarms |
| 40 finished tasks recorded as not-started; four race judgments frozen behind them | closed on a three-signal evidence set; all four races then judged |
| the dashboard rate column read UNKNOWN forever | rendered 53.0/s against hand arithmetic of 6465 ÷ 122 = 53.0; the MAX method it replaced reported 15% of truth |
| `dispatch_verify` could not tell "nonce not echoed" from "work absent" | the winning patch landed verbatim; the incident case is now a pinned arm, shown red before and green after, and shown **red under a flattering patch** |

## 3. What is still broken — floors, not totals

Every figure below came from two independent observers whose findings were **nearly disjoint**, so each
is a floor and a third pass will raise it.

- **23 of 86 regression scripts fail.**
- **12 reporting surfaces** emit a value where the honest answer is "cannot determine" (arm A found 6,
  arm B found 6, **zero overlap**).
- **8 checks cannot fail under any input** (4 and 4, disjoint) — plus **8 scripts wired to no gate**.
- **8 places reinterpret unrecognised input** as valid.
- **12 jobs have more than one implementation.**
- Every load-bearing citation in both arms was opened and verified. They were not contradicting each
  other; each saw half the terrain.

## 4. Two retractions. Do not repeat them.

**`oxalpha` is not unreliable at protocol compliance.** That claim was made three times by this seat
and is withdrawn on two independent grounds: the nonce check **passes on a JSON-mode lane even with an
empty model reply**, because the harness echoes the prompt (which carries the nonce) back to stdout — so
it cannot fail there and falsely accuses elsewhere; and the operator observes explicit upstream `429`
rate-limits from that provider while **our harness records those runs as `exit 0` with no output.** A
provider refusal is currently invisible to our records on `pi` lanes.

**Do not infer model quality from a single empty run.** Two instrument defects produced the same false
accusation against one model. n=1 is not evidence, least of all when the instrument is blind.

## 5. The plan, ratified by the operator

1. **Consolidate the ideal.** Done — both blind designs independently converged on one closed
   three-valued reading type making a false reading unrepresentable. Final document committed.
2. **Audit the what-is** — verify assertions, union rather than average, resolve contradictions four ways
   (A right · B right · both wrong · a third reading better), and extract a **should-be**. Done.
3. **Green-up.** Fix and simplify the actual tooling, eliminate duplicate interfaces, until every test
   passes — accepting the result is far from ideal. **Two conditions:** "all green" is dishonest while
   vacuous checks remain, so every red/vacuous/unwired check is classified **delete / fix-test /
   fix-code** with *delete* expected for anything that cannot fail; and every change to actuality is
   **logged**, or round 2 becomes uninterpretable.
4. **What-is round 2** against the simplified actuality, where real agreement becomes possible.
5. **Merge** the consolidated ideal with the should-be. **Not before** — grading observers against a
   messy actuality measures the mess, exactly as the compliance check measured our harness.

**Deletion before addition.** Today was 164:1 the wrong way. The next stretch must be net-negative lines.
The targets are all deletions and all identified: 32 duplicate scratch-repo scripts, six ways to run
tests, four pause mechanisms, two task stores, the vacuous checks.

## 6. In flight at handover

| row | model | work |
|---|---|---|
| T861 | deepseek-v4-pro | module-test contract: declare and select — **prerequisite for accepting any change** |
| T867 | deepseek-v4-flash | the trusted bootstrap: `tools/facts`, importing nothing, judging nothing |
| T869 | claude-sonnet-5 | blind third what-is pass, testing the disjointness prediction |
| T870 | claude-opus-5 | classify every red/vacuous/unwired check — decides only, changes nothing |

`T863` (eight-model protocol race) is **deliberately blocked**: run under today's invocations it would
measure our harness, not the models.

## 7. Before believing any status

```
bin/managent reap
git rev-parse --show-toplevel          # must be this repo
git config --get core.worktree          # must be unset
git ls-tree -r --name-only HEAD | wc -l # must be > 2000
git show HEAD:.gitignore | wc -l        # must be 46
git log -1 --format=%ae                 # must be alex@genaud.net, not a t*@test fixture
```

Re-verify after every commit. **The fleet keeper is paused deliberately** (one dispatcher; the seat holds
it) — reason and wake condition are in `docs/status/OPEN.md`.

## 8. Caps and standing orders

**At most 2 rows per model, 5 per family, 10 concurrent — with no expectation of approaching them.** The
operator's reason, which governs future changes: parallelism is only a wall-clock optimisation and is
often the source of unnecessary complexity and failure. **The per-model limit of 2 has no implementation**
— the module knows only totals and families — so the seat enforces it by hand.

For important findings and audits, use **one model per family** — one Claude, one DeepSeek, one Ollama,
plus oxalpha when responsive. Family diversity is what separates a property of the problem from a habit
of one provider; the disjoint what-is halves are the proof.

## 9. How to talk to the operator

`docs/infra/discuss.md` governs: **recap in human words, exactly one decision per ask, then stop.** He
tracks nothing between messages. **Never use a structured question widget — he has asked explicitly that
it never be shown to him again.** Do not ask him to choose between abstractions; propose alternatives,
pick one, and argue it. He will likely accept a well-argued recommendation, and he demands you prove to
yourself that you found the best one.

Two things are his alone: **stripping "proven" from 42 claims with no committed evidence**, and a **2–2
tie** between two competing rewrites.

## 10. Specific to a Fable seat

Fable is reserved and expensive, and is believed to have a boundary near 200k. **Hand this seat over
before 90% of that.** Your value here is judgement on direction, not bookkeeping — today's seat performed
~40 evidence-closes and 120 commits, which is grind that would consume your window without using your
strength. So: **rule on the recovery plan, dispatch the next wave, then hand to a fresh Opus** with a
resume written the way this one is.

## 11. The single most useful habit

Every real defect found today surfaced when someone asked *why is that number what it is.* The tooling
surfaced none of them. Where a reading looks fine, compute it by hand once. That is how the rate column
was caught at 15% of truth while looking plausible for weeks.
