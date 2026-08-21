# Measuring models — appetite, the metric matrix, and how scores are compared

**Status:** DESIGN, not ratified. Nothing here is implemented. · **Date:** 2026-08-21 ·
**Authors:** `deepseek-v4-pro`/T556 (t11: appetite config, matrix schema, model-perf restructure) +
`claude-opus-5` (t12: this consolidation, the v2 refinements) ·
**Operator rulings inline, dated — they are the source of truth where anything here disagrees.** ·
**Provenance (untracked, at risk):** `untracked/bakeoff/pass1-overnight/t11-appetite-design/out.md`
and `…/t12-methodology-v2.md`. This file is written to be self-contained; read those only for history.
**Reads on:** `goldilocks.md` (tier definitions), `grand-race.md` §5–§6 (grading controls, ledger
schema), `metric-vocabulary.md` (grader-proposed metrics), `../model-task-matrix.md` (current
dispatch policy + measured cells).

## 0. The governing constraint (operator, 2026-08-21)

> "Be sure that the cure is not more dangerous than the disease. … prepare to massage the data
> later, but do not over-engineer too early, or solve problems we do not yet understand."

Keep it simple. Everything in §4 is deliberately recorded as **vision, not specification** — it is
written down so nobody has to remember it, and so nobody builds it before the data asks for it.

## 1. Appetite — which family may spend, on what

Levels: `OFF` < `PROBE` < `CONSERVE` < `SPEND` < `RESERVED`. Reservations are hard and override
appetite. The table is the authority; a machine-readable mirror is optional and not needed yet.

| family | appetite | budget state (as_of 2026-08-21) | race spend | execution spend | reservations (hard) |
|---|---|---|---|---|---|
| ollama-cloud (glm / minimax / kimi) | **OFF** → **SPEND** | 0 tokens, ~48 h ±24 h; "many next week" | no | no | rejoin is a **human flip**, never a calendar auto-trust (the window is fuzzy) |
| claude (opus / sonnet / haiku) | **CONSERVE** | weekly ≈70 % used | override only | only where no cheaper qualified lane exists | 5 h rolling window: never start a task whose estimated wall exceeds the remaining window; no eager batching |
| claude-fable | **RESERVED** | inherits claude weekly; hand over before 90 % of 200 k | upper tier only | only for reserved task types | deep holistic review · gate-holder verification · spec/design adjudication; same-day availability; never one-off/general |
| deepseek (dspro / flash) | **SPEND** | generous, no recorded ceiling | yes | yes | soft burn-rate guard only |
| local (qwen / gemma) | **PROBE** | no credits, costs the machine | exploration only | probe-flagged rows only | never during a measured suite run (load contamination — the D6/D12/D14 cull) |

Source: operator inputs 2026-08-21 (t11 §Inputs). Task-type shares that tell us which cells matter:
audit 27 % · infra 22 % · battery 18 % · implement 11 % · orchestration 8 % · integration 6 % ·
research 4 % · spec 3 %. **Operator intent: shift energy into `spec`** so less is spent later
debugging — so `spec` is the high-leverage under-measured cell, not a rounding error.

## 2. Epoch — deliberately simple (operator ruling, 2026-08-21)

- The epoch stays **roster-wide** and is bumped on a **monthly or weekly cadence, and whenever we
  KNOW** a new model, version, or silent update landed. That is sufficient.
- Every record carries `serving_tag` + `as_of`. Never aggregate across an epoch boundary
  (`grand-race.md` §2); a cross-epoch comparison is **labelled and uncounted**, the same treatment
  family grades get under G3.
- **Rejected as premature:** an automatic silent-swap detector (a sealed "canary fixture" re-run on a
  cadence to catch a mid-epoch model swap). It solves a problem we have not observed, and a
  detector we would not trust to re-epoch on its own buys nothing a human date does not.
- Same name across two epochs is **suspicious, not disproven**. Absence of an assertion is UNKNOWN.

