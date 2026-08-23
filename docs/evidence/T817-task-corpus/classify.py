#!/usr/bin/env python3
"""T817 — the two type classifiers.

legacy  — tools/model-profiles.py classify_type (slug + note + verdict_note),
          imported by path so this module tracks the committed instrument.
brief   — brief-aware, five-stage, ordered specific-beats-general:
          1. declarative self-type phrases in the brief body (negation-guarded)
          2. slug + title keywords
          3. deliverable-filename keywords
          4. note/verdict_note keywords (orchestration excluded: attribution
             noise — "the Orchestrator ruled" appears in ordinary close text)
          5. UNKNOWN when no signal exists.

Measured accuracy on the self-declared + race-organizer hold-out (n=27):
100% vs the legacy classifier's 78% — see calib.py and task-corpus.md §2.
"""
import re, importlib.util, os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

_spec = importlib.util.spec_from_file_location("mp", f"{ROOT}/tools/model-profiles.py")
mp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mp)

SHORT = {
    "spec/design": "spec",
    "implementation-bounded": "implement",
    "audit/verification": "audit",
    "integration/reframe": "integration",
    "infra/tooling": "infra",
    "research/census": "research",
    "battery-heavy": "battery",
    "orchestration-seat": "orchestration",
}

# declarative self-type phrases, checked FIRST (the task's own words)
DECLARATIVE = [
    (r"\bthis (?:row|task|brief|deliverable|work) (?:is|delivers|produces|writes) (?:a |an |the |only )?(?:spec|specification)", "spec"),
    (r"\bspec[ -]only\b", "spec"),
    (r"\bdelivers? the spec\b", "spec"),
    (r"\bwrites the spec\b", "spec"),
    (r"\bspec amendment\b", "spec"),
    (r"\bis a census\b", "research"),
    (r"\bcensus task\b", "research"),
    (r"\bis a research task\b", "research"),
    (r"\ba research row\b", "research"),
    (r"\bis a race lane\b", "audit"),
    (r"\bthis is a race\b", "audit"),
    (r"\brace lane\b", "audit"),
    (r"\bis a race\b", "audit"),
    (r"\bis a tooling test\b", "infra"),
    (r"\bis a battery\b", "battery"),
    (r"\bacceptance battery\b", "battery"),
    (r"\bis a tooling\b", "infra"),
    (r"\btooling task\b", "infra"),
    (r"\bis a proposal\b", "spec"),
    (r"\bis a plan\b", "spec"),
    # race-protocol-specific demands (high precision)
    (r"\brace brief\b", "audit"),
    (r"\bgrading instrument\b", "audit"),
    (r"\bsealed key\b", "audit"),
    (r"\bblind judge\b", "audit"),
    (r"\bgrader must\b", "audit"),
]

# slug+title keyword rules (ordered specific-beats-general).  "dispatch" is
# deliberately NOT an orchestration keyword: in titles it usually names the
# subject ("dispatch-verify deliverable reconcile" is infra tooling), not the
# task's own seat role.
TITLE_KW = [
    ("battery", ["battery", "mutant", "golden-master", "baseline", "tournament",
                 "bracket", "exhaustive", "movegen", "kifu", "discharge", "vb_",
                 "bellman", "scc", "smd1", "batt", "calibration",
                 "budget", "golden", "bakeoff", "bake-off", "arena"]),
    ("orchestration", ["orcha", "orchestrat", "seat", "triage", "inbox",
                       "crash-recovery", "dispatch-authoring", "console", "landmark",
                       "ruling", "sprint-console"]),
    ("audit", ["audit", "verify", "verif", "race", "probe", "falsif", "confirm",
               "grade", "grading", "re-audit", "reaudit", "second-auditor",
               "third-auditor", "cross-check", "independent", "review", "blinding",
               "rubric", "adjudicat", "discernment", "check", "reproducib",
               "invariance", "citation", "consistency", "discrepanc", "refut"]),
    ("integration", ["integration", "reframe", "consolidat", "absorb", "merge",
                     "repoint", "re-point", "unify", "migrate"]),
    ("research", ["research", "census", "survey", "inventory", "epistemic",
                  "taxonomy", "provenance", "study", "axiom", "theorem",
                  "termination", "patholog"]),
    ("spec", ["spec", "design", "strategy", "architecture", "plan", "blueprint",
              "proposal", "draft"]),
    ("implement", ["fix", "implement", "assert", "isolation", "alias", "desync",
                   "crosstalk", "hang", "leak", "flake", "gtp", "taskid", "propagat",
                   "bughunt", "clobber", "mutex", "recursion", "timeout", "hard-fail",
                   "repair", "oob", "intcast"]),
    ("infra", ["infra", "tooling", "managent", "claimlint", "runner", "fleet",
               "harness", "guard", "hygiene", "suite-truth", "ratchet", "manifest",
               "bisect", "onboarding", "normaliz", "diet", "restructure", "archive",
               "repoint", "regtest", "smoke", "stale", "metric", "telemetry",
               "budget", "gate", "duty"]),
]

