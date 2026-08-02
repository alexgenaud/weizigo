# Grand Audit — weizigo, 2026-08-02

Role: Grand Auditor · Model: Claude Fable 5 · Date: 2026-08-02 · At HEAD `e714fd4` (clean tree)

**Method.** Four parallel audit arms, each an independent agent with its own context, plus the
Grand Auditor's own instrument runs. Everything below was verified against files, commands, or
git — cites included. Raw arm reports (unedited) sit beside this file:

- `arm-epistemology-claims.md` — claims register, evidence integrity, doc coherence
- `arm-code-tests.md` — engine code, test quality, controls
- `arm-infra-tooling.md` — managent, runner, claimlint, binaries, artifacts
- `arm-orchestration-process.md` — roles, channel, delegation, parallelization, process cost

Instrument runs performed directly by the Grand Auditor (not delegated): `zig build test`
(exit 0, 242/242, with anomalies noted in §2), `bin/weizigo-claimlint` (exit 1),
`bin/managent status`, `shasum -a 256 -c artifacts/SHA256SUMS` (all 10 OK).

---

## The verdict

**The epistemic machinery is real and unusually good. The enforcement layer is theater. The
coordination layer costs more than the work it coordinates.** The project has built the best
claim-hygiene apparatus this auditor has seen in a working repo — and then wired none of it to
anything that can say no. Every "mandatory gate" is prose: there are no git hooks, claimlint
exits 1 at HEAD, the debt ratchet has been silently exceeded, and the tip commit over that red
gate is titled "shut down clean." Meanwhile the two newest correctness wounds (T193, T265)
share one root cause the remediation did not fix, and the remediation itself shipped a
tautological test.

---

## 1. The most serious findings

