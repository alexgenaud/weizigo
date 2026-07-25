#!/usr/bin/env python3
# Play against a weizigo oracle artifact in the terminal.
#
#   python3 tools/play_oracle.py [artifact.wzo] [b|w]
#
# Defaults: data/oracle-4x4.wzo, you play Black. Enter moves as "c3", or
# "pass"; "quit" resigns the session. Thin wrapper over the GTP (Go Text
# Protocol) engine src/gtp.zig — builds it on demand via `zig build-exe`.
# Standard library only.

import subprocess, sys, os, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
GTP_BIN = ROOT / "zig-out" / "gtp"

artifact = sys.argv[1] if len(sys.argv) > 1 else str(ROOT / "data" / "oracle-4x4.wzo")
human = (sys.argv[2] if len(sys.argv) > 2 else "b").lower()[0]
engine_color = "w" if human == "b" else "b"

if not GTP_BIN.exists():
    print("building GTP engine ...")
    subprocess.run(["zig", "build-exe", "-O", "ReleaseFast", "src/gtp.zig",
                    f"-femit-bin={GTP_BIN}"], cwd=ROOT, check=True)

# stderr inherits the terminal: the engine narrates each of its moves there
# (stored value, chosen child value, DTT, KO_SENSITIVE / HISTORY-DIVERGED) —
# HISTORY-DIVERGED marks the GHI gap where superko bans beat the fresh-start
# optimum (see research/retrograde-4x4.md, "the B+16 game")
p = subprocess.Popen([str(GTP_BIN), artifact], stdin=subprocess.PIPE,
                     stdout=subprocess.PIPE, text=True)

def gtp(cmd):
    p.stdin.write(cmd + "\n")
    p.stdin.flush()
    out = []
    while True:
        line = p.stdout.readline()
        if line == "":
            raise SystemExit("engine terminated")
        if line.strip() == "" and out:
            break
        out.append(line.rstrip("\n"))
    reply = "\n".join(out)
    ok = reply.startswith("=")
    return ok, reply.lstrip("=? ").strip()

_, version = gtp("version")
size = int(version.split("x")[0])
gtp(f"boardsize {size}")
gtp("clear_board")

def board():
    _, b = gtp("showboard")
    rows = [r for r in b.splitlines() if r.strip()]
    cols = "  " + " ".join("ABCDEFGHJ"[:size])
    print(cols)
    for i, r in enumerate(rows):
        print(f"{size - i} {r}")
    print()

print(f"weizigo oracle {version} — you are {'Black (X)' if human == 'b' else 'White (O)'}; "
      f"moves like 'c3', or 'pass'\n")
passes, to_move = 0, "b"
board()
while passes < 2:
    if to_move == human:
        try:
            mv = input(f"your move ({human}): ").strip().lower()
        except EOFError:
            break
        if mv in ("quit", "exit", "resign"):
            break
        ok, err = gtp(f"play {human} {mv}")
        if not ok:
            print(f"  rejected: {err}")
            continue
    else:
        _, mv = gtp(f"genmove {engine_color}")
        print(f"oracle plays: {mv}")
    passes = passes + 1 if mv == "pass" else 0
    to_move = "w" if to_move == "b" else "b"
    board()

_, score = gtp("final_score")
print(f"final score (komi 0): {score}")
gtp("quit")
