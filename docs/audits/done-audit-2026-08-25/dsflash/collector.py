#!/usr/bin/env python3
"""T947 DONE-audit dsflash arm — mechanical-field collector.

Gathers the machine-collectible fields of the corpus schema for the 24 rows
(12 disjoint + 12 control) from:
  - docs/infra/managent/tasks.json          (verdict, model, attempts, acceptance)
  - untracked/runs/T<id>*.json              (wall, exit, killed, tokens_out)
  - untracked/T<id>-*.md bundles            (deliverables=, acceptance=)
  - findings/                               (exists, bytes)
  - git                                     (deliverable presence at HEAD, touching SHAs)

Writes collector-output.json to this directory. The thinking half is done by
hand afterwards and merged into records.json.
"""
import json, os, re, subprocess, sys, glob

ROOT = "/Users/alex/Project/Zig/weizigo"
TASKS = json.load(open(os.path.join(ROOT, "docs/infra/managent/tasks.json")))
SLICES = json.load(open(os.path.join(ROOT, "docs/audits/done-audit-2026-08-25/slices.json")))
ROWS = SLICES["dsflash"] + SLICES["control"]

def git(args):
    r = subprocess.run(["git", "-C", ROOT] + args, capture_output=True, text=True)
    return r.stdout.strip()

def find_bundle(task_id):
    pat = os.path.join(ROOT, "untracked", task_id + "-*.md")
    hits = sorted(glob.glob(pat))
    return hits[0] if hits else None

def bundle_meta(bundle_path):
    """Extract deliverables= and acceptance= from the <!--managent ...--> header line."""
    deliv, acc = [], None
    if not bundle_path:
        return deliv, acc
    with open(bundle_path, encoding="utf-8", errors="replace") as f:
        first = f.readline()
    # header is <!--managent ... deliverables=a,b acceptance=...--> — value runs to
    # the next key= or the comment close.
    def kv(s):
        out = {}
        for m in re.finditer(r"(\w+)=([^\s]+)", s):
            out[m.group(1)] = m.group(2)
        for k, v in list(out.items()):
            out[k] = v[:-3] if v.endswith("-->") else v
        return out
    d = kv(first)
    if "deliverables" in d:
        deliv = [x for x in d["deliverables"].split(",") if x]
    if "acceptance" in d:
        acc = d["acceptance"]
    return deliv, acc

def run_records(task_id):
    """All run records untracked/runs/T<id>*.json (numeric suffixes)."""
    recs = []
    for p in sorted(glob.glob(os.path.join(ROOT, "untracked/runs", task_id + "*.json"))):
        base = os.path.basename(p)
        # exclude e.g. T907.1.json? no — those ARE attempts of T907. Keep all.
        try:
            recs.append(json.load(open(p)))
        except Exception:
            pass
    return recs

def findings_files(task_id):
    return sorted(glob.glob(os.path.join(ROOT, "findings", task_id + "-*.json")))

def in_git(path):
    r = subprocess.run(["git", "-C", ROOT, "cat-file", "-e", "HEAD:" + path],
                       capture_output=True)
    return r.returncode == 0

def touching_shas(paths):
    shas = []
    for p in paths:
        out = git(["log", "--format=%H", "--", p])
        shas += out.splitlines()
    return sorted(set(shas))

out = {}
for tid in ROWS:
    t = TASKS.get(tid, {})
    bundle = find_bundle(tid)
    deliv, acc_b = bundle_meta(bundle)
    acc_t = t.get("acceptance")
    recs = run_records(tid)
    ff = findings_files(tid)
    attempts = t.get("attempts") or []

    # wall / exit / killed / tokens from the union of tasks.json attempts and run records
    walls, exits, killed_flags, tokens = [], [], [], []
    for a in attempts:
        if a.get("wall") is not None:
            walls.append(a["wall"])
        if a.get("exit") is not None:
            exits.append(a["exit"])
        kb = a.get("killed_by")
        if kb and kb not in ("none", None):
            killed_flags.append(kb)
        elif a.get("killed"):
            killed_flags.append(str(a.get("killed")))
    for r in recs:
        if r.get("wall") is not None:
            walls.append(r["wall"])
        if r.get("exit") is not None:
            exits.append(r["exit"])
        kb = r.get("killed_by")
        if kb and kb not in ("none", None):
            killed_flags.append(kb)
        elif r.get("killed"):
            killed_flags.append(str(r.get("killed")))
        if r.get("tokens_out") is not None:
            tokens.append(r["tokens_out"])

    present = [d for d in deliv if in_git(d)]
    out[tid] = {
        "task_id": tid,
        "title": t.get("title"),
        "model": t.get("model"),
        "verdict": t.get("verdict"),
        "verdict_note": t.get("verdict_note"),
        "done": t.get("done"),
        "added": t.get("added"),
        "claimed": t.get("claimed"),
        "acceptance_declared": acc_t or acc_b,
        "bundle": os.path.basename(bundle) if bundle else None,
        "deliverables_declared": deliv,
        "deliverables_present_in_git": present,
        "findings_file_exists": len(ff) > 0,
        "findings_files": [os.path.basename(x) for x in ff],
        "findings_file_bytes": os.path.getsize(ff[0]) if ff else None,
        "run_record_exists": len(recs) > 0,
        "run_record_files": [os.path.basename(r.get("_p", "")) for r in recs]
                            if False else sorted(os.path.basename(p) for p in
                                glob.glob(os.path.join(ROOT, "untracked/runs", tid + "*.json"))),
        "wall": max(walls) if walls else None,
        "wall_all": walls,
        "run_record_exit": exits[-1] if exits else None,
        "attempts": len(attempts),
        "killed": len(killed_flags) > 0,
        "killed_by": killed_flags,
        "tokens_out": sum(tokens) if tokens else None,
        "commit_shas_touching_deliverables": touching_shas(deliv),
        "task_type": t.get("task_type"),
        "set": t.get("set"),
        "needs": t.get("needs"),
    }

with open(os.path.join(ROOT, "docs/audits/done-audit-2026-08-25/dsflash/collector-output.json"), "w") as f:
    json.dump(out, f, indent=1)
print("wrote collector-output.json for", len(out), "rows")
for tid in ROWS:
    o = out[tid]
    print(f"{tid} model={o['model']} verdict={o['verdict']} wall={o['wall']} exit={o['run_record_exit']} "
          f"killed={o['killed']} attempts={o['attempts']} findings={o['findings_file_exists']} "
          f"deliv_in_git={o['deliverables_present_in_git']} tok={o['tokens_out']}")
