# Phase 0 Execution Audit — the first execution portion of DIRECTION.md

Role: Auditor (ephemeral, per DIRECTION §6) · Model: Claude Fable 5 · Date: 2026-08-03 · At HEAD `f8eb7c3` (dirty: tasks.json, vb_common.zig, verify_battery.zig)

**Scope.** Phase 0 per DIRECTION §5: AXIOMS.md, the requirement tree derived top-down
from Z, old register rows mapped onto it, MIGOS/tie adjudication — executed as T271
plus the T272 gate, declared delivered at `3058f81` (2026-08-02 21:58), with
follow-ups T274/T275/T280/T281/T284/T285 and the Phase 1/2 boundary (T273, T290–T292)
where it bears on Phase 0's gate function.

**Method.** Three parallel verification arms (register consistency; gate mechanization
and history; phase mapping and ordering) plus the Auditor's own instrument runs:
`tools/regression-precommit.sh` (exit 0, hook refusal observed live on a seeded
regression), `bin/weizigo-claimlint` (exit 1, counts exactly at floor), evidence-line
checks (`build-T184-2026-08-01.stdout:162`), and direct reads of `rules.zig`,
`differential.zig`, `findings/T273-kernel-ko.json`, and both phase documents.
Everything below is cited to files, commits, or observed runs.

---

## The verdict

