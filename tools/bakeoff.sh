#!/usr/bin/env python3
"""tools/bakeoff.sh — head-to-head model bake-off harness (T328)

Given a task brief path and a roster, runs one dispatch command per model,
each wrapped in tools/runner (RSS/wall/CPU guards, per-lane trailer with
wall + CPU + peak RSS, heartbeat record), each writing its own
untracked/bakeoff/<run>/<model>/out.md.

  tools/bakeoff.sh <brief> <roster> [--run NAME] [--emit] [--wall N] [--claude-tools S]

  <brief>          task brief path (its text is the prompt, identical per lane)
  <roster>         one lane per line: '<family> <canonical-label> [ollama-tag]'
                   families: deepseek | claude | ollama   (# comments, blank ok)
                   deepseek: pi harness, provider deepseek
                   claude:   headless Claude Code session (claude -p --model ...)
                   ollama:   ollama launch pi (third field = serving tag, e.g.
                             glm-5.2:cloud — REQUIRED: the tag is what is served;
                             the canonical label alone does not pin a serving tag)
  --run NAME       run directory name under untracked/bakeoff/ (default:
                   bakeoff-YYYYMMDD-HHMMSS; must be fresh — never overwritten)
  --emit           print the per-lane shell commands and exit; executes nothing.
                   The emitted block is self-contained: a human pastes it into
                   ONE console at the repo root so every lane shares start
                   conditions (queue position, API state).
  --wall N         tools/runner --max-wall guard, seconds (default 1800)
  --claude-tools S --allowedTools value for claude lanes (default
                   "Read,Write,Edit,Bash"); narrow per task, e.g.
                   --claude-tools "Read,Write,Edit,Bash(zig build test)"

Lane layout (untracked/bakeoff/<run>/):
  prompt.txt                     the exact prompt bytes (identical per lane)
  roster.txt                     copy of the roster used
  tokens.template.md             operator token-readout table (fill per lane at
                                 close; a lane without a reading is reported as
                                 such, never estimated)
  <model>/out.md                 lane stdout = the model's answer (the deliverable)
  <model>/trailer.log            tools/runner stderr: argv echo, guards, exit
                                 line (wall), peak RSS/CPU per PID
  lanes.json                     the dispatch record: lane map + command + clocks
                                 + status (label hygiene: lane identity is read
                                 from this file, never from the model)

Claude execution gate: claude lanes EXECUTE only when
WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1 is exported. Without it the lane is refused
and the run exits 1 naming the lane. --emit always shows the claude command.
(T328 bar: this row emits only — never exports the variable.)

No API keys in argv, ever: credentials travel by environment (DEEPSEEK_API_KEY
for deepseek lanes). tools/runner echoes argv to the trailer and the heartbeat
writer records it; an --api-key flag would leak into evidence on every lane.

Lanes run SEQUENTIALLY by default (deterministic, no shared-credential
contention — the fleet cap of two concurrent pi-subagents is a rate-limit
scope). When start-condition comparability matters more than isolation, the
human runs the --emit block from one console; lanes may then be backgrounded
and `wait`ed.

Exit codes: 0 when every executed lane exited 0; 1 when any lane failed or was
refused (the summary says which); 2 on harness errors (bad args/roster, run
name exists, missing dispatch binary, missing credential).

Engineering rules (sprint.md): one state area under untracked/ (untracked/
bakeoff/, nothing in docs/src/data/artifacts); root resolved via
`git rev-parse --show-toplevel` (worktree-aware — accepts both a `.git` dir
and a `.git` FILE with a `gitdir:` pointer, T376); flock on
untracked/bakeoff/.lock around run-dir creation and lanes.json;
standalone binary, stdlib only; shallow interface. Python3 because macOS ships
no flock(1) and the trailer parse + JSON lane map want stdlib json/re/shlex.

Task: T328 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-05
"""

import fcntl
import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from datetime import datetime, timezone

# ── constants ────────────────────────────────────────────────────────

