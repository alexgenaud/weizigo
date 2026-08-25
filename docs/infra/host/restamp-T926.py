#!/usr/bin/env python3
"""
restamp-T926.py — retire the 8 T924 rows' peak_rss_mb values, stamp
regime_observed + regime_mismatch on every row, and replace
peak_rss_mb_suspect with peak_rss_mb_retired (the T926 ruling: a suspect
number in an authoritative ledger must end up either corrected or gone,
not annotated forever).

The wrapper fix in tools/goban-scaling-capture.sh cannot re-measure
historical runs.  The wall, nodes, exit, and head fields are sound
(they came from the run's own output and from a wall clock — the brief
explicitly says so).  peak_rss_mb is the only field with no path back
to the truth, so it retires to null with a reason.

Re-stamp is git-tracked: the script is a one-shot tool, but its input
is the file in git, and its output is the file in git.  The history of
the rows is preserved (the rows themselves are not deleted; peak_rss_mb
is set to null, and the original numerical value is preserved in
peak_rss_mb_retired_value for archaeological readers who need to
reconstruct the post-T924 / pre-T926 reading).  The 8 T924 rows
otherwise remain in place with their sound fields.

Usage: python3 docs/infra/host/restamp-T926.py
       # no args; reads/writes docs/infra/host/goban-scaling.jsonl in place
"""
import json, sys
from pathlib import Path

LEDGER = Path(__file__).parent / "goban-scaling.jsonl"
RETIRE_REASON = "pre-T926 under-reports; see T926 for fix.  Row retired rather than annotated forever (Ruling: a suspect number in an authoritative ledger must end up corrected or gone).  The wall_s, nodes, exit, head fields are sound and remain."

# T924 was the only task on the ledger before T927.  The 4x4 row 7
# (writes-on, 1231s) is the row T924 marked as "writes-on" by hand after
# the wrapper trusted the wrong `writes-off` arg — but the actual
# command did NOT set RETRO_SOUND, so regime_observed=memo-reuse and
# regime_mismatch=True.  Rows 1-6 and 8 (regime=writes-off) likewise
# have regime_observed=memo-reuse and regime_mismatch=True (T924 set
# the arg to writes-off but did not set RETRO_SOUND).  All 8 rows are
# the same shape — the wrapper's regime arg was wrong, and the only
# row that survived was the one someone hand-corrected.  The
# post-T926 wrapper would have caught the rest.
def regime_observed_for(r):
    # Without RETRO_SOUND, the solver runs in memo-reuse mode (the
    # default).  T924 did not set RETRO_SOUND in any of its commands
    # (the wrap is `tools/goban-scaling-capture.sh N M regime T924 --
    # zig build-...`, no env-var assignment, no RETRO_SOUND=1 prefix).
    return "memo-reuse"

def restamp(r):
    r2 = dict(r)
    r2["regime_claimed"] = r.get("regime")
    r2["regime_observed"] = regime_observed_for(r)
    r2["regime_mismatch"] = r2["regime_claimed"] != r2["regime_observed"]
    if "peak_rss_mb" in r and r["peak_rss_mb"] is not None:
        r2["peak_rss_mb_retired_value"] = r["peak_rss_mb"]
        r2["peak_rss_mb"] = None
    if "peak_rss_mb_suspect" in r2:
        # T926: retire the suspect annotation rather than carry it
        # forever.  The reason lives in peak_rss_mb_retired_reason;
        # readers can grep the field to find the row.
        del r2["peak_rss_mb_suspect"]
    r2["peak_rss_mb_retired_reason"] = RETIRE_REASON
    return r2

def main():
    rows = [json.loads(l) for l in LEDGER.read_text().splitlines() if l.strip()]
    new_rows = [restamp(r) for r in rows]
    out = "\n".join(json.dumps(r, sort_keys=True) for r in new_rows) + "\n"
    LEDGER.write_text(out)
    n = sum(1 for r in new_rows if r.get("regime_mismatch"))
    n_retired = sum(1 for r in new_rows if r.get("peak_rss_mb") is None)
    print(f"restamp: {len(new_rows)} rows; {n_retired} retired (peak_rss_mb nulled); {n} regime_mismatch")

if __name__ == "__main__":
    main()
