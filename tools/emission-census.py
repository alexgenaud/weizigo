#!/usr/bin/env python3
"""tools/emission-census.py — mechanical census of emission points (T898).

An "emission point" (defined in full in
docs/epics/E1-markovian/L1-dashboard/S11-honest-instruments/stream2-whatis/census-method.md)
is a call site, in tracked source, that places bytes on the channel this
repository's own code already declares as the fact channel — stdout — or
that ends the process with an observable exit status. Diagnostics-only
channels (stderr) are excluded BY RULE, not by omission: the exclusion is
itself counted (--verbose lists it) so the denominator's boundary is
inspectable, not asserted.

Scope (must match census-method.md's "what is in and out" section):
  bin/argus, bin/dispatch, bin/subagent          — tracked bin/* scripts
  tools/**  (every git-tracked file under tools/, any language)
  src/managent/*.zig                             — the dispatcher
  src/claimlint.zig, src/absorb.zig               — "the checkers"

This is a census, not a defect scan: it counts and locates emission points.
It does not judge whether any one of them is honest or dishonest — that is
the classification wave's job (T898 brief, Constraints).

Usage:
  tools/emission-census.py                 human-readable summary + counts
  tools/emission-census.py --json          full inventory as JSON to stdout
  tools/emission-census.py --self-test     null control + seeded-defect control
"""
from __future__ import annotations

import ast
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(HERE)

# ── scope ─────────────────────────────────────────────────────────────────

BIN_SCOPE = ("bin/argus", "bin/dispatch", "bin/subagent")


def scope_files(repo_root: str) -> list[str]:
    """Every git-tracked path inside this census's declared scope, relative
    to repo_root. Mechanical (git ls-files), not a reading pass."""
    out = subprocess.run(
        ["git", "-C", repo_root, "ls-files",
         "tools", "src/managent", "src/claimlint.zig", "src/absorb.zig"],
        capture_output=True, text=True, check=True,
    ).stdout.splitlines()
    files = [p for p in out if p]
    files.extend(p for p in BIN_SCOPE if os.path.exists(os.path.join(repo_root, p)))
    return sorted(set(files))


def detect_lang(path: str) -> str | None:
    if path.endswith(".zig"):
        return "zig"
    if path.endswith(".py"):
        return "python"
    if path.endswith(".sh"):
        return "shell"
    if path.endswith((".json", ".md", ".fixture", ".roster", ".plist")):
        return None
    # extensionless — sniff the shebang (tools/runner, tools/facts,
    # tools/gen-indices, tools/git-commit-mine, tools/hooks/pre-commit, bin/*)
    try:
        with open(path, "r", errors="replace") as f:
            first = f.readline()
    except OSError:
        return None
    if first.startswith("#!"):
        if "python" in first:
            return "python"
        if "bash" in first or "/sh" in first or first.strip().endswith("sh"):
            return "shell"
    return None


# ── python: a real parse, not a regex guess ─────────────────────────────

class _PyEmissionVisitor(ast.NodeVisitor):
    def __init__(self):
        self.stdout: list[int] = []
        self.exit: list[int] = []
        self.diag: list[int] = []

    @staticmethod
    def _dotted(func) -> str | None:
        if isinstance(func, ast.Name):
            return func.id
        if isinstance(func, ast.Attribute):
            parts = []
            cur = func
            while isinstance(cur, ast.Attribute):
                parts.append(cur.attr)
                cur = cur.value
            if isinstance(cur, ast.Name):
                parts.append(cur.id)
                return ".".join(reversed(parts))
        return None

    def visit_Call(self, node: ast.Call):
        name = self._dotted(node.func)
        if name == "print":
            to_stderr = any(
                kw.arg == "file" and "stderr" in ast.dump(kw.value)
                for kw in node.keywords
            )
            (self.diag if to_stderr else self.stdout).append(node.lineno)
        elif name in ("sys.exit", "os._exit", "exit", "quit"):
            self.exit.append(node.lineno)
        elif name == "sys.stdout.write":
            self.stdout.append(node.lineno)
        elif name == "sys.stderr.write":
            self.diag.append(node.lineno)
        self.generic_visit(node)


def scan_python(text: str) -> _PyEmissionVisitor:
    v = _PyEmissionVisitor()
    try:
        tree = ast.parse(text)
    except SyntaxError:
        return v
    v.visit(tree)
    return v


# ── zig: the repo names its own stdout/stderr split (src/util.zig:1-4,
# src/managent/main.zig:33-54) — match those literal, documented call forms.

