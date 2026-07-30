<!--managent set=A holds=src/managent/main.zig-->
# T122 — `managent` memory-safety: audit crashes, status output corrupts

**Type:** MUTATION · **Holds:** `src/managent/main.zig` · **Priority:** the whole
Orchestrator cadence reads through these two commands.

## Defect 1 — `managent audit` bus-errors after printing (confirmed, one line)

`src/managent/main.zig:2534` frees `f.level`:

```zig
defer {
    for (findings.items) |f| {
        alloc.free(f.level);   // <-- f.level is always a string literal
        alloc.free(f.msg);
    }
    findings.deinit(alloc);
}
```

Every `.level` assignment in the function is a literal — `"FIX"` or `"WARN"`
(`:2563, :2573, :2585, :2592, :2619, :2629, :2652, :2655, :2673, :2682, :2689,
:2704, :2724, :2745`). Freeing `.rodata` bus-errors. `.msg` is allocated and
its free is correct.

Reproduce: any state with ≥1 finding. Findings print, then:

```
Bus error at address 0x...
  .../std/mem/Allocator.zig:448:5: in free__anon_...
  src/managent/main.zig:2534:23: in cmdAudit
```

**Consequence beyond the crash.** `ORCHESTRATOR.md` cadence step 2 reads
"Non-zero exit = FIX-level findings exist". The crash makes the exit status
mean *crashed*, not *findings*, so the documented signal has been unreliable
for as long as this has been in. Fix is deleting the `alloc.free(f.level)`
line; then verify the exit code actually distinguishes FIX from clean.

## Defect 2 — `managent status` prints garbage (non-deterministic)

After the T120 purge left a single task, `status` emits fragments out of order
and sometimes nothing at all. Two consecutive runs, same state:

```
$ bin/managent status
   -- none --
(0)
/dispatch/T120-terminology-sweep.md

$ bin/managent status
                       # (no output)
```

`--json` is corrupt the same way — `]` first, then a truncated object, no
opening `[`:

```
$ bin/managent status --json
]
 {"id":"T120","status":"dispatchable","set":"A","bundle":"docs/..."
```

`docs/infra/managent/tasks.json` is **intact and correct** throughout — this is
output-path only, not state corruption. Non-determinism across identical runs
points at a use-after-free or a flush-ordering bug between buffered writers
rather than a formatting mistake.

**Suspect:** `STREAM-DISCIPLINE` split stdout/stderr across 8 files behind
`util.out` / `note` / `warn` (445+53 call sites). That task's regression checks
passed, so whatever they checked did not cover this. Start by auditing writer
lifetime and flush order in `cmdStatus` (`:1603`) — confirm every writer is
flushed before the process exits and that no writer outlives its buffer.

Defect 1 corrupts the allocator, so check whether it can reach `status` through
a shared path before assuming the two are independent. Fix defect 1 first and
re-test defect 2.

## Acceptance

- `managent audit` exits cleanly with findings present; exit code distinguishes
  FIX-level findings from a clean run.
- `managent status` and `status --json` produce complete, correctly ordered
  output at 0, 1, and >20 tasks. `--json` parses with `jq`.
- A regression check covering the 1-task case, which is what exposed this.
- `cp zig-out/bin/managent bin/managent` — or the binary stays stale.

## Deliverable

The fix, the regression check, and a short note in
`docs/infra/managent/spec.md` on the audit exit-code contract.
