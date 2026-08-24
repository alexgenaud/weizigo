#!/usr/bin/env python3
"""T818 (blind second pass) — corpus miner, method version 1.

Deterministic, re-runnable derivation of task_type / task_scope / capabilities
for every task id in the managent store. Written by ox-alpha/T818 (2026-08-23).

Universe: union of docs/infra/managent/tasks.json + archive.json ids, minus
"_sys". Sorted lexicographically; chunks of 50; chunk k is a fixed id set.

Usage:
  python3 derive.py [--only-chunk K]     # resume-aware via manifest.json

Does NOT read: docs/infra/task-corpus.jsonl, docs/infra/task-corpus.md,
findings/T817-* (blind-second-pass constraint), tools/model-profiles.py.
"""
import json, glob, hashlib, os, re, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
os.chdir(ROOT)
STORE = "docs/infra/task-corpus-b"
CHUNK_SIZE = 50
METHOD_VERSION = 6

# ---------------------------------------------------------------- sources

def load_records():
    live = json.load(open("docs/infra/managent/tasks.json"))
    arch = json.load(open("docs/infra/managent/archive.json"))
    ids = sorted(set(list(live) + list(arch)) - {"_sys"})
    recs = {}
    for tid in ids:
        r = {}
        if tid in arch and isinstance(arch[tid], dict):
            r.update(arch[tid])
        if tid in live and isinstance(live[tid], dict):   # live wins on overlap
            r.update(live[tid])
        recs[tid] = r
    return ids, recs

def brief_paths(tid):
    pats = []
    for base in ("untracked", "docs"):
        pats += glob.glob(f"{base}/**/{tid}-*.md", recursive=True)
    return sorted(set(pats))

def parse_deliverables(brief_text):
    m = re.search(r"<!--managent[^>]*deliverables=([^->]*)", brief_text)
    if not m:
        return []
    raw = m.group(1).replace("holds=", " ").replace("-->", " ")
    return [p.strip() for p in re.split(r"[,\s]+", raw) if p.strip()]

def run_files(tid):
    out = []
    for p in glob.glob(f"untracked/runs/*.json"):
        b = os.path.basename(p)
        if (re.match(rf"{re.escape(tid)}(\.\d+|-.*)?\.json$", b) or b == f"{tid}.json"):
            try:
                out.append(json.load(open(p)))
            except Exception:
                pass
    # also bakeoff_*_<tid>-* files
    for p in glob.glob(f"untracked/runs/bakeoff_{tid.lower()}-*.json"):
        try:
            out.append(json.load(open(p)))
        except Exception:
            pass
    return out

def findings_count(tid):
    return len(glob.glob(f"findings/{tid}*.json"))

TOKENS = None
def token_rows(tid):
    global TOKENS
    if TOKENS is None:
        TOKENS = {}
        p = "untracked/tokens/tokens.jsonl"
        if os.path.exists(p):
            for line in open(p):
                try:
                    d = json.loads(line)
                    t = d.get("task")
                    if t:
                        TOKENS.setdefault(t, []).append(d)
                except Exception:
                    pass
    return TOKENS.get(tid, [])

# ---------------------------------------------------------------- classifier v1

AUDIT_RE  = re.compile(r"\b(audit|auditor|adjudicat|grader|all-grade-all|grade\b|grading|"
                       r"independent(ly)? (check|verif|re-?run|reproduc)|re-?verify|cross-check|"
                       r"second pass|blind second|verify .{0,30}(refutat|claim|finding)|shadow)\b")
ORCH_RE   = re.compile(r"\b(orchestr|dispatch(es|ing)?\b.{0,40}(task|fleet)|delegat|kanban queue|"
                       r"sprint plan|owns? pass-\d phases|oversight seat|relay(ed)? between|fleet-wide)\b")
SPEC_RE   = re.compile(r"\b(spec\b|specification|design doc|proposal\b|ratif(y|ies|ication))\b")
BATTERY_RE= re.compile(r"\b(battery|exhaustive|sweep|enumerate all|every (position|state|goban)|"
                       r"golden.?master|full run of the suite|race [a-z]+ (batch|lane)|seeds?\b|"
                       r"self-play games|regression battery)\b")
INTEG_RE  = re.compile(r"\b(absorb|integrate|wire .{0,30}(into|to) the (gate|build|suite)|smoke test|"
                       r"deploy|end-to-end|handshake|sabaki|gtp compat|migration|migrate)\b")
RESEARCH_Q= re.compile(r"^(does|is|are|can|should|what|which|why|how|do we|whether)\b.*\?$")
RESEARCH_RE=re.compile(r"\b(falsif|hypothes|probe\b|invariant to|decide,|decision doc|reframe|"
                       r"ruleset option|research question|measure agreement|cost model)\b")
