# T334 — plan audit gate: G3b value-correctness pass0 PLAN, Revision 3 (round 2 of 2)

```
Task: T334 · Role: plan audit gate · Model: kimi-k2.7-code:cloud · Date: 2026-08-04
Plan audited: docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/plan.md
Revision: 3 · Commit: 85839f4 · Status: PROPOSED
```

## F1–F6 closure (round-1 disposition check)

| ID | disposition from T332 | status in Rev 3 | notes |
|---|---|---|---|
| F1 | Re-root closure to real WZO2 artifact; rebuild membership predicate and memory budget against parsed schema | **fixed as dispositioned** | §2.1/§2.6 now name `data/oracle-4x4-v2.wzo2`, WZO2 header figures, group-index binary search + in-group linear scan, ~531 MB peak. Header parsed independently for this audit; all figures match. |
| F2 | I5 first seeded-defect control at 3×2 mechanized as I5-4x4 row bar | **fixed as dispositioned** | §5 row `I5-4x4` now carries the 3×2 red-then-green bar explicitly, not effort-table prose. |
| F3 | DISCHARGE bar is seven mutant-kill assertions inverted in `vb_mutants.zig` | **fixed as dispositioned** | §5 mutant→killer mapping restates the bar; DISCHARGE row keeps row-level `needs` and adds the mechanized assertion. |
| F4 | Comparison-harness author distinct from MG-KERN (A) and R8 (B); "(or A)" dropped | **fixed as dispositioned** | §6 assigns author C to the comparison harness and requires C ≠ A and C ≠ B. |
| F5 | EXP-3 sweep citation relabelled analogy; actual sweep count deferred to `accept.md` | **fixed as dispositioned** | §2.1 now labels ≤40 sweeps a planning estimate and states the real count is an `accept.md` measurement. |
| F6 | MG-INV covers full `(pos, side, ko, passes)` including `ko≠NONE`, with ko-recapture mutant at ko-active state | **fixed as dispositioned** | §5 `MG-INV` row commits to exhaustive 2×2/3×2/3×3 over the full state space including ko-active states and a ko-recapture seeded-defect control. |

## Findings

| ID | grade | file:line | finding |
|---|---|---|---|
| N1 | must | `pass0/plan.md:318-319` | §4 says "Spec is done (Rev 3, RATIFIED 2026-08-04)" while the phase table immediately below and the document header state the ratified spec is **Rev 4**. Rev 3 was the artifact-identity amendment (T332 F1); it was never the ratified revision. This stale cross-reference contradicts the spec path the rest of the plan depends on and is a regression introduced by the Rev 3 repoint. Fix: change "Rev 3" to "Rev 4". |
| N2 | should | `pass0/plan.md:359` and `:366` | Two rows — `MG-INV` and `KEY-4x4` — both declare `holds=src/differential.zig`. `pass0/spec.md:248` assigns `src/differential.zig` to **one** owner (`movegen-invariant-row`); `AGENTS.md` requires one writer per engine file. The plan mitigates by putting both rows in `set=g3b-movegen`, which serializes them, and §6 assigns both to the same comparison-harness author C, but the kanban will still show two tasks holding the same file. The clean fix is for `MG-INV` to remain the sole writer of `src/differential.zig`; the 4×4-scale key-agreement run is authored as part of the MG-INV deliverable (or in a separate file imported by `differential.zig`), not by a second row editing the same file. |

## Header and layout measurements (§2.1 arithmetic)

Parsed `data/oracle-4x4-v2.wzo2` independently with a short Python reader, 2026-08-04.

| quantity | plan claim | measured | match |
|---|---|---|---|
| file size | 518,123,097 B | 518,123,097 B | ✓ |
| magic | `WZO2` | `WZO2` | ✓ |
| version | 1 | 1 | ✓ |
| `w` / `h` | 4 / 4 | 4 / 4 | ✓ |
| `rules_id` | 3 | 3 | ✓ |
| `entry_size` | 4 | 4 | ✓ |
| `group_header_size` | 5 | 5 | ✓ |
| `ko_bits` | 5 | 5 | ✓ |
| `hdr_flags` bit 0 (`PASSES_2_OMITTED`) | 1 | 1 | ✓ |
| `n_groups` | 24,318,165 | 24,318,165 | ✓ |
| `n_entries` | 99,133,036 | 99,133,036 | ✓ |
| `data_offset` | 128 | 128 | ✓ |
| layout check `data_offset + n_groups×5 + n_entries×4` | 518,123,097 | 518,123,097 | ✓ |
| embedded zero-slot SHA-256 | `57009d93…` | `57009d9346…` | ✓ |
| full-file SHA-256 | `0c3366f0…` | `0c3366f07f…` | ✓ |
| group index sorted by colex | yes (design-M1 §2.4) | order spot-check passed | ✓ |
| max group `entry_count` | ≤ `2×(16+2)=36` | 8 | ✓ |
| `passes=1` entries with `ko≠none` | 0 (§2.5 invariant) | 0 | ✓ |
| total entries scanned | 99,133,036 | 99,133,036 | ✓ |

Memory figures derived from the header also check out:

| component | plan | measured / computed |
|---|---|---|
| group index | 121.59 MB | `24,318,165 × 5 = 121,590,825 B` ≈ 121.59 MB |
| entry data | 396.53 MB | `99,133,036 × 4 = 396,532,144 B` ≈ 396.53 MB |
| visited bitset (C-A2) | 12.39 MB | `99,133,036 / 8 = 12,391,630 B` ≈ 12.39 MB |
| sparse prefix sum | ~380 KB | `⌈24,318,165 / 256⌉ × 4 = 380,284 B` ≈ 371 KB |
| C-A2 peak | ~531 MB | 121.59 + 396.53 + 12.39 + scratch ≈ 530.5 MB |

