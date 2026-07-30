#!/usr/bin/env python3
"""
Task: F1-CENSUS-GAP · Role: worker · Model: DSPro/F1-CENSUS-GAP · Date: 2026-07-30

Standalone diff harness: compute the reachable 3×2 state sets under four
configurations (old/new ko rule × 4-seed/1-seed), find the symmetric
difference between the two configurations that produced the +3 gap, and
decode every state in the difference.

Read-only on src/ — this is a new file in docs/evidence/QA-023/.
Uses indep_3x2.py (Opus-5 audit, old ko rule) as the base module;
the corrected ko rule is applied per corrected.py's apply_place_fixed.
"""
import sys
from collections import deque
import indep_3x2 as M

# ── Corrected ko rule (from corrected.py, Opus-5) ──────────────────────────
def apply_place_fixed(board_rank, side, ko, passes, cell):
    board = M.unrank(board_rank)
    colour = 1 if side == 0 else -1
    if board[cell] != 0:
        return None
    if ko != M.KO_NONE and cell == ko:
        return None
    nxt = M.pos_from_move(board, colour, cell)
    if nxt is None:
        return None
    opp_before = sum(1 for i in range(M.N) if board[i] == -colour)
    opp_after  = sum(1 for i in range(M.N) if nxt[i] == -colour)
    captured = [i for i in range(M.N) if board[i] == -colour and nxt[i] == 0]
    new_ko = M.KO_NONE
    if opp_before - opp_after == 1 and captured:
        cells, _ = M.chain(nxt, cell)       # the placed stone's CHAIN (NOT just NBR of cell)
        libs = set(q for c in cells for q in M.NBR[c] if nxt[q] == 0)
        if len(cells) == 1 and len(libs) == 1:  # lone stone, one liberty
            new_ko = captured[-1]
    new_side = 1 if colour == 1 else 0
    return (M.rank(nxt), new_side, new_ko, 0), nxt


# ── Modified successors that can use either ko rule ────────────────────────
def make_successors(apply_place_fn):
    def successors(lin):
        board_rank, side, ko, passes = M.delinear(lin)
        if passes == 2:
            return []
        out = []
        p = M.apply_pass(board_rank, side, ko, passes)
        if p:
            out.append(p)
        for cell in range(M.N):
            r = apply_place_fn(board_rank, side, ko, passes, cell)
            if r:
                out.append(r)
        return out
    return successors


# ── Reachability fixpoint ──────────────────────────────────────────────────
def reach_from(roots, successors_fn, legality_filter=True):
    seen = set(roots)
    dq = deque(roots)
    while dq:
        lin = dq.popleft()
        for (st, nb) in successors_fn(lin):
            if legality_filter and not M.is_legal(nb):
                continue
            cl = M.linear(*st)
            if cl not in seen:
                seen.add(cl)
                dq.append(cl)
    return seen


# ── Seed sets ──────────────────────────────────────────────────────────────
# 4 seeds: empty goban × side (B,W) × passes (0,1) × KO_NONE (F1-SEEDROOTS)
ROOTS_4 = [M.linear(0, s, M.KO_NONE, p) for s in (0, 1) for p in (0, 1)]

# 1 seed: empty, Black, KO_NONE, passes=0 (single true game root)
ROOTS_1 = [M.linear(0, 0, M.KO_NONE, 0)]


# ── Goban display ──────────────────────────────────────────────────────────
def board_str(board_rank):
    """Return something like '.XO/XX.' for a 3×2 board."""
    b = M.unrank(board_rank)
    ch = {0: '.', 1: 'X', -1: 'O'}
    row0 = ''.join(ch[b[i]] for i in range(M.W))
    row1 = ''.join(ch[b[i + M.W]] for i in range(M.W))
    return f"{row0}/{row1}"

def side_str(side):
    return "B" if side == 0 else "W"

def ko_str(ko):
    if ko == M.KO_NONE:
        return "none"
    r, c = divmod(ko, M.W)
    return f"{chr(ord('a')+c)}{r+1}"

def decode_state(lin):
    board, side, ko, passes = M.delinear(lin)
    return (board_str(board), side_str(side), ko_str(ko), passes)