# Canonical model labels — the single source of truth is the
# canonical_models array in src/managent/main.zig (T317); this list must
# stay in sync. The ledger rejects non-canonical labels.
CANONICAL = {
    "claude-opus-5", "claude-sonnet-5", "claude-fable-5",
    "claude-haiku-4-5-20251001",
    "deepseek-v4-pro", "deepseek-v4-flash",
    "glm-5.2", "minimax-m3", "kimi-k2.7",
}

FAMILIES = {"deepseek", "claude", "ollama"}
RUN_NAME_RE = re.compile(r"^[A-Za-z0-9._-]+$")
CLAUDE_GATE = "WEIZIGO_BAKEOFF_ALLOW_CLAUDE"
DEFAULT_CLAUDE_TOOLS = "Read,Write,Edit,Bash"
DEFAULT_WALL = 1800

HEADER = (
    "You are one lane in a head-to-head bake-off: several models race the "
    "same bounded task, blind-graded. Follow the task brief exactly.\n\n"
    "Produce your entire deliverable as your final message — the harness "
    "captures your output verbatim to a file. Do not write files or run "
    "shell commands unless the task brief explicitly requires it.\n\n"
    "===== TASK BRIEF =====\n"
)
FOOTER = "\n===== END TASK BRIEF =====\n"


def die(msg, code=2):
    sys.stderr.write(f"bakeoff: {msg}\n")
    sys.exit(code)


def diag(msg):
    sys.stderr.write(f"[bakeoff] {msg}\n")


def find_root():
    """Repository root, worktree-aware (T376).

    A git WORKTREE's `.git` is a FILE carrying a `gitdir:` pointer, not a
    directory, so the old isdir-only walk-up could not see a worktree root
    and would silently keep walking into a parent checkout — the exact
    failure where a lane would read the WRONG repo's keys. Prefer git's own
    answer (`git rev-parse --show-toplevel` accepts both forms); absence of
    git is the error case, never a guess.
    """
    here = os.path.dirname(os.path.abspath(__file__))
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            cwd=here,
        )
    except FileNotFoundError:
        die(f"no git on PATH — cannot resolve the repository root (from {here})")
    if proc.returncode != 0:
        die(f"not inside a git repository (git rev-parse failed from {here}): "
            f"{proc.stderr.strip() or 'no error output'}")
    root = proc.stdout.strip()
    if not root:
        die("git rev-parse --show-toplevel returned an empty root")
    # Sanity: this harness must live inside the resolved root. A detector
    # that silently returns a DIFFERENT checkout's root (e.g. a nested repo
    # between here and the intended root) would run lanes with the wrong
    # repo's untracked/ in reach — refuse rather than guess.
    script = os.path.realpath(__file__)
    expected = os.path.realpath(os.path.join(root, "tools", "bakeoff.sh"))
    if script != expected:
        die(f"resolved root {root!r} does not contain this harness "
            f"({script} != {expected}) — refusing to guess")
    return root


# ── roster ───────────────────────────────────────────────────────────

def parse_roster(path):
    lanes = []
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) < 2 or len(parts) > 3:
                die(f"roster {path}:{lineno}: expected '<family> <canonical-label> [ollama-tag]', got {line!r}")
            family, label = parts[0], parts[1]
            if family not in FAMILIES:
                die(f"roster {path}:{lineno}: unknown family {family!r} (use deepseek|claude|ollama)")
            if label not in CANONICAL:
                die(f"roster {path}:{lineno}: {label!r} is not a canonical model label "
                    f"(canonical set: {', '.join(sorted(CANONICAL))})")
            if family == "ollama":
                if len(parts) < 3:
                    die(f"roster {path}:{lineno}: ollama lanes must name the serving tag "
                        f"(third field, e.g. glm-5.2:cloud) — the canonical label alone "
                        f"does not pin what is served")
                tag = parts[2]
            else:
                tag = parts[2] if len(parts) == 3 else label
            lanes.append({"family": family, "label": label, "serving_tag": tag})
    if not lanes:
        die(f"roster {path} is empty")
    labels = [l["label"] for l in lanes]
    dupes = {x for x in labels if labels.count(x) > 1}
    if dupes:
        die(f"roster {path}: duplicate lane label(s) {', '.join(sorted(dupes))} — "
            f"out directories would collide")
    return lanes


