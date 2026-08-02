# H5(a): the play-time chainability check — a weaker-but-honest player

**Task:** `docs/infra/dispatch/EXP-9.md` (set A, holds `src/gtp.zig`).
**Date:** drafted 2026-07-28, completed and measured **2026-07-29**.
**Status:** implemented, all five acceptance criteria exercised; criterion 4
**partially met** — see the honest finding in §5. Reproduction commands given
for every number.

**Provenance note.** The first implementation pass (agent Minimax-m3) was
interrupted mid-flight by a machine-level kernel panic on 2026-07-29 02:37 and
never ran acceptance or wrote this document. The code it left in the tree was
completed, corrected (one real sign defect, §3), measured, and documented by
Opus 5 on 2026-07-29. Nothing about the panic affected the repository or the
artifacts; see the resume surface (`bin/managent resume`) for the current state.

---

## 1. What this does, and what it does not do

`Session.choose` picks a move by taking the extremum over its children's stored
`V0` values — a one-ply minimax over the table. That is a sound evaluation only
where the history-free Bellman identity holds. In the ko-sensitive (`L < H`)
region each slot holds an **independent fresh-start PSK solve**, so adjacent
slots answer questions under mutually inconsistent premises and the extremum
compares incommensurable quantities. On 4×4 the disagreement reaches the full
goban swing, `32 = 2n`.

This change does **not** fix that. The fix is the ruleset/representation change
(EXP-2..8). What this does is stop the player from *acting* on the incoherent
comparison, and make the refusal a visible certification signal.

Before trusting the extremum, the engine now verifies the identity twice
(`choose_with_check`, `src/gtp.zig`):

- **A1 — at the current node `P`:** does `opt over children of V0(child,-s)`
  (including the pass edge `V1(P,-s)`) equal the stored `V0(P,s)`?
- **A2 — at the chosen child `C*`:** the same identity must hold at the node
  the engine is about to move *into*. This is the DECISIONS **D-3** correction:
  A1 alone certifies only that `V0(P)` agrees with its own children; it says
  nothing about whether the child you enter is itself chainable, so a node-only
  check warns *after* you are already in trouble.

Outcomes:

| case | behaviour |
| --- | --- |
| A1 and A2 both hold | play the extremum, exactly as before — **no strength lost** |
| either fails | **refuse** the `V0` comparison; play the move maximising a history-free score; log `UNCHAINABLE` |
| no legal move / all children UNDEF | pass (pre-existing behaviour) |

The refusal fallback is **`fallback_score`**: own Benson-alive stones and
Benson-alive-enclosed territory, minus the opponent's. It is sound by Benson's
theorem regardless of history and depends only on the post-move snapshot, which
is exactly the property required. **Refusal is never a pass** — passing in the
opening is itself a blunder, so a pass-on-refusal player would pass out of the
opening.

The log names *which* check fired, because they mean different things:

```
(UNCHAINABLE A1@node   — refused V0 comparison; played history-free fallback)
(UNCHAINABLE A2@chosen-child — refused V0 comparison; played history-free fallback)
```

## 2. Reproduction

```sh
zig build                                    # clean
zig test src/gtp.zig                         # 58/58
zig build-exe -O ReleaseFast src/gtp.zig -femit-bin=/tmp/gtp-exp9
```

Build **ReleaseFast**, as `tools/play_oracle.py` does. A default `-O Debug`
build of this file is what preceded the 2026-07-29 OOM/kernel panic; it is not
needed for anything here.

## 3. A defect corrected during completion — the fallback sign

`fallback_score` is **side-relative**: it counts the mover's own Benson-alive
stones and territory as positive and the opponent's as negative, so

```
fallback_score(pos, +1) == -fallback_score(pos, -1)
```

for every position. Both colours therefore **maximise** it, which is what the
function's own doc comment said. The draft implementation nevertheless branched
on `maximizing = side > 0` and **minimised for White**, i.e. White chose the
move *worst for itself* on every refused ply — inverting the fallback precisely
where it is supposed to be the sound floor.

