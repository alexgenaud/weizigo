#!/usr/bin/env python3
"""T817 — shared data loading for the retro task corpus.

Reads the kanban store + archive.  Defaults to the LIVE store (the corpus
deliverable itself is a point-in-time artifact built from a snapshot); pass
T817_SNAPSHOT_DIR=/path/to/snapshot to reproduce the committed corpus
exactly (SHAs in docs/infra/task-corpus.md §0).
"""
import json, os, re, glob

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
SNAPSHOT = os.environ.get("T817_SNAPSHOT_DIR")


def store_paths():
    if SNAPSHOT:
        return f"{SNAPSHOT}/tasks.json", f"{SNAPSHOT}/archive.json"
    return f"{ROOT}/docs/infra/managent/tasks.json", f"{ROOT}/docs/infra/managent/archive.json"


def load_store():
    tpath, apath = store_paths()
    store = json.load(open(tpath))
    arch = json.load(open(apath))
    tasks = {}
    for k, v in arch.items():
        if k != "_sys":
            tasks[k] = v
    for k, v in store.items():
        if k != "_sys":
            tasks[k] = v
    return tasks


def load_runs():
    """task -> list of run dicts (recursive over untracked/runs/)."""
    runs = {}
    for f in glob.glob(f"{ROOT}/untracked/runs/**/*.json", recursive=True):
        base = os.path.basename(f)
        if base.startswith("archive-"):
            continue
        try:
            d = json.load(open(f))
        except Exception:
            continue
        if not isinstance(d, dict):
            continue
        t = d.get("task")
        if not t:
            continue
        runs.setdefault(t, []).append(d)
    return runs


def load_tokens():
    rows = [json.loads(l) for l in open(f"{ROOT}/untracked/tokens/tokens.jsonl") if l.strip()]
    by_task = {}
    for r in rows:
        t = r.get("task")
        if t:
            by_task.setdefault(t, []).append(r)
    return by_task


def load_findings_index():
    idx = {}
    for f in glob.glob(f"{ROOT}/findings/*.json"):
        base = os.path.basename(f)
        m = re.match(r"(T\d+)", base)
        if m:
            idx.setdefault(m.group(1), []).append(base)
    return idx


def load_briefs():
    briefs = {}
    for f in glob.glob(f"{ROOT}/untracked/T*.md"):
        base = os.path.basename(f)
        m = re.match(r"(T\d+)", base)
        if not m:
            continue
        tid = m.group(1)
        try:
            text = open(f, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        rec = {
            "brief_path": f, "brief_bytes": len(text.encode("utf-8")),
            "header": "", "title": "", "landmark": "", "gate": "",
            "deliverables": [], "holds": [],
        }
        h = re.search(r"<!--managent[^>]*-->", text)
        if h:
            rec["header"] = h.group(0)
            dm = re.search(r"deliverables=([^\s>]+)", h.group(0))
            if dm:
                rec["deliverables"] = [p for p in dm.group(1).split(",") if p]
            hm = re.search(r"holds=([^\s>]+)", h.group(0))
            if hm:
                rec["holds"] = [p for p in hm.group(1).split(",") if p]
        tm = re.search(r"^#\s+(.+)$", text, re.M)
        if tm:
            rec["title"] = tm.group(1).strip()
        lm = re.search(r"\*\*Landmark:\*\*\s*(.+)", text)
        if lm:
            rec["landmark"] = lm.group(1).strip()
        gm = re.search(r"\*\*gate:\*\*|gate=\s*([^\s]+)", text)
        if gm:
            rec["gate"] = gm.group(1).strip() if gm.lastindex else "declared"
        briefs[tid] = rec
    return briefs


def agg_runs(runs_by_task, tid):
    rs = runs_by_task.get(tid, [])
    if not rs:
        return {"n_runs": 0, "wall_s": None, "cpu_s": None, "rss_mb": None,
                "exit_nonzero": 0, "killed": 0}
    walls = [r.get("wall") for r in rs if isinstance(r.get("wall"), (int, float))]
    cpus = [r.get("cpu") for r in rs if isinstance(r.get("cpu"), (int, float))]
    rss = [r.get("rss_mb") for r in rs if isinstance(r.get("rss_mb"), (int, float))]
    return {
        "n_runs": len(rs),
        "wall_s": round(sum(walls), 1) if walls else None,
        "cpu_s": round(sum(cpus), 1) if cpus else None,
        "rss_mb": int(max(rss)) if rss else None,
        "exit_nonzero": sum(1 for r in rs if r.get("exit") not in (0, None)),
        "killed": sum(1 for r in rs if r.get("exit") == 124),
    }


def agg_tokens(tok_by_task, tid):
    rows = tok_by_task.get(tid, [])
    if not rows:
        return {"n_rows": 0, "tokens_in": None, "tokens_out": None}
    tin = sum(r.get("tokens_in") or 0 for r in rows if isinstance(r.get("tokens_in"), int))
    tout = sum(r.get("tokens_out") or 0 for r in rows if isinstance(r.get("tokens_out"), int))
    return {"n_rows": len(rows), "tokens_in": tin, "tokens_out": tout}
