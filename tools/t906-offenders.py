#!/usr/bin/env python3
# T906 offender-list generator (scope item 3): rows still dispatchable or
# blocked whose bundle title is missing or over 40 chars, with a suggested
# short title each — a deliverable the seat can apply.  It does NOT edit
# anything: several offender rows are held by other rows, and historical
# titles are part of the record (fix forward, T906).
#
# Title extraction shares the registration gate / dispatch grammar:
#   ^#\s+\S+\s+(?:\u2014|--|-)\s+(.+?)\s*$
# (any id token — the fleet mints T<digits> ids, but duties are
# DARGUS/STANDING-* and fixtures use arbitrary ids; the 40-char rule is
# about the TITLE portion, not the id's shape) so this list and the gate
# measure the same thing.
#
# Usage:  python3 tools/t906-offenders.py [--json findings/T906-title-gate-offenders.json]
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORE = os.path.join(ROOT, "docs/infra/managent/tasks.json")
TITLE_RE = re.compile(r"^#\s+\S+\s+(?:\u2014|--|-)\s+(.+?)\s*$")
LIMIT = 40

def title_of_bundle(path):
    """Returns the title portion (or None): the text after `# <id> — ` in
    the first matching line.  The grammar is the one the registration gate
    and dispatch share (`#\s+\S+\s+(?:\u2014|--|-)\s+<title>` — any id
    token, so DARGUS/STANDING-* duties are measured like any brief)."""
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = TITLE_RE.match(line.strip())
                if m:
                    return m.group(1)
    except OSError:
        return None
    return None

def main():
    out_path = None
    if len(sys.argv) > 1 and sys.argv[1] == "--json":
        out_path = sys.argv[2]
    tasks = json.load(open(STORE))
    offenders = []
    counts = {"dispatchable": 0, "blocked": 0, "over40": 0, "no-title-line": 0, "dangling": 0}
    for tid, row in sorted(tasks.items()):
        if tid.startswith("_"):
            continue
        if row.get("status") not in ("dispatchable", "blocked"):
            continue
        bundle = row.get("bundle") or ""
        if not bundle:
            continue
        path = bundle if os.path.isabs(bundle) else os.path.join(ROOT, bundle)
        if not os.path.exists(path):
            counts[row["status"]] += 1
            counts["dangling"] += 1
            offenders.append({
                "id": tid, "status": row["status"], "bundle": bundle,
                "title": None, "length": 0, "class": "dangling",
                "duty": bool(row.get("duty")),
                "suggested": f"{tid}: stored bundle path is unreadable — fix the row's bundle path or its brief",
            })
            continue
        title = title_of_bundle(path)
        if title is None:
            cls = "no-title-line"
        elif len(title) > LIMIT:
            cls = "over40"
        else:
            continue
        counts[row["status"]] += 1
        counts[cls] += 1
        offenders.append({
            "id": tid,
            "status": row["status"],
            "bundle": bundle,
            "title": title,
            "length": len(title) if title else 0,
            "class": cls,
            "duty": bool(row.get("duty")),
            "suggested": suggest(title, tid),
        })
    summary = {
        # Schema-conformant findings record (claimlint C7 scans every
        # findings/*.json — a non-conforming file makes `c7 --json` exit 1):
        # the offender census rides in the `notes` and a custom field, the
        # register rows are empty (T906 proposes no claim changes).
        "task_id": "T906",
        "date": "2026-08-24",
        "model": "deepseek-v4-flash",
        "claims": [],
        "new_rows": [],
        "rule": "DELEGATOR.md §Task titles: one line, under 40 chars (the title PORTION after `# <id> — `)",
        "limit": LIMIT,
        "rows_measured": counts["dispatchable"] + counts["blocked"],
        "counts": counts,
        "offenders": offenders,
    }
    if out_path:
        with open(out_path, "w") as f:
            json.dump(summary, f, indent=1, ensure_ascii=False)
        print(f"wrote {out_path}: {len(offenders)} offenders "
              f"({counts['over40']} over-40, {counts['no-title-line']} no-title-line, "
              f"{counts['dangling']} dangling) across dispatchable/blocked rows")
    else:
        print(json.dumps(summary, indent=1, ensure_ascii=False))

def suggest(title, tid):
    """A ≤40-char human-shaped short title.  Truncation is the fallback; the
    seat may prefer its own wording — the suggestion is a starting point."""
    if title is None:
        return f"{tid} re-titled at the seat's wording"
    t = title.strip()
    # strip a trailing parenthetical (often the over-long part)
    short = re.sub(r"\s*\(.*\)\s*$", "", t).strip()
    if len(short) > LIMIT:
        short = t
    if len(short) > LIMIT:
        # cut at the last word boundary before the limit
        cut = short[:LIMIT]
        cut = cut[: cut.rfind(" ")] if " " in cut else cut
        short = cut.rstrip(" ,;:-")
    return short

if __name__ == "__main__":
    main()
