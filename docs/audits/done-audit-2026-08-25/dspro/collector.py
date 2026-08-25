#!/usr/bin/env python3
"""T946 dspro DONE-audit mechanical-field collector.

Collects the machine-checkable fields for one auditor arm's 24 rows from:
  - docs/infra/managent/tasks.json   (task store: model, verdict, acceptance, bundle)
  - untracked/runs/<task>*.json       (run records: wall, exit, tokens_out, killed)
  - findings/<task>-*.json            (findings file presence + bytes)
  - git (deliverables present, commits touching them)
  - the bundle file's managent metadata header (deliverables=, acceptance=)

Outputs a JSON array of per-row mechanical dicts keyed by task_id.
Judgement fields are NOT produced here — they are added by hand afterwards.

Author: deepseek-v4-pro/T946 (DONE-audit dspro arm).
"""
import json, glob, os, re, subprocess, sys

REPO = os.path.dirname(os.path.abspath(__file__))
while not os.path.exists(os.path.join(REPO, "docs/infra/managent/tasks.json")):
    REPO = os.path.dirname(REPO)

TASKS_PATH = os.path.join(REPO, "docs/infra/managent/tasks.json")
RUNS = os.path.join(REPO, "untracked/runs")
FINDINGS = os.path.join(REPO, "findings")

DISJOINT = ["T900","T685","T804","T810","T580","T779","T564","T396","T426","T903","T901","T330"]
CONTROL = ["T932","T927","T894","T924","T921","T943","T842","T841","T907","T387","T929","T421"]
TASKS = DISJOINT + CONTROL


def git(args):
    return subprocess.run(["git", "-C", REPO] + args, capture_output=True, text=True).stdout


def parse_managent_meta(text):
    """Extract key=value pairs from the <!--managent ...--> header line."""
    m = re.search(r"<!--managent(.*?)-->", text, re.S)
    if not m:
        return {}
    body = m.group(1).strip()
    meta = {}
    for key, val in re.findall(r"(\w+)=(\S+)", body):
        # deliverables / holds / needs are comma lists; keep raw for now
        meta.setdefault(key, val)
    return meta


def split_list(s):
    if not s:
        return []
    return [x for x in s.split(",") if x.strip()]


def find_bundle(task, bundle_field):
    """Return the bundle file path for a task, tolerating empty/abs path."""
    if bundle_field and os.path.exists(bundle_field):
        return bundle_field
    if bundle_field and os.path.exists(os.path.join(REPO, bundle_field)):
        return os.path.join(REPO, bundle_field)
    # fall back to pattern match in untracked/
    pats = glob.glob(os.path.join(REPO, "untracked", f"{task}-*.md"))
    pats = [p for p in pats if not p.endswith(".done.md")]
    if pats:
        return sorted(pats)[0]
    return None


def collect_deliverables_from_bundle(bundle_path, meta):
    """Deliverables = union of metadata deliverables= and the ## Deliverables section."""
    d = set(split_list(meta.get("deliverables", "")))
    if bundle_path and os.path.exists(bundle_path):
        text = open(bundle_path, encoding="utf-8", errors="replace").read()
        sec = re.search(r"## Deliverables?\s*\n(.*?)(?=\n## |\Z)", text, re.S)
        if sec:
            for line in sec.group(1).splitlines():
                line = line.strip()
                m = re.match(r"^[-*]\s+`?([^`\s]+)`?", line)
                if m:
                    d.add(m.group(1))
                elif line.startswith("- "):
                    d.add(line[2:].strip().strip("`"))
    return sorted(d)


def run_records(task):
    recs = []
    for f in sorted(glob.glob(os.path.join(RUNS, f"{task}*.json"))):
        # skip archive/ subdirs handled by glob anyway (they are under runs/archive-...)
        if "/archive" in f:
            continue
        try:
            r = json.load(open(f))
            if r.get("task") == task or f.split("/")[-1].startswith(task):
                recs.append((f, r))
        except Exception:
            pass
    return recs


def killed_flag(rec):
    """True if the run was terminated by watchdog/SIGKILL — infer from exit code / reap."""
    exit_code = rec.get("exit")
    if exit_code is None:
        return None  # unknown
    # 137 = SIGKILL, 143 = SIGTERM, 124 = timeout
    if exit_code in (124, 137, 143):
        return True
    return False


def primary_run(task):
    """Pick the run record with a real wall time (the substantive run)."""
    recs = run_records(task)
    if not recs:
        return None, 0
    best = None
    for f, r in recs:
        if r.get("wall") is not None:
            if best is None or r.get("wall", 0) > best.get("wall", 0):
                best = r
    if best is None:
        best = recs[-1][1]
    return best, len(recs)


def commit_shas_for(paths):
    shas = set()
    for p in paths:
        rel = os.path.relpath(p, REPO) if os.path.isabs(p) else p
        out = git(["log", "--format=%H", "--", rel])
        for line in out.splitlines():
            if line.strip():
                shas.add(line.strip())
    return sorted(shas)


def main():
    tasks = json.load(open(TASKS_PATH))
    out = []
    for tid in TASKS:
        t = tasks.get(tid)
        if t is None:
            out.append({"task_id": tid, "error": "missing from tasks.json"})
            continue
        bundle_path = find_bundle(tid, t.get("bundle") or "")
        meta = {}
        if bundle_path:
            meta = parse_managent_meta(open(bundle_path, encoding="utf-8", errors="replace").read())
        declared = collect_deliverables_from_bundle(bundle_path, meta)
        # also honour acceptance= in metadata (may differ from tasks.json)
        acceptance = t.get("acceptance") or meta.get("acceptance") or None

        rec, nattempts = primary_run(tid)
        findings_files = sorted(glob.glob(os.path.join(FINDINGS, f"{tid}-*.json")))
        findings_bytes = None
        findings_exists = False
        if findings_files:
            findings_exists = True
            # prefer the primary (non -context) findings file
            primaries = [f for f in findings_files if "-context" not in f and "-notes" not in f]
            fp = primaries[0] if primaries else findings_files[0]
            findings_bytes = os.path.getsize(fp)

        # deliverables present in git tree at HEAD (git-aware, not working-tree)
        present = []
        for d in declared:
            p = os.path.join(REPO, d)
            rel = os.path.relpath(p, REPO)
            r = subprocess.run(["git", "-C", REPO, "cat-file", "-e", f"HEAD:{rel}"],
                               capture_output=True)
            if r.returncode == 0:
                present.append(d)

        row = {
            "task_id": tid,
            "model": t.get("model"),
            "agent": t.get("agent"),
            "verdict": t.get("verdict"),
            "done": t.get("done"),
            "wall": rec.get("wall") if rec else None,
            "deliverables_declared": declared,
            "deliverables_present_in_git": present,
            "findings_file_exists": findings_exists,
            "findings_file_bytes": findings_bytes,
            "findings_files": [os.path.basename(f) for f in findings_files],
            "acceptance_declared": acceptance,
            "run_record_exists": rec is not None,
            "run_record_exit": rec.get("exit") if rec else None,
            "run_record_wall": rec.get("wall") if rec else None,
            "attempts": nattempts if nattempts else (t.get("attempts") or t.get("claim_count") or 1),
            "killed": killed_flag(rec) if rec else None,
            "tokens_out": rec.get("tokens_out") if rec else None,
            "run_kind": rec.get("run_kind") if rec else None,
            "bundle": os.path.relpath(bundle_path, REPO) if bundle_path else None,
            "commit_shas_touching_deliverables": commit_shas_for([os.path.join(REPO, d) for d in declared]),
        }
        out.append(row)

    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