Fixed: there is no colour branch in `fallback_pick`; the colour is already
inside the score. The premise is now pinned by a unit test,
`"H5(a) fallback_score is side-relative (antisymmetric), so both colours
maximise it"`, which checks a Benson-alive example plus antisymmetry over 2 000
pseudo-random gobans.

(On the specific game measured in §4 the two variants happen to pick the same
move — White's candidate scores are all equal there and the colex tie-break
decides — so this defect is invisible in that transcript. It would not stay
invisible.)

## 4. Acceptance 1–3, 5 — measured

Artifact `data/oracle-4x4.checkpoint.wzo` unless stated. "Baseline" is a
ReleaseFast build of `src/gtp.zig` at HEAD `c63b678` in a detached worktree.

### 1. Build and tests

`zig build` clean (rc=0). `zig test src/gtp.zig` → **58/58** (57 pre-existing,
+1 new). The B+15.5 fixed-transcript regression is unchanged — only the
engine's *live* play changes.

> `zig build test` prints `failed command: … --listen=-` while every test
> passes. This is **pre-existing and unrelated**: verified identical at HEAD in
> the baseline worktree. The GTP regression test writes to stdout, which
> corrupts the build-runner IPC.

### 2. No 32-point collapse — the ko-win line

Black's moves from `regressions/4x4-black-win-after-ko.txt` (second game),
engine as White via `genmove W`:

| | baseline (HEAD) | EXP-9 |
| --- | --- | --- |
| final score | **B+16** | **W+3** |
| `HISTORY-DIVERGED` plies | **3** | **0** |
| refusals | — | 1 (`A1@node`, White's 4th move) |

The baseline reproduces the recorded transcript exactly, including the
collapse at White's 8th move (`W -> D4 child-value=16 stored-v0=-16`, a gap of
**32**). With the check, the engine refuses four plies earlier and every
subsequent ply satisfies `child-value == stored-v0`, so the **maximum
stored-vs-played gap goes 32 → 0**.

Note the endgame: White finishes at `-3`, exactly the stored fresh-start value
of that node. `regressions/README.md` observes that "a genuinely
fresh-start-perfect player would achieve −3 there" — on this line, the
mitigated player now does.

The 19-point swing (B+16 → W+3) is a **measured outcome on one line**, not a
claimed strength gain. The honest claim is the one about the gap: the engine no
longer steers by an undefined comparison.

### 3. No false refusal where `L == H`

3×3 even self-play on `artifacts/oracle-3x3.wzo`:
**`UNCHAINABLE` count = 0**, game ends **B+9**. Identity holds at every node
and every chosen child, as required.

Companion check — the *first* game in `4x4-black-win-after-ko.txt` is byte-for-byte
identical between baseline and EXP-9 (**W+16** both, zero refusals): where the
table is chainable, nothing changes.

### 5. Cost

Added work is ~`2n` table lookups per genmove (A1 over ≤ n children plus the
pass edge; A2 the same at the chosen child) — 32 lookups on 4×4. Measured over
**140 000 genmoves** on the game-1 line, where both engines play identically so
the delta is purely the check (artifact load, 0.45 s, excluded; 3 runs each,
spread ≤ 0.03 s):

| | wall | per genmove |
| --- | --- | --- |
| baseline | 3.54 s | 22.0 µs |
| EXP-9 | 3.75 s | 23.6 µs |
| **added** | **0.21 s** | **≈ 1.5 µs (+6.8 %)** |

Caveat: this measures the **accepted** path. A *refused* ply is dearer — the
fallback runs `benson_alive` twice plus a region flood per candidate move,
O(n²)-ish rather than O(n) — but it only occurs on refused plies, and it is
still microseconds at 4×4.

**The user decides whether +6.8 % per genmove is acceptable.**

