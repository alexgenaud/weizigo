#!/usr/bin/env python3
"""T820 — blind third-pass corpus miner, method v1 (final).

Derives three fields per task from the task corpus:
  1. task_type   — D027's eight classes (spec/implement/audit/integration/
                   infra/research/battery/orchestration).
  2. task_scope  — size (brief_bytes, unique_paths, measured wall/cpu/rss_mb)
                   plus a 5-class ordinal (XS/S/M/L/XL) from brief_bytes.
  3. capabilities — a vocabulary derived from the data (see notes.md).

Blindness contract: this script NEVER reads docs/infra/task-corpus.jsonl,
docs/infra/task-corpus.md, docs/infra/task-corpus-b/**, findings/T817-* or
findings/T818-*.  Its method was built from the raw sources listed in the
brief; the keyword rules below are original, not taken from
tools/model-profiles.py (which this arm is forbidden to consult).

Classification design (v1): tiered weighting, because the brief *body*
references many project concepts incidentally (every brief has a
"Landmark" line, mentions "battery", "audit", "regression" in passing).
  - title + filename slug : weight 3.0 per distinct keyword hit (curated)
  - deliverables/holds path prefixes : decisive boosts (src/build -> impl,
    tools/bin -> infra, docs/audits -> audit, ...)
  - body keywords : weight 0.3 per hit, capped at 2.0 contribution per type
    (a fallback signal, never decisive on its own)

Reproducibility / resumability:
  - Deterministic partition: corpus = union(tasks.json, archive.json) minus
    the structural keys `_sys` and `--bundle`; ids sorted by natural key
    (T<digits> numeric, then suffix; non-T ids lexicographic). Chunk size 50.
  - Chunk k covers the fixed id slice [k*50:(k+1)*50].
  - Append-only: a chunk file that already exists on disk is left untouched;
    resume skips it and re-verifies its sha256 against the manifest.
  - method version stamped on every row.

Resume command (also in notes.md):
    python3 docs/infra/task-corpus-c/derive.py
"""
import os, re, json, glob, hashlib, datetime, sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUTDIR = os.path.join(REPO, "docs", "infra", "task-corpus-c")
CHUNK_SIZE = 50
METHOD = 1

# ----------------------------------------------------------------------------
# Loading
# ----------------------------------------------------------------------------

def load_combined():
    tasks = json.load(open(os.path.join(REPO, "docs/infra/managent/tasks.json")))
    arch = json.load(open(os.path.join(REPO, "docs/infra/managent/archive.json")))
    combined = {}
    combined.update(arch)
    combined.update(tasks)  # tasks.json wins on the overlap keys
    return combined


def natural_key(tid):
    m = re.match(r"^T(\d+)(.*)$", tid)
    if m:
        return (0, int(m.group(1)), m.group(2))
    return (1, 0, tid)


def corpus_ids(combined):
    ids = [k for k in combined if k not in ("_sys", "--bundle")]
    return sorted(ids, key=natural_key)


# ----------------------------------------------------------------------------
# Per-task source resolution
# ----------------------------------------------------------------------------

def find_brief(tid, record):
    bundle = record.get("bundle")
    if bundle:
        p = bundle if os.path.isabs(bundle) else os.path.join(REPO, bundle)
        if os.path.isfile(p):
            return p
    for g in (f"untracked/{tid}-*.md", f"untracked/{tid}.md"):
        hits = sorted(glob.glob(os.path.join(REPO, g)))
        if hits:
            return hits[0]
    return None


def parse_meta(text):
    """Parse the <!--managent ...--> first line. Returns dict."""
    meta = {"set": None, "deliverables": [], "holds": [], "acceptance": None}
    m = re.search(r"<!--managent\s+(.*?)-->", text, re.S)
    if not m:
        return meta
    body = m.group(1)
    for key in ("set", "deliverables", "holds"):
        mm = re.search(rf"\b{key}=(\S+)", body)
        if mm:
            val = mm.group(1)
            if key in ("deliverables", "holds"):
                meta[key] = [v for v in val.split(",") if v]
            else:
                meta[key] = val
    mm = re.search(r"acceptance=(.*?)$", body)
    if mm:
        meta["acceptance"] = mm.group(1).strip().rstrip("-->").strip()
    return meta