# ── prompt / commands ────────────────────────────────────────────────

def build_prompt(brief_path):
    with open(brief_path) as f:
        body = f.read()
    return HEADER + body + FOOTER


def lane_argv(lane, prompt, wall, claude_tools):
    """tools/runner wrapper + dispatch argv for one lane. The prompt is the
    same string object for every lane — identical brief text per lane."""
    runner = ["tools/runner", "--max-wall", str(wall), "--"]
    fam = lane["family"]
    if fam == "deepseek":
        return runner + ["pi", "--provider", "deepseek", "--model", lane["label"],
                         "--no-session", "-p", prompt]
    if fam == "claude":
        return runner + ["claude", "-p", prompt, "--model", lane["label"],
                         "--allowedTools", claude_tools, "--output-format", "text"]
    if fam == "ollama":
        return runner + ["ollama", "launch", "pi", "--model", lane["serving_tag"],
                         "-y", "--", "-p", prompt]
    raise AssertionError(fam)


def lane_emit_cmd(lane, prompt_ref, wall, claude_tools):
    """Shell string for --emit. prompt_ref is a shell expression that yields
    the prompt text (the $(cat prompt.txt) expansion), deliberately left
    unquoted so the human's console expands it."""
    base = f"tools/runner --max-wall {wall} -- "
    fam = lane["family"]
    if fam == "deepseek":
        return (base + f"pi --provider deepseek --model {lane['label']} "
                f"--no-session -p {prompt_ref}")
    if fam == "claude":
        return (base + f"claude -p {prompt_ref} --model {lane['label']} "
                f"--allowedTools {claude_tools} --output-format text")
    if fam == "ollama":
        return (base + f"ollama launch pi --model {lane['serving_tag']} -y -- "
                f"-p {prompt_ref}")
    raise AssertionError(fam)


# ── trailer parse (wall + CPU + RSS from tools/runner stderr) ─────────

EXIT_RE = re.compile(r"\[runner\] exit (\d+)(?: \(([^)]*)\))? in ([\d.]+) s")
CPU_RE = re.compile(r"^\[runner\]\s+pid\s+\d+\s+.*\(([\d.]+)s\)\s*$", re.M)
RSS_RE = re.compile(r"^\[runner\]\s+pid\s+\d+\s+(\d+)\s+MB\s*$", re.M)
KILL_RE = re.compile(r"\[runner\] KILL: ([^\n]+)")


def parse_trailer(path):
    try:
        with open(path, "rb") as f:
            text = f.read().decode("utf-8", errors="replace")
    except FileNotFoundError:
        return {"exit": None, "wall_s": None, "cpu_s": None, "rss_mb": None,
                "kill": None, "note": "trailer missing"}
    m = list(EXIT_RE.finditer(text))
    if m:
        last = m[-1]
        exit_code = int(last.group(1))
        wall = float(last.group(3)) if last.group(3) else None
        note = last.group(2)
    else:
        exit_code, wall, note = None, None, "no runner exit line in trailer"
    cpu = sum(float(x) for x in CPU_RE.findall(text))
    rss = max((int(x) for x in RSS_RE.findall(text)), default=0)
    km = KILL_RE.search(text)
    return {"exit": exit_code, "wall_s": wall, "cpu_s": cpu, "rss_mb": rss,
            "kill": km.group(1) if km else None, "note": note}


# ── emit ─────────────────────────────────────────────────────────────