DL_KW = [
    ("battery", ["battery", "mutant", "bracket", "baseline", "golden-master",
                 "tournament", "kifu", "discharge", "vb-"]),
    ("audit", ["audit", "verify", "verif", "race", "probe", "grade", "review",
               "cross-check", "adjudicat", "discernment"]),
    ("orchestration", ["orcha", "seat", "triage", "console", "dispatch-author"]),
    ("integration", ["integration", "reframe", "absorb", "merge", "consolidat",
                     "repoint", "migrat"]),
    ("research", ["census", "research", "survey", "inventory", "epistemic", "taxonomy"]),
    ("spec", ["spec", "design", "plan", "proposal", "blueprint", "draft"]),
    ("implement", ["fix", "implement", "repair", "leak", "hang", "bughunt", "timeout"]),
    ("infra", ["runner", "managent", "claimlint", "fleet", "harness", "guard", "tool"]),
]


def brief_text(b):
    try:
        body = open(b["brief_path"], encoding="utf-8", errors="replace").read()
    except Exception:
        body = ""
    return (b["title"] + " " + body)


def classify_legacy(tid, task):
    full = mp.classify_type(task)
    return SHORT[full], full


def classify_brief(tid, task, briefs):
    """Brief-aware. Returns (type, basis, evidence). basis in
    {declarative, title, deliverable, note, unknown}."""
    b = briefs.get(tid)
    title, body, note = "", "", " ".join([task.get("note") or "", task.get("verdict_note") or ""])
    if b:
        title = b["title"]
        body = brief_text(b)
    slug = (task.get("bundle") or "").rsplit("/", 1)[-1].replace(".md", "")

    if b:
        low = (title + " " + body + " " + note).lower()
        for pat, typ in DECLARATIVE:
            for m in re.finditer(pat, low):
                pre = low[max(0, m.start() - 30):m.start()]
                if re.search(r"not (?:a |an |the )?\w*$|no (?:a |an )?$", pre):
                    continue
                return typ, "declarative", m.group(0)
    hay = (slug + " " + title).lower()
    for typ, kws in TITLE_KW:
        for kw in kws:
            if kw in hay:
                return typ, "title", kw
    if b:
        for d in b["deliverables"]:
            base = d.lower()
            for typ, kws in DL_KW:
                if any(k in base for k in kws):
                    return typ, "deliverable", d
    for typ, kws in TITLE_KW:
        if typ == "orchestration":
            continue
        for kw in kws:
            if kw in note.lower():
                return typ, "note", kw
    return "UNKNOWN", "unknown", ""


if __name__ == "__main__":
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import lib as L
    from collections import Counter
    tasks = L.load_store()
    briefs = L.load_briefs()
    c = Counter()
    dis = 0
    for tid in sorted(tasks):
        t = tasks[tid]
        lt = classify_legacy(tid, t)[0]
        bt = classify_brief(tid, t, briefs)[0]
        c[bt] += 1
        dis += (lt != bt)
    print("rows:", len(tasks))
    print("brief-aware distribution:", dict(c.most_common()))
    print("disagreements (legacy vs brief):", dis)
