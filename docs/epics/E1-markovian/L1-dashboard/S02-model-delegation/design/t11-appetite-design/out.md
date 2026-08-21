Design complete — grounded in `goldilocks.md` (tier defs), `model-task-matrix.md` (the current dispatch policy + measured cells), `model-perf.md` (the legacy prose to archive), and the roster/epoch rules in `grand-race.md`. Nothing edited, per the brief.

---

# Model-delegation economics — design

**Source of truth:** operator inputs dated 2026-08-21 (appetite + token constraints + task-type history). Where they disagree with existing files, the operator wins.

## 1. Appetite config

**Levels (a total order the dispatch decision consults):** `OFF` < `PROBE` < `CONSERVE` < `SPEND` < `RESERVED`. Appetite answers *"may this family spend on (a) races vs (b) real execution, given budget state?"* Reservations are hard constraints that override appetite.

### Human-readable table (the authority)

| family | appetite | budget state (as_of 2026-08-21) | race spend | execution spend | reservations (hard) |
|---|---|---|---|---|---|
| ollama-cloud (glm / minimax / kimi) | **OFF** → **SPEND** | 0 tokens, ~48h ±24h; "many next week" | no | no | auto-rejoin as a *delta epoch* on refresh; never aggregate across the gap |
| claude (opus / sonnet / haiku) | **CONSERVE** | weekly ≈70% used | only with explicit override (`WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1` already exists) | only where no non-Claude qualified lane exists | 5h rolling window: never start a task whose estimated wall exceeds remaining window; no eager batching (mid-task block is catastrophic) |
| claude-fable | **RESERVED** | inherits claude weekly; plan ≤200k, handover before 90% | upper-tier only (vs dspro/opus) | only when task_type ∈ reserved set | reserved_for = {deep holistic review, gate-holder verification, spec/design adjudication}; same-day availability; never one-off/general |
| deepseek (dspro / flash) | **SPEND** | generous; no ceiling recorded | yes | yes | soft burn-rate guard only — "do not abuse the generous budget" |
| local (qwen / gemma) | **PROBE** | no credits; costs the machine | exploration-first only | probe-flagged rows only (small in/out, no deadline) | never during a measured suite run (load contamination) |

### Machine-readable (optional, proposed `docs/infra/delegation/appetite.yaml`)

```yaml
version: 1
as_of: 2026-08-21
levels: [OFF, PROBE, CONSERVE, SPEND, RESERVED]
families:
  ollama-cloud:  {appetite: OFF, refresh: "~2026-08-23 (48h ±24h)", then: SPEND, race: false, exec: false}
  claude:        {appetite: CONSERVE, weekly_used_pct: 70, weekly_ceiling_pct: 85,
                  hard_block: "5h-rolling: wall-est <= remaining window; no eager batching",
                  race: override-only, exec: "no-cheaper-qualified-lane"}
  claude-fable:  {appetite: RESERVED, reserved_for: [holistic-review, gate-verification, spec-adjudication],
                  same_day: true, race: upper-tier-only}
  deepseek:      {appetite: SPEND, guardrail: soft-burn-rate, race: true, exec: true}
  local:         {appetite: PROBE, hard_block: "never during measured suite run", race: exploration-only}
```

### Consult rule (decision function)

```
allow(task_type, model, is_race):
  f = family(model)
  OFF      -> reject ("zero spend until {refresh}")
  PROBE    -> allow iff row.probe_flag and not is_race
  RESERVED -> allow iff task_type in f.reserved_for and headroom_ok(f) and not is_race
  CONSERVE -> allow iff weekly_used_pct < f.ceiling and (not is_race or f.race_override)
  SPEND    -> allow iff not burn_spike(f)
```

`OFF`→`SPEND` for ollama is a **human flip** on refresh, never a calendar auto-trust — the 48h window is ±24h fuzzy.

## 2. Model-task-metric matrix schema

**Taxonomy = the operator's 8 types** (canonical for measurement; the old `T-A…T-H` labels migrate per §3). `share` is today's dispatch weight; it tells the appetite config which cells matter (audit+infra+battery = 67%).

| task_type | share |
|---|---|
| audit (audit/verification) | 27% |
| infra (infra/tooling) | 22% |
| battery (mutation/verify-battery) | 18% |
| implement (implementation-bounded) | 11% |
| orchestration (orchestration-seat) | 8% |
| integration (integration/reframe) | 6% |
| research (research/census) | 4% |
| spec (spec/design) | 3% |

*(Operator intent: shift energy into `spec`, currently 3%, to cut later debug/refactor. The tier report surfaces `spec` as an under-measured, high-leverage cell.)*

### Record schema (one JSONL row per measured instance; `docs/infra/model-task-metrics.jsonl`)

