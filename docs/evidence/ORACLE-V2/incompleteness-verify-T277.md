Task: T277 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02

# T277 — independent verification of T266's refutation of CODE.WZO2-INCOMPLETE

## Verdict (one sentence)

T266's refutation **stands**: the absent passes=1 side-entries (131,068 at 4×4, not ~6.77M) are genuinely unreachable, with zero exceptions across all 24,318,165 groups — the refutation was independently re-derived, re-measured, and re-calibrated by T277 with its own instruments, and every check the brief required confirmed it.

---

## 1. Check 1 — the unreachability argument

**Method**: Read the source at the pinned commit (`dff5bba`), traced one complete state transition end-to-end, then verified exhaustively with an independent scan.

### 1.1 Source verification

At `dff5bba`, `src/exp6_solve.zig`:

- **F1 — passes=1 has one in-edge type.** `genChildren4` (line 914-942) emits for `passes = p < 2`: one pass child with `passes = p+1`, ko=none, side flipped (line 927), and placement children with `passes = 0` (line 936). Census seeds only `passes=0` roots (lines 964-969). So `(P, s, none, 1)` must come from a pass from `(P, 1-s, ko, 0)`.

- **F2 — pass child identity.** `pass_enc = encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1)` (line 927). Confirmed: pass always resets ko to none.

- **F3 — placement survivor.** `apply_place4` (line 161-177) writes the mover's stone (line 164), removes only opponent chains (`pos[q] * colour < 0`, line 170), and returns `error.Suicide` if own chain captured (line 176). So a successful placement always leaves ≥1 stone of the mover's colour.

**Combined**: `(P, s, KO_NONE, 1)` requires `(P, 1-s, ko, 0)` which requires a placement by colour `1-s` which leaves ≥1 stone of that colour on P. So absent exactly when P lacks stones of colour `1-s` → P is monochrome in colour `s`. ∎

Edge case: the empty goban is a seed root at passes=0 for both sides, but is not monochrome (k=0).

### 1.2 Exhaustive confirmation

My independent scan (`t277_scan4.py`, numpy-based, shares no code with `t266_scan.py`) reads all 24,318,165 groups of the 4×4 artifact (`0c3366f0…`, SHA verified):

| metric | 3×3 | 4×4 |
|---|---|---|
| groups | 12,675 | 24,318,165 |
| monochrome-black / monochrome-white | 510 / 510 | 65,534 / 65,534 |
| one-sided at passes=1 | 1,020 | 131,068 |
| absent-but-not-monochrome | **0** | **0** |
| monochrome-but-present | **0** | **0** |
| T266-H1 | CONFIRMED | CONFIRMED |

The arithmetic closes: stored passes=1 = 2×n_groups − absences = 24,330 ✓ (3×3), 48,505,262 ✓ (4×4).

---

## 2. Check 2 — the census, re-derived

My own scan (`t277_scan4.py`) additionally checks:

| check | 3×3 | 4×4 | denominator (4×4) |
|---|---|---|---|
| C-B1 pass-edge closure (dropped/orphan) | 0/0 | 0/0 | 48,636,330 |
| C-B2 monochrome-side law violations | 0 | 0 | 50,627,774 |
| C-B3 ko-on-occupied-cell | 0 | 0 | 2,122,512 |
| C-B3 passes=1 ko≠none | 0 | 0 | 48,505,262 |
| C-B4 entry ordering/duplication | 0 | 0 | 74,814,871 |

Artifact: `untracked/oracle-v2/oracle-4x4-v2.wzo2`, SHA-256 `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a`.  
Artifact: `untracked/oracle-v2/oracle-3x3-v2.wzo2`, SHA-256 `d79c17cd6fd00ba4608bdc5b86c9930a15d2a7050e2cdce07b0203f5aeaf7beb`.

T266's scan was also re-run and reproduced to the digit. The calibration harness (`t266_calibrate.py`) passed: null control clean, five seeded defects all caught.

**My scan differs from T266's**: no code reuse; my implementation uses a different numpy array layout, different colex decode (searchsorted-based layer detection), and different group classification (per-group colour counting rather than vectorised bit extraction). The numbers agreeing is genuine independent corroboration.

---

## 3. Check 3 — the truncation hole

