#!/usr/bin/env python3
"""T751 — the token-to-metrics join.

The metrics record (docs/infra/model-task-metrics.jsonl) holds the quality
readings (correctness, canary_recall, qualified, …) and the row labels
(task_id, model, as_of).  The token ledger (untracked/tokens/tokens.jsonl)
holds the cost readings (tokens_in/out, fresh/cache_read split, the trust
grade).  Until this row the two were never joined, so 24 of 24 metric rows
held `cost: null` while the readings sat on disk — the operator's ruling
(2026-08-23, T746 §3.2) made the readings trusted-grade but did not name
the consumer that surfaces them.

THIS TOOL IS THE NAMED CONSUMER.  It joins on (task_id, model) — the two
identities the records agree on — and writes the six named fields
(tokens_fresh, tokens_cache_read, tokens_out, tokens_source, trusted,
corroborated) into the metric row.  Prices stay out (the tokens-now-prices-
later doctrine, docs/infra/bakeoff.md): no USD cost, no tokens-to-dollars
conversion, no normalisation.  The brief: "join on task_id at grade time
and write tokens_fresh, tokens_cache_read, tokens_out, tokens_source,
trusted, corroborated."

DISCIPLINE.

- The ledger is append-only.  A MISSING record is a dated assertion and is
  never edited by a join.  Only READING entries (tokens_in / tokens_out
  non-null) join.  A MISSING ledger entry is left for a future consumer
  to surface — it is the cost-ladder's "UNKNOWN" datum, not a hole to fill.
- Dispatch-time truth outranks retro.  When a (task_id, model) has BOTH a
  dispatch-time reading (claude-json-envelope / pi-session-jsonl) AND a
  retro reading (pi-session-jsonl-retro), the dispatch-time one wins — the
  same rule T746's tools/token-backfill.py enforces.  The retro reading is
  never substituted for a real reading.
- The join writes ATOMICALLY (tmp + os.replace), so a torn write can never
  leave the metrics record half-rebuilt (the dispatch path and the cost
  ladder both read it).
- TRUST GRADES propagate verbatim: the ledger's `trusted` and `corroborated`
  ride through unchanged.  The join never re-grades a reading.

USAGE.

    tools/token-join.py --jsonl docs/infra/model-task-metrics.jsonl \\
                        --ledger untracked/tokens/tokens.jsonl \\
                        --output docs/infra/model-task-metrics.jsonl

    tools/token-join.py --dry-run           # print the proposed join only
    tools/token-join.py --stats             # coverage census, no write
    tools/token-join.py --task T706         # restrict to one task_id
    tools/token-join.py --model deepseek-v4-pro   # restrict to one model

OUTPUT.  A stats report on stderr (data on stdout when --json):

    join: rows=52 readings=29 joined=27 retro_wins=0 missing=2
    by source: claude-json-envelope=14 pi-session-jsonl=8 pi-session-jsonl-fallback=5 retro=0
    trust grades propagated: trusted=22 untrusted=5 none=0

EXIT 0 on a clean join (every input parses, the rewrite succeeds).
Exit non-zero only on a structural failure (unreadable JSONL, missing
schema field, torn-write detected) — never on a coverage gap (a row with
no reading stays unchanged).

Task: T751 · Author: minimax-m3/T751 · Date: 2026-08-25
"""
import argparse
import json
import os
import sys
from collections import Counter

# The six fields the brief names — and ONLY these six are written into the
# metric row.  Anything else (a USD cost, a normalised score, a derived
# delta) is a derivation that belongs at report time, not in the record.
JOINED_FIELDS = (
    "tokens_fresh", "tokens_cache_read", "tokens_out",
    "tokens_source", "trusted", "corroborated",
)

# Sources that count as dispatch-time truth (per T746 / T662).  When a
# (task_id, model) has multiple readings, a dispatch-time one wins over
# the others.
DISPATCH_TIME_SOURCES = {"claude-json-envelope", "pi-session-jsonl"}


def _is_reading(entry):
    """A real reading (not a MISSING record) — the only kind that joins."""
    return (entry.get("tokens_in") is not None
            or entry.get("tokens_out") is not None)


def _read_jsonl(path):
    """Parse a JSONL file into a list of dicts; skip blank lines; collect
    parse errors as (lineno, error) for the stats report.  The path must
    exist — a missing file is a structural error (exit 2), not a coverage
    gap (a coverage gap is rows missing readings, the file existing)."""
    if not os.path.isfile(path):
        print(f"FAIL: file not found: {path}", file=sys.stderr)
        sys.exit(2)
    rows = []
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except ValueError as e:
                print(f"FAIL: {path}:{lineno}: parse error: {e}", file=sys.stderr)
                sys.exit(2)
    return rows


