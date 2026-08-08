#!/usr/bin/env python3
"""Race-1 mechanical grader (T371 conductor).

A proposal for a packet is a set of test scripts. Each test runs twice:
  - against the MUTANT  (untracked/race-grading/race1/<pkt>/mutant/)  -> kill  = non-zero exit
  - against the CLEAN   (untracked/race-grading/race1/<pkt>/clean/)  -> pass  = zero exit
A packet point iff >=1 test kills the mutant AND passes the clean twin.
Recall = packets killed / 3. False alarms = tests that kill the clean twin
or that fail to kill the mutant while claiming to.

Usage:
  grade_packet <pkt> <test1.py> [<test2.py> ...]   -> prints per-test kill/pass + point
  grade_lane   <dir-with-PROP/>  (PROP files named t_*.py per packet dir pkt_<name>/)
"""
import os, sys, subprocess, re, json, tempfile

GRADING = "untracked/race-grading/race1"
PACKETS = ["r1-p1", "r1-p2", "r1-p3"]

def run_test(test_path, variant_dir):
    """Run python3 <test> with cwd=variant_dir (so `import impl` resolves)."""
    r = subprocess.run([sys.executable, test_path], cwd=variant_dir,
                       capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout, r.stderr

def grade_packet_tests(pkt, test_paths, verbose=True):
    mutant_dir = os.path.join(GRADING, pkt, "mutant")
    clean_dir  = os.path.join(GRADING, pkt, "clean")
    results = []
    killed = False
    clean_passed = False
    false_alarms = 0
    for tp in test_paths:
        mk, mout, merr = run_test(tp, mutant_dir)
        ck, cout, cerr = run_test(tp, clean_dir)
        kill = (mk != 0)
        passc = (ck == 0)
        # false alarm: kills the clean twin
        if ck != 0:
            false_alarms += 1
        if kill: killed = True
        if passc: clean_passed = True
        if verbose:
            print(f"  test {os.path.basename(tp)}: mutant_exit={mk} clean_exit={ck} "
                  f"kill={kill} clean_pass={passc}")
        results.append({"test": os.path.basename(tp), "mutant_exit": mk,
                        "clean_exit": ck, "kill": kill, "clean_pass": passc})
    point = killed and clean_passed
    return {"packet": pkt, "point": point, "killed_mutant": killed,
            "clean_passed": clean_passed, "false_alarms": false_alarms,
            "tests": results}

# ---- extract tests from a lane out.md: fenced ```python blocks ----
PYFENCE = re.compile(r"```python\n(.*?)```", re.S)

def extract_tests(out_md_path, dest_dir):
    """Write each fenced python block to dest_dir/t_NNN.py. Returns list of paths."""
    txt = open(out_md_path, encoding="utf-8").read()
    blocks = PYFENCE.findall(txt)
    paths = []
    for i, b in enumerate(blocks, 1):
        p = os.path.join(dest_dir, f"t_{i:03d}.py")
        with open(p, "w") as f:
            f.write(b if b.endswith("\n") else b + "\n")
        paths.append(p)
    return paths

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "grade_packet":
        pkt = sys.argv[2]
        tests = sys.argv[3:]
        res = grade_packet_tests(pkt, tests)
        print(json.dumps(res, indent=2))
        print(f"POINT {pkt}: {res['point']}")
    elif cmd == "grade_lane":
        # lane proposal dir: subdirs pkt_r1-p1/ etc with t_*.py
        lane_dir = sys.argv[2]
        total = 0
        summary = []
        for pkt in PACKETS:
            pdir = os.path.join(lane_dir, pkt)
            if not os.path.isdir(pdir):
                summary.append({"packet": pkt, "point": False, "note": "no proposal dir"})
                print(f"{pkt}: NO PROPOSAL DIR")
                continue
            tests = sorted([os.path.join(pdir, f) for f in os.listdir(pdir)
                            if f.endswith(".py")])
            if not tests:
                summary.append({"packet": pkt, "point": False, "note": "no tests"})
                print(f"{pkt}: no tests")
                continue
            print(f"=== {pkt} ===")
            res = grade_packet_tests(pkt, tests)
            print(f"  -> point={res['point']} killed_mutant={res['killed_mutant']} "
                  f"clean_passed={res['clean_passed']} false_alarms={res['false_alarms']}")
            total += int(res["point"])
            summary.append(res)
        print(f"\nRECALL: {total} / {len(PACKETS)} packets killed (point earned)")
        fa = sum(s.get("false_alarms", 0) for s in summary)
        print(f"FALSE ALARMS (clean-twin kills): {fa}")
        print(json.dumps({"recall": total, "denominator": len(PACKETS),
                          "false_alarms": fa, "per_packet": summary}, indent=2))
    else:
        sys.exit("unknown cmd")
