<!-- RESCUED EVIDENCE -->
> **Provenance header** (added 2026-07-28 by the `docs/evidence/` rescue sweep;
> the body below this rule is verbatim and unedited).
>
> - **Original path:** `untracked/SUBAGENTS.md`
> - **Original mtime:** 2026-07-26T15:31:04
> - **Rescued:** 2026-07-28
> - **sha256 (original, at rescue):** `b58a36fd852584a83a7fc92ec0e2afd9630043990f9d1e401b06f741c327728b`
> - **Supports:** `GLOBAL.UD-1`, `GLOBAL.UD-2`, `GLOBAL.UD-3`, `GLOBAL.T14.1`; also holds the one-line result summaries for `2x2.T12` and `3x2.T13`, whose own records are CONFIRMED LOST
> - **Cited by:** `docs/epistemic/PROGRESS.md:239` — "UD-3 acted on as YES (see `../../untracked/SUBAGENTS.md`)"; `docs/epistemic/CLAIMS.md:259`
>
> The original in `untracked/` is git-ignored and may be deleted at any time.
> This copy is the durable one. Do not edit the body; append corrections to
> `docs/evidence/README.md` instead.

---

# SUBAGENTS — delegated bundles and prompts

**Purpose:** concise registry of dispatched bundles, prompts, status, and
parallelization/serialization rules. Read-only for subagents. Updated by
Boss only. No prose; prompts and statuses only.

**Last update:** 2026-07-26

---

## Completed

| ID | Owner | Prompt | Key result | Notes |
|---|---|---|---|---|
| T04 | Minimax-m3 | `Minimax-m3: follow untracked/T04-minimax.md` | Doc pruning done | ~25 min |
| T09 | Minimax-m3 | `Minimax-m3: follow untracked/T09-minimax.md` | 4×4 Benson regression PASS | 24,318,165 positions |
| T10 | GLM-5.2 | `GLM-5.2: follow untracked/T10-glm.md` | FP1-4×4 PARTIAL | SOUND subset 0 violations |
| T10-audit | Kimi-k2.7 | `Kimi-k2.7: follow untracked/T10-fp1-audit.md` | Confirmed PARTIAL | 211,495 expected mixing |
| T11 | Minimax-m3 | `Minimax-m3: follow untracked/T11-minimax.md` | D3-4×3 GO | 33.3 s vs 2.7 s |
| T12 | Minimax-m3 | `Minimax-m3: follow untracked/T12-minimax.md` | C2-pilot-2×2 PARTIAL/tautological | No non-root cycles |
| T13 | Kimi-k2.7 | `Kimi-k2.7: follow untracked/T13-minimax.md` | **C2 FALSIFIED at 3×2** | 12/508 mismatches |
| T14.1 | Minimax-m3 | `Minimax-m3: follow untracked/T14-minimax.md` | 4×4 bracket-only PASS | 258 MB artifact |
| T15 | Kimi-k2.7 | `Kimi-k2.7: follow untracked/T15-kimi.md` | Capture-all design done | Implementation deferred |
| T15-review | Kimi-k2.7 | `Kimi-k2.7: follow untracked/T15-review-kimi.md` | Recommend **defer** | Until T14/T17 |
| T16 | GLM-5.2 | `GLM-5.2: follow untracked/T16-glm.md` | EPISTEMIC/CONCEPTS rewrite done | Content review pending |
| T17-plan | GLM-5.2 | `GLM-5.2: follow untracked/T17-plan-glm.md` | KM deps regen design done | Implementation blocked |
| B03 | GLM-5.2 | `GLM-5.2: follow untracked/B03-glm.md` | Doc audit ACCEPT-with-edits | Blocker 2, Critical 4 |
| B05 | GLM-5.2 | `GLM-5.2: follow untracked/B05-glm.md` | Reframe plan + 8-edit plan | Boss applied edits |
| B06 | Kimi-k2.7 | `Kimi-k2.7: follow untracked/B06-kimi.md` | E2 re-run PASS at 2×2/3×2; FAIL at 3×3 | 50/8000 leaks at 3×3 |
| B08 | GLM-5.2 | `GLM-5.2: follow untracked/B08-glm.md` | Onboarding PARTIAL PASS | CURRENT.md inconsistency found |
| B02 | GLM-5.2 | `GLM-5.2: follow untracked/B02-glm.md` | T14.3 PARTIAL; C2 FALSE-AS-SCOPED | Subtask 1 & 2 done |
| B04 | Minimax-m3 | `Minimax-m3: follow untracked/B04-minimax.md` | Scratch-file triage done | 9 active, 30 archived |
| B07 | Minimax-m3 | `Minimax-m3: follow untracked/B07-minimax.md` | Fresh-start sanity PASS | S1/S2/S3 done; retro.zig lock released |
| B10 | Minimax-m3 | `Minimax-m3: follow untracked/B10-minimax.md` | 3×2 divergence stats done | H1 supported, H2/H4 falsified |
| B11 | Boss | `Kimi-k2.7-code: follow untracked/B11-boss-apply.md` | Applied B05 doc edits | Done |
| B12 | GLM-5.2 | `GLM-5.2: follow untracked/B12-glm.md` | CONTINUE verdict | Temp files cleaned up 2026-07-26 |

