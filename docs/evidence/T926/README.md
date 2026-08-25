# T926 lane death — oxalpha, 2026-08-25

Preserved because the originals are volatile (`untracked/runs/`, `untracked/log/`) and this is
the evidence for OPEN.md **B4**, rewritten the same day.

`run-record.json` — the runner's own record: **exit 0, wall 37.4 s, rss 158 MB, model oxalpha,
tokens null.**

`lane-death.log` — the last 20 lines of the lane log. The sequence that matters:

    [runner] exit 0 in 37.4 s
    [runner] auto-close net: declined — T926 is 'dispatchable', not in_progress;
             no open row to close (T862 ·3)
    [verify] worker exited 0 but the task never left dispatchable — verification FAILED
    [verify]   FAIL kanban: task T926 is still dispatchable (no claim/done recorded)

**The lane never claimed the row.** It exited cleanly in 37 seconds having done nothing at all —
not a nonce skipped, not a deliverable missed: no claim, no work, no output. A model declining to
follow protocol does not also decline to start.

Compare T924 the same day: 4,110 s, a complete 2×2→4×4 ladder with both arms, first-rate science,
and then exit 0 with **neither** declared deliverable written — consistent with a lane whose
budget or connection ended before the write-up.

Together these supersede B4's earlier reading ("does not reliably echo the dispatch nonce"). The
operator's diagnosis on 2026-08-25 — *"the model is just dying due to popular load"* — fits the
evidence; the protocol reading does not.
