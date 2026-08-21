# Sprint bookend disposition — 2026-08-01

```
Role: worker · Task: T219 · Model: DSFlash/T219 · Date: 2026-08-01
Brief: untracked/T219-sprint-bookend-disposition.md
Scope: the four sprints under docs/epics/E1-markovian/sprints/ with no
  accept.md — argus, knowledge-capture, orcha-tools, subagent-harness.
  oracle-v2 and verify-battery are excluded (still seeking G3).
Method: per sprint, read the sprint's own spec.md acceptance criteria and
  answer against evidence on disk (commits, code, logs, fixtures) — not
  against the kanban saying "done".
Constraint honoured: no accept.md written, no spec header edited. The
  proposed one-line spec-header texts below are for the Orcha to apply.
```

## Summary of verdicts

| sprint | verdict | missing (if not closeable) |
|---|---|---|
| argus | **NOT CLOSEABLE** | spec §5 A1/A2/A4/A5/A7 acceptance evidence — the M4 bundle (`docs/evidence/ARGUS/`) was never produced; G1 (human) approval unrecorded |
| knowledge-capture | **CLOSEABLE** | — |
| orcha-tools | **CLOSEABLE** | — (A1 FAIL at T196 is discharged by T204, evidence below) |
| subagent-harness | **NOT CLOSEABLE** | A4 partial — no T169-notes.md retrofit; spec R2/R4 reference the superseded schema location |

---

## 1. argus — NOT CLOSEABLE

### What the spec promised

`docs/epics/E1-markovian/sprints/argus/pass0/spec.md` (revision 1, audited
PASS by T161 — `archive/spec.audit-1.md`, absorbed `082433e`): a read-only
watchdog, 14 requirements, two modes (checklist, sweep), an append-only log
and a summary, with **seven acceptance criteria** (§5):

