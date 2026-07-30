#!/usr/bin/env python3
# T110 (2026-07-30): diff the Python port's 3x2 retrograde tables against the
# committed Zig, slot by slot.  Validates the half of `t13_probe.py` that is a
# port (as opposed to the probe driver, which is a reconstruction).
#
#   zig build-exe -O ReleaseFast --dep retro \
#       -Mmain=docs/evidence/T13/zig_dump_3x2.zig -Mretro=src/retro.zig \
#       -femit-bin=/tmp/dump3x2
#   /tmp/dump3x2 2>/tmp/zig-tables.txt
#   python3 docs/evidence/T13/diff_zig_tables.py /tmp/zig-tables.txt
#
# (the Zig dumper writes through std.debug.print, hence stderr)

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from t13_probe import build_tables  # noqa: E402

COLUMNS = ["idx", "settled", "score",
           "lo.b0", "hi.b0", "lo.w0", "hi.w0",
           "lo.b1", "hi.b1", "lo.w1", "hi.w1", "vb"]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/zig-tables.txt"
    t = build_tables(verbose=False)
    header = None
    rows = 0
    cells = 0
    bad = 0
    for ln in open(path):
        if ln.startswith("#"):
            header = ln.strip()
            continue
        zig = [int(x) for x in ln.split()]
        i = zig[0]
        py = [i, 1 if t.settled[i] else 0, t.score[i],
              t.lo["b0"][i], t.hi["b0"][i], t.lo["w0"][i], t.hi["w0"][i],
              t.lo["b1"][i], t.hi["b1"][i], t.lo["w1"][i], t.hi["w1"][i],
              t.vb[i]]
        rows += 1
        cells += len(zig)
        if py != zig:
            bad += 1
            if bad <= 5:
                diff = [c for c, a, b in zip(COLUMNS, zig, py) if a != b]
                print(f"MISMATCH idx={i} columns={diff} zig={zig} py={py}")
    print(f"zig header: {header}")
    print(f"python    : legal={t.legal_count} settled={t.settled_count} "
          f"kob={t.ko_sensitive_b} kow={t.ko_sensitive_w} sweeps={t.sweeps}")
    print(f"rows compared: {rows}   cell values compared: {cells}")
    print(f"rows differing: {bad}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