def load_brief(tid, record):
    path = find_brief(tid, record)
    if not path:
        return None
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    meta = parse_meta(text)
    lines = text.split("\n")
    title = None
    body_start = 0
    for i, ln in enumerate(lines):
        if ln.startswith("<!--managent"):
            body_start = i + 1
            continue
        if title is None and ln.startswith("# "):
            title = ln[2:].strip()
    body = "\n".join(lines[body_start:])
    slug = os.path.basename(path)
    return {
        "path": os.path.relpath(path, REPO),
        "bytes": os.path.getsize(path),
        "meta": meta,
        "title": title,
        "body": body,
        "slug": slug,
    }


def load_findings(tid):
    out = []
    for g in (f"findings/{tid}-*.json", f"findings/{tid}.json"):
        for p in sorted(glob.glob(os.path.join(REPO, g))):
            try:
                d = json.load(open(p, encoding="utf-8"))
            except Exception:
                continue
            out.append((os.path.relpath(p, REPO), d))
    return out


def load_runs(tid):
    recs = []
    for g in (f"untracked/runs/{tid}.json", f"untracked/runs/archive-*/{tid}.json"):
        recs += sorted(glob.glob(os.path.join(REPO, g)))
    wall = cpu = rss = None
    n = 0
    for p in recs:
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        if d.get("task") and d.get("task") != tid:
            continue
        n += 1
        if d.get("wall") is not None and (wall is None or d["wall"] > wall):
            wall = d["wall"]
        if d.get("cpu") is not None and (cpu is None or d["cpu"] > cpu):
            cpu = d["cpu"]
        if d.get("rss_mb") is not None and (rss is None or d["rss_mb"] > rss):
            rss = d["rss_mb"]
    if n == 0:
        return None
    return {"run_count": n, "wall_s": wall, "cpu_s": cpu, "rss_mb": rss}


def load_tokens(tid):
    path = os.path.join(REPO, "untracked/tokens/tokens.jsonl")
    if not os.path.isfile(path):
        return None
    n = 0
    tin = tout = 0
    have = False
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if not line.strip():
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get("task") != tid:
                continue
            n += 1
            if d.get("tokens_in") is not None:
                tin += d["tokens_in"]; have = True
            if d.get("tokens_out") is not None:
                tout += d["tokens_out"]; have = True
    if n == 0:
        return None
    return {"record_count": n, "tokens_in": tin if have else None, "tokens_out": tout if have else None}


# ----------------------------------------------------------------------------
# task_type classification (method v1)
# ----------------------------------------------------------------------------

# Keyword lists are trimmed to distinctive, low-collision terms. Broad words
# ("brief", "landmark", "acceptance", "add", "check", "evidence") are excluded
# because they appear in nearly every brief's boilerplate.
TYPE_KEYS = {
    "spec": ["spec", "design", "proposal", "taxonomy", "ratif", "draft", "schema", "contract", "plan"],
    "implement": ["fix", "implement", "wire", "patch", "refactor", "harden", "re-issue", "decode", "remechanize", "mechanize"],
    "audit": ["audit", "verify", "verif", "re-derive", "independent", "trace", "review", "blind", "second pass", "third pass", "cross-check", "falsif"],
    "integration": ["integrat", "reframe", "adopt", "absorb", "migrat", "restructur", "relocat", "consolidat", "unif", "rename", "sweep"],
    "infra": ["tool", "instrument", "pipeline", "hook", "runner", "claimlint", "managent", "deploy", "smoke", "cli", "gtp"],
    "research": ["census", "research", "measure", "mine", "survey", "probe", "experiment", "feasib", "hypothes", "investigat", "quantif", "study", "analyz", "reconcile"],
    "battery": ["battery", "bakeoff", "lane", "tournament", "divergence", "benchmark", "seeds", "race", "regtest"],
    "orchestration": ["orchestrat", "orcha", "seat", "handover", "sprint", "register", "assign", "delegat", "dispatch", "kanban"],
}

