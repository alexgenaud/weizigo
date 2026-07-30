#!/usr/bin/env python3
"""
Match runner: weizigo-oracle vs KataGo on small Go boards.

Usage:
  python3 untracked/katago-match.py [--board 3] [--games 10] [--katago-config CONFIG]
                                    [--weizigo-oracle BIN] [--weizigo-artifact WZO]

Plays N games alternating colors. Outputs SGF files to untracked/sgf/
and logs stderr from both engines.
"""
import argparse
import os
import subprocess
import sys
import time
import re
import signal

def log(msg):
    print(f"[match] {msg}", file=sys.stderr)
    sys.stderr.flush()

class GTPEngine:
    """Manages a subprocess GTP engine."""
    def __init__(self, name, cmd, stderr_log_path):
        self.name = name
        self.cmd = cmd
        self.stderr_log_path = stderr_log_path
        self.stderr_f = open(stderr_log_path, "w")
        self.proc = None
        self.last_cmd = None

    def start(self):
        log(f"Starting {self.name}: {' '.join(self.cmd)}")
        self.proc = subprocess.Popen(
            self.cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=self.stderr_f,
            text=True,
            bufsize=1,
        )
        # Read initial banner (if any) — GTP engines should respond with "=" to commands
        # but some may print startup messages. We'll just flush by sending a known_command.
        # Actually, we can just proceed with init_commands.

    def send(self, cmd):
        """Send a GTP command and return the response (without status line)."""
        self.last_cmd = cmd
        self.stderr_f.write(f">>> {cmd}\n")
        self.stderr_f.flush()
        self.proc.stdin.write(cmd + "\n")
        self.proc.stdin.flush()
        response_lines = []
        while True:
            line = self.proc.stdout.readline()
            if line == "":
                raise EOFError(f"{self.name}: process terminated unexpectedly after command '{cmd}'")
            line = line.rstrip("\n").rstrip("\r")
            if line.startswith("="):
                # GTP status line: "= response" or "="
                response = line[1:].strip()
                response_lines.append(response)
                break
            elif line.startswith("?"):
                error = line[1:].strip()
                raise RuntimeError(f"{self.name}: GTP error for '{cmd}': {error}")
            elif line == "":
                # Blank line before response is normal GTP
                pass
            else:
                response_lines.append(line)
        return "\n".join(r for r in response_lines if r)

    def boardsize(self, size):
        self.send(f"boardsize {size}")

    def clear_board(self):
        self.send("clear_board")

    def komi(self, k):
        self.send(f"komi {k}")

    def play(self, color, move):
        self.send(f"play {color} {move}")

    def genmove(self, color):
        return self.send(f"genmove {color}")

    def final_score(self):
        return self.send("final_score")

    def quit(self):
        try:
            self.send("quit")
        except Exception:
            pass

    def close(self):
        if self.proc:
            try:
                self.proc.terminate()
                self.proc.wait(timeout=5)
            except Exception:
                self.proc.kill()
                self.proc.wait()
        self.stderr_f.close()


def sgf_escape(s):
    """Escape text for SGF."""
    return s.replace("\\", "\\\\").replace("]", "\\]")