All plan §2.1 numbers are confirmed by direct measurement.

## Verdict

**PASS-WITH-EDITS** — the six dispositioned round-1 findings are fixed, the WZO2 header and derived memory arithmetic are verified, and the plan is otherwise coherent with spec Rev 4. The one must finding (N1) is a stale cross-reference left by the Rev 3 repoint; the should finding (N2) is a file-ownership hygiene issue that the plan already mitigates via same-set serialization. Both are fixable with the exact edits below.

### Required edits

1. `docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/plan.md:318-319`
   - Change: `Spec is done (Rev 3, RATIFIED 2026-08-04).`
   - To: `Spec is done (Rev 4, RATIFIED 2026-08-04).`

2. `docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/plan.md:366`
   - Change the `KEY-4x4` row's `holds` field from `src/differential.zig` to a separate file (e.g. `src/vb_keyagree_4x4.zig`) or to `—` with a note that the 4×4-scale key-agreement extension is authored within the MG-INV row's ownership of `src/differential.zig`.

## Rationale

Revision 2 fixed the load-bearing F1 defect by re-rooting the closure design to the real WZO2 artifact and rebuilding the membership predicate against the parsed schema. Revision 3 correctly repointed the artifact path to the deployed `data/` copy. The remaining defects are editorial/hygiene: a stale spec revision reference and a second task claiming the same source file. Once those two edits are applied, the plan satisfies the spec, the one-writer rule, and the audit gate requirements; no further audit round is needed.

## Auditor identity and method

Fresh-session document review against `pass0/plan.md` Revision 3 (commit `85839f4`), `pass0/spec.md` Revision 4 (RATIFIED), `archive/plan-audit-r1.md` (T332), `sprint.md`, `DIRECTION.md` + Amendments 1 & 2, `WAYPOINTS.md`, `sprints/verify-battery/pass1/mutants.md`, `sprints/oracle-v2/pass0/design-M1.md` (rev 3), and `sprints/verify-battery/pass0/design-M1.md` §4.6. No `untracked/msg/` channel traffic, author framing, or prior audit reasoning was consulted before forming findings. The WZO2 header and invariants were parsed independently with `xxd` and a short Python reader (`data/oracle-4x4-v2.wzo2`, byte-identical to `untracked/oracle-v2/oracle-4x4-v2.wzo2`, both pinned in `artifacts/SHA256SUMS`).

## Gate-holder disposition (Orcha/Opus 5, 2026-08-04)

Verdict accepted: **PASS-WITH-EDITS**. Both required edits applied in plan **Rev 4**;
**plan.md is RATIFIED** and build-row decomposition follows. Round 2 of 2 — no further
audit round is owed.

| ID | disposition |
|---|---|
| N1 | **Confirmed and fixed.** `plan.md:318` did say "Spec is done (Rev 3, RATIFIED)" while the header and the §7 gate table said Rev 4. It is a regression this gate-holder introduced in the Rev 3 repoint — the gate table was bumped and this prose was missed. The auditor caught the gate-holder's own error, which is the gate working as designed. |
| N2 | **Substance confirmed, citation corrected, suggested remedy rejected in favour of a different one.** Both `MG-INV` and `KEY-4x4` did declare `holds=src/differential.zig`, and the spec does assign that file to `movegen-invariant-row` alone — **but at `spec.md:278`, not `spec.md:248`, which is a blank line.** Verified by reading both. A finding must be checkable at the line it cites; this is the same class of slip as T324's "SOLE evidence" overstatement, and it is recorded here rather than waved through. Fix applied: MG-INV stays the sole declared holder; KEY-4x4 declares no hold and writes the file under MG-INV's ownership, serialized by its `needs MG-INV` edge inside set `g3b-movegen`. The auditor's alternative — a separate `src/vb_keyagree_4x4.zig` — is **rejected**: spec §6.4 decided to reuse `differential.zig`, and splitting one harness across two files to satisfy bookkeeping is worse than declaring ownership correctly. **Carried into decomposition as a live question, not a settled one:** whether `managent`'s hold conflict fires against *any* row declaring the path or only a live one. If only live rows conflict, KEY-4x4 should carry the hold from the moment MG-INV closes; that will be tested against a temp store at registration, not assumed. |

**What this audit demonstrated, worth recording.** The brief required an artifact parse
with measured-vs-claimed numbers, and the auditor delivered a 17-row measurement table
that independently reproduced every §2.1 figure — including two the plan did not claim
(max group `entry_count` = 8 against a bound of 36, and zero `passes=1` entries with
`ko≠none`, which is the §2.5 invariant checked rather than quoted). Round 1's only
critical finding came from a header parse after two document reviews missed the same
defect; round 2's measurements confirmed the rebuild. `sprint.md:93`/`:100` again:
instruments that touch the artifact find things, and document review finds the stale
cross-references — which is also real work, since N1 was one.

### Postscript — N2's open question, resolved by measurement (same session)

The disposition above left one thing open: whether `managent`'s hold conflict fires
against *any* row declaring a path or only a live one. Read rather than assumed:
`holdsConflict` (`src/managent/main.zig:976-991`) `continue`s past every row whose
`status != .in_progress`, and it is called from `claim` (`:1268`, `:1315`) — never from
`add`. Two registered rows may both declare a file; the refusal fires only while one is
in progress.

That **inverts** the fix: KEY-4x4's `holds=src/differential.zig` is restored (plan Rev 5),
because declaring it is what mechanizes one-writer-at-a-time, while the no-hold version
this gate-holder wrote in Rev 4 would have enforced nothing at all. The finding N2 raised
was real; the first remedy for it was wrong, and cost nothing to correct because the
question was asked of the source instead of settled by argument.