# Path-prefix boosts over deliverables+holds. Decisive.
def path_boosts():
    return [
        ("src/", "implement", 5),
        ("build.zig", "implement", 5),
        ("tests/", "battery", 3),
        ("tools/", "infra", 4),
        ("bin/", "infra", 4),
        ("docs/audits", "audit", 3),
        ("docs/research", "research", 2),
        ("docs/evidence", "research", 2),
        ("docs/infra/delegation", "orchestration", 2),
        ("docs/infra/managent", "infra", 2),
        ("docs/infra", "infra", 1),
        ("docs/epic", "spec", 2),
    ]


def count_hits(text, keys):
    low = text.lower()
    return sum(1 for k in keys if k in low)


def classify_type(brief, record):
    if brief is None:
        slug = os.path.basename(record.get("bundle") or "") or record.get("set") or ""
        title = None
        body = ""
        holds = record.get("holds") or []
        deliverables = []
        title_slug = slug
    else:
        slug = brief["slug"]
        title = brief["title"]
        body = brief["body"]
        holds = brief["meta"]["holds"]
        deliverables = brief["meta"]["deliverables"]
        title_slug = f"{slug} {title or ''}"

    scores = {t: 0.0 for t in TYPE_KEYS}
    evidence = []

    # tier 1: slug + title (curated, weight 3.0/hit)
    for t, keys in TYPE_KEYS.items():
        hits = count_hits(title_slug, keys)
        if hits:
            scores[t] += 3.0 * hits
            evidence.append(f"title_slug:{t}:{hits}")

    # tier 2: path prefixes (decisive)
    for p in list(deliverables) + list(holds):
        for pref, t, w in path_boosts():
            if p.startswith(pref):
                scores[t] += w
                evidence.append(f"path:{t}")
                break

    # record set H nudges infra lightly (hardening fleet)
    if record.get("set") == "H":
        scores["infra"] += 0.5

    def winner(sc):
        top = sorted(sc.items(), key=lambda kv: -kv[1])
        return top[0][0], top[0][1], (top[1][1] if len(top) > 1 else 0.0)

    best, best_score, second_score = winner(scores)

    # tier 3: body is a FALLBACK only — consulted when the primary signal
    # (title/slug/path) is thin or ambiguous, never decisive on its own.
    used_body = False
    if body and not (best_score >= 3.0 and (best_score - second_score) >= 1.5):
        used_body = True
        for t, keys in TYPE_KEYS.items():
            hits = count_hits(body, keys)
            if hits:
                contrib = min(1.0, 0.2 * hits)
                scores[t] += contrib
                evidence.append(f"body:{t}:{hits}")
        best, best_score, second_score = winner(scores)

    margin = best_score - second_score

    if best_score == 0:
        return {"value": "UNKNOWN", "basis": "no signal (no brief on disk; no holds/deliverables)", "confidence": "low", "score": 0.0}

    if best_score >= 6 and margin >= 1.5:
        conf = "high"
    elif best_score >= 3 and margin >= 0.5:
        conf = "medium"
    else:
        conf = "low"

    return {
        "value": best,
        "basis": ";".join(sorted(set(evidence))[:10]) + f" (score {best_score:.1f})",
        "confidence": conf,
        "score": round(best_score, 1),
    }


# ----------------------------------------------------------------------------
# task_scope
# ----------------------------------------------------------------------------

def scope_class(brief_bytes):
    if brief_bytes is None:
        return "UNKNOWN"
    if brief_bytes < 1500:
        return "XS"
    if brief_bytes < 3000:
        return "S"
    if brief_bytes < 4500:
        return "M"
    if brief_bytes < 6500:
        return "L"
    return "XL"


def build_scope(brief, record, runs):
    brief_bytes = brief["bytes"] if brief else None
    if brief is not None:
        paths = set(brief["meta"]["deliverables"]) | set(brief["meta"]["holds"])
        unique_paths = len(paths)
    else:
        paths = set(record.get("holds") or [])
        unique_paths = len(paths) or None
    cls = scope_class(brief_bytes)
    basis = []
    if brief:
        basis.append("brief on disk")
    else:
        basis.append("no brief on disk (bundle absent/never committed)")
    if unique_paths is not None:
        basis.append(f"unique_paths={unique_paths}")
    if runs:
        basis.append(f"{runs['run_count']} run record(s)")
    return {
        "brief_bytes": brief_bytes,
        "unique_paths": unique_paths,
        "wall_s": runs["wall_s"] if runs else None,
        "cpu_s": runs["cpu_s"] if runs else None,
        "rss_mb": runs["rss_mb"] if runs else None,
        "run_count": runs["run_count"] if runs else 0,
        "class": cls,
        "basis": "; ".join(basis) if basis else "no scope signal",
    }


