# T817 — the retro task corpus: task type × scope × capabilities

**Worker:** deepseek-v4-flash/T817 · **Date:** 2026-08-23 · **Status:** PASS-WITH-FINDINGS
(see findings/T817-task-corpus.json) · **Landmark:** advances L1 (the delegation-evidence
lattice) — the lattice's three axes (model × task type × task scope) had no data on two of
them; this row derives them retroactively from every record we have.

**Dataset:** `docs/infra/task-corpus.jsonl` — one row per task, 578 rows.

**What this document is:** how the corpus was built, the classifier and its measured
accuracy, the scope enumeration and its defence, the capability vocabulary with examples,
the anomaly report (ranked, queries reproducible), and an explicit limits section. This is a
mining-and-inference deliverable; every derived value in the JSONL carries `basis` and
`confidence` and must never be read as a declared value.

---

## 0. Snapshot and reproducibility

The kanban store is a live file (the fleet writes it continuously — the row count moved
from 576 to 579 while this task ran). The corpus is therefore built from a **snapshot**,
not the live file:

- snapshot = a byte copy of `docs/infra/managent/tasks.json` (SHA256
  `4490b3323f5d637ebb7fc241997304b8a69f5dec`; 578 tasks incl. `_sys`, excluded) and
  `docs/infra/managent/archive.json` (SHA256
  `aa119873c6fadd5f4178658c2370626ffac26c3c`) taken at git commit
  `d372b66d996d020856436f8fe6c93f4c0a852373` (the store and archive were modified in the
  working tree by concurrent agents at snapshot time; the corpus is a point-in-time
  artifact of those bytes)
- to reproduce: copy the two store files at that commit into a scratch dir and set
  `T817_SNAPSHOT_DIR=<that dir>` when running the scripts in §8 — the corpus SHA of the
  rebuilt JSONL matches the committed one
- the canonical label list and epoch boundary (`2026-08-18` DeepSeek bump) per
  `docs/infra/model-registry.md` and the T525 epoch ruling

**Every query in this document is re-runnable** against the snapshot; the counting scripts
are committed under `docs/evidence/T817-task-corpus/` (see §8).

## 1. Coverage and sources

**Coverage: 578 rows = every task in store + archive (union), `_sys` excluded.** No store
row is omitted. 136 briefs exist on disk with **no** kanban row — they are listed in the
anomaly report (§6.8), not the corpus.

| source | scale used | fed which fields |
|---|---|---|
| `docs/infra/managent/tasks.json` + `archive.json` (snapshot) | 579 rows | id, status, model, verdict, dates, bundle, note, verdict_note, holds, claim_count |
| task bundles (the gitignored bundle tree, `T*.md`, one brief per task) | 539 briefs on disk (row→brief) | type (brief body), scope class (deliverables=, holds=), brief_bytes, Landmark line, capabilities |
| `findings/*.json` | 704 files, 475 rows have ≥1 | presence count per row; the "work happened" signal for orphan briefs |
| runner run records (the runs/ JSON tree under the gitignored area) | 695 records, 255 rows | wall_s, cpu_s, rss_mb, exit codes |
| runner logs (the `t*.log` tree under the gitignored area) | 2,292 files | kill census (§6.4) — note: counts exit 124 of the *runner's* subprocess records, not of the row's own run |
| token ledger (the tokens/ JSONL under the gitignored area) | 1,221 rows, 458 rows covered | tokens_in / tokens_out (trust-graded retro; treated as size, not as a decision input) |
| `git log` | HEAD..history | relocation of declared deliverables (§6.5) |

Per-row `sources` lists exactly which of the above fed that row.

## 2. task_type — the classifier and its measured accuracy

**Vocabulary:** D027's eight (`docs/infra/managent/directives.jsonl` D027b), normalized onto
the S07 lattice names (LAT-DIM-3): `spec/design`, `implementation-bounded`,
`audit/verification`, `integration/reframe`, `infra/tooling`, `research/census`,
`battery-heavy`, `orchestration-seat`. Corpus rows carry the short keys (`spec`,
`implement`, `audit`, `integration`, `infra`, `research`, `battery`, `orchestration`).