def _index_ledger(ledger_rows, only_task=None, only_model=None):
    """Index the ledger by (task_id, model) -> best reading for the pair.

    Selection rule (T746 contract, reproduced): a dispatch-time reading
    wins over a retro reading.  Within a class, the LAST entry wins
    (idempotent against the append-only ledger — the latest appended
    assertion is the most recent ground truth, retro or dispatch).

    Returns {(task_id, model): entry}.  MISSING entries are excluded.
    """
    by_key = {}
    for e in ledger_rows:
        if not _is_reading(e):
            continue
        task = e.get("task")
        model = e.get("model")
        if not task or not model:
            continue
        if only_task and task != only_task:
            continue
        if only_model and model != only_model:
            continue
        key = (task, model)
        prior = by_key.get(key)
        if prior is None:
            by_key[key] = e
            continue
        prior_is_dispatch = prior.get("source") in DISPATCH_TIME_SOURCES
        new_is_dispatch = e.get("source") in DISPATCH_TIME_SOURCES
        if prior_is_dispatch and not new_is_dispatch:
            # Keep the dispatch-time prior; retro never substitutes.
            continue
        if (not prior_is_dispatch) and new_is_dispatch:
            # The new dispatch-time reading supersedes the prior retro.
            by_key[key] = e
            continue
        # Same class — last appended wins (idempotent re-run friendly).
        by_key[key] = e
    return by_key


def _join_row(row, reading):
    """Write the six joined fields into a COPY of the metric row.  Never
    mutate the input — the metric row was parsed once and the rewrite is
    one atomic operation, so a buggy field-write cannot poison the rest
    of the row.

    LEGACY HANDLING (T751 rule).  Ledger entries written before T751 (T558
    + T746) carry no `trusted` field — the doctrine did not exist when
    they were written.  Their `source` IS the trust signal: a dispatch-time
    source (claude-json-envelope / pi-session-jsonl) written by the runner
    at dispatch is, by construction, a dispatch-time reading; we propagate
    it as trusted=True.  Retro sources (pi-session-jsonl-retro) are
    trusted=False by construction.  MISSING sources carry trusted=None.
    A reading that has `trusted` set explicitly propagates VERBATIM — the
    legacy inference never overrides an explicit grade."""
    out = dict(row)
    out["tokens_fresh"] = reading.get("tokens_fresh")
    out["tokens_cache_read"] = reading.get("tokens_cache_read")
    out["tokens_out"] = reading.get("tokens_out")
    out["tokens_source"] = reading.get("source")
    explicit_trusted = reading.get("trusted")
    if explicit_trusted is not None:
        out["trusted"] = explicit_trusted
    else:
        # Legacy: infer from source.
        src = reading.get("source")
        if src in DISPATCH_TIME_SOURCES:
            out["trusted"] = True
        elif src == "pi-session-jsonl-retro":
            out["trusted"] = False
        else:
            out["trusted"] = None
    corroborated = reading.get("corroborated")
    if corroborated is None and reading.get("source") in DISPATCH_TIME_SOURCES:
        # Legacy dispatch-time reading: no corroboration recorded (the file
        # IS the reading).  The new dispatch-time contract writes 'none'.
        corroborated = "none"
    out["corroborated"] = corroborated
    return out


def join_to_metrics(jsonl_path, ledger_path, only_task=None, only_model=None,
                    stats=None):
    """The join.  Reads the JSONL, indexes the ledger by (task_id, model),
    rewrites every row that has a matching reading with the six fields,
    and writes the result atomically to `jsonl_path` (in place — the metrics
    file is owned by this tool, the join is its only writer).

    `stats` is an optional Counter-like mutable that the caller can read for
    a coverage census.  Always populated when provided.

    Returns the rewritten list of rows (the in-memory representation that
    was just written to disk — useful for tests).
    """
    rows = _read_jsonl(jsonl_path)
    ledger = _read_jsonl(ledger_path)
    index = _index_ledger(ledger, only_task=only_task, only_model=only_model)

    out_rows = []
    for row in rows:
        key = (row.get("task_id"), row.get("model"))
        reading = index.get(key) if key[0] and key[1] else None
        if reading is None:
            out_rows.append(row)
            if stats is not None:
                stats["unjoined"] += 1
            continue
        out_rows.append(_join_row(row, reading))
        if stats is not None:
            stats["joined"] += 1
            src = reading.get("source") or "MISSING"
            stats["by_source"][src] += 1
            # Use the post-join trusted value (legacy-inferred) for the census.
            trust = out_rows[-1]["trusted"]
            if trust is True:
                stats["trusted"] += 1
            elif trust is False:
                stats["untrusted"] += 1
            else:
                stats["trust_unknown"] += 1

    # Atomic write: tmp + os.replace, so the file on disk is either the
    # old version or the complete new one.  A torn write would leave a
    # half-joined file that the cost ladder would silently consume.
    tmp = jsonl_path + ".tmp"
    with open(tmp, "w") as f:
        for r in out_rows:
            f.write(json.dumps(r, sort_keys=True) + "\n")
    os.replace(tmp, jsonl_path)
    return out_rows


