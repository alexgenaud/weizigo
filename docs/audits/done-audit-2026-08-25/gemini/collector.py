#!/usr/bin/env python3
"""
Collector and records builder for DONE audit (gemini arm - T950).
Collects mechanical fields and combines with reasoned judgements for all 24 tasks.
"""

import json
import os
import glob
import re
import subprocess
import sys

TASKS_JSON_PATH = "docs/infra/managent/tasks.json"
CONTROL_TASKS = [
    "T932", "T927", "T894", "T924", "T921", "T943",
    "T842", "T841", "T907", "T387", "T929", "T421"
]
DISJOINT_TASKS = [
    "T462", "T674", "T519", "T746", "T514", "T432",
    "T548", "T702", "T872", "T488", "T326", "T361"
]
ALL_TASKS = CONTROL_TASKS + DISJOINT_TASKS

JUDGEMENTS = {
    "T932": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented round-robin partitioning in finishParallel (src/retro.zig) and delivered regression script matching 11.6x speedup.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified code implementation and passing acceptance script.",
        "absorbed": "yes",
        "absorbed_reason": "Parallel partitioning committed to src/retro.zig and integrated into retrograde solve pipeline.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Machine acceptance test tools/regression-finishparallel-partition.sh passes cleanly in git.",
        "useful": "yes",
        "useful_reason": "Yields 2.3x partition speedup (11.6x overall), making writes-off 4x4 solve tractable."
    },
    "T927": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented caffeinate -i -w guard in tools/runner and delivered 4-arm regression test tools/regression-sleep-guard.sh.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified runner implementation and passing 4-arm regression test.",
        "absorbed": "yes",
        "absorbed_reason": "Runner sleep guard committed to tools/runner and active for all host runs.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Acceptance test tools/regression-sleep-guard.sh passes in suite.",
        "useful": "yes",
        "useful_reason": "Prevents host sleep from corrupting benchmark timings and long retrograde runs."
    },
    "T894": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented queue-head readiness ordering in src/managent/main.zig and delivered regression test tools/regression-queue-ordering.sh.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects that code was delivered but findings/close were absorbed post-exit by orchestrator.",
        "absorbed": "yes",
        "absorbed_reason": "Queue ordering logic committed to src/managent/main.zig and active in bin/managent.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Code and regression script verified and committed by orchestrator seat post-exit.",
        "useful": "yes",
        "useful_reason": "Orders dispatchable queue by readiness and ETA instead of arbitrary task ID."
    },
    "T924": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Executed 68-minute writes-off ladder probe and generated 1,354-row CSV, but calculated an unweighted mean solve projection that was 7.585x too high.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects that experimental data was sound while the headline projection was distorted.",
        "absorbed": "yes",
        "absorbed_reason": "Empirical CSV data committed (docs/evidence/T924/per-root.csv) and used by T929 for weighted correction.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Empirical run data verified on disk; projection error identified and re-analyzed by T929.",
        "useful": "yes",
        "useful_reason": "Provided first empirical measurements of 4x4 writes-off tractability."
    },
    "T921": {
        "work_actually_done": "none",
        "work_actually_done_reason": "Process terminated during cold-cache debug compilation; no deliverables written to disk.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded abandoned accurately reflects process termination with zero deliverables.",
        "absorbed": "no",
        "absorbed_reason": "No deliverables produced or absorbed into tree.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Run logs and git status confirm mid-flight abort with no disk output.",
        "useful": "no",
        "useful_reason": "Produced no measurements or artifacts."
    },
    "T943": {
        "work_actually_done": "partial",
        "work_actually_done_reason": "Documented moving parts inventory and wrote regression script, but regression test had false positive on harness caffeinate causing test suite failure.",
        "verdict_accurate": "no",
        "verdict_accurate_reason": "Auto-closed as pass on process evidence (exit 0 + files present) even though its declared acceptance command was failing.",
        "absorbed": "partial",
        "absorbed_reason": "Inventory committed, but broken regression test required immediate followup fix (T952).",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Acceptance failure verified in commit 35fd322 and runner logs.",
        "useful": "mixed",
        "useful_reason": "Inventory was useful, but broken acceptance test broke test suite."
    },
    "T842": {
        "work_actually_done": "none",
        "work_actually_done_reason": "Runaway model consumed 790/792 Ollama requests over 2902s wall clock, producing no patch and no findings.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded abandoned accurately reflects 2902s runaway with zero deliverables.",
        "absorbed": "no",
        "absorbed_reason": "No patch or findings produced to absorb.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Server request logs and empty disk state confirm runaway execution with no output.",
        "useful": "no",
        "useful_reason": "Produced no patch, wasted host Ollama capacity, and starved concurrent lanes."
    },
    "T841": {
        "work_actually_done": "none",
        "work_actually_done_reason": "Starved by T842 (received only 1 Ollama request), ran 2909s without output, produced no deliverables.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded abandoned accurately reflects lane failure due to infrastructure starvation.",
        "absorbed": "no",
        "absorbed_reason": "No patch or findings produced to absorb.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Run record exit=1 and Ollama server logs verify lane was starved by competing model.",
        "useful": "no",
        "useful_reason": "Produced no deliverables or insights due to infrastructure starvation."
    },
    "T907": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Completed all 233 claim adjudications across 3 lanes, identified 53 defects, but git commit was blocked by pre-commit hook on unrelated dirty file.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded blocked accurately reflected work was complete in tree but commit was blocked by pre-commit hook (later committed at 594d860).",
        "absorbed": "yes",
        "absorbed_reason": "Adjudication matrix committed to docs/epistemic/claims-evidence-audit.md and used in claims updates.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Deliverables verified in tree and committed by orchestrator seat post-block.",
        "useful": "yes",
        "useful_reason": "Provided exhaustive 233-claim adjudication ruling across all auditor disagreements."
    },
    "T387": {
        "work_actually_done": "partial",
        "work_actually_done_reason": "Implemented budget DAG solver in src/t387_budget.zig but suffered 14-hour infinite loop under ReleaseFast (bitpos: u6 vs bitpos < 64); DAG data salvaged but Bellman data incomplete.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded blocked accurately reflects failure to complete research deliverable due to ReleaseFast infinite loop.",
        "absorbed": "partial",
        "absorbed_reason": "Salvaged DAG readings committed to findings/T387-capture-budget-dag.json and cited in T397/T405.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Infinite loop bug confirmed in code; salvaged findings verified in git.",
        "useful": "mixed",
        "useful_reason": "Demonstrated budget game DAG termination theoretically, but defect prevented complete evaluation."
    },
    "T929": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Recomputed 4x4.D3 solve bounds (26.8-214.7h) using layer-population weighting on T924 CSV data, correcting T924's 7.585x error without compute.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects complete analytical re-projection confirming tractability.",
        "absorbed": "yes",
        "absorbed_reason": "Delivered docs/research/4x4-d3-weighted-projection.md, superseding T924 projection in PROGRESS.md.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Mathematical formulas and re-projections verified against committed CSV data.",
        "useful": "yes",
        "useful_reason": "Corrected 7.6x distortion in tractability projection without requiring additional compute."
    },
    "T421": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Repointed 283 /tmp citations to docs/evidence/, marked 43 dead citations EVIDENCE LOST, added claimlint C10 VOLATILE checker and regression test.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass accurately reflects complete remediation and tooling additions in commit e5574d8.",
        "absorbed": "yes",
        "absorbed_reason": "C10 check in src/claimlint.zig and tools/regression-claimlint-volatile.sh active in zig build test.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Regression test passes in test suite; repointed links verified in git.",
        "useful": "yes",
        "useful_reason": "Established durable evidence standard and prevented silent loss of experimental data in /tmp."
    },
    "T462": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Triaged all 25 dispatchable rows into 5 do-now, 3 background, 8 close-with-evidence, and 10 ideas; delivered backlog doc and ideas file.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects triage delivery with notes on kanban retire limitations.",
        "absorbed": "yes",
        "absorbed_reason": "Delivered docs/status/backlog-2026-08-19.md and ideas document; phantom closes executed in T446.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Deliverables present in git at commits 84daa02 and e17210e.",
        "useful": "yes",
        "useful_reason": "Cleared backlog congestion and surfaced phantom dispatchable rows."
    },
    "T674": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Audited 68 uncited evidence documents (56 requested + 12 additional), providing ABSORB/REJECT/EXEMPT rulings and rationale for every document.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects complete delivery backfilled into kanban by T716.",
        "absorbed": "yes",
        "absorbed_reason": "Findings committed in 416033f and absorbed during claims register restructuring (T716/T718).",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Findings file on disk verified by T716 census and git log.",
        "useful": "yes",
        "useful_reason": "Resolved backlog of uncited evidence files and prevented claim regressions."
    },
    "T519": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Swept and corrected stale prose and static metric counts across model-perf.md, bakeoff.md, and model-task-matrix.md.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified doc updates committed across target files.",
        "absorbed": "yes",
        "absorbed_reason": "Documentation fixes committed to docs/infra/ in commits e09586d and 60f4e47.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Committed diffs verify exact text corrections across all three target docs.",
        "useful": "yes",
        "useful_reason": "Replaced misleading stale metrics in core infrastructure docs with references to live tools."
    },
    "T746": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Recovered 448 missing token readings (20%->53% coverage), delivered tools/token-backfill.py, corrected oxalpha appetite, and queued 6 rows.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified recovery of missing ledger data and queued follow-up rows.",
        "absorbed": "yes",
        "absorbed_reason": "Token backfill committed in tools/token-backfill.py; handover doc and tasks absorbed into sprint.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Code, recovery script, and findings verified in commits 4d80d8c, 32a4190, 47b91c0.",
        "useful": "yes",
        "useful_reason": "Recovered large volume of missing model performance data and uncovered critical dispatch/liveness bugs."
    },
    "T514": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Verified committed logjam-flag lifecycle fixes in tools/fleet-keeper.sh, executed regressions (all 3 arms passed), and delivered findings.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified regression test passes and committed findings.",
        "absorbed": "yes",
        "absorbed_reason": "Keeper lifecycle logic active in tools/fleet-keeper.sh; findings committed in 28fa9fe.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Regression test arms g2/g3/g4 verified passing against committed keeper implementation.",
        "useful": "yes",
        "useful_reason": "Fixed stale logjam flag persistence that was triggering false-positive alerts."
    },
    "T432": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented assertion-based status rendering in bin/argus (absence rendered as UNKNOWN), updated regression suite, and documented bundle amendment.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects delivery with documented follow-up for managent status labels.",
        "absorbed": "yes",
        "absorbed_reason": "Argus assertion rendering committed in 6e0c02d and regression tests active in suite.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Regression test arms 6-8 verified green in git.",
        "useful": "yes",
        "useful_reason": "Enforced epistemic honesty in monitoring: distinguishing absence of evidence from absence of consoles."
    },
    "T548": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Added process tree reaping on all runner exit paths, added --reap-orphans sweeper to tools/runner, and delivered 9-arm regression test.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified runner implementation and passing 9-arm regression test.",
        "absorbed": "yes",
        "absorbed_reason": "Process reaping active in tools/runner across all fleet invocations.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "9-arm regression test tools/regression-runner-reap.sh passes in test suite.",
        "useful": "yes",
        "useful_reason": "Prevented orphaned zig test child processes from consuming gigabytes of host memory."
    },
    "T702": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Root-caused 4.9 MB managent binary to Debug build default in build.zig, pinned default to ReleaseSafe, added regression, and redeployed.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified root cause analysis and build mode pin in build.zig.",
        "absorbed": "yes",
        "absorbed_reason": "build.zig updated to pin ReleaseSafe mode; deployed binary size reduced.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Regression test and build.zig edits verified in commit 29a5223.",
        "useful": "yes",
        "useful_reason": "Prevented oversized Debug binaries from inflating repository tools."
    },
    "T872": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Executed all 11 DELETE verdicts from stream2b-green classification, unwired dead scripts from build.zig, and delivered changelog.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified deletions and passing test suite.",
        "absorbed": "yes",
        "absorbed_reason": "Deletions committed and reflected in clean build.zig test suite.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Deliverable changelog and passing zig build test verified in commits 90b5e2c and 3568ba5.",
        "useful": "yes",
        "useful_reason": "Removed 11 obsolete/vacuous test scripts that were giving false confidence."
    },
    "T488": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented JSON parse and required key validation for findings files in tools/dispatch_verify.py with test-first regression.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass matches verified dispatch_verify implementation and passing acceptance command.",
        "absorbed": "yes",
        "absorbed_reason": "Validation active in tools/dispatch_verify.py during task dispatch.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Acceptance test tools/regression-dispatch.sh and dry-run pass in git.",
        "useful": "yes",
        "useful_reason": "Detects malformed findings files at dispatch time before worker begins execution."
    },
    "T326": {
        "work_actually_done": "complete",
        "work_actually_done_reason": "Implemented set_free_handicap, place_free_handicap, and fixed_handicap in src/gtp.zig with regression test; confirmed 88/88 gtp tests pass.",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded pass-with-findings accurately reflects implementation completion and recorded lookup-miss findings.",
        "absorbed": "yes",
        "absorbed_reason": "GTP handicap commands committed to src/gtp.zig and active in oracle GTP interface.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "88/88 GTP unit tests and regression tests pass in git.",
        "useful": "yes",
        "useful_reason": "Enabled GUI tools like Sabaki to configure and play handicap games against oracle."
    },
    "T361": {
        "work_actually_done": "none",
        "work_actually_done_reason": "Console died before starting match runs; no match data or kifus produced (superseded by T509).",
        "verdict_accurate": "yes",
        "verdict_accurate_reason": "Recorded abandoned accurately reflects console exit with zero work done.",
        "absorbed": "no",
        "absorbed_reason": "No match deliverables produced; successor task T509 registered to perform work.",
        "self_reported_or_verified": "verified",
        "self_reported_or_verified_reason": "Absence of evidence doc and successor registration in T509 verified in git.",
        "useful": "no",
        "useful_reason": "Produced no data and required successor re-registration."
    }
}