def emit(brief, roster, run, wall, claude_tools, lanes):
    prompt = build_prompt(brief)
    out = []
    out.append(f"# bakeoff --emit — run {run!r}, {len(lanes)} lane(s)")
    out.append(f"# brief: {brief}")
    out.append(f"# roster: {roster}")
    out.append("# Paste every line below into ONE console at the repo root, in order.")
    out.append(f"# Claude lanes execute only when {CLAUDE_GATE}=1 is exported.")
    out.append("")
    out.append(f"mkdir -p untracked/bakeoff/{run}")
    out.append(f"printf '%s' {shlex.quote(prompt)} > untracked/bakeoff/{run}/prompt.txt")
    out.append(f"cp {shlex.quote(roster)} untracked/bakeoff/{run}/roster.txt")
    prompt_ref = f'"$(cat untracked/bakeoff/{run}/prompt.txt)"'
    for lane in lanes:
        label = lane["label"]
        out.append(f"mkdir -p untracked/bakeoff/{run}/{label}")
        cmd = lane_emit_cmd(lane, prompt_ref, wall, claude_tools)
        out.append(f"{cmd} > untracked/bakeoff/{run}/{label}/out.md "
                   f"2> untracked/bakeoff/{run}/{label}/trailer.log")
    sys.stdout.write("\n".join(out) + "\n")
    return 0


# ── execute ──────────────────────────────────────────────────────────

def preflight(lanes, wall):
    """Checks that fail the whole run before anything dispatches. The claude
    gate is deliberately NOT here: a claude lane without WEIZIGO_BAKEOFF_
    ALLOW_CLAUDE is refused per-lane (status=refused, run exits 1), so the
    non-Claude lanes of the same roster still run — that is how the T328
    dry run demonstrates the emit-only bar while proving the plumbing."""
    for lane in lanes:
        fam = lane["family"]
        if fam == "claude":
            if shutil.which("claude") is None:
                die("claude lane requested but no `claude` binary on PATH")
        elif fam == "deepseek":
            if shutil.which("pi") is None:
                die("deepseek lane requested but no `pi` binary on PATH")
            if not os.environ.get("DEEPSEEK_API_KEY"):
                die("deepseek lane requested but DEEPSEEK_API_KEY is not set "
                    "(credentials travel by environment, never argv)")
        elif fam == "ollama":
            if shutil.which("ollama") is None:
                die("ollama lane requested but no `ollama` binary on PATH")