| field | type | purpose |
|---|---|---|
| `task_type` | enum[8] | row key (operator taxonomy) |
| `model` | canonical label | cell key |
| `serving_tag` | string | where it differs (silent-swap guard) |
| `epoch` | date | roster epoch; **never aggregate across it** |
| `run_id` / `task_id` | string | traceability to evidence |
| `n` | int | instances graded in this record |
| `correctness` | number | raw rubric score (T447-style) |
| `rubric_max` | number | rubric ceiling, for normalization |
| `qualified` | bool | `correctness ≥ threshold` for that task_type |
| `actionable` | bool | output changed a decision/fix |
| `cost` | {tokens \| usd} | feeds the cost ladder |
| `wall_s` / `cpu_s` / `rss_mb` | number | runner trailer (optional, measured) |
| `grader` | canonical label | grader identity (G3: grader≠lane confound) |
| `blind` | bool | grader blinded to model |
| `evidence` | path | git-committed run doc |
| `as_of` | date | record date |

### Goldilocks tier computation (per goldilocks.md: correctness, actionability, cost)

Computed per **task_type × epoch** by a consolidation step, not stored per row:

```
sort models by cost asc
for each model m with qualified=true:
  c = cheapest qualified model strictly cheaper than m
  no c              -> just-right
  actionable_delta(m, c) in {none, marginal} -> overqualified   # same result, more cost
  actionable_delta(m, c) == material          -> just-right     # extra capability buys something
qualified=false -> underqualified                              # wrong or inadequate
```

`actionable_delta` = does m's output *change the decision/fix more* than c's. A cell with `n=0` is **unmeasured** — per model-task-matrix policy, an empty cell is a reason to *dispatch*, and the tier report labels it `unmeasured` rather than guessing.

## 3. model-perf.md restructure

**Archive** (`docs/infra/archive/model-perf-2026-08-21.md`): the ~4,100-line prose impression log — the belief-audit Class A/B/C narrative, dated anecdotes, Boss-era notes. Header stamped `ARCHIVED; impressions, not measurements; not evidence of ranking`.

**Keep / extract** (still-canonical, non-impression content):
- context-window table (model × harness) → `docs/infra/model-registry.md`
- label-normalization + serving-tag/epoch rules → `docs/infra/model-registry.md`
- measured race results (T447 blind scores, T371, T451–T453 verdicts) → seed rows in the JSONL matrix

**New structure:**

| file | role |
|---|---|
| `docs/infra/delegation/appetite.md` (+ `.yaml`) | deliverable 1 — the budget authority |
| `docs/infra/model-task-metrics.jsonl` | deliverable 2 — structured records |
| `docs/infra/model-tiers.md` | **generated** goldilocks tier report per task type (carries n, epoch, confidence); the "insight-discoverable" surface |
| `docs/infra/model-registry.md` | canonical labels, serving tags, epochs, context windows |
| `docs/infra/model-perf.md` | thin pointer/index (see below) |

**Migration order:**
1. Copy legacy prose to archive path; commit.
2. Seed JSONL from measured cells (`model-task-matrix.md` §2/§3b, T447, T371), re-keyed onto the operator taxonomy via this map: `T-A,T-C,T-F→audit` · `T-D→infra` · `T-B→implement` · `T-H→orchestration` · `T-G→research` · `T-E→spec` · reframe sprints→`integration` · battery runs→`battery`. Re-key by reading the row, never by label alone.
3. Extract context windows + label rules → registry.
4. Write appetite config from §1 (operator inputs).
5. Replace `model-perf.md` body with a pointer to the five files — **the old path stays live** so existing citations don't dangle (claimlint C2).
6. Retire the 2026-08-18 "cost stance" section — superseded by the appetite config.
7. Gate: run claimlint; no citation may point into the archive prose.

---

**Headline:** Designed the model-delegation economics — an appetite config per model family, a (task-type × model) metric schema that computes goldilocks tiers, and an archive/migrate plan for the legacy `model-perf.md`.

**Status:** success (design-only, nothing edited, as instructed).

**What you'd want to know:** the operator's 8-type taxonomy is adopted as canonical for measurement and the old `T-A…T-H` labels get a migration map, not a forced equivalence; the goldilocks "over/just-right/under" verdict is a *consolidation over a cost ladder per task type*, so it only becomes computable once a cell has ≥2 qualified models at different cost — unmeasured cells stay "dispatch now." One surprise worth flagging: a profiles tool already refuses to aggregate across roster epochs (`grand-race.md`), so the matrix must carry `epoch` per record or it will silently poison the very tiers this design computes.

**Possible follow-up:** if you ratify, the natural next task is a small `managent profiles` subcommand that reads the JSONL and emits `model-tiers.md` mechanically — that closes the "profiles are folklore" hole with a tool, not a document.
