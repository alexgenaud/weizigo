# Model registry — canonical labels, serving tags, epochs, context windows

**Created:** 2026-08-21 · **Extracted from:** `docs/infra/archive/model-perf-2026-08-21.md` (the
archived prose log) by T565, per `measurement-methodology.md` §8. The archive is the history;
this file is the canonical fact surface. **Status: live.** Claims: none — facts, not register
claims.

## Canonical labels (single source: `bin/managent models`)

`managent models` is the T317 single source for the canonical label list
(`src/managent/main.zig` `canonical_models`). As of 2026-08-23:

```
claude-opus-5 · claude-sonnet-5 · claude-fable-5 · claude-haiku-4-5-20251001
deepseek-v4-pro · deepseek-v4-flash
glm-5.2 · minimax-m3 · kimi-k2.7
qwen3.8:27b-mlx
ox-alpha
```

**Rule (T276, 2026-08-02, human ruling):** model spellings in records use the canonical
labels. The model part of worker identifiers spells the model exactly one way
(`deepseek-v4-pro/2B-3-AUDIT`, never `DSPro/2B-3-AUDIT`). A record spelling a model four
ways is the defect this rule exists to remove. Short names (`dsflash`, `dspro`, `opus`, …)
are **presentation only** — valid in prose *now*, no version meaning; a record (kanban,
ledger, findings) must write the canonical label **and the date**, never a short name alone.

## Short names → canonical (operator rulings 2026-08-19 and 2026-08-23; model-task-matrix.md §0)

T739 (2026-08-23) renamed the flash short name `flash` → `dsflash` and added `oxalpha`; the
canonical labels are unchanged. This table is the ONE short-name mapping — human surfaces
render through it and hold no second copy.

| short | canonical label | serving tag where it differs |
|---|---|---|
| `opus` | `claude-opus-5` | — |
| `fable` | `claude-fable-5` | — |
| `sonnet` | `claude-sonnet-5` | — |
| `haiku` | `claude-haiku-4-5-20251001` | — |
| `dspro` | `deepseek-v4-pro` | — |
| `dsflash` | `deepseek-v4-flash` | — |
| `glm` | `glm-5.2` | `glm-5.2:cloud` |
| `minimax` | `minimax-m3` | `minimax-m3:cloud` |
| `kimi` | `kimi-k2.7` | `kimi-k2.7-code:cloud` |
| `qwen` | `qwen3.8:27b-mlx` | local (MLX) |
| `oxalpha` | `ox-alpha` | `stealth/ox-alpha` |

Distinct short names are needed only when two models with confusable names run at the
same time.

## Serving tags — what to dispatch with (measured 2026-08-18 evening; re-probed after Ollama 0.32.14)

From the serving-tag probe (claude-opus-5/orcha), one `ollama run <tag> "say ready"` per tag:

| tag | result | dispatch use |
|---|---|---|
| `glm-5.2:cloud` | answers | the glm tag |
| `minimax-m3:cloud` | answers | the minimax tag |
| `kimi-k2.7:cloud` | **`Error: model 'kimi-k2.7' not found`** | do NOT dispatch |
| `kimi-k2.7-code:cloud` | answers | **the kimi tag today** (both tags map to canonical `kimi-k2.7`) |
| `kimi-k2-thinking:cloud` | `retired at 2026-06-16` (vendor) | dead |
| `qwen3.8:27b-mlx` | local, 18 GB MLX | the local qwen tag (`qwen3.8` in the pi/Ollama path) |
| `stealth/ox-alpha` | answers (operator-verified headless, 2026-08-23) | the ox-alpha tag — serving tag only, never stored (canonical `ox-alpha`) |

`bin/subagent --provider ollama --model kimi-k2.7-code:cloud` is the working kimi
invocation. Claude lanes need `WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1` (authorized per
grand-race.md §2).

## Stealth model — ox-alpha (T732, 2026-08-23)

- **label:** `ox-alpha` · **family:** UNKNOWN (identity sealed) · **provider:** openrouter ·
  **harness:** pi (headless `pi --provider openrouter --model stealth/ox-alpha -p …`)