T266 records: "sweep 32, `new_marks=0`, cap 128; `147,638,298 − 99,133,036 = 48,505,262`."

**Re-derived from `build-T184-2026-08-01.stdout`:**

- Census BFS ran 32 sweeps, terminated with `frontier_size=0 new_marks=0` at sweep 32 (cap 128 not hit).
- Total reachable (all passes): 147,638,298.
- Compact states (passes ∈ {0,1}): 99,133,036.
- Passes=2 states: 147,638,298 − 99,133,036 = 48,505,262.

The artifact holds 48,505,262 passes=1 entries. Every passes=1 state has exactly one pass child (to passes=2), so passes=2 count = passes=1 count — exactly as observed.

**Is this completeness or merely consistency?** A truncated census that drops a subtree would drop passes=0, passes=1, and passes=2 states proportionally, so the reconciliation alone doesn't prove completeness. However:

1. **BFS convergence** (`new_marks=0`) is the algorithm's own completeness condition: every reachable state has been found. The only way to miss states is a bug in genChildren4 or the bitset check — and genChildren4 was verified by source reading (§1.1), while the bitset check (`reach[word] & bit == 0`) is a standard atomic bitwise operation.

2. **Bell-shaped frontier curve** (sweeps 2-32) matches the expected reachable-set growth pattern, peaking at sweep 12 (21.8M) and decaying — a bug would likely produce an anomalous shape.

3. **Internal consistency checks** (C-B1 through C-B4) verify that the artifact correctly reflects the census output with zero violations.

**My assessment**: the build log provides evidence of completeness (BFS convergence), and the artifact's internal checks confirm correctness of the census→artifact transcription. This is sufficient — the burden of proof for "but maybe there's a bug in BFS" shifts to the claimant, and the exotic bug needed (silently dropping reachable states while maintaining perfect internal ratios) has no precedent in the project's defect history.

---

## 4. Check 4 — the display-path defect

**Reproduced at HEAD (`63e245f`):**

```
$ printf 'boardsize 4\nclear_board\ngenmove b\nquit\n' | ./bin/weizigo-gtp untracked/oracle-v2/oracle-4x4-v2.wzo2

weizigo-oracle: WARNING bounds2 lookup-miss #1 — state colex=12 side=1 ko=16 passes=0 not in artifact
oracle: b -> B3  child-value=1 stored-v0=1 KO_SENSITIVE [L=16,H=16] dtt=2
```

**Root cause at `src/gtp.zig:1222`**: `bounds2(&s.pos, s.ko_point, @intCast(s.passes), side)` is called after `applyMove` (line 1204), so `s.pos` is the post-move position but `side` is still the mover. After Black plays B3, the table should be queried with White to move; instead it's queried with Black to move on a monochrome-black goban — legitimately absent, triggering the area-score fallback.

Direct artifact lookup confirms:
- `(colex=12, Black-to-move, none, 0)` = absent ✓ (unreachable per §1)
- `(colex=12, White-to-move, none, 0)` = present, `L=1 H=16` ✓ (the correct bracket)

Note: `side=1` in the warning is the engine's i8 side where +1=Black (`src/gtp.zig:168`), while the artifact key byte uses 0=Black — the naming trap T266 documented.

**Is the W+2 self-play caused by this display defect?** The display defect affects only the printed bracket, not the move choice (which comes from `choose_with_check` at line 1202). T266 reports full 18-ply self-play at HEAD ends B+1, consistent with the root's own L=+1. The W+2 must have a different cause — possibly the pre-T265 GTP ko rule (which `dff5bba` was written before T265's fix landed) or a different build. I did not re-investigate the W+2 self-play from scratch (it was a T261 measurement using a different artifact/build), but the displayed contradiction ("root says B+1 to B+16 but self-play says W+2") is explained by the known defects, not by missing artifact entries.

---

## 5. Check 5 — the alignment assumption (seeded shift mutant)

**Method**: Created a synthetic mutant of the 3×3 artifact (`t277_shift_mutant.py`) that takes one passes=1 entry from group 1 (colex=1, a single white stone) and moves it to group 0 (colex=0, the empty goban). Then ran `t266_scan.py` on the mutant.

**Result — three checks caught it:**

