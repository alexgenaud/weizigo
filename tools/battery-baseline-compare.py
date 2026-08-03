#!/usr/bin/env python3
"""battery-baseline-compare.py — T292 golden-master comparison for the verify-battery.

Two modes:
  --mode fast   the four git-tracked WZO1 artifacts (artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo).
                Runs inside `zig build test` via tools/regression-battery-baselines.sh.
  --mode sweep  the three data/ 4x4 WZO1 artifacts plus the WZO2 artifact
                (untracked/oracle-v2/oracle-4x4-v2.wzo2 via oracle-v2-accept).
                Runs behind the explicit `zig build battery-sweep` step, never
                in the default suite. Skips loudly when a host-only artifact is
                absent.

Every battery invocation runs under tools/runner (RSS cap 4096 MB per PID,
one invocation at a time — no concurrent sweeps, GRAND-AUDIT §3).

Comparison rule (baselines.md §3, exact equality, no tolerance):
  cell equality = (status, numerator, denominator, mode_declared, mode_actual,
                   exit_class, seed, sample_size, sample_denominator)
  deviation is informational (a note, not a measurement) and does not trigger.
  A baseline whose status is fail or error is a *recorded characteristic*:
  the gate compares the recorded values exactly — a change in either
  direction (fail->pass, or fail with different counts) is the signal.
  An unfixed-seed sampled cell is NOT a golden master and is excluded;
  none exist in the current battery.

Exit: 0 = every compared cell matches the baseline; 1 = at least one diff;
      2 = battery could not run (battery-bad).
"""

import argparse
import json
import os
import re
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FAST_ARTIFACTS = [
    ("artifacts/oracle-2x2.wzo", "2x2"),
    ("artifacts/oracle-3x2.wzo", "3x2"),
    ("artifacts/oracle-3x3.wzo", "3x3"),
    ("artifacts/oracle-4x3.wzo", "4x3"),
]
SWEEP_WZO1 = [
    ("data/oracle-4x4-basicko-tie-area.wzo", "4x4"),
    ("data/oracle-4x4.checkpoint.wzo", "4x4"),
    ("data/oracle-4x4-parallel.checkpoint.wzo", "4x4"),
]
WZO2_PATH = "untracked/oracle-v2/oracle-4x4-v2.wzo2"

# fields compared exactly; deviation is informational
CMP_FIELDS = [
    "status", "numerator", "denominator",
    "mode_declared", "mode_actual", "exit_class",
    "seed", "sample_size", "sample_denominator",
]


def load_baseline(path):
    with open(path) as f:
        return json.load(f)


def sha256(path):
    import hashlib
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def run_battery(battery_bin, goban, artifact):
    """Run the verify-battery binary under tools/runner; return list of result rows."""
    cmd = ["tools/runner", "--", battery_bin, goban, artifact]
    proc = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
    rows = []
    for line in proc.stdout.splitlines():
        if not line.startswith("{"):
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        if r.get("kind") == "result":
            rows.append(r)
    if proc.returncode != 0 and not rows:
        # battery-bad with no result rows — report loudly
        return None, proc.returncode, proc.stderr[-2000:]
    return rows, proc.returncode, None


def norm_row(r):
    """Normalize a battery result row to the baseline cell shape."""
    v = r.get("value") or {}
    return {
        "status": r["status"],
        "numerator": v.get("numerator"),
        "denominator": v.get("denominator"),
        "mode_declared": r.get("mode_declared"),
        "mode_actual": r.get("mode_actual"),
        "exit_class": r.get("exit_class"),
        "seed": r.get("seed"),
        "sample_size": r.get("sample_size"),
        "sample_denominator": r.get("sample_denominator"),
        "deviation": r.get("deviation"),
    }


def compare_cell(inv, baseline_cell, actual_cell):
    """Return list of diff strings (empty = match)."""
    diffs = []
    for f in CMP_FIELDS:
        if baseline_cell.get(f) != actual_cell.get(f):
            diffs.append(f"{f}: baseline={baseline_cell.get(f)!r} actual={actual_cell.get(f)!r}")
    return diffs


