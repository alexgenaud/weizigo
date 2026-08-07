# Instruction corpus audit — 2026-08-07

Task: T410 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-07
Commit audited: `0c5c232d21cf52ce14c009536cd64e594bbd4bd7`
Acceptance: `test -s docs/infra/instruction-audit-2026-08-07.md`

**This row AUDITS and PROPOSES. It does not rewrite.** The prioritized proposal
is in §8; every finding is numbered F01–F16 for cross-reference.

---

## 0. Corpus inventory

**215 files, 27,882 lines** (excluding `untracked/` channel messages and `docs/evidence/`).
Coverage: every file listed below was opened and read at least partially;
every contradiction/duplication candidate was checked against its counterpart.
Files that are short or clearly historical were read in full; long files
(CLAIMS.md, model-perf.md, PROGRESS.md) were read by targeted section. Declared
partial coverage: `docs/evidence/` (124 files, unread — evidence stores, not
instruction) and `docs/epic-01-markovian/sprints/` (not in the routing path).

| directory | files | lines | read |
|---|---|---|---|
| root (`AGENTS.md`) | 1 | 358 | full |
| `docs/infra/` (including `delegation/`, `roles/`, `agents/`, `dispatch/`, `managent/`, `host/`) | 85 | 12,034 | full (short) + sampled (long: spec.md @ 637L, model-perf.md @ 3,215L) |
| `docs/status/` | 16 | 1,937 | full |
| `docs/epistemic/` | 19 | 6,305 | targeted (CLAIMS.md ~100L of 1201; PROGRESS.md full; GLOSSARY.md full) |
| `docs/decisions/` | 22 | 2,421 | headers only (ADRs are historical record, not instruction) |
| `docs/audits/` | 31 | 6,925 | headers + DIRECTION.md |
| `docs/engine/` | 2 | 429 | headers |
| `docs/` (root: INTENT.md, INDEX.md, about-this-document.md, references.md, AGENTS.md) | 9 | 386 | full |
| `docs/research/` | 29 | 6,214 | headers only (historical findings, not instruction) |
| `findings/README.md` | 1 | 93 | full |
| `HUMAN.md` | 1 | 0 | empty file |

**Files the brief listed that do not exist:**
- `CLAUDE.md` — does not exist. AGENTS.md line 4 mentions it in context of harness mechanics ("Harness prefers `CLAUDE.md`/`.cursorrules`? Redirect, don't copy."), which is correct — it's describing what to do if the harness prefers those files. Not an instruction to read them.
- `docs/infra/STATE.md` — does not exist. The brief mentions it as part of the corpus but the actual STATE anchors are at `untracked/msg/milestone-01-ko-reframe/STATE.md` and `docs/infra/channel-template/STATE.md` (a template).

---

## 1. CONTRADICTIONS — two files instructing differently

### F01 — INDEX.md lists retired role names not in ROLES.md [severity: misleads]

**INDEX.md:88:** `→ docs/infra/delegation/ROLES.md — Overseer, Advisor, Theorist, Orchestrator, Auditor, Dabir`

**ROLES.md** (the authoritative role doc) lists exactly three thinking-manager roles: Dabir, Auditor, Orchestrator. "Overseer" and "Theorist" are legacy role names from handover docs dated 2026-07-28/29; "Advisor" was GLM's seat name in 2026-07-28. None of these appear in ROLES.md.

**Verdict:** ROLES.md is correct. INDEX.md is stale. The legacy names should be removed or marked `(historical)`.

### F02 — GLOSSARY.md uses `research/` prefix without `docs/` [severity: breaks work]

**GLOSSARY.md:41:** `see research/ruleset-options.md`
**GLOSSARY.md:142:** `See research/ghi-and-superko.md`

The `research/` directory does not exist at the repo root. The actual paths are `docs/research/ruleset-options.md` and `docs/research/ghi-and-superko.md`. From `docs/epistemic/GLOSSARY.md`, the correct relative paths would be `../research/ruleset-options.md` and `../research/ghi-and-superko.md` — and indeed other lines in the same file (51, 66, 181, 194, 303) correctly use `../research/...`.

**The watchdog (Argus) has been reporting these broken references since 2026-08-01** (7 sweeps, all identical findings). The finding was registered in the watchdog summary but never assigned as a task. An agent clicking these links gets a 404.