| id | criterion | evidence on disk (2026-08-01) |
|---|---|---|
| A1 | known-bad calibration — three seeded defects produce exactly three violations | **NOT EVIDENCED.** `docs/evidence/ARGUS/` (the spec's own M4 deliverable path) does not exist; `untracked/watchdog.md` (196 KB log, runs through 19:06Z today) contains **zero** hits for `seeded|calibrat|phantom` |
| A2 | mode-1 phantom rate, adjudicated by a different seat, with denominator | **NOT EVIDENCED.** No adjudication record found |
| A3 | append-only, proved mechanically (run 2 contains run 1 as byte prefix) | **PARTIAL.** Log is append-only JSONL by construction (`untracked/watchdog.md`, run-marker + finding entries, `bin/argus`); the mechanical double-run proof is not recorded |
| A4 | summary reconciles to the log by a non-producer | **NOT EVIDENCED.** `untracked/watchdog-summary.md` exists and is current (19:06Z); the recount proof is not recorded |
| A5 | read-only, proved mechanically (`git status --porcelain`) | **PARTIAL.** The tool writes only the two allowlisted git-ignored files (`untracked/watchdog.md`, `untracked/watchdog-summary.md` — R3); the mechanical proof is not recorded |
| A6 | consumer-load — Orcha reads the summary and acts | **SUBSTANTIALLY MET post-audit.** CA-11's gap (findings unread, no cadence) closed by T207 (`c9cf609` — ORCHESTRATOR.md now has Argus as cadence step 0, line 13); and the Argus CRITICAL demonstrably drove tasks: `artifact-loadable` FAIL → T208 triage (b5352b9) → T216 re-test (`707015f`, `docs/evidence/GLOBAL.ARGUS/artifact-loadable-T216-2026-08-01.md`). T211 re-baselined from orphan-gate drift (30dd956) |
| A7 | cost reported (wall/turn/token, artifact-load broken out) | **NOT EVIDENCED.** No cost record found |

### What actually landed, at which commit

- T161 spec audit PASS — absorbed `082433e` (`archive/spec.audit-1.md`).
- T195 build + T199 implementation — absorbed `1582294` (origin of
  `bin/argus`, `docs/infra/roles/ARGUS.md`,
  `docs/epics/E1-markovian/sprints/argus/checklist.md`).
- T208 evidence/Argus triage — `b5352b9` (re-baselined orphan-gate;
  CA-5 evidence promotion).
- T211 baseline disposition — `30dd956` (three cry-wolf fixes: summary
  uses most-recent baseline, retention rule for SHA256SUMS-pinned
  artifacts, claimlint graded against the honest-debt floor).
- T216 artifact-loadable re-check — `707015f` + evidence at
  `docs/evidence/GLOBAL.ARGUS/artifact-loadable-T216-2026-08-01.md`:
  all 10 SHA256SUMS-pinned artifacts load with a raised ceiling;
  `oracle-3x2.wzo` loads in 0.3 s — T208's ceiling diagnosis confirmed,
  not a regression.
- T220 (argus-learns-today) — **open**, evolving the checks (hash-drift,
  never-heartbeated in_progress, register-row-suspicion, acceptance-never-ran).
- Live today (T219 probe): `bin/argus --mode checklist` → exit 0,
  2 violations logged (stale-in-progress = T212+T219; orphan-gate
  findings=12 vs baseline 1) — the watchdog works.

### Verdict

**NOT CLOSEABLE.** The tool is live, healthy, and being actively evolved
(T220), but the sprint's own acceptance criteria A1, A2, A4, A5 and A7
have **no recorded evidence** — the spec's M4 deliverable
(`docs/evidence/ARGUS/`: seeded-defect calibration, adjudicated phantom
rate, double-run byte-prefix, recount, read-only proof, cost numbers) was
never produced. A3 and A5 are satisfiable by construction but their
mechanical proofs are unrecorded. Additionally, the spec's approval gate
is "human only" and T161's audit ended "ready for the human gate (G1)" —
**no G1 grant is recorded anywhere I found.** A bookend written now would
convert seven open questions into a false record.

**Proposed one-line spec-header text (for Orcha; not applied):**
`ACTIVE — built T195/T199 (1582294), live since 2026-08-01, CRITICALs
dispositioned (T208/T216), routing promoted (c9cf609); NOT CLOSEABLE —
spec §5 A1/A2/A4/A5/A7 evidence (M4 → docs/evidence/ARGUS/) outstanding;
G1 approval unrecorded`

---

## 2. knowledge-capture — CLOSEABLE

### What the spec promised

`docs/epics/E1-markovian/sprints/knowledge-capture/pass0/spec.md`
(revision 1): standardised findings JSON (R1), claimlint C7 check (R2),
absorption tool (R3), absorption log as tool by-product (R4). Acceptance:
A1 — T129 gap (QA-027 falsified at 4×4, register said CLAIMED) flagged by
claimlint; A2 — absorption tool generates correct diff for T172 GAP-5;
A3 — after absorption, claimlint exits 0 for that task's findings.

### What actually landed, at which commit

- T188 plan+design, T194 build — absorbed `1582294`: `findings/README.md`
  (canonical schema), fixtures `findings/T129-qa027.json` +
  `findings/T172-gap5.json`, C7 in `src/claimlint.zig`, `src/absorb.zig`
  (D1–D5 of plan.md all present).
- T198 C7 backlog — `a20ad8f` (0 unabsorbed).
- T206 absorb deploy — `88a657a` (`weizigo-absorb` → `bin/`).

### Acceptance evidence

- **A1 — SATISFIED.** `findings/T129-qa027.json` proposes QA-027 →
  FALSE-AS-SCOPED with rationale and evidence path; the register row
  (`docs/epistemic/CLAIMS.md:575`) now reads FALSE-AS-SCOPED (absorbed
  `622275f`); claimlint C7's flagging mechanism is calibrated — its
  embedded known-bad 6 is precisely the "findings says FALSE-AS-SCOPED,
  register says PROVEN → must be CAUGHT" case, and it passes every run.
  C7 today: 0 unabsorbed.
- **A2 — SATISFIED.** `weizigo-absorb` is live and correct: dry-run today
  on `findings/T172-gap5.json` emits
  `{"directive":"noop","claim_id":"CODE.VB-BLINDGAPS","note":"new-row already
  in register with matching status PROVEN"}` — i.e. the T172 GAP-5 diff was
  generated and absorbed (CODE.VB-BLINDGAPS is in the register as PROVEN),
  and the tool now converges on the register state.
- **A3 — SATISFIED.** claimlint exits with C7=0; both fixtures are
  absorbed (QA-027 status matches; CODE.VB-BLINDGAPS absorbed).

### Verdict

**CLOSEABLE.** All three acceptance criteria satisfied with on-disk
evidence; the tool chain (findings/ → C7 → absorb → absorption log at
`untracked/absorption.md`) is in daily use (T205, T210, T211, T213, T216,
T217 findings files all live in `findings/`).

**Proposed one-line spec-header text (for Orcha; not applied):**
`RATIFIED — built T188/T194 (absorbed 1582294), C7 + absorb live; A1–A3
evidenced (T129/T172 fixtures, C7=0, absorb dry-run converges)`

---

## 3. orcha-tools — CLOSEABLE (A1 FAIL discharged by T204)

### What the spec promised

`docs/epics/E1-markovian/sprints/orcha-tools/pass0/spec.md` (revision 1):
R1 `managent suggest` mints a T-ID + bundle + prompt line; R2 `done`
verifies declared deliverables on disk; R3 `audit` flags done tasks whose
deliverables are uncited. Acceptance: A1 suggest happy path; A2 missing
deliverable → non-zero exit, stays in_progress; A3 audit flags
T129's QA-027 finding when uncited.

### What actually landed, at which commit

- T159 build + T160 review — absorbed `082433e` (suggest / done-check /
  audit-flag implemented in `src/managent/main.zig`).
- T196 consumer acceptance — `b37ec92` (report) / `e08f95e` (absorb):
  **A2 PASS, A3 PASS, A1 FAIL** — with `_sys.next_id=165` drifted,
  `suggest` minted T165 over the done T165 record (attribution + audit
  trail destroyed); reproduced in sandbox on T165 and T202.
- T204 root fix — `a98bf04` (audit CA-1): `parseStateJson` reconciles
  `sys_next_id = max(parsed T-ID)+1` on load (`src/managent/main.zig:672-673`);
  `audit` flags `next_id ≤ max T-ID` (:3186-3198); regression
  `tools/regression-managent-integrity.sh` written red→green. Gate-verified
  by Fable (integrity 3/3, memsafety 8/8, peek no-write).

### Does T204 discharge A1? — YES, with evidence

- The T196 report's own recommended next step was "rerun A1 against the
  fix, same sandbox harness; happy-path probes are the known-good, the
  T165/T202 repros the known-bad". The regression test IS that rerun: it
  seeds a store with `next_id=100` while T105 exists, runs `suggest`, and
  asserts (a) suggest auto-corrects to T106, (b) the T105 record and
  bundle survive, (c) audit flags the seeded collision. **I ran it today:
  `T204/T209/T213/T217: ALL CHECKS PASS`** (the suite also exercises the
  done-deliverable check and the acceptance field, keeping A2 covered).
- A2 remains exercised: regression done-deliverable refusal + T217's
  `acceptance=` execution paths (seen live in the same run:
  missing deliverable → REJECTED, stays in_progress).
- A3 remains live: `audit` produces citation WARNs (12 findings in my
  live probe today) and now also the next_id collision check.

### Verdict

**CLOSEABLE.** A1 FAIL at T196 is discharged by T204's root fix + the
red→green regression; A2/A3 passed at T196 and are still exercised by the
regression suite and live runs. This is the one sprint of the four where
the kanban's "done" initially looked like a rubber stamp — the evidence
shows the fix is real (code + green regression + Fable gate), not an
acceptance relabelled.

**Proposed one-line spec-header text (for Orcha; not applied):**
`RATIFIED — T196 acceptance 2026-08-01: A1 FAIL → discharged by T204 root
fix (a98bf04, regression green); A2/A3 PASS`

---

## 4. subagent-harness — NOT CLOSEABLE (narrow gap)

### What the spec promised

`docs/epics/E1-markovian/sprints/subagent-harness/pass0/spec.md`
(revision 1): three deliverable files, no code — subdelegation.md prompt
wrapper (R1), findings schema at `untracked/T<id>-findings.json` (R2),
manager brief template (R3), manager absorption handoff (R4). Acceptance:
A1 wrapper dispatch auto-claims + writes a findings file; A2 findings file
passes JSON schema validation; A3 manager brief generates
T173-equivalent coordination; A4 existing `untracked/T169-notes.md` and
`untracked/T172-blind-analysis.md` can be retrofitted to the schema by
hand as proof.

### What actually landed, at which commit

- T179 build — absorbed `a20a87f` (`docs/infra/agents/subdelegation.md`
  wrapper, `findings-schema.json`, `manager-brief-template.md`).
- T207 schema unification (CA-4) — `c9cf609`: all three files rewritten
  to the **knowledge-capture** schema — `findings/<TASKID>-<slug>.json`,
  `findings/README.md` canonical, `docs/infra/agents/findings-schema.json`
  is the machine-readable copy "must not diverge".
- T209 dispatch ergonomics — `2ccfe9f` (model bound at dispatch time).

### Acceptance evidence

- **A1 — SATISFIED-BY-CONSTRUCTION, not witnessed post-fix.** The wrapper
  (`subdelegation.md` §Prompt wrapper, lines 58-105) mandates
  claim → findings at `findings/<TASK-ID>-<slug>.json` → done, and
  forbids `done` before a findings write. The only witnessed subagent
  chains (dogfood #2: T189→T195, T190→T197) predate the T207 unification
  and exhibited exactly the CA-4 failure (findings to the wrong schema);
  no dispatch under the corrected wrapper is on record.
- **A2 — SATISFIED.** `findings-schema.json` is a faithful machine copy
  of `findings/README.md`; nine `findings/*.json` files parse (claimlint
  consumes them daily).
- **A3 — SATISFIED.** `manager-brief-template.md` exists and was used in
  practice (the T189→T195 / T190→T197 chains per dogfood #2 retrospective).
- **A4 — PARTIAL.** The T172 half is proven: `findings/T172-gap5.json`
  is a schema-conformant capture of exactly the GAP-5 finding from
  `T172-blind-analysis.md` (created by the sibling knowledge-capture
  build, T194). The **T169 half is not in evidence**: no
  `findings/T169-*.json` exists; T169's table-invariant substance reached
  the register via T174–T176 absorption, but not as a schema retrofit.
- **Spec staleness:** R2/R4 name `untracked/T<id>-findings.json` and
  `untracked/absorption-<date>.json` — both superseded by
  `findings/T<id>-<slug>.json` + the absorb log (T207 unified the docs,
  the spec text was not revised).

### Verdict

**NOT CLOSEABLE** — the gap is narrow and concrete: A4's T169 retrofit
artifact is missing, and the spec text references a superseded schema
location (the deliverables themselves are live and aligned). Closing
requires either the T169 retrofit proof or an explicit descope ruling on
A4 by the Orcha under D-19.

**Proposed one-line spec-header text (for Orcha; not applied):**
`BUILT T179 (absorbed a20a87f); schema unified with knowledge-capture by
T207 (c9cf609); NOT CLOSEABLE — A4 partial (T172 proven via
findings/T172-gap5.json; T169 retrofit absent); R2/R4 cite superseded
untracked/T<id>-findings.json location`

---

## Notes for the Orcha (judgment calls that are not mine)

1. **argus G1** — the spec's approval is "human only". If the human
   considers the 2026-08-01 build + live operation to be the grant,
   record that; otherwise the G1 question stays open alongside the
   acceptance evidence.
2. **subagent-harness A4 descope** — D-19's "whoever specs, accepts"
   makes this the Orcha's call: accept `findings/T172-gap5.json` +
   register absorption as the A4 proof and descope the T169 half, or
   require the retrofit.
3. **`docs/evidence/GLOBAL.ARGUS/`** (T216) vs the spec's `docs/evidence/ARGUS/`
   — the naming differs; if argus acceptance evidence is produced, pick
   one home for it (evidence/README.md:218's naming rule).

— DSFlash/T219, disposition report, 2026-08-01
