#!/usr/bin/env python3
"""DONE-audit mechanical collector for the kimi arm (T948).

Reads tasks.json, the per-task bundle, the run record, and git HEAD to
populate the machine-collectible half of the auditor record schema.
Judgement fields are left empty for hand-scoring.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TASKS_PATH = ROOT / "docs/infra/managent/tasks.json"
RUNS_DIR = ROOT / "untracked/runs"
FINDINGS_DIR = ROOT / "findings"
UNTRACKED_DIR = ROOT / "untracked"

CONTROL = [
    "T932", "T927", "T894", "T924", "T921", "T943",
    "T842", "T841", "T907", "T387", "T929", "T421",
]
DISJOINT = [
    "T627", "T683", "T614", "T440", "T835", "T625",
    "T800", "T732", "T643", "T728", "T516", "T482",
]


def load_json(path):
    with open(path) as f:
        return json.load(f)


def find_bundle(tid, task):
    bundle = task.get("bundle")
    if bundle and Path(bundle).exists():
        return Path(bundle)
    # Fallback for orphan backfills whose bundle field may be empty.
    candidates = list(UNTRACKED_DIR.glob(f"{tid}*.md"))
    if candidates:
        return candidates[0]
    return None


def parse_bundle_comment(path):
    if not path:
        return {}, {}
    with open(path) as f:
        first = f.readline().strip()
    if not (first.startswith("<!--") and first.endswith("-->")):
        return {}, {}
    inner = first[4:-3].strip()
    # Strip a leading "managent " token if present.
    inner = re.sub(r"^managent\s+", "", inner)
    # Split on spaces that separate key=value pairs, but value may contain spaces (rare).
    # We only care about deliverables= and acceptance=; use regex.
    deliverables = re.search(r"deliverables=([^ ]+(?:,[^ ]+)*)", inner)
    acceptance = re.search(r"acceptance=(.+?)(?=\s+\w+=|$)", inner)
    out = {}
    if deliverables:
        out["deliverables"] = [p.strip() for p in deliverables.group(1).split(",") if p.strip()]
    if acceptance:
        out["acceptance"] = acceptance.group(1).strip()
    return out, {}


def git_tree_has(path):
    try:
        result = subprocess.run(
            ["git", "ls-tree", "-r", "HEAD", "--", path],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        return bool(result.stdout.strip())
    except Exception:
        return False


def commits_touching(path):
    try:
        result = subprocess.run(
            ["git", "log", "--format=%H", "--", path],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        return result.stdout.strip().splitlines()
    except Exception:
        return []


def find_findings_file(tid, declared):
    # Prefer a findings path that is explicitly declared and exists.
    for p in declared:
        if p.startswith("findings/") and (ROOT / p).exists():
            return ROOT / p
    # Otherwise, any findings/TID-*.json file.
    candidates = sorted(FINDINGS_DIR.glob(f"{tid}-*.json"))
    if candidates:
        return candidates[0]
    return None


def collect_task(tid, task):
    record = {"task_id": tid}
    record["model"] = task.get("model")
    record["verdict"] = task.get("verdict")

    bundle_path = find_bundle(tid, task)
    comment, _ = parse_bundle_comment(bundle_path)

    declared = comment.get("deliverables", [])
    record["deliverables_declared"] = declared

    acc = task.get("acceptance") or comment.get("acceptance")
    record["acceptance_declared"] = acc

    # Attempt data: prefer the first entry in tasks.json attempts (the real
    # dispatched run), falling back to the per-task run record file.
    task_attempts = task.get("attempts")
    first_attempt = None
    if isinstance(task_attempts, list) and task_attempts:
        first_attempt = task_attempts[0]

    run_path = RUNS_DIR / f"{tid}.json"
    run = {}
    if run_path.exists():
        try:
            run = load_json(run_path)
            record["run_record_exists"] = True
        except Exception:
            record["run_record_exists"] = bool(first_attempt)
    else:
        record["run_record_exists"] = bool(first_attempt)

    def pick(field):
        if first_attempt and field in first_attempt and first_attempt[field] is not None:
            return first_attempt[field]
        return run.get(field) if run else None

    record["wall"] = pick("wall")
    record["run_record_exit"] = pick("exit")
    record["tokens_out"] = pick("tokens_out")

    # attempts count
    if isinstance(task_attempts, list) and task_attempts:
        record["attempts"] = len(task_attempts)
    elif run:
        record["attempts"] = run.get("attempt", 1)
    else:
        record["attempts"] = 1

    # killed: a dispatch without a recorded exit is treated as killed mid-flight
    def is_killed(attempt):
        if attempt.get("killed") is True:
            return True
        kb = attempt.get("killed_by")
        if kb and str(kb).lower() != "none":
            return True
        if attempt.get("exit") is None:
            return True
        return False

    record["killed"] = bool(first_attempt and is_killed(first_attempt)) or bool(
        (not first_attempt) and run and (run.get("killed") is True or
         (run.get("killed_by") and str(run.get("killed_by")).lower() != "none"))
    )

    # findings file
    findings_file = find_findings_file(tid, declared)
    record["findings_file_exists"] = findings_file is not None
    record["findings_file_bytes"] = findings_file.stat().st_size if findings_file else None

    # deliverables in git
    present = [p for p in declared if git_tree_has(p)]
    record["deliverables_present_in_git"] = present

    # commits touching deliverables
    shas = []
    for p in declared:
        shas.extend(commits_touching(p))
    record["commit_shas_touching_deliverables"] = sorted(set(shas))

    return record


def main():
    tasks = load_json(TASKS_PATH)
    records = []
    for tid in CONTROL + DISJOINT:
        task = tasks.get(tid, {})
        records.append(collect_task(tid, task))
    out = {"records": records}
    out_path = Path(__file__).with_suffix(".json")
    with open(out_path, "w") as f:
        json.dump(out, f, indent=2)
        f.write("\n")
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