## B13/B14 — dispatched to DeepSeek-Pro (Pi)

| ID | Owner | Prompt | Status | Notes |
|---|---|---|---|---|
| B13 | DeepSeek-Pro | `follow untracked/B13-kimi.md` | DONE | Terminology sweep (5 files) + doc fixes applied |
| B14 | DeepSeek-Pro | `follow untracked/B14-glm.md` | DONE | Engine-vs-engine + KataGo design; see untracked/B14-deepseek.md |

## Dispatchable now (parallel sets)

### Set A — independent read-only / standalone

```text
B07: follow untracked/B07-minimax.md    # code audit / fresh-start sanity
B10: follow untracked/B10-minimax.md    # 3×2 divergence statistics
```

### Set B — doc/test (no engine contention)

```text
B08: follow untracked/B08-glm.md        # fresh-agent onboarding test
```

B08 already ran once; dispatch again only if the CURRENT.md inconsistency fix
needs re-testing.

### Set C — requires sole `src/retro.zig` ownership

```text
B09: follow untracked/B09-kimi.md       # synthetic-bug injection / auditor sensitivity
```

**Cannot run concurrently with B07 or any other engine editor.**

## Blocked / deferred / moot

| ID | Owner | Blocker | Notes |
|---|---|---|---|
| T14.2 | Minimax-m3 | User decision UD-2 | 4×4 writes-off finisher; moot until reframe sign-off |
| T15-impl | TBD | T14/T17 complete | Capture-all census deferred |
| T17-impl | TBD | T14.2 artifact | KM regen blocked |
| T16-content-review | TBD | B01 subtask 2 on hold | EPISTEMIC/CONCEPTS content review |
| Cleanup | TBD | B04 + reframe settle | Remove scratch binaries and backups |

## Pending user decisions

| ID | Question | B05 recommendation |
|---|---|---|
| UD-1 | Track A 2×2/3×2 regen now? | YES (cheap, publishable immediately) |
| UD-2 | 4×4 deliverable bracket-only now? | YES (sound, ships now) |
| UD-3 | Adopt fresh-start-only near-term deliverable? | YES |

## Serialization rules

- `src/retro.zig`: one writer at a time. Currently B09 is the only task that
  needs it; B07 is read-only.
- `data/oracle-*.wzo` / `artifacts/*.wzo`: no silent overwrites.
- `docs/status/CURRENT.md`, `docs/status/HANDOVER.md`: one editor per session.
- B03-style doc-audit runs **after** Boss applies B05/B11 edits, not
  concurrently.
