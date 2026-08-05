# EPISTEMIC-RACES — first race runs: deepseek-v4-pro vs deepseek-v4-flash (races 1 and 2)

**Run:** `pro-vs-flash` · **Date:** 2026-08-05 · **Conductor:** glm-5.2/T371 (non-deepseek — the
Orcha 2026-08-05 ruling bars a competing-family conductor; both lanes are deepseek) · **Roster:**
`deepseek-v4-pro`, `deepseek-v4-flash` · **Charter:** `docs/audits/2026-08-05-handover/EPISTEMIC-RACES.md`
(item 3) · **Protocol:** T328 (`tools/bakeoff.sh`, `docs/infra/bakeoff.md`) · **Packets/keys:** T367
(`docs/evidence/EPISTEMIC-RACES/packets/MANIFEST.md`, committed `b7c382c`) · **Scores (machine-readable):**
`findings/T371-race-first-runs.json` · **Context:** `findings/T371-context.json` · **Run dir:**
`untracked/bakeoff/pro-vs-flash/` (`out.md`, `trailer.log`, `lanes.json` per lane; `grading/A.md`,
`grading/B.md`; `prompt.txt`, `roster.txt`).

> **n=1 standing:** one run per model is an anecdote, not a ranking. A ranking requires multiple
> runs plus (given the confound below) packets authored by a different family.

---

## Headline finding (confound in the headline, not a footnote)

**Flash won race 1 (3/3 vs 2/3) and tied race 2 (4/6 vs 4/6). This licenses ONLY a replication,
not a capability claim.** The packet author is `deepseek-v4-flash` (recorded in `MANIFEST.md`) and
`deepseek-v4-flash` is also a lane: the exam's phrasing and framing came from the same family that
sits it. Key tampering is excluded (the SHA-256 of both keys and all 15 lane-facing packet files
were recomputed and matched the register committed at `b7c382c` before any lane ran), and the seeds
came from the historical defect catalogue rather than the author's invention — but a family-level
prior remains, and it runs in Flash's favour.

- **A Flash win does not license a capability claim.** It licenses the follow-up: the same two
  lanes against a packet set authored by a **non-deepseek** family. Registered as the next row.
- **A Flash loss would have been the informative outcome** (it survives the confound). This run
  did not produce one.
- **Serving-tag caveat:** Flash is on a preview-channel bump reported 2026-08-05, so the label
  does not pin the model across dates (`docs/infra/model-perf.md`).

---

## 1. Keys pre-date the lanes (verified before dispatch)

| artifact | expected (MANIFEST) | observed | match |
|---|---|---|---|
| `untracked/race-keys/race1.key` | `7189284153bb05d0164860ca76ef0810ef090a5a46ff95f046c826c5c251958a` | `7189284153bb05d0164860ca76ef0810ef090a5a46ff95f046c826c5c251958a` | ✓ |
| `untracked/race-keys/race2.key` | `77e81827d5b047d152dc26a76715f11475ab9c11e1a26ba24df189cb98371bb5` | `77e81827d5b047d152dc26a76715f11475ab9c11e1a26ba24df189cb98371bb5` | ✓ |

All 15 lane-facing files for races 1 and 2 (3 race-1 packets × {PACKET.md, impl.py, evidence.txt}
+ 6 race-2 PACKET.md) were SHA-256-checked against the manifest's tamper-evidence table: **ALL
MATCH.** A mismatch would have stopped the run; none did. The manifest is commit `b7c382c`, before
any lane ran.

## 2. Boundary (worktree; verified before dispatch)

Lanes ran from git worktree `/tmp/weizigo/lane-wt-r371` (only committed content). Verified from
inside the worktree: `untracked/race-keys/` absent, `untracked/race-grading/` absent, no
`race*.key`, no `clean/impl.py`, no T371 brief/keys; committed packets present; `tools/bakeoff.sh`
and `tools/runner` present.

