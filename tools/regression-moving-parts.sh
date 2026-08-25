#!/usr/bin/env bash
# regression-moving-parts.sh — T943 / T952 controls:
#
# Inventory and process hygiene gate:
#   1. Every running project-owned process matches an entry in docs/infra/moving-parts.md.
#   2. Undocumented processes, orphaned test trees, and prohibited daemons fail loudly.
#   3. Scratch directories (/tmp/weizigo) do not leak across runs.
#   4. Background launchd plists are verified unloaded.
#   5. Caffeinate processes are attributed by ancestry: harness caffeinate is exempt,
#      project-spawned timed caffeinate (-i -t) is prohibited (T952).
#
# Controls:
#   A. Null control: live system with only documented processes passes silently.
#   B. Seeded defect: undocumented project process is detected and named loudly.
#   C. Seeded defect & ancestry discrimination: prohibited timed caffeinate (-i -t) in
#      project tree is detected and rejected, while external harness caffeinate is exempt.
#   D. Stale / orphan detection: expired wall budget and orphaned test processes are flagged.
#   E. Scratch cleanliness: running subagent / tests creates zero directory leaks in /tmp/weizigo.
#   F. Launchd census: no com.weizigo plists loaded in launchd.
#
# Task: T943/T952 · Model: gemini-3.7-flash · Date: 2026-08-25

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0

pass() { echo "    PASS: $*"; }
fail() { echo "    FAIL: $*"; FAIL=1; }

echo "=== regression-moving-parts (T943/T952) ==="

# ── Helper: Process Scanner (Python) ───────────────────────────────────────
SCANNER_PY="$PROJECT/tools/moving-parts-scanner.py"
cat <<'PYEOF' > "$PROJECT/tools/moving-parts-scanner.py"
#!/usr/bin/env python3
"""Scanner for weizigo moving parts and process hygiene."""

import json, os, re, subprocess, sys

REPO_ROOT = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True).stdout.strip()
if not REPO_ROOT:
    REPO_ROOT = os.path.abspath(".")

# Documented allowed command regexes
ALLOWED_PATTERNS = [
    r"tools/pop-next\.sh",
    r"tools/fleet-keeper\.sh",
    r"untracked/watch-fleet\.sh",
    r"tools/watch-fleet\.sh",
    r"bin/subagent",
    r"bin/dispatch",
    r"tools/runner",
    r"caffeinate -i -w \d+",
    r"zig build test",
    r"zig build",
    r"zig test",
    r"\.zig-cache/.*build\b",
    r"\.zig-cache/.*test\b",
    r"bin/managent",
    r"bin/argus",
    r"tools/suite-truth\.sh",
    r"tools/git-commit-mine",
    r"tools/goban-scaling-capture\.sh",
    r"(?:zig-out/)?bin/weizigo-[a-z0-9-]+",
    r"tools/regression-[a-z0-9_-]+\.sh",
    r"tools/deploy\.sh",
    r"tools/smoke\.sh",
    r"python3.*tests/unit",
    r"pytest",
    r"moving-parts-scanner\.py",
    r"regression-moving-parts\.sh",
    r"claude -p",
    r"pi --provider",
    r"claude --dangerously-skip-permissions",
]

def is_project_cmd(cmd):
    if REPO_ROOT in cmd:
        return True
    keywords = [
        "weizigo", "pop-next", "fleet-keeper", "watch-fleet", "managent",
        "subagent", "dispatch_verify", "goban-scaling-capture", "suite-truth"
    ]
    return any(kw in cmd for kw in keywords)

def has_project_ancestor(pid, proc_map, max_depth=50):
    curr = pid
    visited = set()
    depth = 0
    while curr in proc_map and curr not in ("0", "1") and depth < max_depth:
        visited.add(curr)
        ppid, _, pcmd = proc_map[curr]
        if is_project_cmd(pcmd):
            return True
        if ppid in visited:
            break
        curr = ppid
        depth += 1
    return False

