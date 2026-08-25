#!/usr/bin/env python3
"""T956 (does the qwencloud DONE-audit slice match the records?) — mechanical collector.

Gathers the machine-collectible fields of the corpus.md §5 schema for the
qwencloud slice (12 control + 12 disjoint rows) from:
  docs/infra/managent/tasks.json   — store row (verdict, model, acceptance, attempts, done)
  untracked/runs/                  — run records (wall, exit, tokens_out, killed)
  findings/                        — findings files (existence, bytes)
  untracked/<bundle>               — brief (deliverables= meta or ## Deliverables section)
  git log -- <deliverable>         — commit SHAs touching each deliverable path

Judgement fields are left as null; the thinking half is filled by hand.
Stdlib only. Run from the repo root:
    python3 docs/audits/done-audit-2026-08-25/qwencloud/collector.py
"""
import json
import os
import re
import subprocess

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))

SLICES = json.load(open(os.path.join(ROOT, "docs/audits/done-audit-2026-08-25/slices.json")))
CONTROL = SLICES["control"]
DISJOINT = SLICES["qwencloud"]

TASKS = json.load(open(os.path.join(ROOT, "docs/infra/managent/tasks.json")))
RUNS_DIR = os.path.join(ROOT, "untracked/runs")
FINDINGS_DIR = os.path.join(ROOT, "findings")

# T317 canonical labels (src/managent/main.zig) — vendored here deliberately:
# the collector must not import Zig.  Non-canonical serving tags map below.
CANON = {
    "claude-opus-5", "claude-sonnet-5", "claude-fable-5", "claude-haiku-4-5-20251001",
    "deepseek-v4-pro", "deepseek-v4-flash", "glm-5.2", "minimax-m3", "kimi-k2.7",
    "qwen3.8:27b-mlx", "oxalpha", "gemini-3.7-flash",
    "gpt-5.6-luna-pro", "qwen3.8-27b", "nemotron-3.5-lightning", "solar-pro4",
}
SERVING_TAG_MAP = {
    "stealth/ox-alpha": "oxalpha",
    "ox-alpha": "oxalpha",
    "qwen3.8-27b:cloud": "qwen3.8-27b",
}


def canonical(model):
    if model is None:
        return None
    m = model.strip()
    if m in CANON:
        return m
    if m in SERVING_TAG_MAP:
        return SERVING_TAG_MAP[m]
    return m  # unknown — report as-is rather than guess


def load_run_records(task_id):
    """All run JSONs for a task: T<id>.json plus T<id>.<n>.json attempts."""
    recs = []
    for name in sorted(os.listdir(RUNS_DIR)):
        if not name.endswith(".json"):
            continue
        stem = name[:-5]
        if not (stem == task_id or re.match(task_id + r"\.\d+$", stem)):
            continue
        try:
            recs.append(json.load(open(os.path.join(RUNS_DIR, name))))
        except Exception:
            recs.append({"_unparseable": name})
    recs.sort(key=lambda r: r.get("attempt") or 0)
    return recs


def parse_deliverables(bundle_path):
    """Declared deliverables from the managent meta line, else the
    ## Deliverables section.  Returns (list, source)."""
    if not bundle_path or not os.path.exists(bundle_path):
        return [], "bundle-missing"
    text = open(bundle_path, errors="replace").read()
    m = re.search(r"deliverables=([^>]+?)-->", text)
    if m:
        raw = m.group(1)
        # the value runs until the next "key=" token (holds=, acceptance=, ...)
        raw = re.split(r"\s+[A-Za-z_]+=", raw)[0]
        return [x.strip() for x in raw.split(",") if x.strip()], "managent-meta"
    m = re.search(r"^##\s*Deliverables\s*$(.*?)(^##\s|\Z)", text, re.M | re.S)
    if m:
        section = m.group(1)
        paths = re.findall(r"[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:md|json|zig|sh|py|txt|csv|wzo)", section)
        seen, out = set(), []
        for p in paths:
            if p not in seen:
                seen.add(p)
                out.append(p)
        return out, "deliverables-section"
    return [], "none-found"