## 5. Acceptance 4 — the honest finding: partially met

Criterion 4 predicted that on the `4x4-black-win-after-ko` line "at ply 7 the
node identity holds but the chosen child's does not → the engine refuses at ply
7 (not ply 8)."

A new GTP introspection command, `weizigo_chaincheck <colour>`, reports A1 and
A2 separately for the current position **without playing**, so the checks can be
traced along the *fixed* transcript (`genmove` would change the line). Trace
over `regressions/4x4-history-blunder.gtp`:

| ply | to move | a1 | a2 | `choose` would play | v0 |
| ---: | :--- | :-: | :-: | :--- | ---: |
| 1–6 | … | 1 | 1 | … | 2 |
| 7 | B | **1** | **1** | A2 | 2 |
| 8 | W | **0** | 1 | B4 | 0 |
| 9–12 | … | 1 | 1 | … | 1 … −3 |
| **13** | **B** | **1** | **0** | **D4** | **−3** |
| 14 | W | 0 | 0 | A1 | −3 |
| 15 | B | 0 | – | pass | −16 |
| 16 | W | 0 | 1 | A4 | −16 |
| 17–19 | … | 1 | 1 | … | 16 |

**The A2 mechanism is confirmed — at ply 13, not ply 7.** Ply 13 is exactly the
D-3 pattern: the node's own identity holds (`a1=1`) while the move `choose`
wants to play enters an unchainable child (`a2=0`), so the engine refuses at
ply 13 rather than walking into the incoherent ply-14 node. That is the
behaviour the criterion is *about*.

**But the specific ply-7 prediction does not reproduce.** At ply 7 both checks
pass, so the ply-8 A1 failure is **not** caught one ply early. The reason is
structural and worth recording: **A2 inspects the child of the move `choose`
prefers, not the move actually played.** At ply 7 `choose` prefers `A2`, whose
child is chainable; the transcript plays `C1`, and it is `C1` that leads to the
unchainable ply-8 node. A2 cannot anticipate a ply the engine would not have
played. Against an opponent who deviates from the engine's own preference — i.e.
any real opponent — A2 is a guard on *the engine's own next step*, not a general
one-ply-ahead alarm.

This does not weaken the mitigation: A1 catches the node when the engine
actually arrives there (ply 8, `a1=0` → refuse), which is what happened in the
live game in §4.2. It does mean the brief's framing — that the chosen-child
check would catch "the ply-8 entry" — is **not** what the trace shows, and the
`ply 7 / ply 8` numbering in `EXP-9.md` appears to come from a different line or
indexing than the committed regression transcript.

## 6. Epistemic status

**CLAIMED**, not verified-optimal. Specifically:

- The engine is **not** claimed optimal. Where both checks pass it plays the
  same move as before, which is fresh-start-optimal only on the `L == H` region
  (claim **C2**); the checks passing in the `L < H` region is a coincidence of
  that node, not a certificate.
- What *is* sound by theorem: the refusal fallback quantity (Benson) and the
  claim that a refused ply is one the engine declines to certify.
- Measured outcomes (§4) are single-line observations on 4×4 with one artifact.
  Per-goban epistemic independence forbids extrapolating them to other sizes.
- Not attempted here: bracket cuts on `[L, H]` (that is H5(c)/C3, falsified at
  3×3), and any change to the ruleset, the engine core, or the artifacts.

The intended reading is the one in the brief: **weaker but honest** — optimal
where the table is chainable, visibly refusing with a sound fallback where it
is not.

## 7. Files

- `src/gtp.zig` — `chainable_at_pos` / `chainable_at` / `rhs_chain`,
  `fallback_score` / `fallback_pick`, `choose_with_check` + `Refusal`, the
  `weizigo_chaincheck` GTP command, the refusal logging, and the new
  antisymmetry test.
- `docs/research/h5a-player-mitigation-2026-07-28.md` — this document.