def get_git_files():
    res = subprocess.run(["git", "ls-files"], capture_output=True, text=True)
    return set(res.stdout.splitlines())

def get_commits_for_file(filepath):
    if not filepath:
        return []
    res = subprocess.run(["git", "log", "--format=%h", "-n", "10", "--", filepath], capture_output=True, text=True)
    shas = [line.strip() for line in res.stdout.splitlines() if line.strip()]
    return shas

def get_bundle_content(tid, t):
    bp = t.get("bundle")
    if bp and os.path.exists(bp):
        try:
            return open(bp, "r", encoding="utf-8", errors="replace").read()
        except Exception:
            pass
    matches = glob.glob(f"untracked/*{tid}*.md") + glob.glob(f"docs/**/*{tid}*.md", recursive=True)
    for m in matches:
        try:
            return open(m, "r", encoding="utf-8", errors="replace").read()
        except Exception:
            pass
    return ""

def extract_declared_deliverables(bundle_content):
    if not bundle_content:
        return []
    delivs = []
    m = re.search(r"deliverables=([^\s>\-]+)", bundle_content)
    if m:
        for d in m.group(1).split(","):
            d = d.strip()
            if d:
                delivs.append(d)
        return delivs
    
    m2 = re.search(r"## Deliverables\s*\n(.*?)(?=\n## |\Z)", bundle_content, re.DOTALL)
    if m2:
        lines = m2.group(1).strip().split("\n")
        for l in lines:
            l = l.strip()
            if l.startswith("- `") or l.startswith("* `"):
                parts = l.split("`")
                if len(parts) >= 2 and parts[1].strip():
                    delivs.append(parts[1].strip())
            elif l.startswith("- ") or l.startswith("* "):
                words = l[2:].strip().split()
                if words:
                    cand = words[0].strip("`:,")
                    if "/" in cand or cand.endswith((".json", ".md", ".zig", ".sh", ".wzo", ".py", ".csv")):
                        delivs.append(cand)
    return delivs