**Verdict:** GLOSSARY.md lines 41 and 142 are wrong; lines 51/66/181/194/303 show the correct pattern (`../research/...`).

---

## 2. STALE INSTRUCTIONS — commands, paths, or counts now wrong

### F03 — AGENTS.md references `research/ruleset-options.md` (wrong path) [severity: misleads]

**AGENTS.md:15:** `See ADR-0013, research/ruleset-options.md`
**AGENTS.md:19:** `No free lunch. See research/ruleset-options.md`

The file is at `docs/research/ruleset-options.md`. The `research/` prefix without `docs/` resolves to nothing. These are in the "Non-negotiable rules" (foreclosures) section — the most load-bearing part of AGENTS.md.

**Verdict:** Should read `docs/research/ruleset-options.md`.

### F04 — `docs/status/HANDOVER.md` (the template) still instructs reading `CURRENT.md` [severity: misleads]

**HANDOVER.md:4:** `in-flight task state lives in CURRENT.md`
**HANDOVER.md:20:** `3. CURRENT.md — live state, uncommitted-work table, next actions by cost.`
**HANDOVER.md:69:** `post an intent line in CURRENT.md before touching src/retro.zig...`

`CURRENT.md` was retired 2026-08-03 (T286) and replaced by `bin/managent resume`. HANDOVER.md is the handover *template* — the document that says "read this first." It is now teaching a stale read order. Six separate references to CURRENT.md remain.

The `docs/status/handover-*.md` files that reference CURRENT.md (handover-glm-5.2-2026-07-29.md, handover-minimax-m3-2026-07-29.md, handover-dspro-2026-08-01.md, retrieval-test-2026-07-29.md, roadmap-audit-remediation-2026-08-01.md) are **historical records** of sessions that predate T286 — those should stay as-is. The template HANDOVER.md is the one that needs updating.

**Verdict:** HANDOVER.md is a stale template. The references to CURRENT.md should be replaced with `bin/managent resume` per the T286 ruling.

### F05 — Dispatch briefs reference `docs/status/CURRENT.md` for ownership declarations [severity: misleads]

Eight dispatch briefs instruct workers to declare file ownership in `docs/status/CURRENT.md`:
- `EXP-3.md:164`, `EXP-4.md:145`, `EXP-5.md:145`, `EXP-6.md:103,155`, `EXP-7.md:164`, `EXP-7-4x4-rerun.md:149,214`, `EXP-8.md:186`

These tasks are all closed (done) — the briefs are historical. But if an agent reads an EXP-N.md brief for context (as the dispatch README instructs), it will encounter a stale instruction. The current mechanism is the kanban `holds=` field (`managent show <id>`; `bin/managent resume`).

**Verdict:** Historical briefs — preserve the text but consider adding a banner or note in the dispatch README.

### F06 — `docs/infra/sprint.md` listed as "RATIFIED rev 4" in INDEX.md attic [severity: clutter]

**INDEX.md attic table:** `docs/infra/sprint.md — RATIFIED rev 4 (d53c2a8); rewritten 200b974`

But `sprint.md` is an **active document** — it was retired and then un-retired (Dabir: "Retire nothing that prevents a known failure mode"). The attic entry is wrong: sprint.md is not superseded.

**Verdict:** Remove sprint.md from the INDEX.md attic table.

---

## 3. DEAD WEIGHT — files no longer read, or likely to be mistaken for current

### F07 — `docs/infra/dispatch/` contains ~80 briefs for long-closed tasks [severity: clutter]

The dispatch directory holds briefs for tasks from the `2B-*`/`EXP-*`/`T1xx-*` era. All are closed. The `AGENTS.md` router points here only through `docs/infra/dispatch/README.md`, which explains the dependency graph for experiments that are now done. Individual briefs are archival.

**Recommendation:** Keep them — they are the historical record of what was asked. But the dispatch README should state explicitly that these are closed, and that current work dispatches from `bin/managent status` / `untracked/` bundles. The current README's dependency graph still shows EXP-2 as "THE GATE" — an agent reading it cold might think these are still live.

### F08 — `docs/AGENTS.md` is a stray fragment with a redirect [severity: clutter]

Already documented as "stray fragment" in INDEX.md attic. Kept because evidence docs cite its line numbers. No action needed — the redirect works.