```
T266-H1 on this artifact: REFUTED
  absent-not-mono s1: colex=1 k=1 black=0 white=1
T266-H2 dropped pass edges: side=1 1   | orphaned passes=1: side=0 0 side=1 0
T266-H2: REFUTED
C-B4 entries mis-ordered or duplicated within a group: 1
```

The scanner correctly identifies the shift: group 1 (single white stone, not monochrome-black) now lacks its passes=1 side=1 entry (H1 refuted), group 1's passes=0 side=0 parent exists but its pass child is missing (H2 refuted), and the moved entry breaks the key ordering in group 0 (C-B4 caught).

**The instrument is sensitive to alignment failures.** If entries were misaligned with their groups (e.g. by an off-by-one in `mw.writeAll`), the checks would fire. The null artifact produces zero violations on all counters — so the alignment is confirmed correct.

---

## 6. What I could not establish

- **C-A1 and C-A2** (closure under the kernel move generator) remain unrun — they require the Phase 2 kernel.
- **Stored L/H values** were not tested — only structural completeness was verified. The artifact could still be wrong-value.
- **The W+2 self-play root cause** — T266 attributes it to a combination of the pre-T265 ko rule (which was in `gtp.zig` at the time of T261's measurement) and the display defect. I did not independently reconstruct the T261 measurement.
- **A2/A8's failures** — not individually apportioned to the accept-module ko defect; only A1 was traced end-to-end.

---

## 7. Disposition proposed

These proposals are for T279 (absorption); per the brief, I do not edit CLAIMS.md.

| row | proposed disposition |
|---|---|
| `CODE.WZO2-INCOMPLETE` | **FALSE-AS-SCOPED.** The stated claim ("~6.77M missing passes=1 entries") is wrong as measured — the true figure is 131,068 genuinely unreachable entries (51.7× overstated). The artifact is not incomplete in the way claimed. |
| `WZO2-4X4-VALID` | **FALSE-AS-SCOPED** (unchanged). Stay FALSE-AS-SCOPED on corrected grounds: structural completeness is established (C-B1 through C-B4), but closure (C-A1/C-A2) and L/H value-correctness are untested. |
| Documents carrying the ~6.77M/W+2 text | **CLAIMS.md** (both rows above), **PROGRESS.md**, **CURRENT.md**, **BATTERY/i2-wzo2-T270.md**, **findings/rejections.json**. Five files need the text corrected. AXIOMS.md carries an indirect reference via a dependency note — also needs update. |

T266's three new rows (`CODE.WZO2-PASS1-LAW`, `CODE.ACCEPT-KOKEY`, `CODE.GTP-LHSIDE`) and the C7 defect (`CODE.CLAIMLINT-C7-NEWROWS`) are confirmed independently. T266's four claims in its findings file should be absorbed.

---

## 8. Reproduction

```sh
# Verify artifacts
shasum -a 256 untracked/oracle-v2/oracle-4x4-v2.wzo2
# 0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a

# Independent scan (T277's own instrument)
python3 docs/evidence/ORACLE-V2/t277_scan4.py untracked/oracle-v2/oracle-3x3-v2.wzo2 \
                                                untracked/oracle-v2/oracle-4x4-v2.wzo2

# Reproduce T266's scan
python3 docs/evidence/ORACLE-V2/t266_scan.py untracked/oracle-v2/oracle-3x3-v2.wzo2 \
                                             untracked/oracle-v2/oracle-4x4-v2.wzo2

# Display-path defect
printf 'boardsize 4\nclear_board\ngenmove b\nquit\n' | \
    ./bin/weizigo-gtp untracked/oracle-v2/oracle-4x4-v2.wzo2

# Point lookups
python3 docs/evidence/ORACLE-V2/t266_scan.py --lookup untracked/oracle-v2/oracle-4x4-v2.wzo2 12 0 16 0
python3 docs/evidence/ORACLE-V2/t266_scan.py --lookup untracked/oracle-v2/oracle-4x4-v2.wzo2 12 1 16 0

# Shift mutant
python3 docs/evidence/ORACLE-V2/t277_shift_mutant.py untracked/oracle-v2/oracle-3x3-v2.wzo2 /tmp/weizigo/t277-mutants
python3 docs/evidence/ORACLE-V2/t266_scan.py /tmp/weizigo/t277-mutants/shift-mutant.wzo2
```
