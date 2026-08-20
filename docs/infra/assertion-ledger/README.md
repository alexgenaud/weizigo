# Assertion ledger — retired 2026-08-19

The artifact formerly at `docs/infra/assertion-ledger/{spec.md,verdict.md,
assertions.jsonl}` was a third copy of evidence that better lives in
`docs/infra/managent/tasks.json` + git + `findings/`. Per the verdict it
generated (`docs/infra/assertion-ledger/archive/verdict-2026-08-19.md`),
KILL THE LEDGER AS A STANDALONE ARTIFACT, MIGRATE THE ASSERTIONS, was
adopted under T495 (correction sprint, 2026-08-19). The verdict's
recommendation was to retire the directory; the spec, the verdict, and the
17 assertions are archived at the paths below for browsing.

| archived file | what it was |
|---|---|
| `docs/infra/assertion-ledger/archive/spec-2026-08-08.md` | T426's design (`T426 · 2026-08-08`); diagnosis and data model that were never finished — every one of 17 entries had `actor: "unknown"` despite the spec mandating `<model>/<role>`. |
| `docs/infra/assertion-ledger/archive/verdict-2026-08-19.md` | T461's verdict (`T461 · 2026-08-19`); three falsifications of the diagnosis, migration table, and operator asks that have now been resolved. |
| `docs/infra/assertion-ledger/archive/assertions-2026-08-19.jsonl` | the 17 assertions written between 2026-08-08 and 2026-08-19; A0004–A0017 migrated per the verdict table, A0018–A0020 were stopgaps for T464 (T497 fixes the resolver's two-source defect). |

The ledger is not the authority for any question. The authority is the
kanban (`bin/managent show <id>` and `bin/managent status`), git
(`git log --grep=<task-id>`), and `findings/` (one JSON file per task).
Three sources; no fourth.

`managent assert` is retained as a power tool for Orchestrator-typed
consoles; it writes to a no-op target. No kanban or dashboard integration
is needed for it to be useful as a free-form append-only log.