DIAG_RE   = re.compile(r"\b(triage|diagnos|debug)\b|\b(root cause|post-mortem)\b|^why (is|do|does|are)\b")
QWORDS    = {"does","is","are","can","should","what","which","why","how","do","where","when","whether"}
RACE_RE   = re.compile(r"race [a-z]+ .*(lane|batch)|science lane", re.I)
CONSOLE_RE= re.compile(r"sprint console|console #\d+", re.I)
IMPL_RE   = re.compile(r"\b(implement|fix(es)?\b|bug|patch|add unit|unit-test|write the tests?|"
                       r"build the|install|refactor|rewrite|extend|backfill|repair)\b")

CODE_PREFIXES = ("src/",)
INFRA_PREFIXES = ("bin/", "tools/", "tests/unit/", "tests/")

def code_kind(paths):
    kinds = set()
    for p in paths:
        if p.startswith(CODE_PREFIXES) or p.endswith(".zig"): kinds.add("engine")
        elif p.endswith(".py") or p.startswith(INFRA_PREFIXES): kinds.add("pytool")
    return kinds

def classify(tid, title, text, note, paths, bundle_path=None, duty=False):
    """Returns (type, basis, confidence). Deterministic cascade, first hit wins.
    v5: all text inputs are case-folded before matching."""
    title, text, note = title.lower(), text.lower(), note.lower()
    blob = " \n ".join(filter(None, [title, text[:4000], note]))
    seat = not re.match(r"^T\d+$", tid)
    dk = code_kind(paths)

    # 1 orchestration — fleet-level coordination content, seat handovers, non-T seats
    if (ORCH_RE.search(blob) or (bundle_path and "ORCHA" in os.path.basename(bundle_path))
            or "orchestrator seat" in text[:600] or "orchestrator seat" in note):
        return ("orchestration", "seat handover / orchestration vocabulary in title/note/brief",
                "high" if ("orchestrator seat" in text[:600] or "ORCHA" in (bundle_path or "")) else "medium")
    # 1b race compute lanes are battery runs, even when their briefs discuss grading
    if RACE_RE.search(title):
        return ("battery", "title names a race lane/batch: a compute run producing gradeable artifacts", "high")
    # 1c sprint consoles are orchestration seats
    if CONSOLE_RE.search(title):
        return ("orchestration", "title names a sprint console (a coordination seat)", "high")
    # 2 audit — verification of others' work
    if AUDIT_RE.search(title) or AUDIT_RE.search(text[:1200]) and not IMPL_RE.search(title):
        where = "title" if AUDIT_RE.search(title) else "brief head"
        return ("audit", f"audit/verification vocabulary in {where}", "high" if AUDIT_RE.search(title) else "medium")
    # 3 spec — authoring a specification/proposal as the deliverable
    if SPEC_RE.search(title) and not dk:
        return ("spec", "spec/proposal vocabulary in title, no code deliverable", "high")
    if any(re.search(r"(spec|design|proposal)", p, re.I) for p in paths if p.endswith(".md")):
        return ("spec", f"deliverable path names a spec/design doc: {[p for p in paths if 'spec' in p.lower() or 'design' in p.lower() or 'proposal' in p.lower()][:1]}", "high")
    # 4 integration — joining existing components / absorb / gates
    if INTEG_RE.search(blob) and not BATTERY_RE.search(title):
        return ("integration", "absorb/wire/smoke/deploy vocabulary", "medium")
    # 5 battery — running compute over many states/games
    if BATTERY_RE.search(blob):
        return ("battery", "battery/exhaustive/race-run/seeds vocabulary", "medium")
    # 6 research — questions, falsification, decisions, diagnosis
    tq = title.strip().split()
    if "?" in title:
        return ("research", "title asks a question", "high")
    if (tq and tq[0].lower().rstrip(",") in QWORDS) or DIAG_RE.search(title):
        return ("research", "title phrased as an empirical question or a diagnosis", "high")
    if RESEARCH_RE.search(blob) or DIAG_RE.search(blob):
        return ("research", "falsification/hypothesis/diagnosis/decision vocabulary", "medium")
    # 6b standing duties classified by their standing brief's verb
    if duty:
        if re.search(r"absorb", blob, re.I):
            return ("integration", "standing absorption duty (absorb vocabulary)", "medium")
        if re.search(r"run \w+ once|doctor|health", blob, re.I):
            return ("infra", "standing fleet-health duty (run-a-checker vocabulary)", "medium")
        return ("UNKNOWN", "standing duty whose brief verb matched no cascade rule", "low")
    # 7 implement vs infra split by code kind
    if dk or IMPL_RE.search(blob):
        kind = "engine code (src/*.zig)" if "engine" in dk else \
               "python tooling (bin/, tools/, tests/unit)" if "pytool" in dk else \
               "implementation verbs in title/note"
        t = "implement" if "engine" in dk else ("infra" if "pytool" in dk else "implement")
        conf = "high" if dk else "low"
        return (t, f"code deliverable: {kind}" if dk else f"implementation verbs, no code file on disk ({kind})", conf)
    if seat:
        return ("UNKNOWN", "standing/seat task with no classifying signal", "low")
    return ("UNKNOWN", "no cascade rule fired", "low")