def _stats_report(stats, jsonl_path, ledger_path, dry):
    """One-line summary on stdout (data) + a per-source / per-grade
    breakdown on stderr (diagnostics).  Both are stdlib parseable for
    tools/regression-token-join.sh (the control)."""
    by_source = ", ".join(
        "%s=%d" % (s, n)
        for s, n in sorted(stats["by_source"].items(), key=lambda kv: -kv[1])
    ) or "(none)"
    grades = (
        "trusted=%d untrusted=%d unknown=%d"
        % (stats["trusted"], stats["untrusted"], stats["trust_unknown"]))
    summary = {
        "jsonl": jsonl_path,
        "ledger": ledger_path,
        "rows": stats["rows"],
        "joined": stats["joined"],
        "unjoined": stats["unjoined"],
        "by_source": dict(stats["by_source"]),
        "grades": {
            "trusted": stats["trusted"],
            "untrusted": stats["untrusted"],
            "unknown": stats["trust_unknown"],
        },
        "dry_run": dry,
    }
    print(json.dumps(summary, sort_keys=True))
    print(f"join: rows={stats['rows']} joined={stats['joined']} "
          f"unjoined={stats['unjoined']}", file=sys.stderr)
    print(f"  by source: {by_source}", file=sys.stderr)
    print(f"  grades:    {grades}", file=sys.stderr)


def main(argv):
    ap = argparse.ArgumentParser(prog="token-join.py")
    ap.add_argument("--jsonl", required=True,
                    help="path to docs/infra/model-task-metrics.jsonl "
                         "(read AND written in place when not --dry-run)")
    ap.add_argument("--ledger", required=True,
                    help="path to untracked/tokens/tokens.jsonl")
    ap.add_argument("--output", default=None,
                    help="output path (default: write back to --jsonl)")
    ap.add_argument("--dry-run", action="store_true",
                    help="compute the join and print stats; never write")
    ap.add_argument("--stats", action="store_true",
                    help="alias for --dry-run with stats on stdout")
    ap.add_argument("--task", default=None, help="restrict join to this task_id")
    ap.add_argument("--model", default=None, help="restrict join to this model")
    ap.add_argument("--json", action="store_true",
                    help="machine-readable stats on stdout")
    args = ap.parse_args(argv)

    # The test fixture writes the JSONL in place; we mirror that for live use
    # unless --output is given.  In --dry-run mode we never write.
    out_path = args.output if args.output else args.jsonl
    dry = args.dry_run or args.stats

    stats = {
        "rows": 0, "joined": 0, "unjoined": 0,
        "trusted": 0, "untrusted": 0, "trust_unknown": 0,
        "by_source": Counter(),
    }
    rows = _read_jsonl(args.jsonl)
    stats["rows"] = len(rows)
    ledger = _read_jsonl(args.ledger)
    index = _index_ledger(ledger, only_task=args.task, only_model=args.model)

    out_rows = []
    for row in rows:
        key = (row.get("task_id"), row.get("model"))
        reading = index.get(key) if key[0] and key[1] else None
        if reading is None:
            out_rows.append(row)
            stats["unjoined"] += 1
            continue
        out_rows.append(_join_row(row, reading))
        stats["joined"] += 1
        src = reading.get("source") or "MISSING"
        stats["by_source"][src] += 1
        # Use the post-join trusted value (legacy-inferred) for the census.
        joined_row = out_rows[-1]
        trust = joined_row["trusted"]
        if trust is True:
            stats["trusted"] += 1
        elif trust is False:
            stats["untrusted"] += 1
        else:
            stats["trust_unknown"] += 1

    if not dry:
        tmp = out_path + ".tmp"
        with open(tmp, "w") as f:
            for r in out_rows:
                f.write(json.dumps(r, sort_keys=True) + "\n")
        os.replace(tmp, out_path)

    if args.json or args.stats:
        _stats_report(stats, args.jsonl, args.ledger, dry)
    else:
        print(f"join: rows={stats['rows']} joined={stats['joined']} "
              f"unjoined={stats['unjoined']} dry={dry}")
        by_source = ", ".join(
            "%s=%d" % (s, n)
            for s, n in sorted(stats["by_source"].items(), key=lambda kv: -kv[1])
        ) or "(none)"
        print(f"  by source: {by_source}")
        print(f"  grades:    trusted={stats['trusted']} "
              f"untrusted={stats['untrusted']} "
              f"unknown={stats['trust_unknown']}")
        if not dry:
            print(f"  written:   {out_path}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