## 3. The record — store facts, derive numbers at report time

One JSONL row per measured instance (proposed `docs/infra/model-task-metrics.jsonl`). The rule that
matters: **store what was observed; never freeze a derived or normalized number into the record.**
That is what keeps §4's renormalization possible later without a migration.

Observed, per row: `task_type` (the 8 types above) · `model` (canonical label) · `serving_tag` ·
`epoch` · `run_id`/`task_id` · `n` · `score_raw` + `rubric_max` · `cost` (tokens or usd) ·
`wall_s`/`cpu_s`/`rss_mb` · `grader` · `blind` · `evidence` (a committed path) · `as_of`.

Verification, per row (§5): `claims_load_bearing` · `verified` · `unverified` ·
`fabricated_citations` · `unique_catch`.

Anchor, per row: `anchor_id` and the anchor's own `score_raw` **in the same race, same panel, same
rubric** — recorded as a fact, not as a delta.

Derived at report time, never stored: `delta_anchor`, tier, moving averages, any renormalization.

## 4. Comparing scores — vision, deferred

The problem is real and already observed: **a score is relative to the field it competed in.** Sonnet
"good" against Fable and "excellent" against Gemma are not the same reading, and averaging them
inflates Sonnet. The plan, in the order we expect to need it:

1. **Anchor every race** on a small fixed set that appears in every race — `deepseek-v4-flash`
   primary (cheap, SPEND appetite, always available), `claude-sonnet-5` secondary when Claude
   appetite permits. A race with no anchor yields a within-race order and **no matrix cell**.
2. **Renormalize against the anchor mean** — the operator's shape: *the average Flash+Sonnet score,
   per metric, per task type, per race*, as the zero point. Legacy rows get renormalized the same way
   when the anchors' scores for that race are recoverable, and stay uncounted when they are not.
3. **Moving averages** per (model × task_type × metric), so a tier reflects a trend rather than the
   last round. Bounded by the epoch rule: a moving average never spans an epoch boundary.
4. **Ceiling caveat, already measured:** Flash is *not* reliably mid-tier — it scored 4.86/5 ("great")
   in `pass1-spec-r1`, tying the top. An anchor at the ceiling compresses every delta above it. So
   renormalize on **0–10 metric scores with headroom, never the 5-step verdict scale**, and keep a
   rank-distance alongside the score delta, which survives saturation.

None of this is worth building until several anchored races exist. Until then, per-race ordinal
readings plus honest `n` are the whole of the truth we have.

## 5. Verification metrics and the stance on dissent

*Machiavelli, The Prince — "protection against flattery": the counsel worth having is the counsel
that risks contradicting you.* Three asymmetries, and they are the point of the whole section:

1. Position relative to consensus contributes **zero**. Dissent is never itself a penalty.
2. **Verified dissent is the most valuable output there is** — `unique_catch`: a finding no other lane
   produced, which then verified, counted only when verified by someone other than the claimant.
   (Worked example: qwen's `getsid` catch — only qwen found it, and it held.)
3. **Unverified load-bearing claims are penalized whether they agree with consensus or not**, so
   herding earns no shelter. An unverified claim is worse than silence.

`verification_rate` = verified ÷ `claims_load_bearing`. Unchecked and refuted are recorded
**separately** — an unchecked claim is not a verified one.

**A gate before the cost ladder.** Fabrication disqualifies independently of score:

```
qualified(m) = score ≥ threshold(task_type)
               AND fabricated_citations == 0
               AND verification_rate ≥ floor(task_type)
not qualified -> underqualified, regardless of cost or panel praise
```

Then `goldilocks.md`'s cost ladder runs over the qualified set unchanged. This is what made
`pass1-spec-r1`'s haiku verdict mechanical rather than panel opinion — a nonexistent
`tools/console.zig` is checkable, and mechanical anchors outrank panel scores (`grand-race.md` §7).

**Emission gate.** A tier is emitted only when the cell is anchored, has `n ≥ 2`, and holds ≥2
qualified models at different cost. Otherwise print `unmeasured` or `provisional (n=1)` — never a
tier. Under this rule `pass1-spec-r1` seeds cells and emits **no** tiers, which is the honest reading
of its own low-confidence label.

## 6. Metrics carried forward from round 1

- **citation-integrity — promote, and split.** The round's rank-1 discriminator (sd ≈2.3, 5/7
  recurrence). Split into `citation_integrity_mech` (paths/lines that do not exist or do not say what
  was claimed — mechanical, outranks panel) and a panel score for what was left uncited.
