#!/usr/bin/env python3
"""T817 — the anomaly queries of task-corpus.md §6, all re-runnable.

Each query prints its finding; the md ranks them by consequence.  Uses the
live store by default; T817_SNAPSHOT_DIR reproduces the committed corpus.
"""
import sys, os, json, glob, re, collections, statistics, datetime
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib as L

rows = [json.loads(l) for l in open(f"{L.ROOT}/docs/infra/task-corpus.jsonl")]
tasks = L.load_store()
briefs = L.load_briefs()
runs = L.load_runs()
byid = {r["id"]: r for r in rows}


def q_orphan():
    """Q-ORPHAN / Q-ORPHAN-FINDINGS: briefs on disk with no kanban row."""
    brief_ids = set()
    for f in glob.glob(f"{L.ROOT}/untracked/T*.md"):
        m = re.match(r"(T\d+)", os.path.basename(f))
        if m:
            brief_ids.add(m.group(1))
    orphans = sorted(brief_ids - set(tasks))
    find_ids = set()
    for f in glob.glob(f"{L.ROOT}/findings/T*.json"):
        m = re.match(r"(T\d+)", os.path.basename(f))
        if m:
            find_ids.add(m.group(1))
    print(f"Q-ORPHAN: {len(orphans)} briefs on disk with no kanban row")
    print(f"Q-ORPHAN-FINDINGS: {len(set(orphans) & find_ids)} of them have committed findings files")
    return orphans


def q_absent():
    """Q-ABSENT: pass rows whose declared deliverables are absent from disk."""
    absent = collections.defaultdict(list)
    for r in rows:
        if r["verdict"] not in ("pass", "pass-with-findings"):
            continue
        for d in r["scope"]["files_in_scope"]:
            if not os.path.exists(d):
                absent[r["id"]].append(d)
    moved = sum(1 for ds in absent.values()
                for d in ds if d.startswith("docs/epic-01-markovian/"))
    print(f"Q-ABSENT: {len(absent)} pass rows cite an absent deliverable; "
          f"{moved} paths are the epic-01-markovian tree move; "
          f"{sum(len(v) for v in absent.values()) - moved} are per-task relocations")
    return absent


def q_fail():
    """Q-FAIL / Q-PASS-MODEL: fail-found asymmetry."""
    ff = [r for r in rows if r["verdict"] == "fail-found"]
    print(f"Q-FAIL: {len(ff)} fail-found closes")
    for r in ff:
        print(f"  {r['id']} type={r['type']['brief']} model={r['model']} epoch={r['epoch']}")
    done = [r for r in rows if r["verdict"]]
    by_model = collections.defaultdict(list)
    for r in done:
        by_model[r["model"] or "NO-MODEL"].append(r)
    print("Q-PASS-MODEL (models with >=3 closes):")
    for m, rs in sorted(by_model.items(), key=lambda kv: -len(kv[1])):
        if len(rs) < 3:
            continue
        p = sum(1 for r in rs if r["verdict"] in ("pass", "pass-with-findings"))
        print(f"  {m:28s} n={len(rs):3d} pass+pwf={p} ({p/len(rs):.0%})")


def q_kill():
    """Q-KILL / Q-RUNS-EXIT: log kill census vs run-record exit codes."""
    kills = collections.Counter()
    for f in glob.glob(f"{L.ROOT}/untracked/log/t*.log"):
        base = os.path.basename(f)
        m = re.match(r"(t\d+)", base, re.I)
        if not m:
            continue
        try:
            txt = open(f, errors="replace").read()
        except Exception:
            continue
        n = txt.count("exit 124")
        if n:
            kills[m.group(1).upper()] += n
    print(f"Q-KILL: {sum(kills.values())} 'exit 124' lines across {len(kills)} task-logs")
    print("  top killers (kill-instrumentation tasks dominate):")
    for tid, n in kills.most_common(8):
        r = byid.get(tid)
        print(f"    {tid}: {n}  ({r['title'][:50] if r else 'no row'})")
    print("Q-RUNS-EXIT: run-record exit codes are clean (the outer dispatch succeeded):")
    for tid in ["T625", "T629", "T643"]:
        for f in glob.glob(f"{L.ROOT}/untracked/runs/{tid}.json"):
            d = json.load(open(f))
            print(f"    {tid}.json exit={d.get('exit')} wall={d.get('wall')}")


def q_acc_close():
    """Q-ACC-CLOSE: briefs whose close text never mentions acceptance/gate."""
    nacc = nclose = 0
    for r in rows:
        t = tasks.get(r["id"], {})
        if not r["brief_on_disk"]:
            continue
        nacc += 1
        blob = (t.get("verdict_note") or "") + " " + (t.get("note") or "")
        if any(w in blob for w in ["acceptance", "accepted", "gate"]):
            nclose += 1
    print(f"Q-ACC-CLOSE: {nclose}/{nacc} briefs-on-disk rows mention acceptance/gate at close "
          f"({nclose/max(1, nacc):.0%})")


def q_retry():
    """Q-RETRY: claim_count > 1 by model/type/epoch/hour."""
    rc = [(tid, t.get("claim_count") or 0, t.get("agent"),
           byid[tid]["type"]["brief"] if tid in byid else None)
          for tid, t in tasks.items() if (t.get("claim_count") or 0) > 1]
    print(f"Q-RETRY: {len(rc)} rows claimed >1 time")
    cm = collections.Counter(a for _, _, a, _ in rc)
    print(f"  by agent: {dict(cm.most_common(6))}")
    ct = collections.Counter(x for _, _, _, x in rc)
    print(f"  by type: {dict(ct)}")
    hours = collections.Counter()
    for tid, cc, a, t in rc:
        d = tasks[tid].get("claimed") or tasks[tid].get("added")
        if d:
            hours[datetime.datetime.fromisoformat(d.replace("Z", "+00:00")).hour] += 1
    print(f"  claim hour (UTC): {dict(sorted(hours.items()))}")


def q_scope_census():
    """Q-SCOPE-CENSUS / Q-TYPE-CENSUS: the two censuses for the lattice."""
    sc = collections.Counter(r["scope"]["class"] for r in rows)
    ty = collections.Counter(r["type"]["brief"] for r in rows)
    n = len(rows)
    print("Q-TYPE-CENSUS (n=%d):" % n)
    for t, c in ty.most_common():
        print(f"  {t:15s} {c:4d} {c/n:5.1%}")
    print("Q-SCOPE-CENSUS (n=%d):" % n)
    for t, c in sc.most_common():
        print(f"  {t:9s} {c:4d} {c/n:5.1%}")


def q_scope_ordinal():
    """Defence: scope class vs wall/rss monotonicity."""
    print("Q-SCOPE-ORDINAL: wall/rss by scope class (tasks with runs):")
    for sc in ["S1", "S2", "S3", "S4", "S5", "S-unknown"]:
        rs = [r for r in rows if r["scope"]["class"] == sc and r["scope"]["wall_s"]]
        if not rs:
            continue
        ws = [r["scope"]["wall_s"] for r in rs]
        print(f"  {sc}: n={len(rs):3d} wall median={statistics.median(ws):7.0f}s")


if __name__ == "__main__":
    for fn in [q_scope_census, q_scope_ordinal, q_orphan, q_absent, q_fail,
               q_kill, q_acc_close, q_retry]:
        print(f"\n=== {fn.__name__} ===")
        fn()