ZIG_STDOUT = [re.compile(r"\butil\.out\("), re.compile(r"\butil\.println\("),
              re.compile(r"\bw\.data\(")]
ZIG_DIAG = [re.compile(r"\bstd\.debug\.print\("), re.compile(r"\bw\.diag\("),
            re.compile(r"\butil\.note\("), re.compile(r"\butil\.warn\(")]
ZIG_EXIT = [re.compile(r"\bstd\.process\.exit\(")]


def scan_zig(text: str):
    stdout_lines, diag_lines, exit_lines = [], [], []
    for i, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        for pat in ZIG_STDOUT:
            if pat.search(line):
                stdout_lines.append(i)
        for pat in ZIG_DIAG:
            if pat.search(line):
                diag_lines.append(i)
        for pat in ZIG_EXIT:
            if pat.search(line):
                exit_lines.append(i)
    return stdout_lines, diag_lines, exit_lines


# ── shell: echo/printf as a command word, minus anything redirected to
# stderr on the same line; `exit N` as the exit-emission form.

_SHELL_CMD_WORD = re.compile(r"(?:^|[;&|(]\s*|\bthen\s+|\belse\s+)\s*(echo|printf)\b")
_SHELL_STDERR_REDIR = re.compile(r">&2|1>&2|>\s*/dev/stderr")
_SHELL_EXIT = re.compile(r"(?:^|[;&|]\s*)exit\b\s*(\d*)")


def scan_shell(text: str):
    stdout_lines, diag_lines, exit_lines = [], [], []
    for i, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        if _SHELL_CMD_WORD.search(line):
            if _SHELL_STDERR_REDIR.search(line):
                diag_lines.append(i)
            else:
                stdout_lines.append(i)
        if _SHELL_EXIT.search(line):
            exit_lines.append(i)
    return stdout_lines, diag_lines, exit_lines


# ── driver ────────────────────────────────────────────────────────────────

def census(repo_root: str) -> dict:
    files = scope_files(repo_root)
    records = []
    per_file = {}
    excluded_diag = 0
    skipped_no_lang = []
    for rel in files:
        abspath = os.path.join(repo_root, rel)
        lang = detect_lang(abspath)
        if lang is None:
            skipped_no_lang.append(rel)
            continue
        try:
            with open(abspath, "r", errors="replace") as f:
                text = f.read()
        except OSError:
            continue
        if lang == "python":
            v = scan_python(text)
            stdout_lines, diag_lines, exit_lines = v.stdout, v.diag, v.exit
        elif lang == "zig":
            stdout_lines, diag_lines, exit_lines = scan_zig(text)
        else:
            stdout_lines, diag_lines, exit_lines = scan_shell(text)
        for ln in stdout_lines:
            records.append({"file": rel, "line": ln, "kind": "stdout"})
        for ln in exit_lines:
            records.append({"file": rel, "line": ln, "kind": "exit"})
        excluded_diag += len(diag_lines)
        if stdout_lines or exit_lines:
            per_file[rel] = {"stdout": len(stdout_lines), "exit": len(exit_lines),
                              "diag_excluded": len(diag_lines), "lang": lang}
    stdout_n = sum(1 for r in records if r["kind"] == "stdout")
    exit_n = sum(1 for r in records if r["kind"] == "exit")
    return {
        "scope_files": len(files),
        "scope_files_skipped_unrecognized_language": skipped_no_lang,
        "emission_points": records,
        "count_stdout": stdout_n,
        "count_exit": exit_n,
        "count_total": stdout_n + exit_n,
        "count_diag_excluded": excluded_diag,
        "per_file": per_file,
    }


# ── controls: the count does not count until it has caught what it must
# catch, and reported zero where there is nothing (brief Acceptance #2) ────

_SEEDED_ZIG = """\
const std = @import("std");
const util = @import("util.zig");
pub fn cmdExample(w: Writers) !void {
    util.out("result: {d}\\n", .{42});   // 1 stdout
    w.data("more data\\n", .{});          // 1 stdout
    util.note("progress\\n", .{});        // excluded (diagnostic)
    std.debug.print("warn\\n", .{});      // excluded (diagnostic)
    std.process.exit(1);                 // 1 exit
}
"""

_SEEDED_PY = """\
import sys, os
print("a fact")                      # 1 stdout
print("noise", file=sys.stderr)       # excluded (diagnostic)
sys.stdout.write("raw fact\\n")        # 1 stdout
sys.exit(2)                           # 1 exit
"""