- **uncertainty / scoping-honesty — re-propose, do NOT attach.** Highest dispersion (≈2.5) at 2/7
  proposers, i.e. exactly the metric awaiting T553's graduation test: *independent* re-proposal across
  rounds. Attaching `metric-vocabulary.md` to the next grader brief would destroy the independence
  that rule measures. Run round 2 with it unattached.
- **Mechanized correctness gate for `implement`.** Acceptance script authored and sha256-sealed
  *before* dispatch; correctness := gate exit status; panel scores are nuance only.
- **Orchestration close-latency / close-completeness.** Both derivable from the managent ledger:
  `close_latency_s` = row-done → absorbed; `close_completeness` = required done-gate fields present ÷
  required. Defining them now means the seat trial produces numbers, not impressions. The gap here is
  **assignment**, not scoring — most models have zero rows of this type.
- **Token instrumentation — the premise was inverted, and the real fix is smaller.** Measured in the
  B-3 trailers: Claude lanes *do* capture usage (`b3-opus` 1,779,565 in / 20,155 out; `b3-sonnet`
  1,178,188 / 21,406; `b3-haiku` 144,251 / 9,809 — the T521 `--output-format json` envelope parsed at
  `tools/runner:1117`). The lanes reporting *no reading* are **pi/DeepSeek and ollama/local**. So:
  **(a)** wire the retroactive pi-session-JSONL meter into the lane record — it blocks the *cheap*
  families, not the Claude ones; **(b)** split `tokens_in` into fresh vs `cache_read`, which
  `tools/runner:1117` currently sums, so opus's 1.78 M "in" is mostly cache reads priced differently.
  **Until (b) lands, the goldilocks cost ladder is not computable across families.** Highest-leverage
  item on this page.

## 7. Race queue, ordered by appetite rather than eagerness

| # | race | fills | blocker | when |
|---|---|---|---|---|
| 0 | **token instrumentation (a)+(b)** — not a race | makes every cost number comparable | none | **first**; nothing downstream is sound without it |
| 1 | **T447 sealed-key audit replication** — opus/sonnet/fable/haiku | matrix hole #5 (Opus/Fable in read-only audit); needs a **non-Claude grader** to be legitimate | Claude CONSERVE, 4 short lanes | next |
| 2 | **mechanized-acceptance implement race** — opus/sonnet/haiku/glm | matrix hole #1: `implement`/T-B is the commonest row shape with **zero** cells filled | glm OFF ~48 h | when ollama returns |
| 3 | **T554 round 2** — different topic, same 7 lanes | is the fable/dspro tier gap a trait or a one-topic artifact | most expensive; Claude-heavy at ~70 % weekly | when Claude headroom allows; new sealed control pair; vocabulary unattached (§6) |
| 4 | **orchestration-seat trial** — opus/sonnet/haiku/fable/glm | hole #4; the dspro-premium hypothesis | long wall; the 5 h window is the risk, not the weekly | last; sequential, never batched |
| 5 | all 7 lanes on one shared task, uniform token capture | the cost ladder end-to-end | gated on #0 | after #0 and once #1–#3 seed cells |

## 8. `model-perf.md` restructure (t11, unchanged)

