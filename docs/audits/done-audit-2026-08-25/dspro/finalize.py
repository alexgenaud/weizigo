#!/usr/bin/env python3
"""Merge collector mechanical fields with hand judgments -> records.json."""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
mech = {r["task_id"]: r for r in json.load(open(os.path.join(HERE, "mechanical.json")))}
judg = json.load(open(os.path.join(HERE, "judgments.json")))

ORDER = ["T900","T685","T804","T810","T580","T779","T564","T396","T426","T903","T901","T330",
         "T932","T927","T894","T924","T921","T943","T842","T841","T907","T387","T929","T421"]

out = []
for tid in ORDER:
    m = mech[tid]
    j = judg[tid]
    rec = {
        "task_id": tid,
        "model": m["model"],
        "verdict": m["verdict"],
        "wall": m["wall"],
        "deliverables_declared": m["deliverables_declared"],
        "deliverables_present_in_git": m["deliverables_present_in_git"],
        "findings_file_exists": m["findings_file_exists"],
        "findings_file_bytes": m["findings_file_bytes"],
        "acceptance_declared": m["acceptance_declared"],
        "run_record_exists": m["run_record_exists"],
        "run_record_exit": m["run_record_exit"],
        "attempts": m["attempts"],
        "killed": m["killed"],
        "tokens_out": m["tokens_out"],
        "commit_shas_touching_deliverables": m["commit_shas_touching_deliverables"],
        "work_actually_done": j["work_actually_done"],
        "work_actually_done_reason": j["work_actually_done_reason"],
        "verdict_accurate": j["verdict_accurate"],
        "verdict_accurate_reason": j["verdict_accurate_reason"],
        "absorbed": j["absorbed"],
        "absorbed_reason": j["absorbed_reason"],
        "self_reported_or_verified": j["self_reported_or_verified"],
        "self_reported_or_verified_reason": j["self_reported_or_verified_reason"],
        "useful": j["useful"],
        "useful_reason": j["useful_reason"],
    }
    # carry anomalies alongside, non-schema
    if m.get("agent") and m["agent"] != m["model"]:
        rec["agent_recorded"] = m["agent"]
    out.append(rec)

with open(os.path.join(HERE, "records.json"), "w") as f:
    json.dump(out, f, indent=2)
    f.write("\n")
print(f"wrote {len(out)} records")