def in_git(rel_path):
    rel_path = rel_path.strip().lstrip("/")
    if not rel_path:
        return False
    r = subprocess.run(["git", "ls-files", "--error-unmatch", rel_path],
                       cwd=ROOT, capture_output=True)
    return r.returncode == 0


def git_shas_touching(rel_path):
    rel_path = rel_path.strip().lstrip("/")
    r = subprocess.run(["git", "log", "--format=%h", "--", rel_path],
                       cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        return []
    return r.stdout.decode().split()


def findings_for(task_id):
    names = [n for n in os.listdir(FINDINGS_DIR)
             if n.startswith(task_id + "-") and n.endswith(".json")]
    if not names:
        return False, None
    primary = sorted(names)[0]
    return True, os.path.getsize(os.path.join(FINDINGS_DIR, primary))


def collect(task_id):
    row = TASKS.get(task_id)
    rec = {
        "task_id": task_id,
        "model": None,
        "verdict": None,
        "wall": None,
        "deliverables_declared": [],
        "deliverables_present_in_git": [],
        "findings_file_exists": False,
        "findings_file_bytes": None,
        "acceptance_declared": None,
        "run_record_exists": False,
        "run_record_exit": None,
        "attempts": 0,
        "killed": False,
        "tokens_out": None,
        "commit_shas_touching_deliverables": [],
        # judgement half — filled by hand:
        "work_actually_done": None,
        "work_actually_done_reason": None,
        "verdict_accurate": None,
        "verdict_accurate_reason": None,
        "absorbed": None,
        "absorbed_reason": None,
        "self_reported_or_verified": None,
        "self_reported_or_verified_reason": None,
        "useful": None,
        "useful_reason": None,
    }
    if not row:
        return rec

    rec["model"] = canonical(row.get("model") or row.get("agent"))
    rec["verdict"] = row.get("verdict")
    rec["acceptance_declared"] = row.get("acceptance")

    attempts = row.get("attempts") or []
    rec["attempts"] = len(attempts)

    runs = load_run_records(task_id)
    if runs:
        rec["run_record_exists"] = True
        # headline attempt = the one with the longest wall (the actual run);
        # tiny follow-up attempts are seat re-closes / re-runs, not the work.
        walls = [r.get("wall") for r in runs if isinstance(r.get("wall"), (int, float))]
        headline = max(runs, key=lambda r: r.get("wall") or 0) if walls else runs[-1]
        rec["run_record_exit"] = headline.get("exit")
        rec["tokens_out"] = headline.get("tokens_out")
        rec["wall"] = max(walls) if walls else None
        rec["run_record_attempts_total"] = len(runs)
        rec["killed"] = any((r.get("killed_by") not in (None, "none"))
                            or (r.get("signal") is not None)
                            or (r.get("killed") not in (None, "none", ""))
                            for r in runs)

    bundle = row.get("bundle") or ""
    if bundle.startswith("/"):
        rel = os.path.relpath(bundle, ROOT)
        bundle = "" if rel.startswith("..") else rel
    dpath = os.path.join(ROOT, bundle) if bundle else None
    declared, dsrc = parse_deliverables(dpath)
    rec["deliverables_declared"] = declared
    for d in declared:
        if in_git(d):
            rec["deliverables_present_in_git"].append(d)
        rec["commit_shas_touching_deliverables"] += git_shas_touching(d)
    rec["commit_shas_touching_deliverables"] = sorted(
        set(rec["commit_shas_touching_deliverables"]))
    rec["deliverables_source"] = dsrc  # extra provenance field, not in schema

    ex, b = findings_for(task_id)
    rec["findings_file_exists"] = ex
    rec["findings_file_bytes"] = b
    return rec


def main():
    rows = [(t, "disjoint") for t in DISJOINT] + [(t, "control") for t in CONTROL]
    out = []
    for tid, kind in rows:
        r = collect(tid)
        r["slice"] = kind
        out.append(r)
    dest = os.path.join(os.path.dirname(__file__), "records.json")
    tmp = dest + ".tmp"
    with open(tmp, "w") as f:
        json.dump(out, f, indent=1)
    os.replace(tmp, dest)
    print("collector: %d rows -> %s" % (len(out), os.path.relpath(dest, ROOT)))


if __name__ == "__main__":
    main()
