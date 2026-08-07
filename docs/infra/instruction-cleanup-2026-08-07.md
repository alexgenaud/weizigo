# Instruction corpus cleanup — 2026-08-07

Task: T413 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-07
Source: `docs/infra/instruction-audit-2026-08-07.md` (T410, 16 findings, 10 proposals)
Commit: see git log for `docs/infra/instruction-cleanup-2026-08-07.md`
Acceptance: `test -s docs/infra/instruction-cleanup-2026-08-07.md`

**This row EXECUTES the T410 proposals and the Part B Ollama-cap correction. It
does not re-audit.** Findings are cited as F01–F16 per the audit doc.

---

## 0. Verdict

| disposition | count | findings |
|---|---|---|
| executed | 10 | F01, F02, F03, F04, F05, F06, F07, F13, F15, F16 |
| deferred (no action, reason recorded) | 5 | F08, F10, F11, F12, F14 |
| disputed (premise refuted, left open) | 1 | F09 |
| **total** | **16** | F01–F16 |

Every executed fix was verified by running it (path checks, `git` checks,
grep over the corpus); none was applied on looks-right. The one disputed
finding (F09) is refuted by evidence and left open for the Orchestrator
rather than silently skipped (brief rule 4).

---

## 1. Diff summary per file

### `AGENTS.md` (repo root) — F03 executed (misleads, foreclosures section)

Two stale `research/ruleset-options.md` links (lines 15, 19) → `docs/research/ruleset-options.md`.
Verified: `test -f docs/research/ruleset-options.md` passes. These sit in the
non-negotiable foreclosures block every agent reads, so the fix is 2 lines in
the most load-bearing file.

### `docs/epistemic/GLOSSARY.md` — F02 executed (breaks work)

Two broken links the Argus watchdog has flagged since 2026-08-01:
- line 41 `research/ruleset-options.md` → `../research/ruleset-options.md`
- line 142 `research/ghi-and-superko.md` → `../research/ghi-and-superko.md`

Verified both targets exist from `docs/epistemic/` (`../research/...` resolves).
The other four `../research/...` links in the file (51, 66, 181, 194) were
already correct and untouched.

### `docs/INDEX.md` — F01 + F06 executed (misleads, clutter)

- **F01** line 88: role list `Overseer, Advisor, Theorist, Orchestrator,
  Auditor, Dabir` → `Dabir, Auditor, Orchestrator` (the three thinking-manager
  seats in `ROLES.md`), with a note that Overseer/Advisor/Theorist are legacy
  names from the 2026-07-28/29 handovers. ROLES.md verified as authoritative —
  it lists exactly Dabir, Auditor, Orchestrator.
- **F06** attic table: removed the `docs/infra/sprint.md` row ("RATIFIED rev 4…").
  Verified sprint.md is an active document: `docs/infra/roles/DABIR.md` cites it
  as the sprint-design authority and records the un-retirement ("Retire nothing
  that prevents a known failure mode"). All other attic rows preserved.

### `docs/status/HANDOVER.md` — F04 executed (misleads, the read-first template)

All six `CURRENT.md` references replaced or annotated per the T286 ruling
(CURRENT.md retired 2026-08-03; the composed surface is `bin/managent resume`):

1. header purpose line — "in-flight task state lives in `bin/managent resume`
   (`CURRENT.md` was retired 2026-08-03, T286)"
2. read-order item 3 — `bin/managent resume`, noted as the replacement
3. read-order item 7 — marked CURRENT.md retired; surface today is `managent resume`
4. one-writer-per-file gotcha — intent line now via kanban `holds=` field
   (`managent show <id>`); CURRENT.md marked retired
5. dirty-tree critical-state line — marked historical, not recoverable via resume
6. next-actions "Detail in" line — CURRENT.md marked retired

Where the reference records a 2026-07-27 session fact (the dirty-tree table),
it is **marked historical, not rewritten** — `bin/managent resume` shows today's
kanban state, not that session's table (brief rule 1: fix the instruction, do
not delete the history).

### `docs/infra/delegation/DELEGATEE.md` — F15 + F16 executed (misleads)

