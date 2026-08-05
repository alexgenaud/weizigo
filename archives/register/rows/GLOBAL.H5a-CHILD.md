# `GLOBAL.H5a-CHILD` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** player

**Epitaph:** Ruled a 1-ply Bellman check at the current node is NOT sufficient — the chosen child must be checked too — shipped in the player; the ruling's instance (4x4.A-3) is archived with it.

**Move reason (from the triage sheet):** [player] child-side Bellman check (D-3, EXP-9) — player-side

**Full register row (verbatim at the time of the move):**

```
| `GLOBAL.H5a-CHILD` | H5(a) correction 1 | 4×4 | **A 1-ply Bellman-identity check at the current node is NOT sufficient** to license table steering — the **chosen child** must be checked too. Ruled 2026-07-28 (D-3, Opus) as a condition of H5(a) shipping. The demonstrating instance is `4x4.A-3`: at ply 14 the node's own V0 was −3 while the child the player chose was −16, so a node-only check passes exactly where the player is about to be wrong. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** child-side refuse-on-divergence check + settled-area fallback in `src/gtp.zig`; a sign defect in the draft was found and fixed (pinned by a new antisymmetry test); +6.8%/genmove. **Acceptance 4 PARTIAL** — the A2 mechanism fires at ply 13 not ply 7 (structural reason in `docs/research/h5a-player-mitigation-2026-07-28.md` §5). **CLAIMED, not verified-optimal.** | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `corrections:99-132`; `regressions/4x4-black-win-after-ko.txt:74`; `open-hypotheses:274-279` | `n:4x4.A-3` (the requirement exists *because* "the player is fresh-start-perfect" is false at the chosen child; if `4x4.A-3` were rehabilitated the node-only check would suffice and this row would lose its reason to exist), `e:GLOBAL.CHAIN-LH`, `e:QA-014` | H5(a) implementation, `GLOBAL.H5` player fork | 0 | ? | RETIRED |
```