def extract_acceptance(bundle_content, t):
    acc = t.get("acceptance")
    if acc:
        return acc
    if not bundle_content:
        return None
    m = re.search(r"acceptance=([^\n>\-]+)", bundle_content)
    if m:
        val = m.group(1).strip().strip('"\'')
        if " " in val and any(val.startswith(p) for p in ["sh ", "zig ", "test ", "python", "bin/"]):
            parts = val.split()
            cmd_parts = []
            for p in parts:
                if any(p.startswith(k) for k in ["set=", "type=", "needs=", "deliverables=", "holds="]):
                    break
                cmd_parts.append(p)
            return " ".join(cmd_parts)
        return val
    return None

def find_primary_findings(tid):
    files = glob.glob(f"findings/{tid}*.json")
    if not files:
        return None, None
    non_ctx = [f for f in files if "-context" not in f]
    chosen = non_ctx[0] if non_ctx else files[0]
    try:
        sz = os.path.getsize(chosen)
        return chosen, sz
    except Exception:
        return chosen, None

def find_run_record(tid):
    candidates = glob.glob(f"untracked/runs/{tid}.json")
    if not candidates:
        candidates = glob.glob(f"untracked/runs/{tid}.*.json")
    if not candidates:
        candidates = glob.glob(f"untracked/runs/*/{tid}*.json")
    if not candidates:
        return None, None
    
    chosen = candidates[0]
    for c in candidates:
        if c == f"untracked/runs/{tid}.json":
            chosen = c
            break
    try:
        data = json.load(open(chosen))
        return chosen, data
    except Exception:
        return chosen, None