# ── Main ───────────────────────────────────────────────────────────────────
def main():
    # Four configurations
    configs = [
        ("old+4", M.apply_place, ROOTS_4),
        ("old+1", M.apply_place, ROOTS_1),
        ("new+4", apply_place_fixed, ROOTS_4),
        ("new+1", apply_place_fixed, ROOTS_1),
    ]

    results = {}
    for label, apply_fn, roots in configs:
        succ_fn = make_successors(apply_fn)
        seen = reach_from(roots, succ_fn, legality_filter=True)
        results[label] = seen
        print(f"# {label}: V = {len(seen)}")
        # Quick tally
        ko_real = sum(1 for l in seen if M.delinear(l)[2] != M.KO_NONE)
        term = sum(1 for l in seen if M.delinear(l)[3] == 2)
        side_b = sum(1 for l in seen if M.delinear(l)[1] == 0)
        boards = len(set(M.delinear(l)[0] for l in seen))
        print(f"#   ko-real={ko_real}  terminals={term}  B/W={side_b}/{len(seen)-side_b}  boards={boards}")

    # ── The gap the brief asks about: old+4 (2,586) vs new+1 (2,583) ──
    print()
    print("=" * 70)
    print("DIFF: old+4 (F1-SEEDROOTS, 2,586)  vs  new+1 (2B-FIX-KO, 2,583)")
    print("=" * 70)

    set_old4 = results["old+4"]
    set_new1 = results["new+1"]

    only_old = set_old4 - set_new1   # in old+4 but not in new+1
    only_new = set_new1 - set_old4   # in new+1 but not in old+4

    print(f"\nOnly in old+4 (not in new+1): {len(only_old)}")
    print(f"Only in new+1 (not in old+4): {len(only_new)}")
    print(f"Symmetric difference: {len(only_old) + len(only_new)}")

    if only_old:
        print(f"\n── States only in old+4 ({len(only_old)}) ──")
        for i, lin in enumerate(sorted(only_old), 1):
            b, s, k, p = decode_state(lin)
            board_r, side_r, ko_r, passes_r = M.delinear(lin)
            print(f"  [{i}] board={b}  side={s}  ko={k}  passes={p}")
            print(f"      linear={lin}  board_rank={board_r}  ko_raw={ko_r}")

    if only_new:
        print(f"\n── States only in new+1 ({len(only_new)}) ──")
        for i, lin in enumerate(sorted(only_new), 1):
            b, s, k, p = decode_state(lin)
            board_r, side_r, ko_r, passes_r = M.delinear(lin)
            print(f"  [{i}] board={b}  side={s}  ko={k}  passes={p}")
            print(f"      linear={lin}  board_rank={board_r}  ko_raw={ko_r}")

    # ── Also show the decomposition: what each factor removes ──
    print()
    print("=" * 70)
    print("DECOMPOSITION: isolating ko-rule effect vs seed-count effect")
    print("=" * 70)

    set_old1 = results["old+1"]
    set_new4 = results["new+4"]

    print(f"\nold+1: V = {len(set_old1)}")
    print(f"new+4: V = {len(set_new4)}")
    print(f"new+1: V = {len(set_new1)}")

    # ko-rule effect at fixed 4 seeds
    ko_rule_removes = set_old4 - set_new4
    ko_rule_adds = set_new4 - set_old4
    # seed-count effect at fixed old ko rule
    seed_removes = set_old4 - set_old1
    seed_adds = set_old1 - set_old4
    # seed-count effect at fixed new ko rule
    seed_new_removes = set_new4 - set_new1
    seed_new_adds = set_new1 - set_new4

    print(f"\nko-rule effect (old+4 → new+4): removes {len(ko_rule_removes)}, adds {len(ko_rule_adds)}")
    print(f"seed effect at old ko (old+4 → old+1): removes {len(seed_removes)}, adds {len(seed_adds)}")
    print(f"seed effect at new ko (new+4 → new+1): removes {len(seed_new_removes)}, adds {len(seed_new_adds)}")

    # Print the ko-rule-only diff
    if ko_rule_removes:
        print(f"\n── Removed by ko-rule fix (old+4 → new+4): {len(ko_rule_removes)} states ──")
        for i, lin in enumerate(sorted(ko_rule_removes), 1):
            b, s, k, p = decode_state(lin)
            board_r, side_r, ko_r, passes_r = M.delinear(lin)
            print(f"  [{i}] board={b}  side={s}  ko={k}  passes={p}")
            print(f"      linear={lin}  board_rank={board_r}  ko_raw={ko_r}")

    if ko_rule_adds:
        print(f"\n── Added by ko-rule fix (old+4 → new+4): {len(ko_rule_adds)} states ──")
        for i, lin in enumerate(sorted(ko_rule_adds), 1):
            b, s, k, p = decode_state(lin)
            board_r, side_r, ko_r, passes_r = M.delinear(lin)
            print(f"  [{i}] board={b}  side={s}  ko={k}  passes={p}")
            print(f"      linear={lin}  board_rank={board_r}  ko_raw={ko_r}")

    # Check: does old+4 ⊆ old+1? (it should be, since 4 seeds ⊂ old+1's reachable... wait no)
    # Actually old+4 uses 4 seeds and old+1 uses 1 seed. old+1 is a subset of old+4's seeds.
    # So old+1 ⊆ old+4 (since starting from fewer roots gives a subset of reachable states).
    # Let's verify.
    print(f"\nSanity: old+1 ⊆ old+4? {set_old1 <= set_old4}")
    print(f"Sanity: new+1 ⊆ new+4? {set_new1 <= set_new4}")
    print(f"Sanity: new+1 ⊆ old+1? {set_new1 <= set_old1}")

    # ── Check for states involving passes=1 seeds ──
    # The 4 seeds include passes=1 (empty, side, KO_NONE, passes=1).
    # Are there states reachable from passes=1 that are NOT reachable from passes=0?
    extra_from_passes1 = set_old1 - results.get("old+0", set())
    # Actually we don't have old+0 but old+1 = single root (passes=0).
    # The difference between old+4 and old+1 should include states that are
    # reachable from the passes=1 seeds but not from passes=0.

    # States reachable as transitives from passes=0 root under old ko
    # but also see what we get from the passes=1 seeds.
    # The seeds in old+4 are: (0,B,none,0), (0,B,none,1), (0,W,none,0), (0,W,none,1)
    # old+1 has only: (0,B,none,0)

    # Let's find the states only reachable from passes=1 seeds
    roots_p0 = [M.linear(0, 0, M.KO_NONE, 0)]
    succ_old = make_successors(M.apply_place)
    set_from_p0 = reach_from(roots_p0, succ_old, legality_filter=True)
    print(f"\nold+0 (single root, passes=0 only): V = {len(set_from_p0)}")

    roots_p1 = [M.linear(0, 1, M.KO_NONE, 0), M.linear(0, 0, M.KO_NONE, 1), M.linear(0, 1, M.KO_NONE, 1)]
    set_from_extras = reach_from(roots_p1, succ_old, legality_filter=True)
    # But these also start from non-root states that may overlap

    # Actually, let me just compute the subset that is reachable from passes=1 seeds but NOT from passes=0
    only_from_p1_seeds = set_old4 - set_from_p0
    print(f"States in old+4 but not reachable from (0,B,none,0) alone: {len(only_from_p1_seeds)}")

    if only_from_p1_seeds:
        print(f"\n── States ONLY reachable via passes=1 seeds (under old ko) ──")
        for i, lin in enumerate(sorted(only_from_p1_seeds), 1):
            b, s, k, p = decode_state(lin)
            board_r, side_r, ko_r, passes_r = M.delinear(lin)
            print(f"  [{i}] board={b}  side={s}  ko={k}  passes={p}")
            print(f"      linear={lin}  board_rank={board_r}  ko_raw={ko_r}")

    # ── Summary ──
    print()
    print("=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"old+4 (F1-SEEDROOTS):  {len(set_old4)}")
    print(f"new+1 (2B-FIX-KO):     {len(set_new1)}")
    print(f"gap:                   {len(set_old4) - len(set_new1)}")
    print(f"symmetric difference:  {len(only_old) + len(only_new)}")
    print(f"  only in old+4:       {len(only_old)}")
    print(f"  only in new+1:       {len(only_new)}")


if __name__ == "__main__":
    main()