- **serving tag:** `stealth/ox-alpha` — a serving tag only; it never reaches the ledger
  (records store the canonical label `ox-alpha`).
- **appetite:** **SPEND — corrected 2026-08-23 (T746).** The earlier `RESERVED` entry recorded a
  reservation the operator never made; his instruction was *"use oxalpha liberally"* and
  *"compare Opus, Sonnet, DSPro and Flash to oxalpha to get a sense of its strengths and
  weaknesses and where it lands on a ladder for our most frequent and important task types
  and phases."* The mislabel was load-bearing, not cosmetic: `bin/managent assign --dry-run`
  excluded ox-alpha from **every** mechanized pick with the reason
  `ox-alpha: family ox-alpha appetite RESERVED (reserved task types only)` — i.e. the record
  blocked the exact comparison it was supposed to serve.
  **Landed 2026-08-23** (seed commit `2ec4f93`): `src/managent/main.zig:322` now reads
  `.{ .family = "ox-alpha", .appetite = .spend }`, so mechanized picks can draw ox-alpha.
  The earlier note here saying the one-liner was still owed is superseded by that commit.
- **scope:** read-only advisor (T745, 2026-08-23) — a *scope* limit, not an appetite limit.
  Dispatch it liberally on read-only work; audit (27% of volume) and spec/design review are
  exactly that shape, so the scope limit costs almost nothing in placement coverage.
- **epoch note:** identity sealed; on reveal, relabel and re-key statistics via an in-place
  epoch-boundary note (the model-perf format convention). Same name across two epochs is
  suspicious, not disproven — the label is an epoch-dependent pointer until the reveal.
  **Ruling (T746, 2026-08-23): the reveal is a RELABEL, not an epoch bump.** Learning a
  model's name is not evidence its weights changed, so measured cells survive the reveal
  under the new label. If the reveal *also* discloses a version change, that is an epoch bump
  and those cells are labelled and uncounted — the two are separate questions and must be
  recorded separately on the day.
- **token capture:** ox-alpha is dispatched as raw `pi --provider openrouter --model
  stealth/ox-alpha -p …`, which the operator confirms works and which may be the *better*
  API-key pattern (2026-08-23). It bypasses `tools/runner`'s `--session` meter, so all five
  ox-alpha lanes were first recorded UNKNOWN. They are **not** unattributable: the cwd-slug
  session scan in `tools/token-capture.py` recovers every one of them, and
  `tools/token-backfill.py` (T746) appended the readings — T735 ×2, T744, T745, T754, all
  five corroborated against an independent run record where one exists. The durable fix is
  the runner falling back to that scan; the invocation pattern stays.

## Epoch rules (measurement-methodology.md §2; grand-race.md §2)

- The epoch stays **roster-wide**, bumped on a monthly/weekly cadence and whenever we KNOW a
  new model, version, or silent update landed. The DeepSeek 2026-08-18 boundary is the last
  known bump: **every deepseek-v4-* observation before 2026-08-18 describes the pre-bump
  models**; the canonical labels are unchanged, but the label is now an epoch-dependent
  pointer.
- Every record carries `serving_tag` + `as_of`. **Never aggregate across an epoch boundary.**
  A cross-epoch comparison is labelled and uncounted.
- Same name across two epochs is **suspicious, not disproven**. Absence of an assertion is
  UNKNOWN. Flash is on a "preview state" per the operator (reported 2026-08-05); the label
  does not pin the model across dates — a head-to-head run must record the exact serving tag
  and date.
- Rejected as premature: an automatic silent-swap detector.

## Context windows (model × harness) — consolidated 2026-08-03, canonical

The window is a property of the **model × harness pair**, not the model: Ollama's effective
window is the serving config, and the pi harness caps differ from Claude Code. **Record only
measured or harness-reported values — never a model's self-report** (asked what they are, 2/2
models were wrong; a self-reported window is the same class of evidence).