- **F15 (P7)**: new standalone section **"Before you work — export your task
  identity (T370, 2026-08-06)"** directly after "The first thing you do",
  with the `export MANAGENT_TASK_ID=<id>` step bolded and in a code block —
  no longer buried in the runner paragraph. The old "Carry your identity"
  paragraph now points to the new section instead of repeating the command
  (one canonical home per rule).
- **F16 (P6)**: new section **"Verification hygiene — scratch paths, never
  deliverable paths"** after "Your context is fresh", documenting the T405
  near-miss (`findings/T401-bracket-tournament-4x4.json` overwritten by a
  control run without `--json`): verification runs write to
  `/tmp/weizigo/`, never to a committed deliverable path.

### `docs/infra/dispatch/README.md` — F07 + F05 executed (clutter, misleads)

- **F07 (P9)**: banner added at the top: **ALL EXPERIMENTS BELOW ARE CLOSED —
  historical record**; current dispatchable work comes from `bin/managent
  status` / `untracked/` bundles. Chose the one-place banner over deleting ~80
  briefs: cheaper, reversible, keeps the record, and matches the audit's own
  recommendation. Read-order step 6 also annotated as historical.
- **F05**: the same banner covers the stale `docs/status/CURRENT.md`
  instructions inside the closed EXP-N briefs — they are now explicitly
  historical, so an agent reading an EXP brief for context is told the
  mechanism is retired. The eight EXP briefs themselves were left untouched
  (historical records, per audit rule).

### `docs/infra/subagent-reach-2026-08-07.md` — Part B executed (false claim)

See §2 below. Correction banner + retracted sentence + decision-table cells
+ concurrency-section interpretation all updated to the standing wording.

### `docs/status/sprint-2026-08-08.md` — Part B executed (citation corrected)

The T408 concurrency bullet now carries the mandatory caveat alongside the
not-observed-through-6 phrasing (see §2).

### `untracked/T410-instruction-file-audit.md`, `untracked/T413-instruction-corpus-cleanup.md` — F13 executed

Short-name questions added to both brief titles in the
`T<n> (does…?)` shape the AGENTS.md landmark rule requires:
- T410: "(what does the instruction corpus disagree about, and where do the
  rules nobody follows live?)"
- T413 (this row's own brief): "(do the ruled-on instruction-corpus fixes
  land, and is the false Ollama-cap claim corrected everywhere it is cited?)"

The audit's F13 also noted most kanban rows lack short names. Scanning and
amending the whole kanban is a re-audit, not an execution — recorded here as
a follow-up, not done.

---

## 2. Part B — the Ollama cap correction

**The false sentence:** *"If a ceiling exists it sits above 6 and was not
hit."* — `docs/infra/subagent-reach-2026-08-07.md` (T408 doc).

**Operator ruling (2026-08-07):** there IS a five-agent Ollama cap; what is
unknown is only how it is enforced (a sixth simultaneous upload/download is
most likely queued or delayed rather than refused, so it never surfaces as an
error). The 6-concurrent probe completed in nine seconds on warm sessions with
a trivial payload and **could not have detected a transfer-session cap** — the
instrument lacked the power to observe what it is cited about.

**What was changed, per the standing wording supplied in the brief:**