def collect_record(tid, tasks_json, git_files):
    t = tasks_json.get(tid, {})
    bundle_content = get_bundle_content(tid, t)
    
    model = t.get("model") or t.get("agent")
    if model in ("unattributed", "unknown", "None", ""):
        model = None
    elif model == "ox-alpha":
        model = "oxalpha"
    verdict = t.get("verdict") or "unknown"
    
    declared_delivs = extract_declared_deliverables(bundle_content)
    
    present_delivs = []
    for d in declared_delivs:
        if d in git_files or os.path.exists(d):
            present_delivs.append(d)
            
    findings_file, findings_bytes = find_primary_findings(tid)
    findings_exists = findings_file is not None
    
    acceptance = extract_acceptance(bundle_content, t)
    
    run_file, run_data = find_run_record(tid)
    run_exists = run_data is not None
    
    wall = None
    exit_code = None
    killed = False
    tokens_out = None
    
    if run_data:
        wall = run_data.get("wall") or run_data.get("wall_s") or run_data.get("elapsed_s")
        if wall is not None:
            wall = float(wall)
        if "exit" in run_data:
            exit_code = run_data.get("exit")
        elif "returncode" in run_data:
            exit_code = run_data.get("returncode")
        
        k_val = run_data.get("killed")
        if k_val:
            killed = True
        elif exit_code in (-9, 137):
            killed = True
            
        tok = run_data.get("tokens_out") or run_data.get("completion_tokens")
        if tok is not None:
            tokens_out = int(tok)
            
    # attempts count
    attempts_field = t.get("attempts")
    if isinstance(attempts_field, list):
        attempts = max(1, len(attempts_field))
    elif isinstance(attempts_field, int):
        attempts = attempts_field
    elif t.get("claim_count") is not None:
        attempts = int(t.get("claim_count"))
    else:
        run_files = glob.glob(f"untracked/runs/{tid}*.json") + glob.glob(f"untracked/runs/*/{tid}*.json")
        attempts = max(1, len(run_files)) if run_files else 1
        
    # Commits touching deliverables
    commits = set()
    for d in (present_delivs if present_delivs else declared_delivs):
        for c in get_commits_for_file(d):
            commits.add(c)
    if findings_file:
        for c in get_commits_for_file(findings_file):
            commits.add(c)
            
    j = JUDGEMENTS.get(tid, {})
    
    return {
        "task_id": tid,
        "model": model,
        "verdict": verdict,
        "wall": wall,
        "deliverables_declared": declared_delivs,
        "deliverables_present_in_git": present_delivs,
        "findings_file_exists": findings_exists,
        "findings_file_bytes": findings_bytes,
        "acceptance_declared": acceptance,
        "run_record_exists": run_exists,
        "run_record_exit": exit_code,
        "attempts": attempts,
        "killed": killed,
        "tokens_out": tokens_out,
        "commit_shas_touching_deliverables": sorted(list(commits)),
        "work_actually_done": j.get("work_actually_done"),
        "work_actually_done_reason": j.get("work_actually_done_reason"),
        "verdict_accurate": j.get("verdict_accurate"),
        "verdict_accurate_reason": j.get("verdict_accurate_reason"),
        "absorbed": j.get("absorbed"),
        "absorbed_reason": j.get("absorbed_reason"),
        "self_reported_or_verified": j.get("self_reported_or_verified"),
        "self_reported_or_verified_reason": j.get("self_reported_or_verified_reason"),
        "useful": j.get("useful"),
        "useful_reason": j.get("useful_reason")
    }

if __name__ == "__main__":
    tasks_json = json.load(open(TASKS_JSON_PATH))
    git_files = get_git_files()
    
    records = []
    for tid in ALL_TASKS:
        rec = collect_record(tid, tasks_json, git_files)
        records.append(rec)
        
    out_path = "docs/audits/done-audit-2026-08-25/gemini/records.json"
    with open(out_path, "w") as f:
        json.dump(records, f, indent=2)
    print(f"Generated {len(records)} records at {out_path}")