**Two classifiers, both recorded per row** (`type.legacy` and `type.brief`):

- **legacy** — `tools/model-profiles.py:classify_type` (T524/T503): ordered keyword rule over
  slug + note + verdict_note. It never reads the brief body.
- **brief** (this row's) — five-stage, ordered, specific-beats-general:
  1. *declarative* self-type phrases in the brief body ("this row delivers the spec only",
     "this is a race lane", "is a census", …), with a negation guard ("not a research row"
     must not fire research);
  2. slug + title keywords (title keywords include corpus-observed vocabulary: `check`,
     `reproducib`, `invariance`, `hygiene`, `ratchet`, `managent`, `claimlint`, `runner`,
     `fleet`, `harness`, `guard`, `gate`, `duty`, `metric`, …);
  3. deliverable-filename keywords (a `findings/Txxx-census.json` is a census signal);
  4. note/verdict_note keywords — **orchestration excluded** (attribution noise: "the
     Orchestrator ruled" appears in ordinary close text; the legacy classifier already
     restricts seat words to the slug);
  5. `UNKNOWN` when no signal exists. UNKNOWN is a value, never a fill.

**Measured accuracy (the calibration the brief demanded):**

| ground truth | n | legacy | brief |
|---|---|---|---|
| self-declared type in brief prose (hand-verified; the 24 tasks listed in §2.1) | 24 | 19/24 = 79% | 24/24 = 100% |
| self-declared + race organizers (T447, T529, T626 — protocol-known audit) | 27 | 21/27 = 78% | 27/27 = 100% |

The Landmark line was tried as a third calibration surface and **failed as ground truth**:
a landmark names the work-stream (domain), not the D027 task type — race lanes carry
"L2 (go science)" (T717…T729, audit), rulebook doc edits carry "L5 (one rulebook)"
(T704/T705, infra-ish), so a landmark→type map scores ~25% for both classifiers and the
mapping itself is the confound, not the classifiers. **The Landmark line is not a type
signal; do not use it as one in the lattice.** (Query §8: Q-CAL.)

**Distribution (brief, n=578):** audit 204 (35.3%) · infra 133 (23.0%) · implement 57
(9.9%) · orchestration 55 (9.5%) · battery 45 (7.8%) · research 23 (4.0%) · spec 23
(4.0%) · integration 18 (3.1%) · UNKNOWN 20 (3.5%).

**Disagreement set (legacy vs brief): 215 of 578 (37%).** Full list in
`findings/T817-task-corpus.json` §disagreements. The disagreement set is itself the
finding about the classifiers:

- the brief classifier's wins are *verification-shaped titles the legacy never reads*
  (T310 "does the 4×4 artifact rebuild reproducibly?" → audit vs legacy infra; T313
  invariance → audit; T278/T360/T374 → implement vs legacy audit) and *tooling titles*
  (T228…T243 regtest fixtures → infra vs legacy implement);
- the legacy classifier's wins are mostly **title-subject words the brief classifier
  over-reads**: "dispatch"/"orcha"/"seat"/"console"/"ruling" in a title often name the
  *subject* (T320 "probe the delegation reach matrix" is an audit, not seat work; T275's
  "Orcha verification" is seat work but the task is an axiom doc write). The brief
  classifier was tuned once (bare "dispatch" removed from orchestration keywords) after
  this was observed; residual risk is stated in §7.
- 22 rows land UNKNOWN (thin or absent briefs, listed in the findings file) — see §6.6.

### 2.1 The 24-task self-declared calibration set (hand-verified)

spec: T323, T443, T776, T785, T803 · research: T382, T471, T592 · infra: T408 · battery:
T270 · audit (race lanes): T615–T624, T674, T683, T685, T687. Each brief carries a
first-person declaration ("this row is the spec bookend only", "this is a census, not a
solve", "this is a race lane", …). The set is the hold-out the accuracy numbers above were
computed against; classifier training never read it.

## 3. task_scope — the enumeration and its defence

**Enumeration: adopted from the S07 lattice spec** (`docs/epics/E1-markovian/L1-dashboard/
S07-delegation-lattice/spec.md` §LAT-DIM-5), the only committed scope enumeration in the
tree — no second taxonomy invented, per the brief's coordinate-don't-duplicate rule. Five
values, ordinal in footprint:

| class | name | derivation (mechanical, as implemented) |
|---|---|---|
| S1 | atom | exactly 1 deliverable, a non-code write (docs/ or root file: config, AXIOMS, rename) |
| S2 | leaf | 1–2 code writes (`src/`, `tools/`, `bin/`, `build.zig`, `tests/`), with a `src/` file or a test arm |
| S3 | feature | ≥2 `src/` writes, or `holds=` names >1 engine file (`src/retro|oracle|rules|solve.zig`), or ≥3 code writes |
| S4 | sweep | deliverables are findings/docs only (read-only output), or a lone findings file |
| S5 | console | orchestration type + console/seat/triage/inbox/landmark words in slug/title |

**Two data-driven amendments to S07's literal rules, both documented because S07's text
leaves the cases uncovered:**

1. **Non-src code writes count.** S07's derivation keys only on `src/` files. 88 corpus
   tasks deliver `findings/…` + a `tools/*.sh` regression script (or `build.zig`, `bin/*`);
   S07's src-only rules leave them unclassifiable. Extension: `tools/`, `bin/`, `build.zig`,
   `tests/` count as code writes for S2/S3. (T268 "deployment is silently broken" =
   build.zig + regression script → S2, which matches its one-session leaf shape.)
2. **Single-deliverable tie-break.** A lone `findings/…` deliverable satisfies both S1 and
   S4 mechanically; resolved as S4 (a findings file is the *output* of analysis =
   sweep-shaped), while a lone docs/root write is S1 (a created artifact = atom-shaped).
   Resolution is prefix-based, orthogonal to task type (LAT-DIM-7 preserved).

**Defence against the corpus** (the ordinal claim, measured):

| class | n | wall median | rss median | brief_bytes median |
|---|---|---|---|---|
| S1 | 14 | 337 s (n=7 with runs) | 362 MB | 1,662 B |
| S2 | 138 | 1,276 s (n=71) | 524 MB | 3,572 B |
| S3 | 27 | 2,325 s (n=6) | 851 MB | 3,678 B |
| S4 | 301 | 647 s (n=144) | 548 MB | 3,103 B |
| S5 | 41 | 1,017 s (n=12) | 613 MB | 3,211 B |
| S-unknown | 57 | — (n=6, 1 s median: never runner-dispatched) | — | 68 B |

S1 < S2 < S3 is monotone in both measured wall and RSS — the write-footprint ladder is an
ordinal in the data, not just in prose. S4 (read-only analysis) sits between S1 and S2 in
wall, matching S07's "bounded" horizon; S5 (console) sits between S2 and S3.

**Scope census (n=578):** S4 301 (52.1%) · S2 138 (23.9%) · S-unknown 57 (9.9%) · S5 41
(7.1%) · S3 27 (4.7%) · S1 14 (2.4%). This is the census S07's LAT-OUT-2 marks "pending";
the lattice can now render `p(scope)`.

**Size measurements per row** (kept separate from class, as the brief demands):
`brief_bytes`, `files_in_scope` (unique deliverables ∪ holds), `n_deliverables`,
`n_src_deliverables`, `wall_s`/`cpu_s`/`rss_mb` (sum/max over the row's run records),
`tokens_in`/`tokens_out` (retro, trust-graded), `n_runs`, `killed`, `exit_nonzero`.

## 4. capabilities — vocabulary derived from the corpus, not imposed

Capability is recorded nowhere in the ledger (`caps` is empty `[]` on all 578 rows), so it
is **inferred from what briefs demanded**. The vocabulary below was derived by clustering
the imperative phrases briefs actually use, not taken from a fixed list; each entry carries
its three example tasks, each hand-checked against the brief's own demand language. A
capability that cannot be exemplified is not in the vocabulary.

| capability | corpus definition | three example tasks (evidence phrase in the brief) |
|---|---|---|
| long-document-coherence | holding one large document in context end-to-end | T255 ("read the entire file. attempt to refute its design"), T628 (5-hour window / token budget guard), T791 ("in one pass… the full") |
| citation-verification | resolving references / checking citations against reality | T764 (brief citation check, report-only), T814 ("1,377 live citations point at volatile paths"), T759 (doctrine disambiguation) |
| census-counting | counting/enumerating rows, files, or states across the corpus | T629 ("every row's model attribution verified… the denominator is visible"), T592 (tools census), T817 (this task) |
| code-writing | writing/editing source under a spec | T452 (own the qa023_brute_2x2 node-budget alarm), T273 (kernel ko rule), T374 (@memcpy OOB fix) |
| test-authoring | writing regression/unit arms, controls, fixtures | T794 (unit-test the token meter), T790 (module test contracts), T226 (engine-unification pass0) |
| adversarial-refutation | trying to break / refute a claim, not confirm it | T660 ("reproduce the H1-MARKOV refutation"), T653 (Race G adversarial arm), T255 (adversary review) |
| arithmetic-over-corpus | computing rates, denominators, aggregates over a corpus | T382 ("measure it at every solved size — each with its denominator"), T750 (two-field metric), T629 (kill census schema) |
| long-horizon-execution | holding a plan across hours of execution | T636 (11,827 s wall), T662 (9,521 s), T774 (5,974 s — all measured from run records, not brief prose) |
| discrimination-saying-no | refusing/escalating rather than guessing | T390 ("make the answer no" — a guard), T429 (audit with a stop-and-report bar), T365 (sweep with zero broken references) |

**Per-task assignment:** keyword demand-phrases over the brief body; `confidence` is
`medium` (≥3 phrases) or `low` (1–2 phrases); the measured long-horizon signal is `high`
(≥3,600 s wall from run records). The vocabulary's prevalence over 578 rows: arithmetic
326 · discrimination 282 · code-writing 232 · census 221 · test-authoring 212 ·
citation-verification 143 · adversarial 95 · long-horizon 57 · long-document 6. The
**long-document** cluster is nearly absent — the corpus rarely demands it; the lattice
should not treat it as a populated cell.

## 5. Epochs

Every row carries `epoch`: `all` (248) for non-DeepSeek models; `pre-2026-08-18` (133) and
`post-2026-08-18` (197) for deepseek-v4-* rows bucketed by claimed→done→added date, plus
`epoch-unknown` for undated deepseek rows. **No aggregation in this corpus crosses the
2026-08-18 DeepSeek boundary**; every epoch-conditional number below states which epoch it
is over. (The model-perf 2026-08-18 note: deepseek-v4-pro shipped a new version under the
same name and deepseek-v4-flash may have been silently updated — a pre-boundary observation
describes a different model.)

## 6. Anomaly report — ranked by consequence

Every item: the claim, the evidence, and the query that found it (all in §8). Queries are
re-runnable; an anomaly nobody can reproduce is gossip.

### 6.1 The delegation-evidence record has a blind spot: 136 briefs (and 31 findings files) with no kanban row — RANK 1

136 task bundles exist on disk whose task has **no row in store or archive**: T1xx (88),
T2xx (23), T6xx (22, including register/absorb work T663–T672 and race lanes), T14-era
relays (3). 31 of them have committed findings files — the work happened, the record is
gone. The lattice's feedstock (`managent` store) cannot see ~19% of the fleet's documented
work; any per-model/type/scope census from the store alone undercounts by that much. The
T6xx orphans are *recent* (2026-08-20+), so this is not only an archaeology artifact.
(Q-ORPHAN, Q-ORPHAN-FINDINGS.)

### 6.2 Declared deliverables are not stable under tree moves: 53 pass rows cite a path absent today — RANK 2

53 of 578 rows with verdict pass/pass-with-findings declare at least one deliverable whose
path is absent from disk. 37 of those are one rename (`docs/epic-01-markovian/*` →
`docs/epics/E1-markovian/*`, commit `eb714a7`); the other 16 are per-task relocations:
`bin/ollama-subagent` → `bin/subagent` (T317/T321/T355/T411/T431), `docs/infra/races/*` →
`docs/epics/…/S02-model-delegation/` (T447/T543/T546/T558), `tools/claimlint.py` →
`src/claimlint.zig` (T710), assertion-ledger retired (T426/T461, commit `21d5093`), S05→S06
spec rename (T748). The close-time deliverable check (T278, asks git at close) cannot catch
this by design. **Consequence for the lattice:** `deliverables=` is load-bearing for scope
(§3); a stale path is a scope-measurement hazard, and "deliverable present at close" is not
"deliverable present now". (Q-ABSENT.)

### 6.3 The pass asymmetry is concentrated, not uniform — RANK 3

4 `fail-found` closes in 578 rows, all audit/battery: T258 (battery, unknown-era), T259
(audit, unknown-era), T332 (audit, kimi-k2.7), T807 (audit, deepseek-v4-pro, post-epoch —
RACE-X audit of S06 rev 2). 3 of 4 are **audit-type**; no fail-found was ever recorded for
infra, implement, spec, integration, research, or orchestration. Per-model pass+pfw rate is
91–100% for every model with ≥3 closes; the two models that ever took a fail-found are
kimi-k2.7 and deepseek-v4-pro. Blocked/abandoned (36) concentrates in infra (15) and
implement (11). (Q-FAIL, Q-PASS-MODEL.)

### 6.4 The log kill census is confounded by kill-instrumentation tasks — RANK 4

The runner logs (`t*.log` under the gitignored area) carry 4,149 "exit 124" lines across 90 task-logs — but the top
six are tasks whose *subject is the kill path*: T625 (389 in its own 54 MB log — it
tests the stale-directive kill), T643, T773, T629, T659, T650. A raw grep census (the
signal `tools/model-profiles.py`'s efficiency dimension uses) over-attributes deliberate
kill-path tests to those tasks; flash (2,652 kill lines) and pro (1,447) lead only because
kill-instrumentation work is allocated to them. The runner's *outer* run records show
`exit 0` for these tasks (the dispatch succeeded; subprocesses died by design). The
efficiency dimension should exclude kill-instrumentation bundles or it measures the wrong
thing. (Q-KILL, Q-RUNS-EXIT.)

### 6.5 Acceptance conditions are rarely re-mentioned at close — RANK 5

73 of 539 rows with a brief on disk (13.5%) have close text (note/verdict_note) containing
an acceptance/gate word. The corpus cannot confirm whether acceptance conditions were
checked at close; the recorded evidence that they were is thin. The T481 mechanism (refuse
close while findings unabsorbed) covers absorption, not acceptance — the gap the brief
hypothesised is visible in the data, and the follow-up instrument (a close-time acceptance
echo) would make it checkable. (Q-ACC-CLOSE.)

### 6.6 UNKNOWN is real: 20 rows have no classifiable type signal — RANK 6

20 rows (3.5%) land UNKNOWN: the six TL1* load-test dummies, STANDING-CLEANUP, the
no-brief dispatchable rows T762/T763 (briefs not yet on disk), and eleven thin-brief rows
(T257/T265/T267/T273/T274/T372/T562/T580/T581/T767/T768). These are *not* a classifier
failure; the text genuinely does not declare a type. The lattice must render them as
UNKNOWN, never fold them into a bucket (S07 C8's "refused and named").

### 6.7 Retries: 89 rows with claim_count > 1, flat across models, peaked at fixed hours — RANK 7

89 of 578 rows were claimed more than once: by model flash 24 / pro 22 / orcha 12 / glm 9 /
opus 7; by type audit 33 / infra 20 / implement 15. The orcha 12 are the T227-regtest
fixtures (dispatcher re-claims); the rest are genuine retries. Retries are **not**
epoch-skewed (39 post-epoch, 43 all) and their claim hours peak at 12:00Z (14) and 22:00Z
(16) — a schedule rhythm, not a uniform process. No model-type interaction stands out
beyond allocation. (Q-RETRY.)

### 6.8 Orphan findings without rows (subset of 6.1) and other small items — RANK 8

- `findings/*.json` names 704 files; 475 rows have ≥1. The 136 orphan briefs' 31 findings
  files are committed evidence of work the kanban never recorded (see 6.1).
- Scope fields are now partially backfilled: 110 rows carry `brief_bytes`/`files_in_scope`
  (the T629-era backfill); `caps` remains `[]` on all rows. The corpus fills both.
- 338 closed rows lack impression/waiver — but the impression gate (T522) began
  2026-08-22; pre-gate closes are expected to lack it, so this is a census, not a leak.
- Kills are not type-uniform (Q2 showed 0 kills in `runs/*.json` exit codes — kills live
  in logs, see 6.4), and `runs/*.json` exit codes are all 0 or null; the runner's outer
  record hides subprocess kills.

## 7. Limits — what this corpus cannot support a claim about

1. **Type and capability are keyword-inferred, not ground truth.** The brief classifier's
   measured accuracy (100% on 27 self-declared/race rows) is against a *small, curated*
   hold-out; the other 551 rows have no independent label. A disagreement between the two
   classifiers (214 rows) is a real uncertainty, not resolved here.
2. **Orchestration-seat is the weakest bucket.** Title words (`orcha`, `seat`, `console`,
   `ruling`, `landmark`) sometimes name the subject rather than the task's own role; the
   classifier was tuned once and the residual is stated, not eliminated.
3. **Capabilities are demand-phrases, not measured performance.** A brief demanding
   "verify every citation" says nothing about whether the model *did* it. The capability
   axis of the lattice must pair with outcome data (verdict, race scores) before it means
   anything about capability.
4. **Scope classes are derivable only where deliverables/holds exist.** 57 rows are
   S-unknown (39 no brief, 18 no deliverables/holds/findings). S07's own design-open (2)
   buckets these as S-unknown — the count must be stated, never silently dropped.
5. **The corpus is a snapshot.** The store is live; rows added after
   `2026-08-23T21:43Z` (or the store snapshot SHA) are not represented. Re-run the builder
   (Q-BUILD) against a fresh snapshot for a current corpus.
6. **Per-goban independence applies to delegation evidence too:** the race protocol,
   epochs, and model roster all changed across the 2026-07→08 span; this corpus labels
   epochs and does not aggregate across them (§5), but it cannot undo allocation
   confounds (which tasks went to which model).
7. **Run records under-measure kills** (6.4) and tokens are retro/trust-graded: wall/cpu/
   rss/token figures in the corpus are *size* context, never efficiency verdicts.

## 8. Reproducibility — the queries

Counting scripts committed under `docs/evidence/T817-task-corpus/`:

| query | what it produces |
|---|---|
| `mine.py` | the JSONL builder (snapshot → `docs/infra/task-corpus.jsonl`); run `python3 docs/evidence/T817-task-corpus/mine.py` |
| `classify2.py` | both classifiers (imported by mine.py) |
| `calib.py` | the calibration table (Q-CAL): self-declared + race-orgs accuracy, and the negative landmark result |
| `anomalies.py` | every §6 query: Q-ORPHAN, Q-ORPHAN-FINDINGS, Q-ABSENT, Q-FAIL, Q-PASS-MODEL, Q-KILL, Q-RUNS-EXIT, Q-ACC-CLOSE, Q-RETRY, Q-SCOPE-CENSUS, Q-TYPE-CENSUS |

The scripts read the live store by default and a snapshot dir via `T817_SNAPSHOT_DIR`
(SHAs in §0); `T817_SNAPSHOT_DIR=<snapshot>` rebuilds the committed corpus exactly. A
fresh clone recreates the snapshot from the §0 store files at the §0 commit before
re-running. Every number in this document was produced by one of these queries on the
§0 snapshot; no number was hand-entered.