def write_sgf(path, board_size, komi, moves, result, player_black, player_white, extra_info=None):
    """Write an SGF file."""
    rows = []
    rows.append(f"(;GM[1]FF[4]CA[UTF-8]SZ[{board_size}]KM[{komi}]")
    rows.append(f"PB[{sgf_escape(player_black)}]")
    rows.append(f"PW[{sgf_escape(player_white)}]")
    rows.append(f"RE[{sgf_escape(result)}]")
    if extra_info:
        for key, val in extra_info.items():
            rows.append(f"{key}[{sgf_escape(str(val))}]")
    for i, (color, move) in enumerate(moves):
        # SGF: B[cc] or W[cc]
        if move.lower() == "pass":
            rows.append(f"{color}[]")
        else:
            rows.append(f"{color}[{move.lower()}]")
        # Add comment with move number
    rows.append(")")
    content = "\n".join(rows)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def play_game(game_idx, board_size, weizigo_cmd, katago_cmd, output_dir):
    """
    Play a single game. weizigo is always Black on even games, White on odd games.
    Returns (result_str, moves_list, weizigo_score, katago_score).
    """
    if game_idx % 2 == 0:
        black_name = "weizigo"
        white_name = "katago"
        black_color = "b"
        white_color = "w"
        black_engine_cmd = weizigo_cmd
        white_engine_cmd = katago_cmd
    else:
        black_name = "katago"
        white_name = "weizigo"
        black_color = "b"
        white_color = "w"
        black_engine_cmd = katago_cmd
        white_engine_cmd = weizigo_cmd

    game_id = f"g{game_idx:02d}-{black_name}-vs-{white_name}"
    log(f"=== Game {game_id} (board {board_size}x{board_size}) ===")

    # Setup stderr logs
    os.makedirs(output_dir, exist_ok=True)
    black_log = os.path.join(output_dir, f"{game_id}-black-stderr.log")
    white_log = os.path.join(output_dir, f"{game_id}-white-stderr.log")

    black = GTPEngine(f"Black({black_name})", black_engine_cmd, black_log)
    white = GTPEngine(f"White({white_name})", white_engine_cmd, white_log)

    moves = []
    try:
        black.start()
        white.start()

        # Initialize both engines
        black.boardsize(board_size)
        white.boardsize(board_size)
        black.clear_board()
        white.clear_board()
        black.komi(0)
        white.komi(0)

        passes = 0
        move_num = 0
        current_player = "b"  # Black starts

        while True:
            if current_player == "b":
                mover = black
                color_name = black_name
            else:
                mover = white
                color_name = white_name

            log(f"  Move {move_num+1}: {color_name} ({current_player}) to move...")
            move = mover.genmove(current_player)
            log(f"  Move {move_num+1}: {color_name} ({current_player}) -> {move}")

            moves.append((current_player.upper(), move))

            # Check for pass
            if move.lower() == "pass":
                passes += 1
            else:
                passes = 0

            # Relay move to the OPPOSING engine only (mover already has it)
            if move.lower() != "pass":
                if current_player == "b":
                    opponent = white
                else:
                    opponent = black
                try:
                    opponent.play(current_player, move)
                except Exception as e:
                    log(f"  ERROR: Opponent engine rejected move: {e}")

            # Check game end: two consecutive passes
            if passes >= 2:
                log(f"  Game ends after {move_num+1} moves (two consecutive passes)")
                break

            # Check move limit (safety)
            move_num += 1
            if move_num >= board_size * board_size * 4:
                log(f"  Game ends after {move_num} moves (move limit)")
                break

            # Switch player
            current_player = "w" if current_player == "b" else "b"

        # Get final score
        black_score = black.final_score()
        white_score = white.final_score()
        log(f"  Black final_score: {black_score}")
        log(f"  White final_score: {white_score}")

        # Determine result string for SGF
        # Final score is usually something like "B+2" or "W+0.5"
        # For area scoring with komi 0, it should be "B+X"
        result = black_score.strip() if black_score else "?"
        log(f"  Result: {result}")

    except Exception as e:
        log(f"  GAME ABORTED: {e}")
        result = f"ABORTED: {e}"
    finally:
        black.quit()
        white.quit()
        black.close()
        white.close()

    return result, moves