# ---------------------------------------------------------------- capabilities v1

CAP_RULES = [
    ("zig-engine-code",      lambda c: bool(c["paths"]) and any(p.startswith("src/") for p in c["paths"]),
                             "a src/*.zig file is a declared deliverable or hold"),
    ("python-tooling",       lambda c: any(p.endswith(".py") or p.startswith(("bin/", "tools/")) for p in c["paths"]),
                             "a bin/, tools/ or .py artifact is in scope"),
    ("test-first-mandate",   lambda c: bool(re.search(r"failing test|test first|tests before implementation|red then green|write the tests? first", c["text"])),
                             "brief mandates writing the failing test before the fix"),
    ("evidence-and-claims",  lambda c: bool(re.search(r"docs/evidence/|CLAIMS\.md|claim register|PROVEN|FALSE-AS-SCOPED", c["text"])),
                             "brief demands evidence under docs/evidence/ or CLAIMS.md status changes"),
    ("git-fleet-discipline", lambda c: bool(re.search(r"stage (them )?by name|git add|hooksPath|pre-commit|git isolation|commit subject", c["text"])),
                             "brief enforces named staging, hooks, or fleet git isolation"),
    ("long-running-compute", lambda c: bool(re.search(r"tools/runner|heartbeat|RETRO_SAVE|wall budget|RSS|sweep|ReleaseFast", c["text"])) or (c["wall_s"] or 0) >= 1800,
                             "brief involves guarded long runs, or measured wall ≥ 1800 s"),
    ("cross-agent-coordination", lambda c: bool(re.search(r"untracked/msg/|dispatch|delegate|subagent|model-perf|another console|blind second|agreement between", c["text"])),
                             "brief involves other agents: dispatch, relay, grading, or agreement measurement"),
    ("schema-design",        lambda c: bool(re.search(r"schema|jsonl? format|manifest|ledger|field(s)? definition|canonical label", c["text"])),
                             "brief authors or amends a data schema/ledger"),
    ("operator-relay",       lambda c: bool(re.search(r"copy/paste|paste boundar|--- fence|payload|one-liner|relay to", c["text"])),
                             "brief governs human-relayed payload formatting"),
    ("statistical-method",   lambda c: bool(re.search(r"\brate\b|denominator|sample|confidence interval|agreement|kappa|distribution|percentile", c["text"])),
                             "brief demands rates, denominators, sampling or agreement statistics"),
]

def capabilities(c):
    caps = [(name, why) for name, fn, why in CAP_RULES if fn(c)]
    if not caps:
        return [("none-inferred", "no capability rule fired on this row's signals")]
    return caps

# ---------------------------------------------------------------- scope

def scope_class(c):
    if (c["wall_s"] or 0) >= 1800 or (c["rss_mb"] or 0) >= 2000:
        return "heavy-compute", "wall ≥ 1800 s or peak RSS ≥ 2000 MB"
    if c["n_paths"] >= 3:
        return "multi-artifact", "≥ 3 unique declared paths (deliverables + holds)"
    if any(p.startswith(("src/",)) or p.endswith(".zig") for p in c["paths"]):
        return "code-touch", "engine source in declared scope"
    if any(p.startswith(("bin/", "tools/", "tests/")) or p.endswith(".py") for p in c["paths"]):
        return "code-touch", "tooling/test source in declared scope"
    if c["n_paths"] <= 2:
        if c["brief_bytes"] and c["brief_bytes"] < 1500:
            return "micro", "≤2 paths and a sub-1500-byte brief (single-question task)"
        return "single-doc", "1–2 documentation/findings paths, no source"
    return "unclassified-scope", "no rule fired"

# ---------------------------------------------------------------- per-task row

