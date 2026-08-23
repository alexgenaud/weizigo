# Directive-ID dedupe — 2026-08-23

**Author:** claude-opus-5/T757 · **Ruling:** operator R5, 2026-08-23
(`findings/T745-terminology.json`) — cleanup-and-relink, not tombstone archaeology.

`docs/infra/managent/directives.jsonl` had reused the same `D<nnn>` tokens across three eras of
fleet activity, so a citation like "D041" named three different directives. This note is the
single place that resolves them. No line was deleted, no other field was touched, and the
citations already written into findings were left verbatim — they resolve through the map below.

## What was found

- **129 directive records**; **32 IDs** were duplicated across **88 records**.
- Three reuse eras: 2026-08-04→06, 2026-08-19→20, 2026-08-22→23. `D021` alone had six records.
- A fourth-era leak landed *during this row*: `managent tell T760` minted a sixth `D021` at
  12:29Z. T758 committed the mint-from-ledger-max fix at `be87b34`, but `bin/managent` was still
  built from `e8c3999-dirty` — the fix was committed and never deployed. Deploying it is T758's
  remaining step, not this row's.
- **The ledger is 75% blank lines** — 384 of 513 lines carry nothing. Same write path, and left
  alone here because compacting it would renumber every line. Recorded, not fixed.
- **One cited directive is absent from the ledger.** `findings/T684-landmark-backfill.json` acks a
  `D042` "SCOPE CUT" at 2026-08-22T20:29+; no record in `directives.jsonl` carries that text or
  that timestamp. The T757 brief's survivor guidance rests on it, so that guidance could not be
  followed as written (see below). A directive was delivered and the ledger did not keep it.

## The rule applied

**The earliest record by timestamp keeps the bare ID; later records take `b`, `c`, `d`, … in
timestamp order.** 56 records re-issued, 32 survivors kept their bare token.

The brief asked for per-ID survivors chosen so that existing findings citations resolve to the
intended line. That is not achievable and the rule above replaces it, for two reasons worth
recording rather than hiding:

1. **The heavily-cited IDs are cited from every era.** `D041` is cited by 19 files spanning
   2026-08-05, -08-20 and -08-23 referents; no single survivor satisfies them. The map resolves
   those citations by date, which is the job the bare token cannot do.
2. **The brief's two anchors do not match the ledger.** T683/T684 cite the SCOPE CUT as `D042`,
   not `D041`, and that record is missing entirely; and the `D041` directive to T543
   (2026-08-20) is the middle of three generations, not the earliest.

Earliest-keeps-bare is deterministic, reproducible by anyone re-reading the ledger, and stable as
new duplicates appear — a citation-weighted choice would have to be re-litigated every time.

## Why this is safe

Read receipts are in-place fields (`read`, `read_by`, `read_at`) on the same record, so re-keying
`id` cannot orphan them. `managent inbox` and `managent tell` match on **target** and the read
flag, never on ID, so delivery and acking are unaffected. Verified after the rewrite: 129 records,
129 unique IDs, and a field-masked diff shows the two files identical apart from `id` values.

## How to resolve a citation

Find the ID in the "cited as" column; the row whose **date** matches the citing document's era is
the one meant. Where a citing document gives no date, prefer the record whose `target` is the
citing task.

