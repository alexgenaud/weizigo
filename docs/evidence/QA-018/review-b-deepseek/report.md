Task: QA-018-REVIEW-B · Role: panel seat B · Model: DeepSeek Pro · Date: 2026-07-29

# QA-018-REVIEW-B — DeepSeek Pro adversarial review of ADR-0017

**One-line headline:** ADR-0017's "refutation failed" verdict is **SOUND**; ADR-0015 **STANDS**.

## Verdict

**Verdict A — ADR-0017's verdict is sound, and ADR-0015 is strengthened.**

Fable's EXP-10 attempt (ADR-0017) does not miss any available exemption. The search-path family that the finisher presents to a bracket cut is **structurally identical** to the family of real PSK-legal game lines from the same root, and the in-family pointwise falsification at 3×2 (T13) closes the last semantic escape route that E2's outcome-level leak left open. No defence discharged ADR-0010's burden; two further candidate exemption arguments (Defences 6 and 7) also fail on inspection.

## The exemption Fable would have needed, and why each shape fails

To overturn ADR-0015, Horn B of EXP-10 had to produce a theorem or construction that **separates the finisher's search-path family** from the real-game histories that falsify the bracket. The candidate shapes are exhaustive:

1. **Family disjointness:** "The finisher's interior arrival histories are not real game lines, so E2/T13 histories are outside the scope of the cut."  
   **Fails.** `ab_value_from_root` resets history to `{root}` and then pushes every placement child onto `O.History` as it descends (`src/retro.zig:642-655`, `:575-577`). Each child is PSK-banned against that history (`src/retro.zig:542-548`). The arrival history at any interior node is therefore exactly *root + a PSK-legal placement path*, with initial ban set `{root}` — the definition of a real game line from that root (`docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md:36-49`). For the empty root the identification is total.

2. **Ban-set-emptiness / move-availability invariant:** "Cuts fire only at nodes whose arrival history has not removed the move that realises the bracket value."  
   **No support exists.** The bracket cut at `src/retro.zig:464-472` is a pure table lookup; it carries no history, ban-set-size, or move-availability condition. T13's 12 mismatches occur under non-trivial histories that include repeated positions, so any such invariant would have to be proved, not assumed (`docs/research/c2-falsification-3x2.md:78-91`).

3. **Window arithmetic / fail-soft / MTD self-correction:** "Even if a bracket is wrong at a node, the value returned by the cut remains a valid bound because of the alpha-beta window."  
   **Fails.** If `V(P,h) > hi(P)`, the `bhi <= alpha0` return at `src/retro.zig:470` supplies an upper bound (`bhi`) that is not an upper bound; if `lo==hi` and `V(P,h) ≠ s`, the exact return at `:469` is wrong outright (T13 shows 12-point errors). Fail-soft window arithmetic cannot repair a wrong bracket.

No other exemption shape is visible in the packet. The structural identification of search-path and real-game histories is the load-bearing obstacle, and it is not addressed by any of the five defences or the two calibration defences below.

## Per-finding grades (message 025)

### Finding 1 — E2 is outcome-level, not pointwise: **SOUND**

Fable's claim-semantics split is correct. E2 measured final score vs the strongest fresh-start promise along a range-aware self-play line (`docs/status/leak-crisis.md:9-15`, `:36`, `:76-79`). A leak of that shape can occur because PSK bans break the *chaining* step (no legal child achieves the parent's `lo`) without any single node's pointwise bracket being wrong. E2 therefore falsifies an **outcome** reading of `GLOBAL.C3`, not the **pointwise** reading the cut at `src/retro.zig:464-472` needs.

The repair — T13's 12 pointwise mismatches on `L==H` slots under reachable, empty-rooted PSK lines (`docs/research/c2-falsification-3x2.md:15-17`, `:45-95`) — is also correct. Because an `L==H` slot has the point bracket `[s,s]`, each mismatch is exactly `V(P,h) ∉ [lo,hi]` with `h` inside the search-path family. This **strengthens** ADR-0015, not weakens it. Caveat (stated in ADR-0017) is acknowledged: the 12 lines' respect for the eye-pruned generator is unverified because the probe source was deleted (`QA-022`).

### Finding 2 — Brackets-off regen is not sufficient: **SOUND**

Fable's sharpening of Horn A is supported by the code:

- The finisher pre-seeds the memo with every certified (`L==H`, non-`KO_SENSITIVE`, non-`FROM_FORWARD`) slot in `base_cb`/`base_cw` (`src/retro.zig:1014`; also `:979-1024` for the surrounding init logic).
- With `deps` off, those seeds are read unconditionally (`src/retro.zig:484`, `:490`).
- With `deps` on, seeded entries are absent from `dep_map`, so `ctx.dep_map.?.get(...) orelse O.fp_zero` yields the empty fingerprint (`src/retro.zig:486`, `:492`), and `fpDisjoint(O.fp_zero, anc_or)` is always true. The seeds therefore still fire unconditionally.
- The artifact-producing path hardcodes `bracketed = true` (`src/retro.zig:2407`).

Consequently a "brackets-off" or "writes-off" regen still reads history-free certified seeds, and those seeds' history-freeness is exactly `GLOBAL.CERTCORE`, already falsified at 3×2 by T13. The only configuration that escapes both bracket cuts and certified-seed memo reads is T13's own `memo=false, brackets=false`.

### Finding 3 — Third-party review, not Opus: **SOUND**

Procedural confirmation. Opus issued D-5 / ADR-0015 and is the ruling party; Fable authored the refutation attempt. ADR-0017 itself routes the adversarial review to a third party (`docs/infra/dispatch/QA-018-RULING.md`, referenced in `docs/decisions/0017-bracket-cut-refutation-attempt-failed.md:1-10`). Seat B satisfies the independence rule.

## Additional calibration defences (panel protocol §3)

Both are adjudicated on the merits. At least one is synthetic; the analysis below treats them as arguments.

### Defence 6 — MTD self-verification: **WRONG**

**Flaw:** Root convergence certifies *consistency* of the search tree under the cuts, not *correctness* of the cuts.  
`ab_value_from_root` runs repeated null-window probes until `lo == hi` (`src/retro.zig:642-655`). If an interior bracket cut returns a wrong but internally consistent value, every probe that depends on it will agree, and the driver will converge — to the wrong value. The MTD loop has no mechanism to detect that a stored `[lo,hi]` bracket itself does not bound the history-exact value. A search tree in which every wrong cut is mutually compatible can converge with zero probe disagreement.

### Defence 7 — The `bracket_fail` gate: **WRONG**

**Flaw:** The gate checks only the *root value* against the *root bracket*; interior cut sites are entirely unmonitored.  
`runRoot` increments `bracket_fail` only when the final solved root value `v` lies outside the root's own `[lo0,hi0]` (`src/retro.zig:1124`). An interior wrong cut can leave the root value comfortably inside a wide root bracket — e.g., the empty 4×4 root bracket is `[−6,+16]` (`ruleset-options.md:213`). `bracket_fail = 0` is therefore consistent with unsound interior cuts and certifies nothing about them. This is a post-hoc aggregate, not a cut-site audit.

## Calibration: evidence that would have changed the verdict

For Verdict B (Fable missed a usable exemption), the following evidence would have been sufficient:

1. **A search-path exemption proof** — a theorem about `src/retro.zig` showing that every node at which a bracket cut fires has an arrival history under which `[lo,hi]` provably bounds the true value (e.g., via a ban-set-emptiness invariant or a fail-soft validity invariant). None is present; the cut site (`src/retro.zig:464-472`) carries no such condition.
2. **A T13 re-run invalidating the 12 lines** — if the 12 falsifying histories all violated the eye-pruned move generator, the in-family strengthening would collapse and the verdict would retreat to ADR-0015's burden-only position. It would **not** revive Horn B, which still fails on Defences 1 and 3–5.
3. **An exhaustive 3×3 cut-site check (ADR-0015 falsifier 2)** — logging every bracket cut over all 622 ko-sensitive orbit representatives and comparing each returned bound against the history-exact value under its real arrival history. Zero mismatches would falsify the ruling as scoped to 3×3 and be the first real evidence for the exemption.

The absence of (1) and the non-existence of (3) in the packet leave Verdict A as the only supported outcome.

## Run stats

- **Model id:** DeepSeek Pro (seat B brief assignment). The user's opening line named Kimi K2.7; the seat brief and deliverable paths are for DeepSeek Pro.
- **Console:** pi coding-agent harness.
- **Wall-clock time:** not measured by this session.
- **Cost:** unknown.
- **Approximate context consumed:** ~35–45k tokens (panel packet: ADR-0017, ADR-0015, ADR-0010, T13 evidence, message 025, `src/retro.zig` sections, panel protocol).
- **Fit issues:** None. The packet was self-contained and fit the context window.