# ----------------------------------------------------------------------------
# capabilities (vocabulary derived from the data — see notes.md)
# ----------------------------------------------------------------------------

def _in_title_slug(b, pat):
    if b is None:
        return False
    return re.search(pat, (b["slug"] + " " + (b["title"] or "")), re.I) is not None


def _in_body(b, pat):
    if b is None:
        return False
    return re.search(pat, b["body"], re.I) is not None


CAP_RULES = [
    ("engine-code",
     lambda b, r: any(p.startswith("src") or p == "build.zig" for p in (b["meta"]["holds"] + b["meta"]["deliverables"] if b else []) + (r.get("holds") or [])),
     "holds/deliverables touch src/*.zig or build.zig"),
    ("test-first",
     lambda b, r: _in_body(b, r"failing test first|show it red|test-first|tests before implementation|write the failing test"),
     "brief mandates test-first / show-it-red"),
    ("audit-verification",
     lambda b, r: _in_title_slug(b, r"\baudit\b|verif|re-deriv") or _in_body(b, r"trace one complete evaluation|positive control|independent re-implementation"),
     "independent audit/verification demanded (title-level or explicit body phrase)"),
    ("evidence-discipline",
     lambda b, r: _in_body(b, r"PROVENANCE|CLAIMS\.md|commit.{0,15}evidence|evidence in git|register.{0,20}(row|claim)"),
     "register/evidence work: PROVENANCE, CLAIMS.md, committed evidence"),
    ("deployment",
     lambda b, r: _in_body(b, r"zig build deploy|smoke|STALE") or (b is not None and any(p.startswith("bin") for p in b["meta"]["deliverables"] + b["meta"]["holds"])),
     "deploys binaries / runs smoke"),
    ("sub-delegation",
     lambda b, r: _in_body(b, r"managent (add|dispatch|claim|tell)|sub.?delegate|odeeppi|oflashpi|\bdelegate\b.{0,20}\bto\b|register.{0,12}dispatch|dispatch.{0,40}--agent"),
     "requires actually dispatching/delegating to other agents"),
    ("independence",
     lambda b, r: _in_body(b, r"blind|do not read|must not read|independently|re-derive independently|has-not-read"),
     "blind / do-not-read / independent re-derivation"),
    ("session-persistence",
     lambda b, r: _in_body(b, r"persistent session|heartbeat|RETRO_SAVE|long run|chunked and resumable|resumable"),
     "long-running / resumable session required"),
    ("data-mining",
     lambda b, r: _in_title_slug(b, r"census|mine|survey|reconcil|inventory") or _in_body(b, r"grep -|aggregat|census of|mining"),
     "corpus census / mining / reconciliation"),
    ("numerical-measurement",
     lambda b, r: _in_title_slug(b, r"battery|seeds|benchmark|bakeoff|metric") or _in_body(b, r"battery run|seeds|benchmark|bakeoff|metrics"),
     "runs a battery/benchmark of experiments and measures numbers"),
    ("spec-writing",
     lambda b, r: (b is not None and any(re.search(r"spec|design|plan", os.path.basename(p), re.I) for p in b["meta"]["deliverables"])) or _in_title_slug(b, r"\bspec\b|\bdesign\b|\bplan\b"),
     "authors a spec/design/plan document"),
    ("orchestration",
     lambda b, r: _in_title_slug(b, r"orchestrat|seat|handover|sprint|kanban|assign|delegat"),
     "seat/delegation/orchestration work"),
]


def build_capabilities(brief, record):
    caps = []
    for name, test, basis_tpl in CAP_RULES:
        if test(brief, record):
            caps.append({"name": name, "basis": basis_tpl, "confidence": "inferred"})
    return caps