# ── WZO2 acceptance normalization ──────────────────────────────────────────

def run_accept(accept_bin, check):
    """Run oracle-v2-accept for one check; return (status, num, den, extra) or None."""
    cmd = [accept_bin, WZO2_PATH, check]
    proc = subprocess.run(cmd, cwd=REPO, capture_output=True, text=True)
    out = proc.stdout + proc.stderr
    verdict = "PASS" if f"{check.upper()} VERDICT: PASS" in out else "FAIL"
    if "OVERALL VERDICT: FAIL" in out:
        verdict = "FAIL"
    m = re.search(rf"{check.upper()} ([^\n]+)", out)
    detail = m.group(1) if m else ""
    num = den = stride = sden = None
    if check == "a1":
        m1 = re.search(r"refusals=(\d+)", detail); m2 = re.search(r"queries=(\d+)", detail)
        num = int(m1.group(1)) if m1 else None; den = int(m2.group(1)) if m2 else None
    elif check == "a4":
        num = 0; den = None
        m1 = re.search(r"total=(\d+)", detail)
        den = int(m1.group(1)) if m1 else None
    elif check == "a2":
        n = 0
        for k in ("L_violations", "H_violations", "missing_child"):
            m1 = re.search(rf"{k}=(\d+)", detail)
            if m1: n += int(m1.group(1))
        num = n
        m1 = re.search(r"checked=(\d+)", detail); m2 = re.search(r"stride=(\d+)", detail)
        m3 = re.search(r"denominator=(\d+)", detail)
        den = int(m1.group(1)) if m1 else None
        stride = int(m2.group(1)) if m2 else None
        sden = int(m3.group(1)) if m3 else None
    elif check == "a3":
        n = 0
        for k in ("violations", "not_found"):
            m1 = re.search(rf"{k}=(\d+)", detail)
            if m1: n += int(m1.group(1))
        num = n
        m1 = re.search(r"checked=(\d+)", detail)
        den = int(m1.group(1)) if m1 else None
    elif check == "a5":
        m1 = re.search(r"mismatches=(\d+)", detail); m2 = re.search(r"checked=(\d+)", detail)
        m3 = re.search(r"stride=(\d+)", detail); m4 = re.search(r"denominator=(\d+)", detail)
        num = int(m1.group(1)) if m1 else None; den = int(m2.group(1)) if m2 else None
        stride = int(m3.group(1)) if m3 else None; sden = int(m4.group(1)) if m4 else None
    elif check == "a8":
        n = 0
        for k in ("terminal_dtt0_errs",):
            m1 = re.search(rf"{k}=(\d+)", out)
            if m1: n += int(m1.group(1))
        m1 = re.search(r"DTT consistency: checked=(\d+)", out)
        m2 = re.search(r"DTT consistency: violations=(\d+)", out)
        m3 = re.search(r"DTT consistency:.*stride=(\d+)", out)
        m4 = re.search(r"A8 DTT: total=(\d+)", out)
        if m2: n += int(m2.group(1))
        den = int(m1.group(1)) if m1 else None
        stride = int(m3.group(1)) if m3 else None
        sden = int(m4.group(1)) if m4 else None
        num = n
    elif check == "a6":
        caught = len(re.findall(r"caught=true", out))
        num = 3 - caught; den = 3
    elif check == "a9":
        ok = re.search(r"sha256_ok=true", out) is not None or re.search(r"ok=true", out) is not None
        ok = ok and "groups_sorted=true" in out and "entries_sorted=true" in out
        num = 0 if ok else 1; den = 1
    status = "pass" if verdict == "PASS" else "fail"
    cell = {
        "status": status, "numerator": num, "denominator": den,
        "mode_declared": "exhaustive", "mode_actual": "exhaustive",
        "exit_class": "pass" if status == "pass" else "artifact-bad",
        "seed": None, "sample_size": None, "sample_denominator": sden,
        "deviation": detail,
    }
    if stride is not None:
        cell["stride"] = stride
    return cell


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--battery", required=True, help="path to the verify-battery binary (build artifact)")
    ap.add_argument("--accept", default=None, help="path to the oracle-v2-accept binary (sweep only)")
    ap.add_argument("--mode", choices=["fast", "sweep"], required=True)
    ap.add_argument("--baseline", default=os.path.join(REPO, "docs/evidence/BATTERY/baselines.json"))
    args = ap.parse_args()

    baseline = load_baseline(args.baseline)
    diffs = []
    skipped = []

    if args.mode == "fast":
        targets = FAST_ARTIFACTS
    else:
        targets = SWEEP_WZO1

    print(f"=== battery baseline comparison [{args.mode}] ===")
    for artifact, goban in targets:
        if not os.path.exists(os.path.join(REPO, artifact)):
            skipped.append(f"{artifact}: artifact absent on this host — SKIP (host-only)")
            print(f"  SKIP  {artifact} (absent)")
            continue
        bsha = baseline["artifacts"].get(artifact, {}).get("sha256")
        if bsha and sha256(os.path.join(REPO, artifact)) != bsha:
            # artifact changed on disk vs recorded baseline — that IS a signal
            diffs.append(f"{artifact}: artifact SHA-256 differs from baseline")
            print(f"  DIFF  {artifact}: SHA-256 differs from baseline")
            continue
        rows, rc, err = run_battery(args.battery, goban, artifact)
        if rows is None:
            diffs.append(f"{artifact}: battery could not run (rc={rc}): {err}")
            print(f"  DIFF  {artifact}: battery-bad (rc={rc})")
            continue
        print(f"  OK    {artifact}  (battery rc={rc})")
        for inv in sorted({r["invariant"] for r in rows}):
            actual = next((r for r in rows if r["invariant"] == inv), None)
            if actual is None:
                continue
            cell = norm_row(actual)
            base = baseline["artifacts"][artifact]["checks"].get(inv)
            if base is None:
                diffs.append(f"{artifact} {inv}: not present in baseline")
                print(f"  DIFF  {inv}: check not in baseline")
                continue
            ds = compare_cell(inv, base, cell)
            if ds:
                diffs.append(f"{artifact} {inv}: " + "; ".join(ds))
                print(f"  DIFF  {inv}: " + "; ".join(ds))
            else:
                print(f"  pass  {inv}: {cell['status']} {cell.get('numerator')}/{cell.get('denominator')}")
        # checks in baseline but not produced by this run
        for inv in baseline["artifacts"][artifact]["checks"]:
            if inv not in {r["invariant"] for r in rows}:
                diffs.append(f"{artifact} {inv}: baseline has check but run produced none")
                print(f"  DIFF  {inv}: baseline-only")

    if args.mode == "sweep":
        if os.path.exists(os.path.join(REPO, WZO2_PATH)):
            if not args.accept or not os.path.exists(args.accept):
                diffs.append("WZO2: --accept binary missing")
            else:
                print(f"  OK    {WZO2_PATH}  (oracle-v2-accept)")
                base = baseline["artifacts"][WZO2_PATH]
                for ch in ["a1", "a4", "a2", "a3", "a5", "a8", "a6", "a9"]:
                    cell = run_accept(args.accept, ch)
                    bcell = base["checks"].get(ch.upper())
                    if bcell is None:
                        diffs.append(f"WZO2 {ch}: not in baseline")
                        print(f"  DIFF  {ch}: not in baseline")
                        continue
                    ds = compare_cell(ch.upper(), bcell, cell)
                    if ds:
                        diffs.append(f"WZO2 {ch.upper()}: " + "; ".join(ds))
                        print(f"  DIFF  {ch.upper()}: " + "; ".join(ds))
                    else:
                        print(f"  pass  {ch.upper()}: {cell['status']} {cell.get('numerator')}/{cell.get('denominator')}")
        else:
            skipped.append(f"{WZO2_PATH}: artifact absent on this host — SKIP (host-only)")

    print("")
    if diffs:
        print(f"BASELINE COMPARISON: FAIL ({len(diffs)} diff(s))")
        for d in diffs:
            print(f"  {d}")
        return 1
    for s in skipped:
        print(f"NOTE: {s}")
    print("BASELINE COMPARISON: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
