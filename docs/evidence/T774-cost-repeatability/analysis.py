#!/usr/bin/env python3
"""T774 — aggregate the per-repeat meters into per-cell spreads.

Reads untracked/bakeoff/t774-cost-repeatability/<cell>/r<N>/run-record.json
for the 4 cells x 5 repeats, computes per-cell mean/sd/CV/min/max/range for
total tokens (in+out), cpu-seconds, and peak rss_mb, applies the T774-control-1
guard (a repeat with no token reading is UNKNOWN for tokens, never 0), and
writes results.csv + the machine-readable summary used by the findings file.

Task: T774 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-23
"""
import csv
import glob
import hashlib
import json
import os
import statistics
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
RUN = os.path.join(ROOT, "untracked", "bakeoff", "t774-cost-repeatability")
CELLS = ["ds-m", "op-m", "ds-a", "op-a"]

rows = []
for cell in CELLS:
    for i in range(1, 6):
        rec_path = os.path.join(RUN, cell, "r%d" % i, "run-record.json")
        d = os.path.join(RUN, cell, "r%d" % i)
        row = {"cell": cell, "r": i, "model": cell.split("-")[0],
               "shape": cell.split("-")[1], "exit": None, "wall": None,
               "cpu": None, "rss_mb": None, "tokens_in": None, "tokens_out": None,
               "tokens_total": None, "tokens_source": None, "fresh": None,
               "cache_read": None, "session_id": None, "out_bytes": None,
               "record": None, "session_sha256": None}
        if os.path.isfile(rec_path):
            with open(rec_path) as f:
                rec = json.load(f)
            row["record"] = rec_path
            row["exit"] = rec.get("exit")
            row["wall"] = rec.get("wall")
            row["cpu"] = rec.get("cpu")
            row["rss_mb"] = rec.get("rss_mb")
            tin = rec.get("tokens_in")
            tout = rec.get("tokens_out")
            src = rec.get("tokens_source")
            row["tokens_source"] = src
            # T774-control-1 guard: no reading (or an all-zero reading from a
            # usage-less session) is UNKNOWN for tokens, never 0.
            if src is not None and tin is not None and tout is not None and (tin + tout) > 0:
                row["tokens_in"] = tin
                row["tokens_out"] = tout
                row["tokens_total"] = tin + tout
                row["fresh"] = rec.get("tokens_fresh")
                row["cache_read"] = rec.get("tokens_cache_read")
                row["session_id"] = rec.get("session_id")
        outp = os.path.join(d, "out.json")
        if os.path.isfile(outp):
            row["out_bytes"] = os.path.getsize(outp)
        sess = os.path.join(d, "session.jsonl")
        if os.path.isfile(sess):
            with open(sess, "rb") as f:
                row["session_sha256"] = hashlib.sha256(f.read()).hexdigest()
        rows.append(row)

with open(os.path.join(ROOT, "docs", "evidence", "T774-cost-repeatability",
                       "results.csv"), "w", newline="") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    for row in rows:
        w.writerow(row)

# ── per-cell spreads ────────────────────────────────────────────────────────
def spread(vals):
    vals = [v for v in vals if v is not None]
    if len(vals) < 2:
        return {"n": len(vals)}
    mean = statistics.mean(vals)
    sd = statistics.stdev(vals)
    return {"n": len(vals), "mean": round(mean, 2), "sd": round(sd, 2),
            "cv": round(sd / mean, 4) if mean else None,
            "min": min(vals), "max": max(vals), "range": round(max(vals) - min(vals), 2),
            "band_lo": round(mean - 2 * sd, 2), "band_hi": round(mean + 2 * sd, 2)}

out = {"cells": {}, "rows": rows}
for cell in CELLS:
    cell_rows = [r for r in rows if r["cell"] == cell]
    out["cells"][cell] = {
        "tokens_total": spread([r["tokens_total"] for r in cell_rows]),
        "tokens_in": spread([r["tokens_in"] for r in cell_rows]),
        "tokens_out": spread([r["tokens_out"] for r in cell_rows]),
        "fresh": spread([r["fresh"] for r in cell_rows]),
        "cache_read": spread([r["cache_read"] for r in cell_rows]),
        "cpu_s": spread([r["cpu"] for r in cell_rows]),
        "rss_mb": spread([r["rss_mb"] for r in cell_rows]),
        "wall_s": spread([r["wall"] for r in cell_rows]),
        "out_bytes": spread([r["out_bytes"] for r in cell_rows]),
        "token_readings": sum(1 for r in cell_rows if r["tokens_total"] is not None),
    }

print(json.dumps(out["cells"], indent=1, sort_keys=True))
with open(os.path.join(ROOT, "docs", "evidence", "T774-cost-repeatability",
                       "analysis-out.json"), "w") as f:
    json.dump(out["cells"], f, indent=1, sort_keys=True)
