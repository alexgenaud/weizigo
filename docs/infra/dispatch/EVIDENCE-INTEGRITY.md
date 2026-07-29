<!--managent set=N holds=docs/epistemic/CLAIMS.md-->
# EVIDENCE-INTEGRITY — downgrade what cannot be reproduced, banner what predates the crisis

**Opened by:** `docs/audits/AUDIT-DSPro-2026-07-29.md` §2.4, §2.5, §2.7, §3.2, adopted by the Orchestrator. Honest bookkeeping that costs nothing and is overdue; standing rule 1 is *evidence in git, or the claim is not proven*, and 79 PROVEN rows have failed it at some point.

## The task

**1. Downgrade claims whose primary evidence is gone.** `CLAIMS.md` §7 lists 9 missing files.

- `3x2.T13` — **stays PROVEN** (the durable summary is in git: `docs/research/c2-falsification-3x2.md`) but its reproduction block gets a `CANNOT REPRODUCE — probe source lost` banner. T13 is the falsification the whole strategy rests on; a reader must know it cannot be re-executed.
- `2x2.B1`, `3x2.B1`, `3x3.B1` — **downgrade PROVEN → CLAIMED**, note "no durable evidence file". B1 is what ruled out failure mode (b); without it the E2 verdict weakens from "the fixpoint does not bound real PSK scores" to "either the fixpoint is wrong or it does not bound".
- `boards/4x4/EPISTEMIC.md` — record that its rewrite basis (T07, eight findings) is **unverifiable**.
- Any other row whose only evidence path is under `untracked/` or `/tmp`.

**2. Re-derive or retire the D18 cross-check** (§2.7). EXP-3's calibration-2 dispute was resolved by an independent depth-parity BFS written to `/tmp/test_census_pure.zig` and deliberately not committed as "a sanity throwaway". That is the T13 mechanism repeating. The census numbers are PROVEN without it; the **dismissal of the calibration mismatch** is not. Re-derive it under `docs/evidence/GLOBAL.H1-CENSUS/`, or mark the dismissal unsupported. Do not assume the original context still exists — it almost certainly does not.

**3. Erratum banners on documents that predate the crisis** (§3.2). Historical records, not errors — but a new reader must not meet the claims without context:
- `ARCHITECTURE.md` — the "5×5, then 6×6, aiming at 7×7" goal assumes the PSK fresh-start representation, now known not to produce real-game scores.
- `ADR-0012-5X5` — the feasibility projection (~53e9 slots, ~106 GB, 4–6 days) was computed before C2 and C3 were falsified, before F2 was orphaned, and before the bracket premise collapsed.
- `docs/research/retrograde-4x4.md` — the "complete, validated 4×4 oracle" claim.
- Each banner: what was assumed, what falsified it, and where the current position is stated.

**4. Add a remediation column to the corrections ledger** (§2.5). `corrections-2026-07-27.md` lists A-1 and A-3 as open, addressed to other agents, but both were already fixed in the repo at the time of the sweep. Give each entry an applied/not-applied state and the commit that applied it. A ledger that cannot be read without a manual diff against the repo cannot do its job.

## Acceptance

- Every downgrade made, with the row and the reason.
- `bin/weizigo-claimlint` **run and green** (or its failures explained) — it is the gate on any `CLAIMS.md` edit and exits non-zero on a malformed row.
- The orphan / dangling-evidence counts before and after, as explicit numbers.
- No claim **upgraded** in this task. If something looks under-rated, say so; do not promote it here.

## Deliverable

The edits themselves, plus a short `docs/status/evidence-integrity-<date>.md` recording what moved and why. **This task owns `CLAIMS.md`** — no other task may hold it concurrently.

**Read first:** `CLAIMS.md` §6-D17, §6-D18, §7; `AUDIT-DSPro-2026-07-29.md` §2.4-§2.7, §3.2; `docs/research/arena-4x4-undef.md:10-18` (the same loss, once before, with the fix stated and not retroactively applied).
