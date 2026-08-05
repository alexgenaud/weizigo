# EPISTEMIC-RACES — packet manifest and sealed key register

Registration-order item 2 of `docs/audits/2026-08-05-handover/EPISTEMIC-RACES.md` (packet
authoring + key sealing). Protocol substrate: T328 bake-off harness
(`untracked/T328-model-bakeoff-harness.md`); answer-key-first pattern per T316
(`docs/evidence/T316/corpus-manifest.sha256`).

- **Packet author:** deepseek-v4-flash / T367 · **Date:** 2026-08-05
- **Author model family:** `deepseek-v4-flash` (serving-tag caveat per `docs/infra/model-perf.md`:
  Flash is on a preview-channel bump reported 2026-08-05; the label does not pin the model
  across dates. Grader family-exclusion and the confirmation-bias baseline depend on this row.)
- **Seeds:** drawn exclusively from the project's historical defect catalogue — mutation
  catalogue (T291), GRAND-AUDIT 2026-08-02, QA-023 package, g3b pass0 accept.md, PROGRESS §S4,
  T274 tie experiment. History wrote the key, which is what keeps key-author bias thin.
- **Keys:** plaintext in `untracked/race-keys/` (gitignored — **outside lane reach by directory
  boundary**: lanes run in worktrees that contain only committed content, and none of the key
  plaintext or clean twins is committed). The SHA-256 of every key is committed **here, in this
  file, in one commit, before any lane runs**. Recompute-and-compare at grading time to prove
  the keys pre-date the lanes.
- **Race 4** has no packet (measured in situ on real rows).

## Packet inventory — one row per packet

### Race 1 — falsification design (graded by execution)

| packet | claim | seed provenance (historical row/finding) | seed kind | N |
|---|---|---|---|---|
| **R1-P1** | state-table key separates (position, side, passes, ko) | T193 passes-bit; mutation catalogue **M2** (gap G1/G3); T178 same family | key mismatch | 1 |
| **R1-P2** | engine ko rule independently re-implemented and differentially verified | GRAND-AUDIT **§1a** (T265 test is a self-comparison); mutation catalogue **M10** (alias-control) | tautological differential | 1 |
| **R1-P3** | evaluator is calibrated; seeded-defect control can fire | QA-023 (POS control ran a separate PSK path; 1,133/1,133 TIE probe); AGENTS.md standing rules 2026-07-29 | control that cannot fire | 1 |

Each packet ships `PACKET.md` (claim + code listing + evidence narrative), `impl.py` (the
seeded code — the mutant, runnable), and `evidence.txt` (genuine transcript of the seeded
run). Clean twins live in `untracked/race-grading/race1/<packet>/clean/impl.py`.

### Race 2 — honest refusal (self-contained packets; lanes get no repo access)

| packet | claim | verdict per key | flaw (keyed) / grounding |
|---|---|---|---|
| **R2-P1** | 3×3 empty-goban fresh-start root = +9 (L==H==9) | **PROMOTE** | grounded: T274 §8.1 committed root; exhaustive 0 / 49,428 entries, 176,873 edges (accept.md) |
| **R2-P2** | [L,H] tables bit-identical across five TIE values at 2×2/3×2 | **PROMOTE** | grounded: T274 §8.2 fingerprints; 0 / 1,620 and 0 / 1,732 exhaustive |
| **R2-P3** | C2 falsified at 3×2: 154/508 non-trivial PSK histories disagree | **PROMOTE** | grounded: T13 re-implementation (docs/evidence/T13); denominator stated |
| **R2-P4** | C-A1 closure PASS at 4×4: 0 children-not-in-table | **REFUSE** | **no denominator** — accept.md §2.3 (C-A1 tabled PASS without a denominator; honest state is a 22-entry sample, full run deferred) |
| **R2-P5** | colour inversion violated on 48.2% of 4×4 positions | **REFUSE** | **dangling evidence path** — GRAND-AUDIT §3 (m4a-accept-T212, 2026-07-30-audit-2x2-mismatch: evidence cites vanished /tmp logs; C2 ratchet) |
| **R2-P6** | independent cross-validation: 0 disagreements over 500 gobans | **REFUSE** | **sample presented as census** — PROGRESS §S4 / GLOBAL-S4 (independent Python validation was 120 gobans; 500 is the Zig-vs-Zig self-test) |

### Race 3 — prior-art mapping (keyed names, judged residue)

