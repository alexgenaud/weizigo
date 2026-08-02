#!/usr/bin/env python3
"""
Task: T277 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-02

Seeded shift mutant — test the alignment assumption that entry rows
appear in group-index order. The writer's loop writes entries group by group,
and the scanner assumes that group-start offsets computed from cumulative
counts are correct. If a single entry were shifted to a wrong group (e.g.
by an off-by-one in mw.writeAll), the scanner's internal-consistency checks
would need to catch it.

This creates a synthetic mutant of the 3x3 artifact that shifts one passes=1
entry to a neighbouring group, then runs t266_scan.py to verify detection.
"""
import os
import struct
import sys
import tempfile
import shutil

# Copy the artifact to a temp location
src = sys.argv[1]
out_dir = sys.argv[2] if len(sys.argv) > 2 else tempfile.mkdtemp(prefix='t277-mutants-')
os.makedirs(out_dir, exist_ok=True)

with open(src, 'rb') as f:
    buf = bytearray(f.read())

w, h = buf[6], buf[7]
ko_bits = buf[13]
n_groups = struct.unpack('<Q', buf[16:24])[0]
n_entries = struct.unpack('<Q', buf[24:32])[0]
ko_none = w * h
n = ko_none

# Parse group index
gbase = 128
ebase = 128 + 5 * n_groups

gi = buf[gbase:ebase]
colex = []
counts = []
for i in range(n_groups):
    off = i * 5
    cx = gi[off] | (gi[off+1] << 8) | (gi[off+2] << 16) | (gi[off+3] << 24)
    colex.append(cx)
    counts.append(gi[off+4])

starts = [0]
for c in counts[:-1]:
    starts.append(starts[-1] + c)

# Find a passes=1 entry in group g1, and shift it to a neighbouring group g2.
# This breaks the assumption that entries appear in group-index order.
# If the scanner's start offsets are correct, this creates both:
#   - a dropped pass edge in g1 (CB1)
#   - an orphan in g2 (CB1)  
#   - likely a key ordering violation in g2 (CB4)

found = False
for g1 in range(1, n_groups):
    s1 = starts[g1]
    e1 = s1 + counts[g1]
    for i in range(s1, e1):
        kb = buf[ebase + 4 * i]
        passes = (kb >> (2 + ko_bits)) & 1
        if passes == 1:
            # Move this entry to group g1-1 (preceding group)
            g2 = g1 - 1
            s2 = starts[g2]
            e2 = s2 + counts[g2]

            # Extract the 4 bytes
            entry_bytes = bytes(buf[ebase + 4 * i: ebase + 4 * (i + 1)])

            # Shift all entries from s1 to i down by 4 bytes
            src_pos = ebase + 4 * s1
            dst_pos = ebase + 4 * s1
            length = 4 * (i - s1)
            buf[dst_pos + 4: dst_pos + 4 + length] = buf[src_pos: src_pos + length]

            # Insert at end of g2
            insert_pos = ebase + 4 * e2  # after all entries of g2
            shift_len = 4 * (i - e2)  # entries from e2 to i (exclusive)
            # Move entries from e2 to i right by 4 bytes
            buf[insert_pos + 4: insert_pos + 4 + shift_len] = buf[insert_pos: insert_pos + shift_len]
            # Write the entry
            buf[insert_pos: insert_pos + 4] = entry_bytes

            # Update group counts
            counts[g1] -= 1
            counts[g2] += 1

            # Rewrite group index
            for gi_idx in range(n_groups):
                off = gbase + gi_idx * 5
                cx_val = colex[gi_idx]
                buf[off] = cx_val & 0xFF
                buf[off+1] = (cx_val >> 8) & 0xFF
                buf[off+2] = (cx_val >> 16) & 0xFF
                buf[off+3] = (cx_val >> 24) & 0xFF
                buf[off+4] = counts[gi_idx]

            # Update n_entries stays same
            found = True
            break
    if found:
        break

if not found:
    print("FAIL: could not find a passes=1 entry to shift")
    sys.exit(1)

mutant_path = os.path.join(out_dir, 'shift-mutant.wzo2')
with open(mutant_path, 'wb') as f:
    f.write(bytes(buf))

print(f"Mutant written to {mutant_path}")
print(f"Shifted passes=1 entry from group {g1} (colex={colex[g1]}) to group {g2} (colex={colex[g2]})")
print(f"Expected: at least CB1 (dropped/orphaned) and CB4 (order) violations")