| cited as | now | timestamp | target | from |
|---|---|---|---|---|
| `D021` | `D021` | 2026-08-04T16:12:49Z | T355 | unknown |
| `D021` | `D021b` | 2026-08-19T13:15:23Z | ORCHA | deepseek-v4-flash/T466 |
| `D021` | `D021c` | 2026-08-22T12:10:39Z | T587 | deepseek-v4-pro/T568 |
| `D021` | `D021d` | 2026-08-22T13:05:51Z | T625 | T612 |
| `D021` | `D021e` | 2026-08-23T02:04:58Z | T720 | fable/holistic via Orcha |
| `D021` | `D021f` | 2026-08-23T12:29:41Z | T760 | unknown |
| `D022` | `D022` | 2026-08-04T16:16:15Z | T355 | T355-test |
| `D022` | `D022b` | 2026-08-19T23:07:31Z | T496 | ORCHA-flash |
| `D022` | `D022c` | 2026-08-22T13:19:09Z | T625 | deepseek-v4-pro/T544 |
| `D023` | `D023` | 2026-08-04T16:16:17Z | T355 | T355-test |
| `D023` | `D023b` | 2026-08-19T23:17:11Z | T496 | ORCHA-flash |
| `D023` | `D023c` | 2026-08-22T14:33:20Z | T632 | T612 |
| `D024` | `D024` | 2026-08-04T16:16:17Z | T355 | T355-test |
| `D024` | `D024b` | 2026-08-20T00:52:24Z | T499 | ORCHA-flash |
| `D024` | `D024c` | 2026-08-22T16:42:02Z | T644 | T612 |
| `D025` | `D025` | 2026-08-04T16:43:39Z | T356 | unknown |
| `D025` | `D025b` | 2026-08-20T01:41:59Z | T503 | ORCHA-flash |
| `D025` | `D025c` | 2026-08-22T16:42:02Z | T645 | T612 |
| `D026` | `D026` | 2026-08-04T19:33:51Z | T335 | unknown |
| `D026` | `D026b` | 2026-08-20T01:42:04Z | T503 | ORCHA-flash |
| `D026` | `D026c` | 2026-08-22T16:42:02Z | T646 | T612 |
| `D027` | `D027` | 2026-08-04T20:17:02Z | T335 | unknown |
| `D027` | `D027b` | 2026-08-20T01:54:16Z | T503 | ORCHA-flash |
| `D027` | `D027c` | 2026-08-22T16:42:02Z | T647 | T612 |
| `D028` | `D028` | 2026-08-04T20:33:08Z | T335 | unknown |
| `D028` | `D028b` | 2026-08-20T02:48:00Z | T353 | ORCHA-flash |
| `D028` | `D028c` | 2026-08-22T16:42:02Z | T648 | T612 |
| `D029` | `D029` | 2026-08-04T20:33:08Z | T355 | unknown |
| `D029` | `D029b` | 2026-08-20T02:48:00Z | T362 | ORCHA-flash |
| `D029` | `D029c` | 2026-08-22T17:16:46Z | T644 | T612 |
| `D030` | `D030` | 2026-08-04T20:33:08Z | T356 | unknown |
| `D030` | `D030b` | 2026-08-20T03:00:11Z | T430 | unknown |
| `D030` | `D030c` | 2026-08-22T17:16:46Z | T645 | T612 |
| `D031` | `D031` | 2026-08-04T21:17:10Z | T335 | unknown |
| `D031` | `D031b` | 2026-08-20T03:07:35Z | T432 | unknown |
| `D031` | `D031c` | 2026-08-22T17:16:46Z | T646 | T612 |
| `D032` | `D032` | 2026-08-04T21:17:10Z | T355 | unknown |
| `D032` | `D032b` | 2026-08-20T03:12:56Z | ORCHA-FLASH | unknown |
| `D032` | `D032c` | 2026-08-22T17:16:46Z | T647 | T612 |
| `D033` | `D033` | 2026-08-04T21:17:10Z | T356 | unknown |
| `D033` | `D033b` | 2026-08-20T03:33:09Z | ORCHA | T353 |
| `D033` | `D033c` | 2026-08-22T17:16:46Z | T648 | T612 |
| `D034` | `D034` | 2026-08-04T23:46:36Z | T355 | unknown |
| `D034` | `D034b` | 2026-08-20T03:37:07Z | T364 | unknown |
| `D034` | `D034c` | 2026-08-22T21:34:29Z | T583 | T612 |
| `D035` | `D035` | 2026-08-04T23:46:36Z | T356 | unknown |
| `D035` | `D035b` | 2026-08-20T03:42:02Z | T364 | T353.4 |
| `D035` | `D035c` | 2026-08-22T21:34:29Z | T698 | T612 |
| `D036` | `D036` | 2026-08-04T23:46:36Z | T361 | unknown |
| `D036` | `D036b` | 2026-08-20T12:18:47Z | T536 | unknown |
| `D036` | `D036c` | 2026-08-22T23:28:31Z | T687 | deepseek-v4-flash/T699 |
| `D037` | `D037` | 2026-08-05T12:14:53Z | T363 | unknown |
| `D037` | `D037b` | 2026-08-20T12:38:37Z | T540 | unknown |
| `D037` | `D037c` | 2026-08-22T23:28:31Z | T693 | deepseek-v4-flash/T699 |
| `D038` | `D038` | 2026-08-05T12:17:11Z | T363 | opus-5/Orcha |
| `D038` | `D038b` | 2026-08-20T12:40:48Z | T543 | unknown |
| `D038` | `D038c` | 2026-08-23T00:59:31Z | Orchestrator | deepseek-v4-pro/T630 |
| `D039` | `D039` | 2026-08-05T12:17:23Z | T366 | opus-5/Orcha |
| `D039` | `D039b` | 2026-08-20T12:40:48Z | T542 | unknown |
| `D039` | `D039c` | 2026-08-23T01:27:13Z | T700 | deepseek-v4-flash/T525 |
| `D040` | `D040` | 2026-08-05T12:17:23Z | T367 | opus-5/Orcha |
| `D040` | `D040b` | 2026-08-20T12:42:46Z | T537 | deepseek-v4-pro/T538 |
| `D040` | `D040c` | 2026-08-23T01:57:43Z | T720 | fable/holistic via Orcha |
| `D041` | `D041` | 2026-08-05T12:18:53Z | T363 | opus-5/Orcha |
| `D041` | `D041b` | 2026-08-20T12:45:06Z | T543 | unknown |
| `D041` | `D041c` | 2026-08-23T01:57:43Z | T721 | fable/holistic via Orcha |
| `D042` | `D042` | 2026-08-05T20:19:03Z | T380 | claude-opus-5 |
| `D042` | `D042b` | 2026-08-20T12:51:42Z | T519 | unknown |
| `D043` | `D043` | 2026-08-06T00:25:28Z | T387 | claude-opus-5 |
| `D043` | `D043b` | 2026-08-20T12:54:24Z | T521 | unknown |
| `D046` | `D046` | 2026-08-06T01:34:27Z | T387 | claude-opus-5 |
| `D046` | `D046b` | 2026-08-20T12:54:52Z | DARGUS | unknown |
| `D047` | `D047` | 2026-08-06T01:49:57Z | T389 | claude-opus-5 |
| `D047` | `D047b` | 2026-08-20T12:55:28Z | T544 | unknown |
| `D048` | `D048` | 2026-08-06T01:50:23Z | T350 | claude-opus-5 |
| `D048` | `D048b` | 2026-08-20T13:05:11Z | T538 | unknown |
| `D049` | `D049` | 2026-08-06T01:51:24Z | T350 | claude-opus-5 |
| `D049` | `D049b` | 2026-08-20T13:07:26Z | T544 | unknown |
| `D050` | `D050` | 2026-08-06T01:54:08Z | T390 | claude-opus-5 |
| `D050` | `D050b` | 2026-08-20T13:07:51Z | T544 | unknown |
| `D051` | `D051` | 2026-08-06T07:58:15Z | T392 | claude-opus-5 |
| `D051` | `D051b` | 2026-08-20T14:19:38Z | T541 | unknown |
| `D052` | `D052` | 2026-08-06T14:17:12Z | T392 | claude-opus-5 |
| `D052` | `D052b` | 2026-08-20T15:19:27Z | T546 | unknown |
| `D053` | `D053` | 2026-08-06T14:45:42Z | T394 | opus/orcha |
| `D053` | `D053b` | 2026-08-20T17:12:21Z | T551 | unknown |
| `D054` | `D054` | 2026-08-06T15:30:25Z | T387 | claude-opus-5/orcha |
| `D054` | `D054b` | 2026-08-20T17:24:22Z | T551 | unknown |