def main():
    parser = argparse.ArgumentParser(description="weizigo vs KataGo match runner")
    parser.add_argument("--board", type=int, default=3, help="Board size (default: 3)")
    parser.add_argument("--games", type=int, default=10, help="Number of games (default: 10)")
    parser.add_argument("--katago-config", default="untracked/katago-match.cfg",
                        help="KataGo config file")
    parser.add_argument("--katago-model", default="/opt/homebrew/Cellar/katago/1.16.5/share/katago/g170-b40c256x2-s5095420928-d1229425124.bin.gz",
                        help="KataGo model file")
    parser.add_argument("--weizigo-oracle", default="bin/weizigo-oracle",
                        help="weizigo-oracle binary")
    parser.add_argument("--weizigo-artifact", default="artifacts/oracle-3x3.wzo",
                        help="weizigo artifact file")
    parser.add_argument("--output-dir", default="untracked/sgf",
                        help="Output directory for SGF and logs")
    args = parser.parse_args()

    board_size = args.board
    num_games = args.games

    # Resolve artifact for the requested goban size
    artifact = args.weizigo_artifact
    if not os.path.exists(artifact):
        # Try to find one
        alt = f"artifacts/oracle-{board_size}x{board_size}.wzo"
        if os.path.exists(alt):
            artifact = alt
        else:
            log(f"ERROR: No artifact found for {board_size}x{board_size}")
            log(f"  Tried: {args.weizigo_artifact}, {alt}")
            log(f"  Available artifacts:")
            for f in os.listdir("artifacts"):
                if f.endswith(".wzo"):
                    log(f"    artifacts/{f}")
            sys.exit(1)

    weizigo_cmd = [args.weizigo_oracle, artifact]
    katago_cmd = [
        "katago", "gtp",
        "-config", args.katago_config,
        "-model", args.katago_model,
    ]

    log(f"Board size: {board_size}x{board_size}")
    log(f"Games: {num_games}")
    log(f"weizigo: {' '.join(weizigo_cmd)}")
    log(f"KataGo: {' '.join(katago_cmd)}")

    results = []
    for i in range(num_games):
        result, moves = play_game(i, board_size, weizigo_cmd, katago_cmd, args.output_dir)

        black_name = "weizigo" if i % 2 == 0 else "katago"
        white_name = "katago" if i % 2 == 0 else "weizigo"
        game_id = f"g{i:02d}-{black_name}-vs-{white_name}"

        sgf_path = os.path.join(args.output_dir, f"{game_id}.sgf")
        write_sgf(sgf_path, board_size, 0, moves, result, black_name, white_name,
                  extra_info={"GN": game_id, "EV": "weizigo-vs-katago"})
        log(f"  SGF: {sgf_path}")

        results.append((game_id, result))
        log(f"  Result: {result}")

    # Print summary
    print("\n" + "=" * 60)
    print(f"MATCH SUMMARY: weizigo vs KataGo on {board_size}x{board_size}")
    print("=" * 60)
    wz_wins = 0
    kg_wins = 0
    draws = 0
    aborted = 0
    for game_id, result in results:
        print(f"  {game_id}: {result}")
        if "ABORTED" in result:
            aborted += 1
        elif result.startswith("B+"):
            # Black wins
            black_name = game_id.split("-")[1]
            if black_name == "weizigo":
                wz_wins += 1
            else:
                kg_wins += 1
        elif result.startswith("W+"):
            white_name = game_id.split("-")[3]
            if white_name == "weizigo":
                wz_wins += 1
            else:
                kg_wins += 1
        elif result == "0" or result == "Draw":
            draws += 1
        else:
            # Try to parse
            try:
                score_val = float(result.replace("B+", "").replace("W+", ""))
                if result.startswith("B+"):
                    black_name = game_id.split("-")[1]
                    if black_name == "weizigo":
                        wz_wins += 1
                    else:
                        kg_wins += 1
                elif result.startswith("W+"):
                    white_name = game_id.split("-")[3]
                    if white_name == "weizigo":
                        wz_wins += 1
                    else:
                        kg_wins += 1
                elif score_val == 0:
                    draws += 1
            except:
                aborted += 1

    print(f"\nweizigo wins: {wz_wins}")
    print(f"KataGo wins: {kg_wins}")
    print(f"Draws: {draws}")
    if aborted:
        print(f"Aborted: {aborted}")
    print(f"\nSGF and logs: {args.output_dir}/")


if __name__ == "__main__":
    main()