_SEEDED_SH = """\
#!/usr/bin/env bash
echo "a fact"          # 1 stdout
echo "noise" >&2        # excluded (diagnostic)
printf 'more fact\\n'    # 1 stdout
exit 3                  # 1 exit
"""

# expected counts for the seeded fixture set above: each of the 3 fixture
# files (zig/python/shell) plants 2 stdout + 1 exit; the zig fixture plants
# 2 diagnostics (util.note AND std.debug.print) where python/shell plant 1
# each, so diag = 2 + 1 + 1 = 4.
_SEEDED_EXPECT = {"stdout": 6, "exit": 3, "diag": 4}

_NULL_ZIG = 'const std = @import("std");\nfn noop() void {}\n'
_NULL_PY = "def noop():\n    pass\n"
_NULL_SH = "#!/usr/bin/env bash\nnoop() { :; }\n"


def _write_scratch_tree(root: str, zig_text: str, py_text: str, sh_text: str):
    os.makedirs(os.path.join(root, "tools"), exist_ok=True)
    os.makedirs(os.path.join(root, "src", "managent"), exist_ok=True)
    with open(os.path.join(root, "src", "managent", "main.zig"), "w") as f:
        f.write(zig_text)
    with open(os.path.join(root, "src", "claimlint.zig"), "w") as f:
        f.write("const std = @import(\"std\");\n")
    with open(os.path.join(root, "src", "absorb.zig"), "w") as f:
        f.write("const std = @import(\"std\");\n")
    with open(os.path.join(root, "tools", "example.py"), "w") as f:
        f.write(py_text)
    with open(os.path.join(root, "tools", "example.sh"), "w") as f:
        f.write(sh_text)
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "t898@test"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "T898"], cwd=root, check=True)
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-qm", "scratch"], cwd=root, check=True)


def self_test() -> bool:
    ok = True
    with tempfile.TemporaryDirectory(prefix="t898-null-") as root:
        _write_scratch_tree(root, _NULL_ZIG, _NULL_PY, _NULL_SH)
        result = census(root)
        if result["count_total"] != 0:
            print(f"NULL CONTROL FAILED: expected 0 emission points, got "
                  f"{result['count_total']}: {result['emission_points']}",
                  file=sys.stderr)
            ok = False
        else:
            print(f"null control:   0 emission points on a call-free tree "
                  f"({result['scope_files']} scope files) — PASS")

    with tempfile.TemporaryDirectory(prefix="t898-seed-") as root:
        _write_scratch_tree(root, _SEEDED_ZIG, _SEEDED_PY, _SEEDED_SH)
        result = census(root)
        want_stdout = _SEEDED_EXPECT["stdout"]
        want_exit = _SEEDED_EXPECT["exit"]
        want_diag = _SEEDED_EXPECT["diag"]
        got_diag = result["count_diag_excluded"]
        if (result["count_stdout"], result["count_exit"], got_diag) != (
                want_stdout, want_exit, want_diag):
            print(f"SEEDED-DEFECT CONTROL FAILED: expected stdout={want_stdout} "
                  f"exit={want_exit} diag_excluded={want_diag}, got "
                  f"stdout={result['count_stdout']} exit={result['count_exit']} "
                  f"diag_excluded={got_diag}\n{json.dumps(result, indent=2)}",
                  file=sys.stderr)
            ok = False
        else:
            print(f"seeded control: {want_stdout} stdout + {want_exit} exit "
                  f"planted, all found; {want_diag} diagnostics planted, all "
                  f"correctly excluded — PASS")
    return ok


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return 0 if self_test() else 1
    result = census(REPO_ROOT)
    if "--json" in argv:
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    print(f"emission-census: {result['scope_files']} scope files "
          f"({len(result['scope_files_skipped_unrecognized_language'])} "
          f"skipped — no recognized language)")
    print(f"  stdout emissions: {result['count_stdout']}")
    print(f"  exit emissions:   {result['count_exit']}")
    print(f"  TOTAL:            {result['count_total']}")
    print(f"  (diagnostics excluded by rule: {result['count_diag_excluded']})")
    print()
    for rel, c in sorted(result["per_file"].items(), key=lambda kv: -(kv[1]["stdout"] + kv[1]["exit"])):
        print(f"  {c['stdout']+c['exit']:5d}  {rel}  "
              f"(stdout={c['stdout']} exit={c['exit']} diag_excluded={c['diag_excluded']})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
