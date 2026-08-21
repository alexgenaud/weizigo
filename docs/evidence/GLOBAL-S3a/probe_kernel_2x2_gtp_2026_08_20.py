#!/usr/bin/env python3
"""DCLAIM chunk #3 — Part B: 2x2 move/capture/suicide kernel vs the engine.

Claim under test — docs/epistemic/CLAIMS.md row `GLOBAL.S3a` (PROVEN, Tier B):
    "The move/capture/suicide kernel is correct; OEIS A094777 attests the
     legal-position count and nothing more"

Part A (probe_legal_count.py) re-derived the OEIS-attested legal-position
counts. Part B tests the kernel itself at the move level: for every 2x2
position and every move, the engine's response and resulting board must match
an independent implementation of the move/capture/suicide rules (place stone;
capture opponent groups with no liberties; reject suicide = placed group with
no liberties; reject occupied cells).

The ko rule and positional superko are SEPARATE legality layers (S3b
territory — explicitly "not attested by OEIS" per 4x4/EPISTEMIC.md), so their
rejections are classified apart from the kernel and verified only for
self-consistency against the session's own history:
  - ko rejection ("illegal move (ko)")   -> ko layer: cannot fire here at all,
    because construction is capture-free (ko stays NONE); any event is flagged.
  - PSK rejection ("positional superko") -> history layer: the move's result
    position must already occur in the session's construction history.
A rejection at either layer is NOT a kernel violation: the kernel verdict is
about accept-vs-board equality and suicide/occupied rejections only.

Method:
  - One engine session per position: construct the position by playing stones
    in reverse-removal order (capture-free and suicide-free by the removal
    lemma: removing a stone from a legal position keeps it legal and never
    reduces remaining liberties), so ko is never set and no construction step
    can capture; each construction step's board is itself verified against the
    independent kernel.
  - In that session run every move expected to be REJECTED (suicide/occupied
    rejections do not mutate session state).
  - Each move expected to be ACCEPTED gets its own fresh session (accepted
    moves mutate state and may set ko; the engine has no undo), so every
    acceptance is verified against an independent expected board.
  - The first-removed construction stone is chosen outside the set of stones
    any accepted test move captures, so capture-move results are absent from
    the construction history and cannot trip PSK — except from 1-stone
    positions, where capturing the last stone recreates the empty board
    (always in history): expected PSK rejection, recorded in the history layer.

Independence: no weizigo source is imported or executed for the kernel; the
engine binary is driven only through its GTP surface.

Usage: python3 probe_kernel_2x2_gtp.py [path-to-gtp-binary] [path-to-wzo]
Exit 0 iff zero kernel violations.
"""

import subprocess
import sys
import time

W = H = 2
N = 4
ARTIFACT = "artifacts/oracle-2x2.wzo"
GTP_BIN = "./zig-out/gtp"


def nb_idx(i):
    r, c = divmod(i, 2)
    out = []
    for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        rr, cc = r + dr, c + dc
        if 0 <= rr < 2 and 0 <= cc < 2:
            out.append(rr * 2 + cc)
    return out