**1a. The T265 regression test is a tautology.** `src/differential.zig:269-272` defines
`engineKoNewGeneric` as literally `return solverKoGeneric(...)` — the test "ko key (T265):
fixed engine rule agrees with solver" (`differential.zig:336-342`) compares the solver's ko
function with an alias of itself. It never imports `gtp.zig` and gives zero coverage of the
actually-fixed code (`gtp.zig:717-744`). If the GTP ko rule regresses tomorrow, this test
stays green. This is verbatim the failure mode the project's own QA-023 standing rule forbids:
"a positive control must exercise the instrument under test, not a parallel one"
(AGENTS.md:146-148). Worse, `differential.zig` isn't in the `zig build test` graph at all
(build.zig:95-158; main.zig's test imports exclude it) — the T257 harness, its null control,
its seeded-defect control, and both T265 ko tests run only if someone types the command by
hand. A control that doesn't run is not a control.

**1b. The ko rule has no owner — the confirmed root cause of three defects.** `rules.zig`
deliberately excludes ko (rules.zig:100). The `liberties == 1 and friendly == 0` ko condition
exists in ~14 hand-written copies (three inside `exp6_solve.zig` alone: lines 285, 575, 909;
plus exp4/exp5/exp7, t129, the qa023 family, differential, and now gtp). T178, T193, and T265
are all producer/consumer key mismatches from this one cause — the 626ec55 commit says so
itself — and the T265 fix *added a fifteenth copy* instead of extracting one production
implementation. The key-agreement invariant the commit admits is "still owed" is registered as
T267 and correctly queued first; until it lands, family defect #4 is structurally available.
The "duplication is the oracle" doctrine does not cover this: the doctrine is one production
implementation plus demoted fixtures; here there are fourteen fixtures and zero production
implementations.

**1c. The gates are dashboards.** `bin/weizigo-claimlint` exits 1 at HEAD: C1a=10 orphans
(including two PROVEN rows sitting on FALSE-AS-SCOPED ancestors — `GLOBAL.F4` at CLAIMS.md:321,
`GLOBAL.H5c` at :470), C2=14 dangling evidence paths against the Argus ratchet of 12
(`docs/infra/roles/ARGUS.md:87-89`), C7=4 unabsorbed findings. No hook, no CI, no audit
FIX-level finding blocks on any of it. The ratchet — the one real control — has been exceeded
with no visible response. And one C7 failure is now *permanent by design*: the register
correctly refuted T212's `WZO2-4X4-VALID` proposal, but findings files are immutable and C7
has no "absorbed-with-rejection" disposition, so a correct refutation fails the lint forever.
A permanently-red gate trains everyone to commit over red — which is exactly what the last
fifteen commits did.

**1d. Semantic contradictions sail through the syntactic checkers.** The sharpest case:
`4x4.BASICKO-TIE` (CLAIMS.md:445) explains the +1-vs-+2 miss against the MIGOS II anchor as
"a ruleset difference (basic ko vs PSK), not a bug" — but the register's own PROVEN row
`GLOBAL.MIGOS-RULE` (CLAIMS.md:382) establishes MIGOS plays **basic ko**, not PSK, and
`4x4.ANCHOR` records a prior correction for exactly this conflation. A basic-ko build
disagreeing with a basic-ko anchor cannot be explained by "basic ko vs PSK." The roadmap had
named +2 as the acceptance criterion for a "finally legitimate comparison"
(roadmap-2026-07-28.md:227-232); the build returned +1 and the miss was absorbed under an
explanation the register itself contradicts. C6 passes because the cite-tags match statuses —
the *logic* is what's wrong. PROGRESS.md repeats it at lines 213 and 218. This is an
unexamined acceptance failure on the flagship artifact wearing a PROVEN tag as camouflage.

**1e. PROGRESS.md — the durable hub — is corrupted and self-contradictory.** §7.4a has a
sentence physically split by the 2026-08-02 insertions (line 383 ends mid-sentence; its
continuation dangles at 407-408 inside a different bullet — nobody re-read after editing).
§8.1 (line 462) still says the 4×4 was "solved … verified genuine" three sections away from
the PROVEN rows recording that the same artifact violates colour inversion on ~48% of
positions (`4x4.V1-INVSYM-BROKEN`) and that the pinned V violates its own Bellman identity at
89.29% of visited nodes. And §S4's "500 random gobans, 0 disagreements" conflates the
independent Python cross-validation (**120** gobans, per
`docs/evidence/GLOBAL-S4/verify-2026-07-30.log:2`) with the Zig-vs-Zig self-test (500) — the
project's own denominator rule, violated in its own narrative centerpiece.

**1f. Generated surfaces lie about their own provenance.** `tools/gen-indices:65` hardcodes
"274 claims" (register has 282) and `:109` hardcodes edge counts that misstate the real graph
by ~2× on `e:` edges — even a fresh regeneration prints the lies. `tools/gen-indices:63`
hardcodes `Model: DSPro` with today's date, meaning every future regeneration **forges worker
attribution**, violating the identity rule (AGENTS.md:67-73). The three INDEX-claim-* files
are also a day stale and missing all 8 newest rows, including everything about the WZO2
refutation.

## 2. Verification theater — the pattern behind the newest layer

The old layers (rules.zig, the T13 evidence package, claimlint's calibration battery) are
rigorous. The **newest** layers repeatedly ship instruments that don't measure:

- The verify-battery ran a stub returning `skipped` for its entire life until T258
  (`CODE.BATTERY-STUBBED`; STATE.md:44-46 — "every battery output before 2026-08-02 came from
  a stub").
- The T265 test is a self-comparison (§1a); its "regression fixtures"
  (`human-game-{1,2}.gtp`) contain `genmove` lines that require a gitignored 518 MB artifact,
  are referenced by no test, and die on a fresh clone — evidence documents dressed as
  regressions. Contrast the older fixture done right: `regressions/4x4-history-blunder.gtp`
  is artifact-independent and mirrored by an in-suite test (gtp.zig:1663).
- `vb_fixpoint.zig:502-530` has two tests that compute, print (`terminals_bad=52`,
  `match=false`), and **assert nothing**; the deferred-to must-fail control opens a gitignored
  file with `catch return`, so on a fresh clone the negative control passes vacuously with no
  skip marker.
- The green suite prints failure-shaped noise: seeded-defect calibration output
  ("A2 L-VIOLATION … stored L=99") appears with no "EXPECTED" marker, and `zig build test`
  interleaves literal `failed command:` lines into a passing run (exit 0, 242/242; reproduced
  across seeds). Both train readers to ignore red text — the precondition for every
  "instrument lying" incident this project has had.
- The findings pipeline is 3 days old and 6 of 37 files (~16%) already violate its required
  schema — and claimlint C7 **skips non-conforming files silently** (T260/T261, cited as
  evidence by PROVEN rows, are among the skipped), the exact sin its own C0 banner denounces.

The QA-023 lesson was codified as prose rules, and the prose rules did not transfer to the
next sprint's instruments. The one mechanism AGENTS.md says has ever found real defects —
independent re-implementation — remains a practice with no enforcement, and the T265
"regression test" shows even the *format* of a control can be counterfeited unintentionally.

## 3. Infrastructure — the guard rails have quiet gaps

- **The B44 fix is silently broken.** `ephemeral` is a plain empty directory, not the
  prescribed symlink to `/tmp/weizigo` (AGENTS.md:187-190) — the disposable/durable split from
  the evidence-loss postmortem doesn't exist on disk, and 229 GTP logs are accreting in `log/`
  as a result.
- **Runner doc contradicts runner code on the safety-critical check.**
  `docs/infra/host/runner.md:18-20` promises RSS "summed across all descendants";
  `tools/runner:649-674` checks per-PID only — eight 3.9 GB children pass. Escape routes:
  daemonizing children reparent past the ppid-walk; `setsid` grandchildren survive the
  `killpg`; `sh -c "zig …"` bypasses the ReleaseFast rewrite. And AGENTS.md:85 points at the
  *stale* runner doc (`docs/infra/runner.md`, pre-T214) — a live violation of the "one
  canonical doc" ruling.
- **Binary drift, convicted by its own stamp.** Every stamped binary in use says
  `626ec55-dirty` — built from an uncommitted tree, so no stamp can reconstruct its source.
  `bin/weizigo-claimlint` is older than `src/claimlint.zig` and unstamped; root-level
  `./managent` (pre-T264, writes the same tasks.json) and `./gtp` (actually a misnamed
  weizigo-oracle) are stale hazards. `gen-version.sh` also misses staged-but-uncommitted
  changes (`git diff --quiet` without `--cached`). T268 in the queue is aimed at this; the
  queue ordering is right.
- **Spec/help/binary are three different command sets** for managent (`--help` omits five
  implemented commands; spec's "eighteen commands" block lists 19 and omits five that `--help`
  shows), and spec.md:52's own regression contract ("status 1>/dev/null is silent") is broken
  by the version banner.
- **Evidence citing `/tmp`** — `m4a-accept-T212` cites two vanished `/tmp/weizigo/` logs;
  `audit-2x2-mismatch-2026-07-30.md` cites `/tmp/audit-2x2-mismatch.log`, reachable from 4
  register rows. AGENTS.md:183-185 says verbatim this must never happen. These are the two
  paths that pushed C2 past its ratchet.
- Note on a foreclosure's wording: `data/` is fully gitignored, so "the **committed**
  ko-sensitive values" (AGENTS.md:20-24) describes 258 MB artifacts that exist only on this
  host, and git cannot police "no silent writes to `data/`" — `artifacts/SHA256SUMS` is the
  real control there (and it verifies clean).

## 4. Orchestration — the court costs more than the bench

- **71% of the 322 commits since 2026-07-22 touch no `src/` file.** `tasks.json` alone appears
  in 153 commits — 47% of the entire history is kanban bookkeeping. Docs-to-src file-touch
  ratio ≈ 6:1. The process doctrine says "least friction, no ceremony"; the measured reality
  is a court that convenes more than it adjudicates.
- **The transport failures are diagnosed and unfixed.** Message-number collisions on 15+
  numbers, continuing five weeks *after* the failure was named (msg 015) and a design of
  record committed (`SPEC-msgbus.md`). The prose fixes drifted immediately; the mechanized
  fixes (managent verdicts, claimlint floors, runner caps) stuck. That asymmetry is the single
  clearest lesson in the whole history: **rules that stayed prose rotted; rules that became
  code held.**
- **Seat inflation outran the registry.** Navigator (10+ messages) and Consul (4) operated
  with no role doc and no ROLES.md entry; even ARGUS.md exists but isn't in the registry
  table. Seven seats on a one-human message bus, each transition costing a handover doc and a
  re-read of a 13.6k-word role corpus.
- **The read-first surface re-rotted within 24 hours of the remediation aimed at it.**
  CURRENT.md says the 4×4 artifact is INVALID (`a892d689`, pre-rebuild); STATE.md says
  `0c3366f0`, M4a 4/4, blocker = incompleteness. The durable resume path (the one that
  survives a clone) tells a cold-booting agent the wrong headline, and the entire 15-commit
  2026-08-02 session is invisible in it. Three competing "read me first" chains exist
  (AGENTS.md:114-115, CURRENT.md:3, ORCHESTRATOR.md:49). This is CA-2 recurring the day after
  CA-2 was remediated — which proves the fix (refresh the file) treats the symptom. A file
  that must be manually refreshed at every shutdown will always be stale; the fix is to
  *generate* the resume surface from tasks.json + STATE.md, or delete CURRENT.md and route
  cold-resume through the register.
- **Worker onboarding is disproportionate**: the dispatch-console read order ("do this first,
  every time") totals ~37,000 words including the 26.6k-word CLAIMS.md — prescribed even for
  a DSFlash terminology sweep. The DELEGATOR brief header is dead letter: zero of ~10 sampled
  briefs use it.
- **DECISIONS.md** — the promotion ledger — failed to record its own promotions (D-22/D-23
  marked pending; both landed), and the open, acknowledged risk that the *ruling ledger
  itself* is git-ignored while eight tracked docs cite it (the T13 destruction mechanism,
  aimed at the most load-bearing untracked file) remains unruled since 2026-08-01.

## 5. What is genuinely excellent — and it is a lot

- **claimlint** is the best epistemic instrument any arm of this audit has seen in a working
  repo: zero-skip parsing, three edge kinds with inverted propagation on `n:`, every check
  mapped to a suffered incident, and a six-known-bad/three-known-good calibration battery that
  runs on every invocation. The "never trust a green test" doctrine, executed in code.
- **rules.zig** is arguably the best-tested thousand lines in the repo — an
  independently-structured second Benson implementation, a test of Benson's *theorem* (not
  just the port), and 4.8M-position stratified sweeps that genuinely run in-suite.
- **Refutations are preserved, not deleted.** The `WZO2-4X4-VALID` row records the
  reasonable-when-made proposal beside its refutation with the moral spelled out ("passing
  every check we had did not make the artifact valid, because no check we had tested
  completeness"). The T13 re-implementation package strengthens the falsification against
  itself (12 → 154/508) while explaining the original undercount. CLAIMS.md §7 inventories
  every destroyed evidence file with a disposition. This is rare practice anywhere.
- **Artifact integrity is perfect** — all 10 SHA-256 hashes in `artifacts/SHA256SUMS`
  independently verified, including the 258 MB checkpoints.
- **Disaster→rule provenance is real, not cargo cult**: runner ← kernel panic,
  evidence-in-git ← T13, copy/paste fences ← truncated relays, verify-then-promote ← QA-023,
  the two-directory doctrine ← B44. And the self-audit reflex works — the process found four
  lying instruments in one day by running its own cadence. It detects its rot; it just re-rots
  fast.
- **The current queue is correctly prioritized.** T266 (completeness), T267 (key-agreement
  invariant), T270 — the register, STATE.md, and the kanban all agree, and they name exactly
  the defects this audit ranks highest. The system knows where its wounds are.

## 6. The prescription — five moves, in order of leverage

1. **Extract one production `koAfterCapture` into `rules.zig` and make all fifteen call sites
   use it or test against it** (fold into T267). This retires the entire T178/T193/T265
   defect family at the root instead of adding invariants around fourteen copies. Then fix
   the T265 test to actually import `gtp.zig`, and wire `differential.zig` into
   `zig build test`.
2. **Wire the gates or stop calling them gates.** One pre-commit hook: claimlint must not
   regress the recorded ratchet (not "must be green" — the honest-debt floor idea is right;
   it's just unenforced and its floor doc didn't move when debt did). Add an
   "absorbed-with-rejection" disposition to C7 so correct refutations don't redden the gate
   forever, and make C7 *report* non-conforming findings files instead of skipping them.
3. **Generate the resume surface; delete what must be hand-refreshed.** CURRENT.md's failure
   is structural — it re-rotted in 24 hours. Emit it from tasks.json + STATE.md at `managent`
   shutdown, or kill it and fix the AGENTS.md read-order table to one chain.
4. **Fix the two lying generators**: gen-indices' hardcoded counts and forged `Model: DSPro`
   attribution; gen-version's staged-changes blind spot; and recreate the `ephemeral` symlink
   (one command, and the B44 fix is real again).
5. **Adjudicate the MIGOS +1/+2 miss honestly.** Reopen `4x4.BASICKO-TIE`'s explanation — the
   register's own PROVEN row contradicts it, and it currently absorbs the flagship acceptance
   failure. The candidate real causes (TIE=0 vs MIGOS tie semantics; fixpoint vs search)
   deserve a row each.

## Coda

This project's history says prose rules drift and mechanized rules hold — managent's verdict
vocabulary stuck, the brief header died; claimlint's checks stick, the read orders contradict
each other. The court's instinct when wounded is to write another rule into AGENTS.md. The
evidence in its own register says: write it into a tool or expect to re-learn it. The
epistemics are the crown jewel; spend the ceremony budget turning them from a dashboard into
a gate, and spend almost nothing else.
