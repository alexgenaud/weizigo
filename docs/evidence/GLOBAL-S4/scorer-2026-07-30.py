#!/usr/bin/env python3
"""GLOBAL.S4 — independent Tromp–Taylor area scorer.

Verification: run against the committed terminal corpus; every
expected score must match the scorer output exactly.

Author: DSPro/T112, 2026-07-30.
"""
import sys

def area_score(board, w, h):
    """Tromp–Taylor Chinese area score, Black-positive.

    A point counts for Black (White) if it holds that colour's stone,
    or is empty and its 4-connected empty region touches only Black
    (White).  Regions touching both colours or neither are neutral.
    Input: flat list `board`, row-major; >0 Black, <0 White, 0 empty.
    """
    n = w * h
    black = white = 0
    visited = [False] * n
    for p in range(n):
        if board[p] > 0:
            black += 1
            continue
        if board[p] < 0:
            white += 1
            continue
        if visited[p]:
            continue
        # flood the empty region
        stack = [p]
        visited[p] = True
        size = 0
        tb = tw = False
        while stack:
            q = stack.pop()
            size += 1
            r, c = divmod(q, w)
            for nb in (q - w,) * (r > 0) + (q + w,) * (r < h - 1) + \
                      (q - 1,) * (c > 0) + (q + 1,) * (c < w - 1):
                if board[nb] > 0:
                    tb = True
                elif board[nb] < 0:
                    tw = True
                elif not visited[nb]:
                    visited[nb] = True
                    stack.append(nb)
        if tb and not tw:
            black += size
        if tw and not tb:
            white += size
    return black - white


# ── size-stratified terminal corpus from project test fixtures ──────────
# Each entry: (name, board_flat, w, h, expected_score)
# Sources: src/terminal.zig, src/rules.zig, src/score.zig — exact values.
# Adds 2×2, 3×2, 4×4 terminals to cover the size-agnostic claim.

# sparse boards defined up front so the corpus is a clean list
_SPLIT_5X5 = [0] * 25; _SPLIT_5X5[0] = 1; _SPLIT_5X5[24] = -1

CORPUS = [
    # ── 2×2 (added; smallest size calibrates flood-fill boundaries) ──
    ("2x2/empty",          [0,0,0,0],                                  2,2,  0),
    ("2x2/all-black",      [1,1,1,1],                                  2,2,  4),
    ("2x2/all-white",      [-1,-1,-1,-1],                              2,2, -4),
    ("2x2/lone-black",     [1,0,0,0],                                  2,2,  4),
    ("2x2/bw-diag",        [1,0,0,-1],                                 2,2,  0),

    # ── 3×2 (added; rectangular, asymmetric) ──
    ("3x2/empty",          [0,0,0,0,0,0],                              3,2,  0),
    ("3x2/all-black",      [1,1,1,1,1,1],                              3,2,  6),
    ("3x2/lone-black",     [1,0,0,0,0,0],                              3,2,  6),

    # ── 3×3 (from rules.zig / score.zig tests) ──
    ("3x3/empty",          [0]*9,                                      3,3,  0),
    ("3x3/mid-col-b",      [0,1,0, 0,1,0, 0,1,0],                     3,3,  9),
    ("3x3/center-b",       [0,0,0, 0,1,0, 0,0,0],                     3,3,  9),
    ("3x3/bw-adjacent",    [1,-1,0, 0,0,0, 0,0,0],                    3,3,  0),

    # ── 4×4 (added; max solved board) ──
    ("4x4/empty",          [0]*16,                                     4,4,  0),
    ("4x4/all-black",      [1]*16,                                     4,4, 16),
    ("4x4/all-white",      [-1]*16,                                    4,4,-16),
    ("4x4/lone-black",     [1]+[0]*15,                                 4,4, 16),
    ("4x4/chessboard",     [1,-1,1,-1, -1,1,-1,1,
                            1,-1,1,-1, -1,1,-1,1],                    4,4,  0),
    ("4x4/bw-split-wall",  [1,1,0,0, 1,1,0,0,
                            0,0,-1,-1, 0,0,-1,-1],                    4,4,  0),

    # ── 5×5 (from terminal.zig tests) ──
    ("5x5/empty",          [0]*25,                                     5,5,  0),
    ("5x5/all-black",      [1]*25,                                     5,5, 25),
    ("5x5/all-white",      [-1]*25,                                    5,5,-25),
    ("5x5/one-black",      [1]+[0]*24,                                 5,5, 25),
    ("5x5/split-corners",  _SPLIT_5X5,                                 5,5,  0),
    ("5x5/mid-col-wall",   [0,0,1,0,0]*5,                              5,5, 25),
    ("5x5/white-2eye",     [-1,-1,-1,-1,-1, -1,0,-1,0,-1,
                             -1,-1,-1,-1,-1,
                             0,0,0,0,0, 0,0,0,0,0],                    5,5,-25),
    ("5x5/army-flags",     [1,2,3,2,1, 4,0,5,0,6,
                             1,1,7,1,1,
                             0,0,0,0,0, 0,0,0,0,0],                    5,5, 25),
    ("5x5/owned-settled",  [1,1,1,1,1, 1,0,1,0,1,
                             1,1,1,1,1,
                             1,1,1,1,1, 1,1,1,1,1],                    5,5, 25),
]

if __name__ == "__main__":
    passed = 0
    for name, board, w, h, expected in CORPUS:
        got = area_score(board, w, h)
        ok = got == expected
        if ok:
            passed += 1
        else:
            print(f"FAIL {name}: got {got}, expected {expected}")
    total = len(CORPUS)
    print(f"{passed}/{total} passed")
    sys.exit(0 if passed == total else 1)