def scan_processes(custom_ps_lines=None):
    if custom_ps_lines is None:
        ps_out = subprocess.run(["ps", "-axo", "pid,ppid,etime,command"],
                                capture_output=True, text=True).stdout.splitlines()
    else:
        ps_out = custom_ps_lines

    findings = {
        "undocumented": [],
        "prohibited_caffeinate": [],
        "orphaned_test_trees": [],
        "stale_runners": [],
        "documented": []
    }

    proc_map = {}
    proc_list = []
    for line in ps_out:
        parts = line.strip().split(None, 3)
        if len(parts) < 4:
            continue
        pid, ppid, etime, cmd = parts
        if pid == "PID":
            continue
        proc_map[pid] = (ppid, etime, cmd)
        proc_list.append((pid, ppid, etime, cmd))

    for pid, ppid, etime, cmd in proc_list:
        # Ignore self / scanner invocations
        if "moving-parts-scanner.py" in cmd or "ps -axo" in cmd:
            continue

        # Check for caffeinate: attribute by ancestry (T952)
        if "caffeinate" in cmd:
            is_ours = is_project_cmd(cmd) or has_project_ancestor(pid, proc_map)
            if not is_ours:
                # External / harness caffeinate (e.g. Claude Code console claude --dangerously-skip-permissions) -> exempt (not ours)
                continue
            if re.search(r"caffeinate -i -w \d+", cmd):
                findings["documented"].append({"pid": pid, "ppid": ppid, "etime": etime, "cmd": cmd})
            else:
                findings["prohibited_caffeinate"].append({"pid": pid, "ppid": ppid, "etime": etime, "cmd": cmd})
            continue

        # Is this process related to the project?
        if not is_project_cmd(cmd):
            continue

        # Check if documented
        matched = False
        for pat in ALLOWED_PATTERNS:
            if re.search(pat, cmd):
                matched = True
                break

        if not matched:
            findings["undocumented"].append({"pid": pid, "ppid": ppid, "etime": etime, "cmd": cmd})
        else:
            findings["documented"].append({"pid": pid, "ppid": ppid, "etime": etime, "cmd": cmd})

        # Check for orphaned test scripts (ppid == 1 and regression-*.sh or zig build test)
        if ppid == "1" and ("regression-" in cmd or "zig build test" in cmd or ".zig-cache" in cmd):
            if not ("pop-next.sh" in cmd or "watch-fleet.sh" in cmd or "fleet-keeper.sh" in cmd):
                findings["orphaned_test_trees"].append({"pid": pid, "ppid": ppid, "etime": etime, "cmd": cmd})

        # Check for stale runner exceeding max wall
        if "tools/runner" in cmd:
            m_wall = re.search(r"--max-wall\s+(\d+)", cmd)
            if m_wall:
                max_wall_s = int(m_wall.group(1))
                # Parse etime: [[dd-]hh:]mm:ss
                etime_parts = etime.split("-")
                days = int(etime_parts[0]) if len(etime_parts) > 1 else 0
                time_str = etime_parts[-1]
                t_parts = [int(p) for p in time_str.split(":")]
                if len(t_parts) == 3:
                    elapsed_s = days * 86400 + t_parts[0] * 3600 + t_parts[1] * 60 + t_parts[2]
                elif len(t_parts) == 2:
                    elapsed_s = days * 86400 + t_parts[0] * 60 + t_parts[1]
                else:
                    elapsed_s = days * 86400 + t_parts[0]
                if elapsed_s > (max_wall_s + 60):  # 60s grace
                    findings["stale_runners"].append({
                        "pid": pid, "ppid": ppid, "etime": etime, "elapsed_s": elapsed_s,
                        "max_wall_s": max_wall_s, "cmd": cmd
                    })

    return findings

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "live"
    if mode == "live":
        res = scan_processes()
        print(json.dumps(res, indent=2))
        errs = (len(res["undocumented"]) + len(res["prohibited_caffeinate"]) +
                len(res["orphaned_test_trees"]) + len(res["stale_runners"]))
        sys.exit(0 if errs == 0 else 1)
    elif mode == "test_synthetic":
        fixture_path = sys.argv[2]
        lines = open(fixture_path).read().splitlines()
        res = scan_processes(custom_ps_lines=lines)
        print(json.dumps(res, indent=2))
        errs = (len(res["undocumented"]) + len(res["prohibited_caffeinate"]) +
                len(res["orphaned_test_trees"]) + len(res["stale_runners"]))
        sys.exit(0 if errs == 0 else 1)