# ----------------------------------------------------------------------------
# Row assembly
# ----------------------------------------------------------------------------

def build_row(tid, record, brief, findings, runs, tokens):
    tt = classify_type(brief, record)
    scope = build_scope(brief, record, runs)
    caps = build_capabilities(brief, record)
    row = {
        "task_id": tid,
        "method": METHOD,
        "task_type": tt,
        "task_scope": scope,
        "capabilities": caps,
        "sources": {
            "brief": brief["path"] if brief else None,
            "findings": [f[0] for f in findings] or None,
            "run_count": runs["run_count"] if runs else 0,
            "token_record_count": tokens["record_count"] if tokens else 0,
            "tokens_in": tokens["tokens_in"] if tokens else None,
            "tokens_out": tokens["tokens_out"] if tokens else None,
        },
        "status": record.get("status"),
        "verdict": record.get("verdict"),
        "agent": record.get("agent"),
        "set": record.get("set"),
        "anomalies": [],
    }
    if brief is None:
        row["anomalies"].append("no brief on disk")
    elif brief["meta"]["deliverables"] == [] and brief["meta"]["holds"] == []:
        row["anomalies"].append("brief has no deliverables/holds meta")
    return row


# ----------------------------------------------------------------------------
# Manifest + chunk IO
# ----------------------------------------------------------------------------

def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_manifest():
    p = os.path.join(OUTDIR, "manifest.json")
    if os.path.isfile(p):
        return json.load(open(p, encoding="utf-8"))
    return None


def write_manifest(manifest):
    p = os.path.join(OUTDIR, "manifest.json")
    with open(p, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)
        fh.write("\n")


def chunk_path(k):
    return os.path.join(OUTDIR, f"chunk-{k:02d}.jsonl")


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    combined = load_combined()
    ids = corpus_ids(combined)
    total = len(ids)
    n_chunks = (total + CHUNK_SIZE - 1) // CHUNK_SIZE

    manifest = load_manifest()
    if manifest is None:
        manifest = {
            "task_id": "T820",
            "created_by": "deepseek-v4-pro/T820",
            "total_tasks": total,
            "chunk_size": CHUNK_SIZE,
            "method_version": METHOD,
            "chunks": [],
        }

    processed = 0
    for k in range(n_chunks):
        lo, hi = k * CHUNK_SIZE, min((k + 1) * CHUNK_SIZE, total)
        id_slice = ids[lo:hi]
        cp = chunk_path(k)

        if os.path.isfile(cp):
            known = next((c for c in manifest["chunks"] if c.get("chunk") == k), None)
            if known and known.get("sha256") == sha256(cp):
                processed += len(id_slice)
                continue
            print(f"WARN chunk {k} exists but manifest hash mismatches; skipping (append-only).",
                  file=sys.stderr)
            continue

        with open(cp, "w", encoding="utf-8") as fh:
            for tid in id_slice:
                rec = combined[tid]
                brief = load_brief(tid, rec)
                findings = load_findings(tid)
                runs = load_runs(tid)
                tokens = load_tokens(tid)
                row = build_row(tid, rec, brief, findings, runs, tokens)
                fh.write(json.dumps(row, ensure_ascii=False) + "\n")

        digest = sha256(cp)
        manifest["chunks"].append({
            "chunk": k,
            "id_range": [ids[lo], ids[hi - 1]],
            "row_count": len(id_slice),
            "sha256": digest,
            "method": METHOD,
            "ts": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        })
        manifest["chunks"] = sorted(manifest["chunks"], key=lambda c: c["chunk"])
        manifest["next_chunk"] = (k + 1) if (k + 1) < n_chunks else None
        write_manifest(manifest)
        processed += len(id_slice)
        print(f"chunk {k:02d}: {len(id_slice)} rows -> {os.path.relpath(cp, REPO)}",
              file=sys.stderr)

    manifest["processed_rows"] = processed
    manifest["total_tasks"] = total
    write_manifest(manifest)
    print(f"done: {processed}/{total} rows across {n_chunks} chunks (method v{METHOD})",
          file=sys.stderr)


if __name__ == "__main__":
    main()