def execute(brief, roster, run, wall, claude_tools, lanes):
    root = find_root()
    # T376 isolation record: a git WORKTREE root has `.git` as a FILE (a
    # `gitdir:` pointer) and holds only committed content, so gitignored
    # state (e.g. untracked/race-keys/, untracked/race-grading/) does not
    # exist in the lane's view at all. That is a RELATIVE-PATH boundary only:
    # a tool-using lane can still read the main checkout's gitignored files
    # via absolute paths (no sandbox, T376 finding 2). The record below makes
    # the truth auditable in lanes.json — it does not make the boundary
    # stronger.
    is_worktree = os.path.isfile(os.path.join(root, ".git"))
    bakeoff_dir = os.path.join(root, "untracked", "bakeoff")
    os.makedirs(bakeoff_dir, exist_ok=True)
    run_dir = os.path.join(bakeoff_dir, run)
    prompt = build_prompt(brief)
    prompt_sha = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
    date = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    with open(os.path.join(bakeoff_dir, ".lock"), "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        if os.path.exists(run_dir):
            die(f"run dir already exists: untracked/bakeoff/{run} — never "
                f"overwritten; pick a fresh --run name")
        os.makedirs(run_dir)
        with open(os.path.join(run_dir, "prompt.txt"), "w") as f:
            f.write(prompt)
        shutil.copy2(roster, os.path.join(run_dir, "roster.txt"))
        _write_tokens_template(run_dir, run, lanes)
        fcntl.flock(lf, fcntl.LOCK_UN)

    diag(f"run {run}: {len(lanes)} lane(s), brief {brief}, wall guard {wall}s")
    results = []
    any_bad = False
    for lane in lanes:
        label = lane["label"]
        fam = lane["family"]
        if fam == "claude" and not os.environ.get(CLAUDE_GATE):
            entry = {
                "family": fam,
                "label": label,
                "serving_tag": lane["serving_tag"],
                "command": shlex.join(lane_argv(lane, prompt, wall, claude_tools)),
                "out": None,
                "trailer": None,
                "status": "refused",
                "exit": None,
                "wall_s": None,
                "cpu_s": None,
                "rss_mb": None,
                "out_bytes": 0,
                "kill": None,
                "note": f"{CLAUDE_GATE} unset — emit only (T328 bar)",
                "elapsed_s": None,
            }
            results.append(entry)
            any_bad = True
            diag(f"lane {label}: refused ({CLAUDE_GATE} unset — emit only)")
            continue
        out_dir = os.path.join(run_dir, label)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "out.md")
        trailer_path = os.path.join(out_dir, "trailer.log")
        argv = lane_argv(lane, prompt, wall, claude_tools)
        env = dict(os.environ)
        env["WEIZIGO_AGENT_DEPTH"] = "3"          # lanes are leaf workers (T431: cap value, not 2)
        env["MANAGENT_TASK_ID"] = f"bakeoff/{run}/{label}"  # heartbeat identity
        diag(f"lane {label}: dispatch {shlex.join(argv)}")
        t0 = time.monotonic()
        with open(out_path, "wb") as of, open(trailer_path, "wb") as tf:
            proc = subprocess.run(argv, cwd=root, env=env, stdout=of, stderr=tf)
        meta = parse_trailer(trailer_path)
        if proc.returncode == 0:
            status = "ok"
        elif proc.returncode == 124 and meta.get("kill"):
            status = "guard-killed"
        else:
            status = "failed"
        entry = {
            "family": fam,
            "label": label,
            "serving_tag": lane["serving_tag"],
            "command": shlex.join(argv),
            "out": os.path.relpath(out_path, root),
            "trailer": os.path.relpath(trailer_path, root),
            "status": status,
            "exit": proc.returncode,
            "wall_s": meta.get("wall_s"),
            "cpu_s": meta.get("cpu_s"),
            "rss_mb": meta.get("rss_mb"),
            "out_bytes": os.path.getsize(out_path) if os.path.exists(out_path) else 0,
            "kill": meta.get("kill"),
            "note": meta.get("note"),
            "elapsed_s": round(time.monotonic() - t0, 2),
        }
        results.append(entry)
        if status != "ok":
            any_bad = True
        diag(f"lane {label}: {status} (exit {proc.returncode}, "
             f"wall {meta.get('wall_s')}s cpu {meta.get('cpu_s')}s "
             f"rss {meta.get('rss_mb')}MB, {entry['out_bytes']}B out)")

    lanes_doc = {
        "run": run,
        "date": date,
        "brief": brief,
        "roster": roster,
        "prompt_sha256": prompt_sha,
        "claude_gate": CLAUDE_GATE,
        "claude_tools": claude_tools,
        "isolation": {
            "root": root,
            "root_is_worktree": is_worktree,
            "lane_cwd": root,  # lanes dispatch with cwd=root
            "strength": "relative-path boundary only — a tool-using lane can "
                         "reach the host filesystem (incl. the main checkout's "
                         "gitignored untracked/) via absolute paths; no sandbox (T376)",
        },
        "lanes": results,
    }
    with open(os.path.join(bakeoff_dir, ".lock"), "w") as lf:
        fcntl.flock(lf, fcntl.LOCK_EX)
        with open(os.path.join(run_dir, "lanes.json"), "w") as f:
            json.dump(lanes_doc, f, indent=2)
            f.write("\n")
        fcntl.flock(lf, fcntl.LOCK_UN)

    # summary — stdout is data
    print(f"run={run}")
    print(f"root={root} worktree={is_worktree}")
    print(f"brief={brief}")
    print(f"roster={roster}")
    print(f"lanes={len(results)}")
    for e in results:
        extra = ""
        if e["status"] != "ok" and (e["kill"] or e["note"]):
            extra = f" note={e['kill'] or e['note']!r}"
        print(f"RESULT {e['label']} family={e['family']} serving_tag={e['serving_tag']} "
              f"status={e['status']} exit={e['exit']} wall_s={e['wall_s']} "
              f"cpu_s={e['cpu_s']} rss_mb={e['rss_mb']} out_bytes={e['out_bytes']}"
              f"{extra}")
    print(f"lane_map={os.path.join('untracked', 'bakeoff', run, 'lanes.json')}")
    return 1 if any_bad else 0