**Phase 0's content passed its own bar; Phase 0's bookkeeping is where every defect
lives.** The theorem is falsifiable, the non-claims are first-class, the MIGOS
adjudication is exemplary, and T271's verification found three real defects before
acceptance. But the grand audit's sharpest lesson — prose rules rot, coded rules
hold — recurred *inside Phase 0 within hours of delivery*: the canonical register
currently states a refuted version of the ko axiom, a DIRECTION-specified deliverable
was deferred into a task that was never registered, the mechanized gate was off
during the exact window the floor was breached, and Phase 2 code shipped before
Phase 1's battery existed even as tasks. All six findings are instances of two rules
the project already holds ("an axiom change is a recorded event" and "a rule that
stays prose is a rule we have chosen to re-learn") being enforced by nothing.

---

## 1. Findings, most severe first

### F1. The register contradicts the axioms document on the load-bearing ko axiom

`docs/epistemic/CLAIMS.md:408` records B1 as "matches the goban **one ply** earlier" —
the pre-Amendment-1 text whose own derivation (AXIOMS.md §2, P₀/P₁/P₂) proves a
one-ply test "would forbid nothing." `CLAIMS.md:406` likewise carries A5's
pre-amendment "does not change goban or affect ko"; the amended axiom says a pass
*clears* the ko point.

Root cause: **Amendments 1 and 2 have no register rows at all**, violating AXIOMS.md's
own rule at lines 12–14 ("a dated entry here plus a register row … Never a silent
edit"). `grep T275 docs/epistemic/CLAIMS.md` returns nothing. Only Amendment 3
(A6/T285 → `GLOBAL.AXIOM-FORCEDPASS`, CLAIMS.md:407) complied. The register — the
surface all 282 rows are supposed to be re-derived against — hands a cold reader the
refuted axiom text.

### F2. A Phase 0 deliverable was dropped, not deferred

DIRECTION §5 lists "old register rows mapped onto it" as Phase 0 content
(DIRECTION.md:102-104). AXIOMS.md §6 defers it ("mapping all 282 register rows onto
the tree (follows in its own task)", AXIOMS.md:399-400); the T271 brief defers it the
same way (`untracked/T271-axioms-and-theorem.md:63-64`). **That task was never
registered** — no entry in tasks.json through T296, no brief, no commit delivers it
(T290's "map the existing checks onto the tree" maps battery checks, a different
object). Phase 0 was declared "delivered" (`3058f81`) with the deliverable dangling,
and nothing in the kanban will ever surface it. It is also the direct input to
Phase 3's "every register row re-derived, demoted, or retired."

### F3. Battery-before-code was violated at the Phase 1/2 boundary, without a ruling

Timeline (all 2026-08-03, +0200): T273 (Phase 2 kernel — `koAfterCapture` +
`stateKey`) landed 00:24 (`b475533`). Phase 1's battery tasks T290–T292 were
registered ~80 minutes *after* T273 closed (23:46–23:47Z per tasks.json); T290's spec
landed 01:53 (`40b70c2`); T291's mutation catalogue landed 02:39 (`ad748c1`) and
measured the battery at a **3/10 mutant kill rate** — calibration was demonstrably
incomplete after the extraction shipped. T292 (baselines + gate) is still
`dispatchable`.

There is a recorded, narrower justification: T273's brief
(`untracked/T273-kernel-ko-and-statekey.md:20-24`) argues T267's key-agreement
invariant is "the test that must reproduce a known defect *before* the extraction
moves anything — battery before code" in miniature; WAYPOINTS.md:41 repeats it, and
WAYPOINTS.md:82 records the reverse dependency (G3b's closure checks need the kernel).
The argument is defensible — but DIRECTION §5's phase ordering was never amended, no
ruling authorizes the substitution, and the gate Phase 0 declared ("gates everything
below") only gated on AXIOMS.md *existing*, not on phase order.

> **Annotation (2026-08-03, T304 absorption):** F3 was true when written — at
the time there was no ruling on phase ordering, and the gap it documents was
real. **Resolved by DIRECTION.md Amendment 2 (ruled 2026-08-03):** §5's phases
are a dependency plan, not a schedule; no phase gates the dispatch of another,
and "acceptance battery before code" binds **promotion, not dispatch**. T273's
kernel extraction therefore shipped within the ruling: both kernel claims were
held at `CLAIMED` ("pending Phase 3 end-to-end A–Z reverification",
`findings/T273-kernel-ko.json`; zero `PROVEN`), which is exactly what Amendment
2's mutation-adequacy promotion gate permits. The finding's corrective content
survives as Amendment 2's five dependency edges, mechanized as `needs` on the
tasks that carry them. The finding is not rewritten; this note records what
resolved it.

### F4. B1 now exists in three inconsistent statements under one claim ID

- **AXIOMS.md §2 B1:** single capture ∧ capturer has exactly one liberty ∧ **resulting
  position identical to the position two plies earlier**.
- **Kernel header `src/rules.zig:1014-1018`** (stamped `[GLOBAL.AXIOM-BASICKO:CLAIMED]`):
  single capture ∧ one liberty ∧ **no friendly neighbours** — the position-identity
  clause dropped, a conjunct added that B1 does not contain.
- **CLAIMS.md:408:** "one ply earlier" (F1).

The two live variants are plausibly extensionally equivalent, but that equivalence is
a lemma argued nowhere and tested nowhere. And the mechanized check AXIOMS.md §2
promises — "run differentially against the **seventeen** existing hand-written
copies" — is not what T273 delivered: the differential runs against `solverKoGeneric`
(`src/differential.zig:227`), a single transcription of the same shape formula, and
the in-file 2×2/3×2 "solver ko" references (`rules.zig:1110`, `:1155`) are inline
re-transcriptions of the same `liberties == 1 and friendly == 0` condition. T273's
own findings file says so honestly (`findings/T273-kernel-ko.json` §4: "not against
the fixture copies"). Exhaustive agreement between two transcriptions of one formula
cannot detect the formula being wrong against B1's position-identity definition. This
is the fourteen-divergent-ko-copies disease reappearing at the *specification* level.

### F5. The mechanized gate went dark during the one window it was needed

Current state is healthy: hook tracked at `tools/hooks/pre-commit`, installed via
`git config core.hooksPath tools/hooks` (set now), floor single-sourced and
machine-readable in `tools/hooks/claimlint-floor.json` (C1a=10, C1b=0, C2=14, C6=0,
pinned to `2432d71`), floor-non-regression not "green", C7 deliberately ungated,
controls rewritten by T280 to exercise the *hook* (`tools/regression-precommit.sh`,
wired at `build.zig:172-175`), fresh-clone tripwire in the suite, and a live refusal
observed by this audit (`seeded C1a=11 > floor 10 — blocking commit`, exit 1).

The history is the finding:

| time (+0200) | event |
|---|---|
| 22:46 | T272 closes `pass` with its deliverable **uncommitted and the hook never installed**; verdict never revised |
| 23:03 | `f9469d1` lands the work "preserved, NOT accepted"; controls violate the QA-023 rule the brief quoted |
| 23:38–23:46 | T280 fixes the controls; first genuine install, refusal verified |
| 23:48 | `8addb86` — deliberate uninstall (Orchestrator D016, fleet running) |
| 23:51 | `446c556` — T281 reinstalls (official; refusal observed) |
| ~23:52–00:22 | **hooksPath unset again — unattributed** (`e9ee023` explicitly declines to guess the cause) |
| 00:22 | `416fdcc` — T279 breaches the floor (C1a 10→13, C2 14→17, C6 0→4) with no refusal |
| 00:24 | `b475533` — T273 hits the red installed-ness check and commits over it as a "pre-existing env issue" |
| 00:28–00:39 | `e9ee023` names the breach; T284 (`7f7761e`) restores the floor **at** (not above) recorded values, reinstalls, proves a refusal |

Residues: (a) the uninstall mechanism was never found, so the silent-off failure mode
remains available until the next `zig build test`; (b) `core.hooksPath` is per-clone
with only a test-suite tripwire, no auto-install; (c) tasks.json still records T272
`verdict: pass, verdict_note: null`, contradicted by `f9469d1` ("this commit accepts
nothing") — the kanban record alone misleads. (d) New instrument bug found live by
this audit: **claimlint truncates its output to 491 bytes when stdout is redirected
to a regular file** (pipe and TTY produce the full ~31 KB; the hook uses a pipe and
is unaffected; any file-redirect consumer gets garbage — likely a Zig File.Writer
flush bug in `src/claimlint.zig`).

### F6. Hand-maintained surfaces re-rotted within hours — the CA-2 pattern again

- `WAYPOINTS.md:18` still says Phase 0 = "**T271 open** — gates everything below" and
  `:20` says "T273 blocked"; both closed `pass` on 2026-08-02 (tasks.json). The file
  *was* revised in place afterward (`540a275` added the Phase 1 section around the
  stale table) — stale by its own maintenance contract (`WAYPOINTS.md:3`).
- AXIOMS.md §5 (line 386) still lists `GLOBAL.TIE-MIGOS` as CLAIMED with the refuted
  claim text, contradicting its own §4.2/§4.4 and CLAIMS.md:421 (FALSE-AS-SCOPED);
  the §5 status note (lines 389-391) is likewise stale.
- AXIOMS.md §3 Z-STATE-KEY (line 219) says T267 is "outstanding" — T267 closed
  2026-08-02 20:43Z, and the file was edited four times afterward without correction.
- `4x4.BASICKO-TIE` (CLAIMS.md:479) carries the T271 correction but still names the
  tie-semantics explanation that T274/T279 refuted — corrected-as-of-T271,
  stale-as-of-T279.

---

## 2. What is genuinely excellent

- **AXIOMS.md is the best axioms document this project has produced**: five explicit
  falsification criteria on Z (§1.1), five non-claims stated as part of the theorem
  (§1.2), every axiom born with a claim ID, all 22 minted register rows verified
  present under CLAIMS.md §2.6a and correctly CLAIMED-not-PROVEN, and evidence
  citations that check to the line (A6's 516,242 terminal flags =
  `docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162` exactly).
- **The MIGOS adjudication (§4) is a model of the method**: primary sources obtained
  and read in full (van der Werf 2005; van der Werf & Winands 2009), *both* candidate
  explanations tested, the +2 anchor refuted as a **different game** (pass-difference
  cycle resolution), an empirical five-value TIE sweep confirming the fixpoint is
  TIE-free on every state of three gobans, and the residue stated honestly (our own
  +1 still owes the #2 auditor).
- **Verification had teeth**: T271's review found three real defects before acceptance
  (A5 vs B2/B3; the B1 ply count; "not a bug" withdrawn), and Amendment 2 refused to
  accept an unshown derivation and wrote it out. T284 restored the breached floor
  *at* the recorded values rather than ratcheting it up ("a floor that rises when
  breached is a high-water mark").
- **The gate as it stands today** is exactly what DIRECTION prescribed, and its
  controls pass under this audit's own hands.
- **T273's findings file is honest about its limits** — it states plainly that the
  differential ran against `solverKoGeneric`, not the fixture copies. The gap is
  real (F4), but the record does not hide it.

---

## 3. Action plan

Ordered by leverage. Items 1–5 are registerable as tasks; acceptance criteria are
stated so `managent done` can enforce them. Briefs never name a model.

### A1 — Absorption: sync the register and both phase docs to reality *(fixes F1, F6)*

Deliverables:
1. `CLAIMS.md:408` (`GLOBAL.AXIOM-BASICKO`) restated to Amendment-1 text ("two plies").
2. `CLAIMS.md:406` (`GLOBAL.AXIOM-PASS`) restated ("clears the ko point").
3. Two new register rows recording Amendment 1 (T275) and Amendment 2 (Orchestrator)
   as axiom-change events, per AXIOMS.md:12-14.
4. AXIOMS.md §5: TIE-MIGOS row → FALSE-AS-SCOPED; status note (lines 389-391) corrected.
5. AXIOMS.md §3 Z-STATE-KEY: "outstanding" → done, cite T267 close.
6. `4x4.BASICKO-TIE` (CLAIMS.md:479): append the T279 correction (surviving
   explanation = different game, not tie semantics).
7. WAYPOINTS.md five-phase table state column refreshed (Phase 0 done; T273 done;
   Phase 1 = T292 open).

Acceptance: `grep -c "one ply" docs/epistemic/CLAIMS.md` returns 0 on axiom rows;
claimlint exit unchanged vs floor; `grep "T271 open" docs/epics/E1-markovian/WAYPOINTS.md`
empty.

### A2 — Register the 282-row mapping task *(fixes F2)*

The deferred Phase 0 deliverable, registered before any Phase 3 decomposition: map
every register row onto the requirement tree (§3 of AXIOMS.md); rows mapping nowhere
are proposed-retired (dispositions, not deletions); tree nodes with no row are listed
as new work. Deliverable: a tracked mapping table + a claimlint-checkable convention
(each row's tree node in its row, so staleness is lintable rather than prose).
Acceptance: row count in the mapping == row count in CLAIMS.md; zero unmapped rows
without a disposition.

### A3 — Unify B1's three statements *(fixes F4)*

1. Kernel header at `rules.zig:1014-1018` quotes AXIOMS.md B1 **verbatim**.
2. Either (a) register the shape-rule ⇔ position-identity equivalence as a tree lemma
   under Z-R-MOVE with a test that constructs the two-ply position comparison and
   checks it against `koAfterCapture` exhaustively at 2×2/3×2 (this is the only check
   that can catch the formula being wrong, not just mistranscribed), or (b) restate
   B1 in shape form by recorded amendment (dated entry + register row).
3. Honor or amend the §2 promise: one differential run of the kernel against the
   actual in-solver ko code paths (`exp6_solve.zig:285/575/909`), not only
   `solverKoGeneric` — or amend §2 to state what was actually run.

Acceptance: one B1 text reachable from the claim ID; the new lemma test wired into
`zig build test`.

### A4 — Close the gate's silent-off hole *(fixes F5 residues a–c)*

1. Add an installed-ness check (`core.hooksPath == tools/hooks`) to a surface that
   runs every session — `bin/managent resume` self-check is the natural host — so an
   unset is caught at the next resume, not the next full test run.
2. Attempt one attribution pass on the 23:52–00:22 unset (shell history, managent
   deploy paths, anything that runs `git config`); record the outcome either way.
3. Annotate T272 in tasks.json (verdict_note) pointing at `f9469d1`/T280/T281 so the
   kanban stops contradicting git. T295's skip-acceptance audit is the precedent.

Acceptance: resume output shows the check; T272's note present.

### A5 — Rule on the Phase 1/2 ordering *(fixes F3)*

A human ruling, recorded in WAYPOINTS.md (and DIRECTION amendment if granted): either
(a) ratify the T273 brief's argument — a scoped extraction may precede full battery
calibration when a defect-reproducing invariant (T267-class) exists for the exact
function moved — or (b) reaffirm strict ordering and require T292 to complete before
any further Phase 2 task dispatches. Either way the gate becomes checkable: Phase 2
tasks carry `needs` on the ruling's condition, not on convention.

### A6 — File the claimlint truncation bug *(fixes F5 residue d)*

Register: claimlint emits 491 fragmented bytes when stdout is a regular file
(reproduce: `bin/weizigo-claimlint > /tmp/out`); pipe/TTY fine. Suspect File.Writer
flush/positioned-write in `src/claimlint.zig`. Not gate-affecting today (hook uses a
pipe) — but it is an instrument that lies under redirection, and the project has a
word for that.

---

## Coda

Phase 0 proved the project can write a theorem worth proving and adjudicate its
hardest open question against primary sources. What it did not prove is that the
paperwork keeps up with the work: every finding above is a divergence between two
copies of the same fact — axiom vs register, doc vs kanban, promise vs delivered
check — and the project already owns the doctrine that names this (one owner per
fact, mechanized or re-learned). The A1–A6 plan is small precisely because the
machinery to hold these fixes already exists; it only needs to be pointed at the
surfaces Phase 0 added.