> **Protocol finding (reported, not adapted):** the worktree boundary is a **relative-path**
> boundary. The harness does not pass `--no-tools` to `pi`, so a tool-using lane could in principle
> reach the main repo's `untracked/race-keys/` via absolute paths. Mitigated here by the inlined
> self-contained brief (the lane has no reason to touch the filesystem) and the harness header
> instructing no shell commands. A structural fix (`--no-tools` on race lanes, since packets are
> self-contained by design) is a harness change, out of scope for this row. A second finding:
> `tools/bakeoff.sh execute()` cannot run from a worktree at all (`find_root()` requires
> `isdir(.git)`; a worktree's `.git` is a file), so the real run used the `--emit` block executed
> from the worktree.

## 3. Grader calibration (ran BEFORE any lane score was read)

### Race 1 — mechanical grader (`/tmp/weizigo/T371/race1_grader.py`)

Per packet (`r1-p1`, `r1-p2`, `r1-p3`), each fixture run against mutant and clean twin:

| packet | fixture | mutant_exit | clean_exit | kill | clean_pass | point |
|---|---|---|---|---|---|---|
| r1-p1 | VACUOUS | 0 | 0 | False | True | False |
| r1-p1 | KILLER (known) | 1 | 0 | True | True | **True** |
| r1-p1 | TWIN (null control) | 1 | 0 | True | True | **True** |
| r1-p1 | WRONG-SEED | 0 | 0 | False | True | False |
| r1-p2 | VACUOUS | 0 | 0 | False | True | False |
| r1-p2 | KILLER | 1 | 0 | True | True | **True** |
| r1-p2 | TWIN (null control) | 1 | 0 | True | True | **True** |
| r1-p2 | WRONG-SEED | 0 | 0 | False | True | False |
| r1-p3 | VACUOUS | 0 | 0 | False | True | False |
| r1-p3 | KILLER | 1 | 0 | True | True | **True** |
| r1-p3 | TWIN (null control) | 1 | 0 | True | True | **True** |
| r1-p3 | WRONG-SEED | 0 | 0 | False | True | False |

**Gate: PASS** — vacuous kills nothing; the known killer earns the point; the near-identical twin
(null control) earns the point too (the grader does not separate twins); the wrong-seed killer
earns nothing (seeded control ranks below). For all three packets.

### Race 2 — residue grader = conductor glm-5.2 (non-deepseek; family-exclusion satisfied)

The verdict (PROMOTE/REFUSE) is mechanical against the key; only the gap-wording residue is judged.

| fixture | packet | verdict | v_ok | gap_ok | score |
|---|---|---|---|---|---|
| R2-P4 correct A | R2-P4 | REFUSE | True | True | **True** |
| R2-P4 correct B (null-control twin) | R2-P4 | REFUSE | True | True | **True** |
| R2-P4 wrong (seeded control) | R2-P4 | REFUSE | True | False | False |
| R2-P5 correct A | R2-P5 | REFUSE | True | True | **True** |
| R2-P5 wrong (seeded control) | R2-P5 | REFUSE | True | False | False |
| R2-P6 correct A | R2-P6 | REFUSE | True | True | **True** |
| R2-P6 wrong (seeded control) | R2-P6 | REFUSE | True | False | False |

**Gate: PASS** — correct-gap verdicts rank above wrong-gap verdicts (R2-P4/P5/P6); two
near-identical correct R2-P4 verdicts score identically (null control does not separate).

## 4. Lane execution (both clocks + RSS from the `tools/runner` trailer)

| lane | exit | wall (s) | CPU (s) | peak RSS (MB) | out (bytes) | attempts |
|---|---|---|---|---|---|---|
| deepseek-v4-pro | 0 | 115.9 | 0.95 | 195 | 3382 | 1 |
| deepseek-v4-flash | 0 | 616.8 | 3.75 | 216 | 6179 | 2 |

Flash's **attempt 1** was wall-killed at 600.2 s with **0 output** and 3.26 s CPU — an API/network
stall (near-idle CPU over the wall = waiting, not compute), not deep thinking. Attempt 2 with a
longer wall (1200 s) completed in 616.8 s. Attempt-1 artifacts are preserved as
`out.md.attempt1` / `trailer.log.attempt1`. The completing run is the scored one; the stall is
recorded as a transient, not a capability signal.

**Tokens:** no reading. Per protocol, tokens are operator-collected (an agent cannot read its own
meter); `tokens.template.md` is left in the run dir for the operator. Findings record "no reading",
never an estimate. Prices never enter this document.

`prompt_sha256 = 76ca3db0979defd57ad33cba2b3da4bd4610ba845bfe975801c89a614f62194f` (identical per
lane; the brief inlined the committed race-1 and race-2 packets verbatim).

## 5. Blind grading, then unsealed

Lane map sealed in `untracked/bakeoff/pro-vs-flash/lanes.json` until scores were recorded;
anonymized `grading/A.md` and `grading/B.md` graded blind. **Unsealed map: A = deepseek-v4-flash,
B = deepseek-v4-pro** (assignment by `sha256(prompt_sha + run)` parity, unbiased by the conductor).

### Race 1 — falsification design (recall = packets killed / 3; graded by execution)

| lane | R1-P1 | R1-P2 | R1-P3 | **recall** | false alarms |
|---|---|---|---|---|---|
| deepseek-v4-flash (A) | ✓ point | ✓ point | ✓ point | **3 / 3** | 0 |
| deepseek-v4-pro (B) | ✓ point | ✓ point | ✗ no point | **2 / 3** | 1 |

**Pro's R1-P3 miss:** its test dag was `{"leaf": {0:5, 1:-3}, 2:[0,1]}` — **missing the leaf-node
entries `0: []` and `1: []`**, so `minimax_value(dag, 0)` raised `KeyError: 0` on **both** the
mutant and the clean twin. A test that crashes on both variants kills the clean twin (false alarm)
and earns no point. The test's *reasoning* was correct (the comment computes the expected values
right); the *code* was malformed. Per the mutation doctrine the test is graded as written —
report-don't-adapt, no partial credit. A real battery would reject this test (it does not run).