NB = [nb_idx(i) for i in range(N)]
VERT = {i: chr(ord('A') + i % 2) + str(2 - i // 2) for i in range(N)}


def group_of(start, cells):
    seen = {start}
    stack = [start]
    while stack:
        c = stack.pop()
        for n in NB[c]:
            if n in cells and n not in seen:
                seen.add(n)
                stack.append(n)
    return seen


def has_liberty(group, occ):
    for c in group:
        for n in NB[c]:
            if n not in occ:
                return True
    return False


def legal_position(black, white):
    """Position legality: every monochromatic group has >= 1 liberty."""
    occ = set(black) | set(white)
    for stones in (black, white):
        rem = set(stones)
        while rem:
            s = next(iter(rem))
            g = group_of(s, rem)
            if not has_liberty(g, occ):
                return False
            rem -= g
    return True


def kernel(black, white, side, cell):
    """Independent Tromp-Taylor move kernel, no ko.

    Returns ('ok', nb, nw) on a legal move, ('occupied',) if the cell has a
    stone, ('suicide',) if the placed group ends with no liberties.
    """
    b = set(black)
    w = set(white)
    mine = b if side == 1 else w
    theirs = w if side == 1 else b
    if cell in b or cell in w:
        return ('occupied',)
    mine.add(cell)
    occ = set(b) | set(w)
    captured = set()
    for s in list(theirs):
        if s in captured:
            continue
        g = group_of(s, theirs)
        if not has_liberty(g, occ):
            captured |= g
    theirs -= captured
    occ = set(b) | set(w)
    g = group_of(cell, mine)
    if not has_liberty(g, occ):
        return ('suicide',)
    return ('ok', frozenset(b), frozenset(w))


def removal_order(black, white, avoid):
    """Reverse-removal construction order for a legal position.

    Returns a list of (cell, side) to play from the empty board (stones first
    placed = removed last). The first-removed stone (last played) is chosen
    outside `avoid` — the set of stones any accepted test move captures — so
    capture-move results are absent from the construction history and cannot
    trip the PSK layer (removal keeps the position legal; the lemma).
    """
    stones = dict()
    for c in black:
        stones[c] = 1
    for c in white:
        stones[c] = -1
    order = []  # cells removed first -> last
    cur_b = set(black)
    cur_w = set(white)
    while cur_b or cur_w:
        pick = None
        for c in sorted(stones):
            if c in (cur_b | cur_w) and c not in avoid:
                pick = c
                break
        if pick is None:
            pick = sorted(cur_b | cur_w)[0]
        order.append(pick)
        cur_b.discard(pick)
        cur_w.discard(pick)
        assert legal_position(cur_b, cur_w), "removal broke legality"
    play = []
    for c in reversed(order):
        play.append((c, stones[c]))
    return play


def history_positions(play):
    """All positions the session passes through: empty + after each play."""
    hist = [frozenset()]
    b = set()
    w = set()
    for cell, side in play:
        if side == 1:
            b.add(cell)
        else:
            w.add(cell)
        hist.append(frozenset(b) | frozenset(w))
    return hist


# ---------------------------------------------------------------------------
# GTP driver
# ---------------------------------------------------------------------------
class Engine:
    def __init__(self, path, artifact):
        self.p = subprocess.Popen(
            [path, artifact], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            text=True, bufsize=1)
        self.gtp("boardsize 2")
        self.gtp("clear_board")

    def gtp(self, cmd):
        self.p.stdin.write(cmd + "\n")
        self.p.stdin.flush()
        out = []
        while True:
            line = self.p.stdout.readline()
            if line == "":
                raise SystemExit("engine terminated")
            if line.strip() == "" and out:
                break
            out.append(line.rstrip("\n"))
        return out

    def close(self):
        try:
            self.p.stdin.write("quit\n")
            self.p.stdin.flush()
        except Exception:
            pass
        self.p.terminate()


def parse_board(reply_lines):
    """showboard reply -> (black, white) index sets.
    reply_lines includes the GTP '= ' prefix line; skip it."""
    lines = reply_lines
    if lines and lines[0].lstrip().startswith("="):
        lines = lines[1:]
    rows = [ln.strip() for ln in lines if ln.strip()]
    b = set()
    w = set()
    for r, row in enumerate(rows):
        toks = row.split()
        for c, tok in enumerate(toks):
            i = r * 2 + c
            if tok == 'X':
                b.add(i)
            elif tok == 'O':
                w.add(i)
    return b, w


def construct(eng, play):
    """Replay `play`; verify each step is accepted and the board matches the
    independent kernel. Returns the final (black, white)."""
    b = set()
    w = set()
    for cell, side in play:
        color = "B" if side == 1 else "W"
        reply = eng.gtp("play %s %s" % (color, VERT[cell]))
        if not reply[0].startswith("="):
            raise AssertionError(
                "construction rejected: %s at %s%s (pos %s/%s) reply %r"
                % (color, VERT[cell], " ", b, w, reply))
        res = kernel(b, w, side, cell)
        assert res[0] == "ok", "construction step not ok: %r" % (res,)
        b, w = set(res[1]), set(res[2])
        nb, nw = parse_board(eng.gtp("showboard"))
        if nb != b or nw != w:
            raise AssertionError(
                "construction board mismatch at %s%s: engine %s/%s vs kernel %s/%s"
                % (color, VERT[cell], nb, nw, b, w))
    return b, w


class Counters:
    def __init__(self):
        self.total = 0
        self.kernel_ok = 0
        self.kernel_reject_ok = 0
        self.occupied = 0
        self.kernel_violations = 0
        self.ko = 0
        self.ko_violations = 0
        self.psk = 0
        self.psk_violations = 0
        self.construction_failures = 0


def check_one(eng, key, exp, hist, counters):
    counters.total += 1
    kind, side, cell = key
    color = "B" if side == 1 else "W"
    if kind == "pass":
        cmd = "play %s pass" % color
    else:
        cmd = "play %s %s" % (color, VERT[cell])
    reply = eng.gtp(cmd)
    head = reply[0]
    if head.startswith("="):
        if exp[0] != "ok":
            counters.kernel_violations += 1
            print("VIOLATION: accepted move, expected %s: %s" % (exp[0], key))
            return
        nb, nw = parse_board(eng.gtp("showboard"))
        if set(nb) == set(exp[1]) and set(nw) == set(exp[2]):
            counters.kernel_ok += 1
        else:
            counters.kernel_violations += 1
            print("VIOLATION: board mismatch: %s engine %s/%s vs kernel %s/%s"
                  % (key, nb, nw, exp[1], exp[2]))
    elif "ko" in head:
        counters.ko += 1
        # ko cannot fire here: construction is capture-free, so ko_point is
        # NONE at the test position in every session. Any ko event is an
        # anomaly in the ko layer (S3b territory), not a kernel verdict.
        counters.ko_violations += 1
        print("KO-LAYER EVENT (unexpected): %s at %s — construction was "
              "capture-free so ko must be NONE here" % (head, key))
    elif "superko" in head:
        counters.psk += 1
        result = frozenset(exp[1]) | frozenset(exp[2]) if exp[0] == "ok" else None
        if result is not None and result in hist:
            pass  # consistent: the move recreates a construction position
        else:
            counters.psk_violations += 1
            print("PSK-LAYER VIOLATION: %s at %s, result %s not in history %s"
                  % (head, key, result, hist))
    else:
        # plain "illegal move": kernel must say suicide or occupied
        if exp[0] in ('suicide', 'occupied'):
            counters.kernel_reject_ok += 1
            if exp[0] == 'occupied':
                counters.occupied += 1
        else:
            counters.kernel_violations += 1
            print("VIOLATION: rejected move, expected %s: %s" % (exp[0], key))


def main():
    gtp_bin = sys.argv[1] if len(sys.argv) > 1 else GTP_BIN
    artifact = sys.argv[2] if len(sys.argv) > 2 else ARTIFACT

    positions = []
    for code in range(3 ** 4):
        b, w = set(), set()
        for i in range(4):
            d = (code // (3 ** i)) % 3
            if d == 1:
                b.add(i)
            elif d == 2:
                w.add(i)
        positions.append((frozenset(b), frozenset(w)))

    c = Counters()
    t0 = time.time()
    for black, white in positions:
        if not legal_position(set(black), set(white)):
            continue  # illegal positions cannot be constructed; not in scope
        expectations = {}
        for side in (1, -1):
            for cell in range(4):
                expectations[("play", side, cell)] = kernel(black, white, side, cell)
        expectations[("pass", 1, None)] = ('ok', black, white)
        expectations[("pass", -1, None)] = ('ok', black, white)

        # stones any accepted test move captures (shrinks the board)
        avoid = set()
        for (kind, side, cell), v in expectations.items():
            if kind == "play" and v[0] == "ok":
                b2, w2 = set(v[1]), set(v[2])
                if len(b2) + len(w2) == len(black) + len(white) - 1:
                    avoid |= (set(black) | set(white)) - (b2 | w2)
        play = removal_order(black, white, avoid)
        hist = history_positions(play)

        rejected = [k for k, v in expectations.items()
                    if v[0] in ('suicide', 'occupied')]
        accepted = [k for k, v in expectations.items() if v[0] == 'ok']

        # session 1: all rejected-expected moves (they do not mutate state)
        if rejected:
            eng = Engine(gtp_bin, artifact)
            try:
                construct(eng, play)
                for key in rejected:
                    check_one(eng, key, expectations[key], hist, c)
            except AssertionError as e:
                c.construction_failures += 1
                print("CONSTRUCTION FAILURE at %s/%s: %s" % (black, white, e))
            finally:
                eng.close()
        # fresh session per accepted move (no undo; accepted moves set ko)
        for key in accepted:
            eng = Engine(gtp_bin, artifact)
            try:
                construct(eng, play)
                check_one(eng, key, expectations[key], hist, c)
            except AssertionError as e:
                c.construction_failures += 1
                print("CONSTRUCTION FAILURE at %s/%s: %s" % (black, white, e))
            finally:
                eng.close()

    elapsed = time.time() - t0
    print()
    print("kernel accepted w/ board match : %d" % c.kernel_ok)
    print("kernel rejections verified     : %d (%d occupied, %d suicide)"
          % (c.kernel_reject_ok, c.occupied, c.kernel_reject_ok - c.occupied))
    print("kernel violations              : %d" % c.kernel_violations)
    print("ko layer events                : %d (all anomalous: %d)"
          % (c.ko, c.ko_violations))
    print("PSK layer events               : %d (consistent %d, violations %d)"
          % (c.psk, c.psk - c.psk_violations, c.psk_violations))
    print("construction failures          : %d" % c.construction_failures)
    print("total moves verified           : %d (%.1fs)" % (c.total, elapsed))
    denom = c.kernel_ok + c.kernel_reject_ok + c.kernel_violations
    print("KERNEL DENOMINATOR             : %d   violations = %d"
          % (denom, c.kernel_violations))
    print("KERNEL VERDICT: %d/%d violations" % (c.kernel_violations, denom))
    bad = c.kernel_violations or c.ko_violations or c.psk_violations \
        or c.construction_failures
    if not bad:
        print("ALL LAYERS CLEAN — kernel reproduced at 2x2")
        return 0
    print("FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