def _write_tokens_template(run_dir, run, lanes):
    rows = []
    for lane in lanes:
        rows.append(
            f"| {lane['label']} |  |  |  |  | {lane['family']} |")
    body = (
        f"# Token readout — {run} (operator fills at each lane's close)\n\n"
        "Harness rule (T328, operator ruling 2026-08-05): agents cannot read\n"
        "their own meter; the harness console can. At each lane's close record\n"
        "the console readout VERBATIM — percent, window denominator, harness —\n"
        "then convert to absolute tokens (3.1% of 1.0 M ≈ 31,000). A lane\n"
        "without a token reading is reported as such, NEVER estimated. Also\n"
        "record the exact serving tag the console shows (a label alone does not\n"
        "pin a serving tag across dates — e.g. the 2026-08-05 preview bump).\n\n"
        "Prices NEVER go in this file or in findings: tokens and clocks are the\n"
        "measured quantities; prices live in the dated table in\n"
        "docs/infra/model-perf.md and quality/price is computed at query time.\n\n"
        "| lane (canonical label) | serving tag as served | percent | window | "
        "abs tokens (percent × window) | harness |\n"
        "|---|---|---|---|---|---|\n"
    ) + "\n".join(rows) + "\n"
    with open(os.path.join(run_dir, "tokens.template.md"), "w") as f:
        f.write(body)


# ── main ─────────────────────────────────────────────────────────────

USAGE = (
    "usage: tools/bakeoff.sh <brief> <roster> [--run NAME] [--emit] "
    "[--wall N] [--claude-tools S]\n"
    "  brief   task brief path (its text is the prompt, identical per lane)\n"
    "  roster  one lane per line: '<family> <canonical-label> [ollama-tag]'\n"
    "          families: deepseek | claude | ollama\n"
    "  --run NAME         run dir under untracked/bakeoff/ (must be fresh)\n"
    "  --emit             print the per-lane commands, execute nothing\n"
    "  --wall N           tools/runner --max-wall seconds (default 1800)\n"
    "  --claude-tools S   --allowedTools value for claude lanes\n"
    "                     (default \"Read,Write,Edit,Bash\")\n"
    "claude lanes execute only with " + CLAUDE_GATE + "=1 exported; --emit always shows them.\n"
)


def main(argv):
    args, flags = [], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--run", "--wall", "--claude-tools") and i + 1 < len(argv):
            flags.append((a, argv[i + 1]))
            i += 2
            continue
        if a == "--emit":
            flags.append((a, None))
            i += 1
            continue
        if a in ("-h", "--help"):
            sys.stdout.write(USAGE)
            return 0
        if a.startswith("--"):
            die(f"unknown flag {a}\n" + USAGE)
        args.append(a)
        i += 1

    if len(args) != 2:
        die(USAGE)
    brief, roster = args[0], args[1]
    if not os.path.isfile(brief):
        die(f"brief not found: {brief}")
    if not os.path.isfile(roster):
        die(f"roster not found: {roster}")

    run = next((v for k, v in flags if k == "--run"), None) or \
        datetime.now(timezone.utc).strftime("bakeoff-%Y%m%d-%H%M%S")
    if not RUN_NAME_RE.match(run):
        die(f"run name {run!r} must match {RUN_NAME_RE.pattern}")
    wall = next((v for k, v in flags if k == "--wall"), None)
    if wall is None:
        wall = DEFAULT_WALL
    else:
        try:
            wall = int(wall)
        except ValueError:
            die(f"--wall must be an integer, got {wall!r}")
    claude_tools = next((v for k, v in flags if k == "--claude-tools"),
                        DEFAULT_CLAUDE_TOOLS)
    emit_only = any(k == "--emit" for k, _ in flags)

    lanes = parse_roster(roster)
    if emit_only:
        return emit(brief, roster, run, wall, claude_tools, lanes)
    preflight(lanes, wall)
    return execute(brief, roster, run, wall, claude_tools, lanes)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
