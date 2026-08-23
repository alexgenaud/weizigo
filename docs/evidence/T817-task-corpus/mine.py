#!/usr/bin/env python3
"""T817 — build docs/infra/task-corpus.jsonl.

Usage: python3 mine.py            # live store (current corpus)
       T817_SNAPSHOT_DIR=/path python3 mine.py   # reproduce the committed corpus
Output: docs/infra/task-corpus.jsonl (one JSON row per task).
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib as L
import classify as C

ENGINE_FILES = ("src/retro.zig", "src/oracle.zig", "src/rules.zig", "src/solve.zig")

# capability demand-phrase sets (precision-tuned; see task-corpus.md §4)
CAPS = {
 'long-document-coherence': [
    "read the entire", "read the whole", "the whole file", "the entire file",
    "long document", "large document", "token budget", "context window",
    "100k", "60k", "40k token", "whole corpus", "entire corpus",
    "reads the whole", "read everything", "from start to finish",
 ],
 'citation-verification': [
    "citation", "cite the", "cites", "references resolve", "resolve the reference",
    "volatile citation", "verify the citation", "citation check", "citation audit",
    "fabricated citation", "dead link", "missing path", "every citation",
    "each citation", "cite only", "claimlint c10", "c10",
 ],
 'census-counting': [
    "census", "count every", "count all", "enumerate", "inventory", "survey",
    "every row", "every file", "every task", "all 4", "all rows", "list all",
    "catalogue", "catalog", "tally", "state the denominator", "count of",
    "how many", "unique", "distinct", "number of tasks", "across files",
 ],
 'code-writing': [
    "implement", "write the code", "fix the bug", "repair", "write a function",
    "write the function", "edit src/", "change src/", "modify src/",
    "make the change", "code change", "the implementation", "implement this",
    "write the", "fix it", "fix the",
 ],
 'test-authoring': [
    "write a test", "write tests", "write the test", "test first", "red first",
    "regression test", "regression arm", "known-good", "known-bad", "fixture",
    "seeded defect", "control arm", "null control", "assert that", "assertion",
    "failing test", "test the fix", "test-driven", "tdd", "test before",
    "shown red then green", "red then green",
 ],
 'adversarial-refutation': [
    "refute", "refutation", "falsif", "adversary", "adversarial", "counterexample",
    "disprov", "disprove", "attempt to break", "attack", "sceptic", "skeptic",
    "critical review", "scrutiny", "try to prove wrong", "find the flaw",
    "prove it wrong", "would prove", "the sentence that decided",
    "challenge", "challeng", "sceptical",
 ],
 'arithmetic-over-corpus': [
    "compute", "arithmetic", "percentage", "percent", "rate of", "statistics",
    "stats", "aggregate", "average", "median", "fraction", "ratio",
    "sum of", "sum the", "share of", "proportion", "distribution of",
    "histogram", "outlier", "denominator", "numerator",
 ],
 'long-horizon-execution': [
    "long run", "overnight", "persistent session", "heartbeat", "never restart",
    "watch it", "monitor", "multi-hour", "all night", "5-hour", "hours of",
    "258 mb", "19 sweeps", "don't restart", "do not restart",
 ],
 'discrimination-saying-no': [
    "say no", "refuse", "stop and report", "out of scope", "escalate",
    "do not guess", "don't guess", "do not implement", "don't implement",
    "do not fabricate", "do not invent", "do not make up", "do not touch",
    "do not edit", "do not fix", "do not modify", "if you cannot",
    "if it cannot", "stop and", "report it", "do not know",
 ],
}


def clean_ds(ds):
    out = []
    for d in ds:
        if d.endswith("--"):
            d = d[:-2]
        if d:
            out.append(d)
    return out


def scope_class(tid, task, b, brief_type, n_findings):
    """S07 S1-S5 (adopted from the lattice spec §LAT-DIM-5) with the two
    data-driven amendments documented in task-corpus.md §3."""
    if b is None:
        return "S-unknown", "no brief on disk", "low"
    ds = clean_ds(b["deliverables"])
    holds = [h[:-2] if h.endswith("--") else h for h in b["holds"]]
    slug_title = ((task.get("bundle") or "").rsplit("/", 1)[-1] + " " + b["title"]).lower()
    if brief_type == "orchestration" and any(w in slug_title for w in
            ["console", "seat", "orcha", "triage", "inbox", "crash-recovery",
             "landmark", "dispatch-authoring", "sprint-console"]):
        return "S5", "orchestration type + console/seat/triage slug/title", "medium"
    code = [d for d in ds if d.startswith(("src/", "tools/", "bin/", "tests/")) or d.startswith("build.zig")]
    srcw = [d for d in ds if d.startswith("src/")]
    engine_holds = [h for h in holds if h in ENGINE_FILES or h.startswith("src/")]
    test_arm = any(d.startswith(("tools/", "tests/")) for d in ds)
    w = len(code)
    if ds and w == 0 and len(ds) != 1:
        return "S4", f"deliverables all findings/docs ({len(ds)} files)", "high"
    if ds and w == 0 and len(ds) == 1 and ds[0].startswith("findings/"):
        return "S4", f"single findings output ({ds[0]})", "high"
    if len(srcw) >= 2 or len(set(engine_holds)) > 1 or w >= 3:
        return "S3", f"{len(srcw)} src/ + {w} code writes, {len(set(engine_holds))} engine holds", "high"
    if w >= 1 and (len(srcw) == 1 or test_arm or w <= 2):
        return "S2", f"{w} code write(s) ({srcw or code[0]})", "high"
    if len(ds) == 1:
        return "S1", f"single non-code write ({ds[0]})", "medium"
    if not ds:
        if n_findings > 0:
            return "S4", f"no declared deliverables; {n_findings} findings files on disk", "low"
        if holds:
            return "S3", "holds declared, deliverables not", "low"
        return "S-unknown", "no deliverables, no holds, no findings", "low"
    return "S-unknown", "deliverable mix not matching S1-S5", "low"


def capabilities_for(b, wall_s):
    if b is None:
        return []
    text = open(b["brief_path"], encoding="utf-8", errors="replace").read().lower()
    caps = []
    for name, kws in CAPS.items():
        hits = [kw for kw in kws if kw in text]
        if hits:
            conf = "medium" if len(hits) >= 3 else "low"
            caps.append({"name": name, "confidence": conf,
                         "basis": "brief demand phrases", "n_phrases": len(hits),
                         "phrases": hits[:5]})
    if wall_s is not None and wall_s >= 3600:
        caps.append({"name": "long-horizon-execution", "confidence": "high",
                     "basis": f"run records: {wall_s:.0f}s total wall", "n_phrases": 1,
                     "phrases": ["measured wall >= 3600s"]})
    return caps


def epoch_of(task):
    ag = (task.get("agent") or "")
    if "deepseek" not in ag.lower():
        return "all"
    d = task.get("done") or task.get("claimed") or task.get("added")
    if not d:
        return "epoch-unknown"
    return "pre-2026-08-18" if d < "2026-08-18" else "post-2026-08-18"


def type_confidence(basis):
    return {"declarative": "high", "title": "medium", "deliverable": "medium",
            "note": "low", "unknown": "low"}.get(basis, "low")


FULL = {"spec": "spec/design", "implement": "implementation-bounded",
        "audit": "audit/verification", "integration": "integration/reframe",
        "infra": "infra/tooling", "research": "research/census",
        "battery": "battery-heavy", "orchestration": "orchestration-seat",
        "UNKNOWN": None}


def main():
    tasks = L.load_store()
    runs = L.load_runs()
    toks = L.load_tokens()
    briefs = L.load_briefs()
    findix = L.load_findings_index()

    rows = []
    for tid in sorted(tasks):
        t = tasks[tid]
        b = briefs.get(tid)
        lt_short, lt_full = C.classify_legacy(tid, t)
        bt, basis, ev = C.classify_brief(tid, t, briefs)
        agg = L.agg_runs(runs, tid)
        tok = L.agg_tokens(toks, tid)
        wall_s = agg["wall_s"]
        sc, sc_basis, sc_conf = scope_class(tid, t, b, bt, len(findix.get(tid, [])))
        caps = capabilities_for(b, wall_s)
        model = t.get("model") or t.get("agent")
        ds = clean_ds(b["deliverables"]) if b else []
        holds = [h[:-2] if h.endswith("--") else h for h in (b["holds"] if b else [])]
        files_in_scope = sorted(set(ds) | set(holds))
        src_sources = ["docs/infra/managent/tasks.json", "docs/infra/managent/archive.json"]
        if b:
            src_sources.append(b["brief_path"])
        if runs.get(tid):
            src_sources.append(f"untracked/runs/*.json (task={tid})")
        if toks.get(tid):
            src_sources.append("untracked/tokens/tokens.jsonl")
        if findix.get(tid):
            src_sources.append(f"findings/*.json (task={tid})")
        rows.append({
            "id": tid,
            "status": t.get("status"),
            "note": t.get("note"),
            "verdict_note": t.get("verdict_note"),
            "set": t.get("set"),
            "model": model,
            "agent": t.get("agent"),
            "epoch": epoch_of(t),
            "verdict": t.get("verdict"),
            "added": t.get("added"),
            "claimed": t.get("claimed"),
            "done": t.get("done"),
            "bundle": t.get("bundle"),
            "brief_on_disk": b is not None,
            "title": b["title"] if b else None,
            "landmark": b["landmark"] if b else None,
            "type": {
                "legacy": lt_short, "legacy_full": lt_full,
                "brief": bt, "brief_full": FULL.get(bt),
                "basis": basis, "evidence": ev,
                "confidence": type_confidence(basis),
                "disagreement": lt_short != bt,
            },
            "scope": {
                "class": sc, "basis": sc_basis, "confidence": sc_conf,
                "brief_bytes": b["brief_bytes"] if b else None,
                "files_in_scope": files_in_scope,
                "n_files_in_scope": len(files_in_scope),
                "n_deliverables": len(ds),
                "n_src_deliverables": len([d for d in ds if d.startswith("src/")]),
                "holds": holds,
                "gate_declared": bool(b and b["gate"]),
                "n_runs": agg["n_runs"],
                "wall_s": wall_s,
                "cpu_s": agg["cpu_s"],
                "rss_mb": agg["rss_mb"],
                "exit_nonzero": agg["exit_nonzero"],
                "killed": agg["killed"],
                "tokens_in": tok["tokens_in"],
                "tokens_out": tok["tokens_out"],
                "n_token_rows": tok["n_rows"],
            },
            "capabilities": caps,
            "n_findings_files": len(findix.get(tid, [])),
            "findings_files": sorted(findix.get(tid, [])),
            "sources": sorted(set(src_sources)),
            "excluded": False,
            "excluded_reason": None,
        })

    out = f"{L.ROOT}/docs/infra/task-corpus.jsonl"
    with open(out, "w") as f:
        for r in rows:
            f.write(json.dumps(r) + "\n")
    print(f"wrote {len(rows)} rows -> {out}")


if __name__ == "__main__":
    main()