Archive the ~4,100-line prose impression log to `docs/infra/archive/model-perf-2026-08-21.md`, stamped
*"impressions, not measurements; not evidence of ranking"*. Extract the still-canonical parts — context
windows, label-normalization, serving-tag/epoch rules — to a `model-registry.md`; seed the JSONL from
the measured cells (`model-task-matrix.md` §2/§3b, T447, T371). Keep `model-perf.md` live as a thin
pointer so existing citations do not dangle (claimlint C2). Re-key the old `T-A…T-H` labels onto the
8 operator types by **reading each row**, never by label alone. Retire the 2026-08-18 cost stance —
§1 supersedes it.

## 9. Ladder findings — and one retraction

**RETRACTED, 2026-08-21 (`findings/T557-b3-verification-review.json`).** OWNER-LOG D27 recorded that
two Claude lanes in the B-3 race "reported verification they could not have performed" under
`--allowedTools Read`. **The premise is false and the finding is withdrawn.** `--allowedTools`
*pre-approves* the named tools; it is not a deny-list (that is `--disallowedTools`), and the lanes ran
in `permissionMode: auto`. The session transcripts
(`~/.claude/projects/<slug>/<session_id>.jsonl`, id in the runner trailer) record **31 executed Bash
calls** for the opus lane and **12** for sonnet. Every opus claim proved true on disk — it built
baseline and patched binaries, neutered SIGKILL as its own seeded instrument, and ran a real
functional A/B. Opus was the field's **best** performer on this axis, not its worst. Do not carry the
retracted version forward; the correction direction matters because this is the
evidence/citation-integrity axis, which §6 names the best discriminator we have.

Standing lesson, cheap and general: **a flag name is not a capability.** The lane transcript is the
capability oracle, and it is on disk for every Claude lane.

## 10. Honest limits

n = 1 per cell today. G3 (grader ≠ family) costs real precision, and in `pass1-spec-r1` the family
effect ran *negative* — family graders were harsher. Blinding was imperfect that round (all six lanes
self-identified; uniform, so it separates nobody, but it is not a clean blind). A harness-killed lane
is a fleet-reliability datum, never a quality datum. And the cost ladder stays uncomputable across
families until §6's token split lands.

## 11. Carry-forward — what the next agent picks up

Nothing here is implemented; this file is the whole handoff.

1. **Ratification owed.** §1 (appetite) and §3 (record shape) are the operator's own inputs written
   down; §4–§7 are proposals. Get §3 and §5's gates ratified before any of it is built — the schema is
   the only part that is expensive to change later.
2. **Build first, and only this:** the token instrumentation fix (§6, item (a)+(b) — `tools/runner`
   and `bin/subagent`). It is not a race, it is cheap, and every cost comparison waits on it.
3. **Do not build yet:** the anchor renormalization, moving averages, and the generated tier report.
   They need several anchored races first (§4). Building them now would be measuring an empty matrix.
4. **Owed by T557 (pass-1 seat), from the B-3 review:**
   a. an OWNER-LOG entry retracting D27's fabrication finding (§9) — D27 itself is a record and stays
      as written; the retraction is a new dated entry, not an edit;
   b. `findings/T557-pass1-phases-8-9.json` repeats the retracted finding in its `notes`. Per
      `findings/README.md` a findings file is **immutable** — do not edit it. The correction is the new
      file, `findings/T557-b3-verification-review.json`;
   c. **the missing B-3 acceptance arm.** `tools/regression-process-ownership.sh` has no arm that
      forces a SIGKILL survivor, so the retry path B-3 just landed is unexercised — a green suite
      proves the old behaviour only. Two real defects were invisible to it and surfaced only under a
      seeded kill-neutering mutation: the sonnet lane's patch reports `killed=0` with four pids
      falsely `vanished`, and the flash lane's patch dies `exit 3` ("freeze did not complete") on its
      first retry round. The owed arm: a claimed member that outlives its SIGKILL, asserting the
      rounds are spent, `killed=` stays honest across rounds, and exit 5.
5. **Race #1 is next** when a seat is free (§7) — and it needs a non-Claude grader to be legitimate.