| model | harness | context window | source |
|---|---|---|---|
| `deepseek-v4-pro` | pi | 1 M | human ruling 2026-08-03; matches "New Boss … 1.0M" |
| `deepseek-v4-flash` | pi | 1.0 M | console readout relayed by operator 2026-08-05 during T365 (`3.1%/1.0M`); harness-reported, admissible |
| `glm-5.2` | pi | 1 M | human ruling 2026-08-03 — supersedes the 950 k prose entry |
| `minimax-m3` | pi | 524 k | human ruling 2026-08-03 |
| `kimi-k2.7` | pi | 262 k | human ruling 2026-08-03 — supersedes the ~556 k prose entry |
| `kimi-k3` | Ollama / pi | 128 k | EXP-11 entry |
| `claude-opus-5` | Claude Code | 1 M | human ruling 2026-08-03; matches the handover-at-64%-of-1M evidence |
| `claude-fable-5` | Claude Code | **plan against 200 k** (1 M observed) | operator read the harness indicator 2026-08-04: window reached 1 M mid-session. The 200 k planning figure is a **cost** boundary, not a capacity one |

Fill a TBD only from the harness config or a human ruling, and date it.

**`claude-fable-5` window observation, 2026-08-04 — corrected attribution.** The **human**
read the harness's context indicator directly and reported it jumping mid-session from
96%-of-200 k to 20.4%-of-1 M. That is a **harness reading by the operator**, which this table
accepts — not a model self-report. An earlier revision wrongly attributed the observation to
the Fable seat itself; that was the Orchestrator's error, corrected in the archive.

**Operating rule for `claude-fable-5` (human directive, 2026-08-04) — binding.** Hand a Fable
seat over **before 90% of 200 k**, and use Fable **sparingly** in any case: a different billing
regime is believed to apply below 200 k versus 200 k–1 M (not officially confirmed; recorded as
the human's operating assumption, not fact — but the rule stands regardless, because the cost
boundary and the window are different questions). Practical consequence for dispatch: Fable is
for work whose *value per token* is highest — deep holistic review, gate-holder verification of
a fleet-critical control — never for cheap audits and never for long-running orchestration.

## Model versions — recorded changes

- **deepseek-v4-flash — preview-channel bump, reported 2026-08-05 (operator).** DeepSeek
  updated its models without changing the V4 version string; Flash is reportedly on a "preview
  state" and may be cheaper and stronger than Pro on many tasks. Canonical label unchanged →
  label no longer pins the model across dates.
- **deepseek-v4-pro — new version under the same name, 2026-08-18 (operator report, return
  from absence).** Both DeepSeek models expected to compete with frontier models; Pro is a
  candidate to replace kimi-k2.7-class or Claude-class seats — undetermined until raced.
- **Ollama 0.32.14 update, 2026-08-18 evening** — before it, the three `*:cloud` models did
  not appear in `ollama list`; after it they do. `kimi-k2.7:cloud` still fails, `kimi-k2.7-code:cloud`
  answers.
- **kimi-k3** (worker, frontier; first dispatch EXP-11 2026-07-28) — not the same model as the
  k2.7 line; context window 128 k (via Ollama in the pi harness only). Excluded on cost from
  most races.
- **qwen3.8:27b-mlx** — local 18 GB MLX build, the local probe model. The label `qwen3.8` was
  added to `canonical_models` in `src/managent/main.zig` (T317) once ledger lines named it.
- **glm-5.2 / minimax-m3 / kimi-k2.7** — ollama-cloud family; appetite OFF → SPEND per
  measurement-methodology.md §1 (rejoin is a human flip, ~48 h ±24 h window as of 2026-08-21).

## Legacy labels — do not use

`DSPro`, `GLM`, `Fable`-as-label, `kimi-k2.7-code` as a canonical (it is a serving tag), the
pre-normalization spellings. The 2026-08-18 cost stance ("Ollama-first for leaf rows") is
**retired** — superseded by measurement-methodology.md §1 (the appetite table), per §8 of that
file.