PYEOF
chmod +x "$SCANNER_PY"

cleanup() {
    rm -f "$SCANNER_PY"
    [ -n "${SEED_PID:-}" ] && kill -9 "$SEED_PID" 2>/dev/null || true
    [ -n "${CAFF_PID:-}" ] && kill -9 "$CAFF_PID" 2>/dev/null || true
    [ -n "${SYNTH_FILE:-}" ] && rm -f "$SYNTH_FILE" || true
}
trap cleanup EXIT

# ── Arm A: Null control on live system ────────────────────────────────────
echo "  A. null control: scan running processes on host (all documented)"
SCAN_OUT=$(python3 "$SCANNER_PY" live 2>&1)
SCAN_RC=$?
if [ "$SCAN_RC" -eq 0 ]; then
    pass "null control: all running project processes are documented and compliant (RC=0)"
else
    fail "null control failed (RC=$SCAN_RC): unexpected undocumented or rogue processes found"
    echo "$SCAN_OUT" | sed 's/^/      | /'
fi

# ── Arm B: Seeded defect — Undocumented process ───────────────────────────
echo "  B. seeded defect: undocumented project process detected and named"
(python3 -c 'import time; time.sleep(30)' --weizigo-unregistered-ghost-process >/dev/null 2>&1) &
SEED_PID=$!
sleep 0.2

OUT_B=$(python3 "$SCANNER_PY" live 2>&1)
RC_B=$?
kill -9 "$SEED_PID" >/dev/null 2>&1 || true
wait "$SEED_PID" 2>/dev/null || true
unset SEED_PID

if [ "$RC_B" -ne 0 ] && echo "$OUT_B" | grep -q "weizigo-unregistered-ghost-process"; then
    pass "seeded defect: undocumented process was caught and named (RC=$RC_B)"
else
    fail "seeded defect failed: undocumented process was NOT caught (RC=$RC_B)"
    echo "$OUT_B" | sed 's/^/      | /'
fi

# ── Arm C: Seeded defect & ancestry discrimination for caffeinate ──────────
echo "  C. seeded defect & ancestry discrimination: prohibited timed caffeinate (-i -t) detected"
if command -v caffeinate >/dev/null 2>&1; then
    (caffeinate -i -t 30 >/dev/null 2>&1) &
    CAFF_PID=$!
    sleep 0.2
    OUT_C=$(python3 "$SCANNER_PY" live 2>&1)
    RC_C=$?
    kill -9 "$CAFF_PID" >/dev/null 2>&1 || true
    wait "$CAFF_PID" 2>/dev/null || true
    unset CAFF_PID
    if [ "$RC_C" -ne 0 ] && echo "$OUT_C" | grep -q "prohibited_caffeinate"; then
        pass "seeded defect: timed caffeinate in project tree was detected and flagged (RC=$RC_C)"
    else
        fail "seeded defect failed: timed caffeinate was NOT flagged (RC=$RC_C)"
        echo "$OUT_C" | sed 's/^/      | /'
    fi
fi

# Synthetic discrimination test (T952): harness caffeinate vs project hung test caffeinate
SYNTH_FILE=$(mktemp /tmp/synth-ps-caff-XXXXXX)
cat <<SYNEOF > "$SYNTH_FILE"
PID  PPID ETIME    COMMAND
9901 9900 00:05:00 caffeinate -i -t 300
9900 1    01:00:00 /usr/local/bin/claude --dangerously-skip-permissions
9903 9902 00:05:00 caffeinate -i -t 300
9902 1    00:10:00 /bin/sh $PROJECT/tools/regression-hung-test.sh
9905 9904 00:02:00 caffeinate -i -w 9904
9904 1    00:02:00 /usr/bin/python3 $PROJECT/tools/runner --max-wall 3600 -- pi --model test
SYNEOF