def build_row(tid, rec):
    bps = brief_paths(tid)
    brief_text = open(bps[0], encoding="utf-8", errors="replace").read() if bps else ""
    m = re.search(r"^# .*?[-–—]\s*(.+)$", brief_text, re.M)
    title = m.group(1).strip() if m else ""
    deliv = parse_deliverables(brief_text)
    holds = list(rec.get("holds") or [])
    paths = sorted(set(deliv) | set(holds))
    runs = run_files(tid)
    wall = sum((r.get("wall") or 0) for r in runs) or None
    cpu = sum((r.get("cpu") or 0) for r in runs) or None
    rss = max([(r.get("rss_mb") or 0) for r in runs], default=0) or None
    tok = token_rows(tid)
    tin = sum((t.get("tokens_in") or 0) for t in tok) or None
    tout = sum((t.get("tokens_out") or 0) for t in tok) or None
    ctx = {
        "id": tid, "title": title, "text": brief_text, "note": rec.get("note") or "",
        "paths": paths, "n_paths": len(paths),
        "wall_s": round(wall, 1) if wall else None,
        "cpu_s": round(cpu, 1) if cpu else None,
        "rss_mb": rss, "n_runs": len(runs),
        "tokens_in": tin, "tokens_out": tout,
        "status": rec.get("status"), "model": rec.get("model"),
        "brief_bytes": os.path.getsize(bps[0]) if bps else rec.get("brief_bytes"),
    }
    bp = bps[0] if bps else rec.get("bundle")
    if bp and not bps and not bp.startswith("/") and os.path.exists(bp):
        try:
            extra = open(bp, encoding="utf-8", errors="replace").read()
            brief_text = brief_text or ""
            if not title:
                m2 = re.search(r"^# .*?[-–—]\s*(.+)$", extra, re.M)
                if m2: title = m2.group(1).strip()
            ctx["text"] = ctx["text"] or extra
        except Exception:
            pass
    tt, tbasis, tconf = classify(tid, title, ctx["text"], rec.get("note") or "", paths,
                                 bundle_path=bp, duty=bool(rec.get("duty")))
    sc, sbasis = scope_class(ctx)
    caps = capabilities(ctx)
    n_find = findings_count(tid)
    return {
        "id": tid,
        "method": METHOD_VERSION,
        "title": title or None,
        "sources": {"brief_on_disk": bool(bps), "brief_path": bps[0] if bps else None,
                     "runs": len(runs), "findings_files": n_find, "token_rows": len(tok)},
        "brief_bytes": os.path.getsize(bps[0]) if bps else rec.get("brief_bytes"),
        "declared_paths": paths,
        "n_declared_paths": len(paths),
        "run_metrics": {"wall_s": ctx["wall_s"], "cpu_s": ctx["cpu_s"], "rss_mb": rss,
                         "n_run_files": len(runs)},
        "tokens": {"in": tin, "out": tout},
        "task_type": {"value": tt, "basis": tbasis, "confidence": tconf},
        "scope_class": {"value": sc, "basis": sbasis},
        "capabilities": [{"name": n, "why": w} for n, w in caps],
        "kanban_status": rec.get("status"),
    }

# ---------------------------------------------------------------- chunked writer

def sha256(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blk in iter(lambda: f.read(65536), b""):
            h.update(blk)
    return h.hexdigest()

def main():
    only = None
    if "--only-chunk" in sys.argv:
        only = int(sys.argv[sys.argv.index("--only-chunk") + 1])
    ids, recs = load_records()
    chunks = [ids[i:i+CHUNK_SIZE] for i in range(0, len(ids), CHUNK_SIZE)]
    man_p = f"{STORE}/manifest.json"
    man = json.load(open(man_p)) if os.path.exists(man_p) else {
        "task": "T818", "method_version": METHOD_VERSION, "chunk_size": CHUNK_SIZE,
        "universe_count": len(ids), "sort": "lexicographic on id string",
        "chunks": [], "next_chunk": 0}
    done_k = {c["k"] for c in man["chunks"] if c["method_version"] == METHOD_VERSION}
    for k, chunk_ids in enumerate(chunks):
        if only is not None and k != only:
            continue
        if k in done_k:
            continue
        cp = f"{STORE}/chunk-{k:02d}-m{METHOD_VERSION}.jsonl"
        rows = [build_row(t, recs[t]) for t in chunk_ids]
        with open(cp, "w") as f:                      # append-only discipline:
            for r in rows:                            # a completed chunk file is
                f.write(json.dumps(r, ensure_ascii=False) + "\n")  # never rewritten;
        man["chunks"].append({                        # resume skips it by k.
            "k": k, "ids": [chunk_ids[0], chunk_ids[-1]],
            "row_count": len(rows), "sha256": sha256(cp),
            "method_version": METHOD_VERSION,
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")})
        man["next_chunk"] = k + 1
        with open(man_p, "w") as f:
            json.dump(man, f, indent=1)
        print(f"chunk {k:02d}: {len(rows)} rows [{chunk_ids[0]}..{chunk_ids[-1]}] -> {cp}")
    print(f"done; next_chunk={man['next_chunk']}/{len(chunks)}")

if __name__ == "__main__":
    main()