| packet | description (de-jargoned) | keyed name |
|---|---|---|
| **R3-P1** | deliberately corrupt the thing under test; a check that still passes wasn't checking that property | mutation testing — DeMillo–Lipton–Sayward 1978 |
| **R3-P2** | freeze known-good output; byte-compare after every change | golden master — Feathers 2004 |
| **R3-P3** | work backward from terminals; table replaces search | retrograde analysis / tablebase (Bellman 1965; Thompson 1986) |
| **R3-P4** | expand where the proof is nearly done (two counters per node) | proof-number search — Allis 1994 |
| **R3-P5** | the frontier: what is already known at 5×5? | van der Werf's 5×5 Go solution 2003 (MIGOS) |
| **R3-P6** | the certificate, not the program (M6's goal) | Schaeffer's checkers proof — 2007 |

### Race 5 — formal precision (seeded inconsistency audit)

| packet | axiom set | verdict per key | seeded inconsistency |
|---|---|---|---|
| **R5-P1** | MIGOS tie semantics (A1–A4) | **INCONSISTENT** | A4 vs A1 (basic-ko-vs-PSK explanation contradicts MIGOS-plays-basic-ko; canonical seed — GRAND-AUDIT §1d, T274) |
| **R5-P2** | fresh-start vs real-game (A1–A4) | **CONSISTENT** | none (control — false alarms measured) |
| **R5-P3** | single tie constant + measured bracket + anchor (A1–A4) | **INCONSISTENT** | {A2,A3,A4} given A1: no single t gives both +2 and −2 (T274 §5) |

## Key register (SHA-256, committed 2026-08-05 before any lane runs)

| key | SHA-256 | plaintext location (gitignored) |
|---|---|---|
| race1.key | `7189284153bb05d0164860ca76ef0810ef090a5a46ff95f046c826c5c251958a` | `untracked/race-keys/race1.key` |
| race2.key | `77e81827d5b047d152dc26a76715f11475ab9c11e1a26ba24df189cb98371bb5` | `untracked/race-keys/race2.key` |
| race3.key | `8f4aeee81149c87fbc4e77876c844731d7d8e9c4148500dd43ff55e7719f2f3b` | `untracked/race-keys/race3.key` |
| race5.key | `8cfd52f1242a53c97c2f05df397443faf72043101cb7a3a4cfa922856e1ab3e5` | `untracked/race-keys/race5.key` |

Each key records: per-packet seed provenance, the seeded mutation, the killer/gap/name
contract, the decoys a grader must not credit, and the calibration fixtures.

## Tamper-evidence (packet hashes, sealed with this manifest)

Lane-facing files under this directory, SHA-256, committed here:

| file | SHA-256 |
|---|---|
| race1/r1-p1/PACKET.md | `bffbef99fb1d8665de1edad51e87ace1941ebdb9dfaf22187ed66c47ca182155` |
| race1/r1-p1/impl.py | `720cc2aefd2020dcb61453ff57c08da54be1f7158344bf384d8b66d5d01c60b0` |
| race1/r1-p1/evidence.txt | `2eba73123852b5f01a15af344b19c3ee8b881ff1b21c67dc0304231936b6afb6` |
| race1/r1-p2/PACKET.md | `2d753b850d216d405bc991aad6ae5ea8ab09af71e91b5453dd856158a4229c14` |
| race1/r1-p2/impl.py | `ad8a2286a9011b25a45ef5aa3b5b641ef369c0ba1b13e214f5640e7bfaebf106` |
| race1/r1-p2/evidence.txt | `4649e39edfe29592356435e606f0c2bad1fafb05e31eccc9d5dfa04560f63f4a` |
| race1/r1-p3/PACKET.md | `f6a96e69781e2969768ae9de8ff64955ea015005cc9c45e08c69c796f84c3cce` |
| race1/r1-p3/impl.py | `74d6e2bbcccbe3ab98e1bf02e4a0fbf2730374dfb7cef1a13da92b3c06cb9942` |
| race1/r1-p3/evidence.txt | `9e45a085c9e0f8afd117f71b194ca8a8222b2fe0ee4147ae96490ecb975d30a2` |
| race2/r2-p1/PACKET.md | `db9d6d6951bc393ee8e791ba339999bd76d95a3458333822c31e14c74b94e106` |
| race2/r2-p2/PACKET.md | `18c76d5ca7560dc8c3e7f92fa3019d825905a7997ab99986d022a3ca6f23d997` |
| race2/r2-p3/PACKET.md | `70eca2a2a5bdbf4937a1da104de708055646d1f4f21fbcf4ad9c58384fd80bd1` |
| race2/r2-p4/PACKET.md | `816f70bd5c963b1a9b0abb6806715b15998783384d0dbdc824d3074f5cceac47` |
| race2/r2-p5/PACKET.md | `1b67cca8dcc688c02fc8cdde3cc42ea1d36bf2833f8bb8871887205ba76f381b` |
| race2/r2-p6/PACKET.md | `e3d62e40a09664b2a52666e55ecd1de2f1a450fc4618bbd0f73ffaf3da2a8e15` |
| race3/r3-p1/PACKET.md | `701a1042c54019cc5a1f7af91bf892ee17e2928bb0b4d555ac1a7699a4abe93c` |
| race3/r3-p2/PACKET.md | `76fd906538307732d5c779a9ef35eb88ed7d989551a55f4cd6d1b0b2d865eee8` |
| race3/r3-p3/PACKET.md | `bd3c6ab1d42cf36a0482779a158d81c6d18bd3c5e12ed1a02939819dbf64346a` |
| race3/r3-p4/PACKET.md | `71cdc3570cedd543923f59c4264eb5b7fa6606d6be661ee11c432d3480cc4139` |
| race3/r3-p5/PACKET.md | `a5bcb4a280d89508ed1b1904c29af2cbda0c261c41adaa6439129e700eddd7f4` |
| race3/r3-p6/PACKET.md | `31e55a2f369e26e044f24d65378eda1c29f2b4cee0997ad9c622bc798057681f` |
| race5/r5-p1/PACKET.md | `3e9f042d40e85b75a4cb1abadea2f603873ca30897f743598d4467df7a00b8ad` |
| race5/r5-p2/PACKET.md | `5b08cf5e6bedcc738e781d275040f73e737ed9ba589ce17242def4d05ef61703` |
| race5/r5-p3/PACKET.md | `7c9f0c4df1050f6d3ccc2da894620973e2478d46df18ad5713ebf4fa360f85b9` |

Grading-only clean twins (uncommitted — verify against these at grading):

| file | SHA-256 |
|---|---|
| untracked/race-grading/race1/r1-p1/clean/impl.py | `32aa03deb67b86f1703937d6a18d538adeaf5f10b1932cad9210de5195764f7c` |
| untracked/race-grading/race1/r1-p2/clean/impl.py | `1603639bfed55891879258a8e9b9f38d4a56cea316e19ae3d6d007e11c01af4f` |
| untracked/race-grading/race1/r1-p3/clean/impl.py | `2c409dcc6e328612a552e4ecfa9b40c78112270494b0022b40f2828b83852c9a` |

## Grading contract (mechanical anchors first)

- **Race 1** is graded entirely by execution: per packet, each proposed test runs against the
  mutant (the committed `impl.py`) and the clean twin. Kill = non-zero exit on the mutant;
  clean-pass = zero exit on the clean twin; point iff a test does both. Recall = packets
  killed / 3; false alarms = tests that kill the clean twin or fail to kill the mutant.
  Contract details and verification record: `untracked/race-grading/README.md`.
- **Race 2**: confusion matrix against the key. Naming the correct gap earns the point;
  blanket skepticism loses as badly as blanket promotion.
- **Race 3**: name-match mechanical against the key (accepted-name sets and citations);
  only the "what it adds" paragraph is blind-graded.
- **Race 5**: seeded inconsistency found (minimal subset named) or missed; false alarms =
  claims of inconsistency where the key says CONSISTENT, or wrong subsets. Decoy pairs are
  recorded in the key so a grader never credits them.
- Blind grader under the T328 validity bars: family exclusion, null + seeded calibration
  before scores count, mechanical anchors first, lane map sealed until scores recorded.

## Grader-calibration fixtures (stated per race; packets double as fixtures)

| race | null control (grader must not separate) | seeded control (grader must rank below the clean twin) |
|---|---|---|
| 1 | two near-identical killer proposals (same seed targeted, cosmetically different) — both must kill the mutant and pass the clean twin | a vacuous proposal (fixture `race1/vacuous.py`) must kill neither; a wrong-seed killer (targets a property the seed does not break) must not earn the point |
| 2 | two near-identical correct verdicts within one rubric step | a wrong-gap verdict — R2-P4 refused on "dangling evidence path", R2-P5 on "no denominator", R2-P6 on "no denominator" — must rank below the correct-gap verdict |
| 3 | two near-identical "what it adds" paragraphs within one rubric step | plausible-but-wrong name (e.g. "genetic programming" for R3-P1; "alpha-beta" for R3-P4) must rank below the keyed name |
| 5 | two audits finding the same inconsistency within one rubric step | an audit that misses the seeded inconsistency (or flags the A2/A3 decoy in R5-P1) must rank below one that finds it |

## Cost bound (per lane, all four races)

Per-lane output estimates, stated with denominators: race 1 ≈ 3 packets × ~150 lines of
runnable tests ≈ 1.8–2.7 k tokens; race 2 ≈ 6 verdict docs ≈ 0.9–1.2 k; race 3 ≈ 6
name+citation+paragraph ≈ 0.7–1.2 k; race 5 ≈ 3 audit docs ≈ 1.2–1.8 k. Total ≈
4.6–6.9 k tokens per lane ≈ 15–25% of one real row (T365 measured ≈ 31 k tokens; ledger
rows run 10–40 k). The first run (registration-order item 3: Pro-vs-Flash on races 1 and 2)
is ≈ 2.7–3.9 k per lane. Packet code is bounded by design: each race-1 impl is ≤ 60 lines of
stdlib-only Python; each lane output is one document.

## Files

- Lane-facing packets: this directory (`race1/` … `race5/`), committed.
- Sealed keys: `untracked/race-keys/` (gitignored; hashes above).
- Grading fixtures and clean twins: `untracked/race-grading/` (gitignored).