### F09 — `HUMAN.md` is an empty file [severity: clutter]

The file exists (0 lines). `docs/infra/human-decisions.md` line 3 says: "The repo-root `HUMAN.md` is the operator's private scratch file and is gitignored — nothing canonical belongs there." If it's gitignored, it shouldn't be tracked. But it appears in my file listing. Let me check — actually, the file exists and is empty and is NOT gitignored based on the file listing. It's tracked as an empty file.

**Verdict:** Either gitignore it (per human-decisions.md's statement) or give it content. An empty tracked file is just noise.

---

## 4. DUPLICATION — same rule in multiple places

### F10 — Model canonical labels: DELEGATEE.md vs `src/managent/main.zig` [severity: clutter — intentional]

DELEGATEE.md maintains a full table of canonical model labels (`deepseek-v4-pro`, `deepseek-v4-flash`, etc.) while also declaring "The full canonical set is the single source of truth in `src/managent/main.zig`." The table is a convenience copy for discoverability — agents reading DELEGATEE.md need the labels immediately.

**Verdict:** Intentional duplication, acceptable. The "single source of truth" statement in DELEGATEE.md line 20 correctly defers to the code. No action needed, but the duplication risk is that one drifts — worth noting that `managent` rejects non-canonical labels at write time, so a drift would fail loudly.

### F11 — "One writer per engine file" rule is stated in AGENTS.md and DELEGATEE.md and dispatch README [severity: clutter — acceptable]

AGENTS.md:64, DELEGATEE.md §Scope, dispatch README.md "Never two consoles on an engine file." All three say the same thing with slightly different emphasis. The `holds=` mechanism now enforces it mechanically.

**Verdict:** Acceptable triplication — each document serves a different reader (all agents, workers, console operators). No drift observed.

### F12 — Landmark rules in AGENTS.md §"Landmarks" and LANDMARKS.md [severity: clutter — acceptable]

AGENTS.md §"Landmarks" states the rules (expand IDs, state direction, say if none). LANDMARKS.md defines the landmarks themselves. These compose rather than duplicate.

**Verdict:** No issue.

---

## 5. RULES NOBODY FOLLOWS

### F13 — "Every row has a SHORT NAME" — violated by T410 itself [severity: misleads]

AGENTS.md §"Landmarks" requires: "Every row has a SHORT NAME, phrased as the question the row answers... It goes in the brief's title line and in the `managent` note."

`managent show T410` shows the bundle path only — no short name. The brief's title is "T410 — audit the instruction corpus: find the kludge, the contradictions, and the rules nobody follow" — this is a title, not a question. Compare with the examples given: `T387 (does a capture cap make the game finite?)`.

The sprint-2026-08-08.md report (T409) follows the landmark-line rule correctly. The sprint-2026-08-07.md report (T405) follows it too. So the rule is followed by sprint consoles — but T410's own brief doesn't comply.

**Verdict:** Add a short-name question to T410's brief. Most rows in the current kanban (`managent status`) also lack short names — only the task description appears. The rule is aspirational rather than enforced.

### F14 — "Every ID is written with its short name" — partially followed [severity: misleads]

AGENTS.md: "`L2 (proven 4×4 values)`, never a bare `L2`."

Sprint-2026-08-08.md line in the table uses `L3 mixed (negative self-play, positive h2h)` — this expands L3 but uses "mixed" rather than the canonical short name "the new engine outplays the old one." The expansion is functional but imprecise.

Sprint-2026-08-07.md uses bare IDs in one place: `L2 narrative accuracy — positive` without expanding L2. But elsewhere it uses `L2 (proven 4×4 values)`.

**Verdict:** Mostly followed; bare IDs slip through occasionally.

---

## 6. GAPS — things every console needed that no document states

### F15 — No document states the `MANAGENT_TASK_ID` requirement for heartbeats [severity: misleads]

The brief says: "Candidates from recent sessions: that heartbeats require `MANAGENT_TASK_ID`."

DELEGATEE.md §"The inbox loop" says: "Right after `managent claim <id>`, run `export MANAGENT_TASK_ID=<id>` in your console (claim prints the exact line) — then every `tools/runner` invocation inherits it." This IS documented. But the brief's mention suggests agents sometimes miss it. The instruction exists but could be more prominent — it's buried in a paragraph about the inbox loop rather than being a standalone, bolded step.

**Verdict:** The instruction exists (DELEGATEE.md). The gap is discoverability, not absence. Consider a dedicated "Before you work" checklist section in DELEGATEE.md.

### F16 — Verification runs writing to deliverable paths [severity: misleads]

The brief's candidate: "verification runs must never write to a deliverable path."

The sprint-2026-08-07.md documents a near-miss: "while verifying T401's controls I ran the instrument without `--json`, and its default path overwrote the committed `findings/T401-bracket-tournament-4x4.json`." The lesson recorded: "verification runs must pass an explicit `--json` scratch path."

This is NOT in any instruction file — it's only in a sprint status doc. A worker reading DELEGATEE.md or AGENTS.md gets no warning about this.

**Verdict:** Add to DELEGATEE.md §"Your context is fresh" or a new "Verification hygiene" section.

---

## 7. Other observations

### The brief's own corpus list contains two files that don't exist

The T410 brief lists `CLAUDE.md` and `docs/infra/STATE.md` as corpus members. Neither exists (F00 above). The brief also mentions `docs/infra/delegation.md` which exists but has a RETIRED banner and is correctly listed as dead.

---

## 8. Prioritized proposal

Ordered by impact × ease. Each entry: severity, what to change, rationale, diff sketch.

### P1 — Fix AGENTS.md stale path (F03) [misleads · 1-line fix]

Two occurrences of `research/ruleset-options.md` → `docs/research/ruleset-options.md`. In the foreclosures section — every agent reads these. Diff: `s/research\/ruleset-options/docs\/research\/ruleset-options/g` in AGENTS.md.

### P2 — Fix GLOSSARY.md broken references (F02) [breaks work · 2-line fix]

Lines 41, 142: `research/` → `../research/`. The watchdog has been reporting these since 2026-08-01.

### P3 — Update HANDOVER.md template (F04) [misleads · ~6 edits]

Replace all `CURRENT.md` references with `bin/managent resume`. The template currently teaches a stale read order.

### P4 — Fix INDEX.md role list (F01) [misleads · 1-line fix]

Remove "Overseer, Advisor, Theorist" from INDEX.md:88 (or mark them `(historical)`). The authoritative ROLES.md lists only Dabir, Auditor, Orchestrator.

### P5 — Remove sprint.md from INDEX.md attic (F06) [clutter · 1-line fix]

sprint.md is an active document, not superseded. Remove the attic entry.

### P6 — Add verification-hygiene to DELEGATEE.md (F16) [misleads · ~3-line addition]

"Verification runs must write to a scratch path, never to a committed deliverable path." The T405 near-miss is the precedent.

### P7 — Add prominent MANAGENT_TASK_ID step to DELEGATEE.md (F15) [misleads · restructure]

Pull the `export MANAGENT_TASK_ID=<id>` step out of the inbox-loop paragraph into a standalone, bolded "Before you work" section. It's too important to bury.

### P8 — Add short name to T410 brief (F13) [clutter · 1-line fix]

Add a short-name question to the brief title. Also consider scanning the kanban for other rows without short names.

### P9 — Update dispatch README to mark experiments as closed (F07) [clutter · ~5-line addition]

Add a banner: "The experiments below are CLOSED. For current dispatchable work, see `bin/managent status`."

### P10 — Fix or gitignore HUMAN.md (F09) [clutter · 1 action]

Per `docs/infra/human-decisions.md`, HUMAN.md is the operator's private scratch file and should be gitignored. It's currently tracked as an empty file.

---

## 9. What was not checked

- `docs/evidence/` (124 files) — evidence store, not instruction; not in routing path
- `docs/epic-01-markovian/sprints/` — deep sprint design docs; not read by workers on standard tasks
- `untracked/msg/` channel messages — historical communication, not instruction
- `src/managent/main.zig` canonical_models array vs DELEGATEE.md table — spot-checked, agree on all 9 entries
- Every dispatch brief (80) was checked for CURRENT.md references (F05); content was not fully audited

---

**Landmark:** advances `L4 (the ledger is clean)` — the instruction corpus is now surveyed with 16 findings, 10 prioritized fixes; all candidates for a single cleanup row. The operator gains a map of where the fleet's instructions disagree with each other or with reality, and a prioritized list to close the gap.