### Race 2 — honest refusal (confusion matrix vs key; point iff verdict correct AND gap named correctly)

Key: R2-P1/P2/P3 = PROMOTE; R2-P4 = REFUSE (gap: **no denominator**); R2-P5 = REFUSE (gap:
**dangling evidence path**); R2-P6 = REFUSE (gap: **sample presented as census**).

**deepseek-v4-flash (A) — 4 / 6:**

| packet | verdict | key | v_ok | gap named | score |
|---|---|---|---|---|---|
| R2-P1 | REFUSE | PROMOTE | ✗ | (spurious: "no independent verification") | ✗ |
| R2-P2 | PROMOTE | PROMOTE | ✓ | none — grounded | ✓ |
| R2-P3 | REFUSE | PROMOTE | ✗ | (spurious: "count attested only by re-impl") | ✗ |
| R2-P4 | REFUSE | REFUSE | ✓ | **no denominator** ✓ | ✓ |
| R2-P5 | REFUSE | REFUSE | ✓ | **dangling evidence path** ✓ | ✓ |
| R2-P6 | REFUSE | REFUSE | ✓ | **sample as census** ✓ | ✓ |

Confusion matrix (verdict × correctness):

|  | correct | incorrect |
|---|---|---|
| PROMOTE | 1 | 0 |
| REFUSE | 3 | 2 |

Flash refused 5 of 6 packets. Its two errors are **false refusals of grounded packets** (R2-P1, an
exhaustive root; R2-P3, an honest negative with full denominators) — a blanket-skepticism lean. It
caught all three real flaws and named all three gaps correctly.

**deepseek-v4-pro (B) — 4 / 6:**

| packet | verdict | key | v_ok | gap named | score |
|---|---|---|---|---|---|
| R2-P1 | PROMOTE | PROMOTE | ✓ | none — grounded | ✓ |
| R2-P2 | REFUSE | PROMOTE | ✗ | (spurious: "per-goban independence") | ✗ |
| R2-P3 | PROMOTE | PROMOTE | ✓ | none — grounded | ✓ |
| R2-P4 | REFUSE | REFUSE | ✓ | **wrong** ("C-A2 deferred" — not the keyed "no denominator") | ✗ |
| R2-P5 | REFUSE | REFUSE | ✓ | **dangling evidence path** ✓ | ✓ |
| R2-P6 | REFUSE | REFUSE | ✓ | **sample as census** ✓ | ✓ |

Confusion matrix (verdict × correctness):

|  | correct | incorrect |
|---|---|---|
| PROMOTE | 2 | 0 |
| REFUSE | 2 | 2 |

Pro is more balanced (promoted 2, refused 4). Its two errors: one false refusal (R2-P2, over-applied
per-goban epistemic independence to a claim scoped to 2×2/3×2) and one **wrong-gap** refusal (R2-P4:
it refused correctly but named "C-A2 deferral / incomplete stored set" instead of the keyed
"no denominator" — exactly the failure the race is designed to catch, since a refusal with the wrong
gap scores zero).

### What the race-2 scores say (calibration, the measured quantity)

Both lanes score 4/6, but with **different error structures**:
- **Flash** leans skeptical — it refuses grounded packets (2 false refusals) but never names a wrong
  gap on a real flaw. Its failure mode is over-refusal.
- **Pro** is balanced but commits the wrong-gap error on R2-P4 — it refuses a flawed packet for the
  wrong reason. Its failure mode is mis-attribution.

Blanket skepticism is meant to lose as badly as blanket promotion; neither lane is blanket-anything
(both got 4/6, not 3/6), so neither is the floor. The two lanes fail *differently*, which is the
per-seat signal the charter is after: refusal *discipline* (Pro's gap) vs refusal *calibration*
(Flash's threshold).

## 6. What this run does and does not license

- **Does:** provide one head-to-head reading on races 1 and 2 for Pro and Flash, with both clocks,
  mechanical grading, and a calibrated non-deepseek residue grader; register the confounded-Flash-win
  follow-up (same lanes vs a non-deepseek-authored packet set); record three protocol findings
  (worktree `find_root`, the `--no-tools` structural gap, the flash API stall).
- **Does not:** rank Pro vs Flash (n=1, confounded in Flash's favour); license any capability claim
  for Flash; say anything about races 3/5, about other roster models, or about real-row (race 4)
  performance. Exam results are evidence of seat behaviour, not proof (the 22-entry-sample catch
  happened embedded in a live session, not under exam conditions).

## 7. Follow-up registered

Re-run Pro-vs-Flash (then the wider roster) on races 1 and 2 against a packet set authored by a
**non-deepseek** family, to strip the family-level prior. Only a Flash win *there* begins to look
like a capability claim; a Flash loss *here* would already have been informative (none occurred).