1. `docs/infra/subagent-reach-2026-08-07.md`:
   - correction banner at the top (retracts the sentence, states the cap
     exists, explains why the probe could not see it, notes the findings file
     is untouched because T408's own wording was accurate)
   - bottom-line summary — now reads "**not observed** as a tool-level cap
     (caveat: … **the cap exists at five**)"
   - decision-table "safe concurrent count" column — `≥6 observed (pool-wide)`
     → `≤5 (operator ruling); probe through 6 could not detect a transfer-session
     cap` (all three rows)
   - §3 concurrency paragraph — the "sits above 6" sentence replaced with the
     standing wording: cap at five, probe lacked power, absence of observed
     effect is not evidence of absence, may choose not to work around it while
     no side effect appears, must not claim there is no cap, binding constraint
     remains max-two-concurrent per parent
2. `docs/status/sprint-2026-08-08.md` — T408 concurrency bullet now quotes the
   not-observed-through-6 phrasing **together with the caveat**, per the
   ruling's requirement that the two travel together.

**Corpus grep for other citations:** `grep -rn "sits above 6"` and
`grep -rn "not observed as a tool-level cap"` over `docs/` and `untracked/`:

| location | disposition |
|---|---|
| `docs/infra/subagent-reach-2026-08-07.md` | corrected (retraction banner) |
| `docs/status/sprint-2026-08-08.md` | corrected (caveat added) |
| `untracked/T414-sprint-loops-and-cleanup.md` | already teaches the correction (audit gate #7: "absence of an observed effect is not evidence of absence") — no change |
| `docs/infra/managent/tasks.json` (T408 amendment) | the ruling's own record — contains the standing wording; no change |
| `docs/status/handover-orcha-2026-08-05.md` (2026-08-05 ruling) | states the five-agent ceiling is the Ollama pool only — consistent with the correction, never claimed absence; no change |

**`findings/T408-subagent-reach.json` was NOT edited** — findings are
immutable; T408's own wording ("not observed as a tool-level cap through 6")
was careful and accurate. The overstatement was the Orchestrator's, and the
correction belongs in the docs, which is where it now lives.

---

## 3. Deferred findings — reasons recorded (none silently skipped)

| finding | severity | reason deferred |
|---|---|---|
| F08 — `docs/AGENTS.md` stray fragment | clutter | audit itself: "No action needed — the redirect works." Evidence docs cite its line numbers; removing it would break citations. |
| F10 — canonical model labels in DELEGATEE.md | clutter (intentional) | audit verdict: intentional duplication for discoverability; `managent` rejects non-canonical labels at write time, so drift fails loudly. |
| F11 — one-writer-per-file in three docs | clutter (acceptable) | audit verdict: each copy serves a different reader; `holds=` now enforces mechanically. |
| F12 — landmark rules in AGENTS.md + LANDMARKS.md | clutter (acceptable) | audit verdict: the two compose rather than duplicate. |
| F14 — bare landmark IDs slip through occasionally | misleads | usage discipline, no mechanical fix proposed by T410; only two observed instances (both in sprint reports, already contextualised). Enforcing would need a lint instrument — out of scope for a doc-only row. |

## 4. Disputed finding — F09, premise refuted (left open for the Orchestrator)

**F09 / P10 claimed `HUMAN.md` is "tracked as an empty file" and should be
gitignored or given content. The premise is false — the end state the proposal
wants already exists:**

- `git ls-files HUMAN.md` → empty (not tracked)
- `git log --all -- HUMAN.md` → no commits (never tracked)
- `git show HEAD:HUMAN.md` → "path 'HUMAN.md' exists on disk, but not in 'HEAD'"
- `git check-ignore -v HUMAN.md` → `.gitignore:27:/HUMAN.md` (already ignored)
- `git status --porcelain --ignored=matching HUMAN.md` → `!! HUMAN.md` (ignored,
  invisible to `git status`)

So the empty file is on disk, ignored, and untracked — exactly the doctrine
`docs/infra/human-decisions.md` states ("the repo-root `HUMAN.md` is the
operator's private scratch file and is gitignored — nothing canonical belongs
there"). T410's file listing misread an ignored file as tracked. **No edit was
made.** Per brief rule 4, the disagreement is recorded here with evidence and
the finding is left open: if the Orchestrator still wants the empty file gone
from disk, that is a one-line `rm` the operator's own scratch file — not a doc
edit.

---

## 5. Bars checked

- Documentation only. No code, engine, artifact, axiom, or `CLAIMS.md` edits.
- Findings file conforms to `findings/README.md` schema and passes
  `bin/weizigo-claimlint`.
- Diff summary per file in §1; executed / deferred / disputed counts with
  denominators against T410's 16 in §0.

**Landmark:** advances `L4 (the ledger is clean)` — the ruled-on corpus fixes
are now in the tree: no agent following AGENTS.md/GLOSSARY.md hits a dead
`research/` path, no console reading HANDOVER.md or an EXP brief is taught a
retired read order, the identity-export step and verification hygiene are
documented where a worker looks, and the false Ollama-ceiling claim is
corrected in the doc that carried it and in the sprint report that cited it.
What remains between here and L4: the kanban-wide short-name scan (F13
residue), ratification of the F09 premise-refutation, and whatever the
Orchestrator's own review finds.

— deepseek-v4-flash/T413