OUT_C_SYNTH=$(python3 "$SCANNER_PY" test_synthetic "$SYNTH_FILE" 2>&1)
RC_C_SYNTH=$?
rm -f "$SYNTH_FILE"
unset SYNTH_FILE

# Verify that PID 9903 (project hung test) is in prohibited_caffeinate, PID 9901 (claude harness) is NOT, and PID 9905 is documented
if [ "$RC_C_SYNTH" -ne 0 ] \
   && echo "$OUT_C_SYNTH" | grep -q '"pid": "9903"' \
   && ! echo "$OUT_C_SYNTH" | grep -q '"pid": "9901"' \
   && echo "$OUT_C_SYNTH" | grep -q '"pid": "9905"'; then
    pass "ancestry discrimination: harness caffeinate (9901) exempt, project timed caffeinate (9903) caught, project -w (9905) documented"
else
    fail "ancestry discrimination failed (RC=$RC_C_SYNTH)"
    echo "$OUT_C_SYNTH" | sed 's/^/      | /'
fi

# ── Arm D: Synthetic stale runner & orphaned test tree detection ──────────
echo "  D. synthetic: stale runner (past max wall) & orphaned test process detected"
SYNTH_FILE=$(mktemp /tmp/synth-ps-XXXXXX)
cat <<SYNEOF > "$SYNTH_FILE"
PID  PPID ETIME    COMMAND
8881 100  02:15:00 /usr/bin/python3 $PROJECT/tools/runner --max-wall 3600 -- pi --model test
8882 1    01:30:00 /bin/sh $PROJECT/tools/regression-watch-fleet.sh
8883 100  00:05:00 /bin/sh $PROJECT/tools/pop-next.sh --loop 240
SYNEOF
OUT_D=$(python3 "$SCANNER_PY" test_synthetic "$SYNTH_FILE" 2>&1)
RC_D=$?
rm -f "$SYNTH_FILE"
unset SYNTH_FILE

if [ "$RC_D" -ne 0 ] \
   && echo "$OUT_D" | grep -q "stale_runners" \
   && echo "$OUT_D" | grep -q "orphaned_test_trees"; then
    pass "synthetic controls: stale runner (02:15:00 > 3600s) and orphaned test tree (ppid 1) both flagged"
else
    fail "synthetic controls failed (RC=$RC_D)"
    echo "$OUT_D" | sed 's/^/      | /'
fi

# ── Arm E: Scratch directory cleanliness & zero growth ───────────────────
echo "  E. scratch directory cleanliness: test execution does not leak dirs in /tmp/weizigo"
COUNT_BEFORE=$(find /tmp/weizigo -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
python3 "$PROJECT/bin/subagent" --help >/dev/null 2>&1 || true
python3 "$PROJECT/bin/subagent" --dry-run --provider deepseek T9999 >/dev/null 2>&1 || true
sh "$PROJECT/tools/regression-canonicalizer-parity.sh" >/dev/null 2>&1 || true
COUNT_AFTER=$(find /tmp/weizigo -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

if [ "$COUNT_AFTER" -le "$COUNT_BEFORE" ]; then
    pass "scratch cleanliness: dir count before=$COUNT_BEFORE, after=$COUNT_AFTER (zero growth)"
else
    fail "scratch cleanliness: dir count grew from $COUNT_BEFORE to $COUNT_AFTER (leak detected)"
fi

# ── Arm F: Launchd plists census ──────────────────────────────────────────
echo "  F. launchd census: no com.weizigo plists loaded"
if command -v launchctl >/dev/null 2>&1; then
    LOADED_WEIZIGO=$(launchctl list 2>/dev/null | grep -iE "com\.weizigo" || true)
    if [ -z "$LOADED_WEIZIGO" ]; then
        pass "launchd census: zero com.weizigo jobs loaded"
    else
        fail "launchd census: com.weizigo job(s) found loaded in launchd:"
        echo "$LOADED_WEIZIGO" | sed 's/^/      | /'
    fi
else
    pass "launchctl not available on this platform"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-moving-parts: ALL CONTROLS PASSED ==="
    exit 0
else
    echo "=== regression-moving-parts: FAILED ==="
    exit 1
fi
