# Orcha-tools — T196 consumer acceptance (R1–R3 vs spec rev 1)

```
Author:   DSFlash/T196 · 2026-08-01
Scope:    managent suggest (R1), done deliverable check (R2), audit
          cross-citation flag (R3) vs docs/epic-01-markovian/sprints/
          orcha-tools/pass0/spec.md rev 1 (PROPOSED).
Method:   consumer-load tests on a sandbox copy of the repo
          (/tmp/weizigo/orcha-accept, rsync of HEAD 15029b5 + working
          tree, minus data/ and *.wzo), live binary bin/managent
          (built 2026-07-31 18:42 from src 16:55; zig-out build
          2026-08-01 09:07, same source), plus one read-only live
          audit probe on the real kanban.
Verdict:  A2 PASS · A3 PASS · A1 FAIL on the live repo state
          (T-ID collision clobbers a done record). Fix needed before
          promote.
```

## 0. Verdict

**NEEDS-FIX — one load-bearing defect.** A2 (done deliverable check) and
A3 (audit cross-citation flag) work as specced, both directions, fixtures
included. A1 (suggest) works on a healthy counter but **mints an in-use
T-ID and overwrites the existing record** whenever `_sys.next_id` has
drifted — which is the current live state (next_id=165 while T165–T197
are all registered). Reproduced twice in the sandbox: T165 (done, agent
DSPro, done=2026-07-31T16:35:41Z → dispatchable, agent/done/claimed
nulled) and T202 (hand-added in_progress fixture → dispatchable).
The prompt line, bundle, and stdout/stderr contract are all correct.

## 1. A1 — `managent suggest <slug>` — FAIL on live state

Requirement: prints next available T-ID, creates `untracked/T<id>-<slug>.md`,
outputs `You are <model>/T<id>. ...`.

Happy path (sandbox, counter corrected to 198): PASS.

- `PI_MODEL=DSFlash ./bin/managent suggest happy-path-test` →
  stdout `You are DSFlash/T198. happy-path-test` (one line, exit 0);
  stderr carries `suggested T198 ... bundle: untracked/T198-happy-path-test.md`.
- Bundle created: `untracked/T198-happy-path-test.md` =
  `<!--managent set=A-->` + `# T198 — happy-path-test`. ✓
- Sequential minting T198→T199→T200→T201 verified. ✓
- `2>/dev/null` yields only the prompt line (stdout=data); `1>/dev/null`
  yields only diagnostics (stderr=diagnostics). ✓
- `--model DeepSeek-V3.1 --set B` honoured (prompt line + `set=B` meta). ✓
- No PI_MODEL → `You are unknown/T201. ...` (AGENTS.md fallback). ✓

Collision path (current live state): FAIL.

- Live `_sys.next_id` = 165; T165, T166, …, T197 are all registered
  (verified in tasks.json history: next_id frozen at 165 since the
  2026-07-31 17:59 "Register T165-T167" commit; the 17:15 fix had set
  166, and every later registration was by hand with explicit IDs).
- `cmdSuggest` (src/managent/main.zig:1300) mints `T{d:0>3}` from
  `sys_next_id` with **no collision check**; `state.put` is an upsert.
- Sandbox repro #1: `suggest accept-load-test` → `suggested T165`,
  `You are DSFlash/T165. accept-load-test`, and tasks.json T165 changed
  from `{status: done, agent: DSPro, claimed: …, done: 2026-07-31T16:35:41Z}`
  to `{status: dispatchable, agent: null, claimed: null, done: null}` —
  the done record (attribution + audit trail) is destroyed.
- Sandbox repro #2 (unintentional, during `--model` test): `suggest
  flagged-test --model …` minted T202 over a hand-added T202 fixture.
- Same unguarded pattern in `add --auto` (main.zig:935–969).

Consequence: on the live repo, the next `managent suggest <slug>` will
print T165 and silently destroy the completed T165 record. "next
available" is not guaranteed by construction; it relies on the human
keeping `_sys.next_id` current (the 2026-07-31 17:15 "Fix _sys.next_id"
commit shows this is a known-fragile spot).

## 2. A2 — `managent done <id>` deliverable check — PASS

Requirement: verifies declared deliverables exist on disk; refuses with
message if missing; non-zero exit; task stays in_progress.

- Fixture: T198 claimed; bundle appended
  `Deliverables: src/managent/nonexistent-deliverable.zig`.
- `managent done T198 --agent DSPro/T196` → exit 1, stderr
  `REJECTED: T198 has 1 missing deliverable(s): - src/managent/nonexistent-deliverable.zig`,
  `Task stays in_progress. Create the file(s) or use --fail.`;
  tasks.json T198 stays `in_progress`, `done` null. ✓
- Positive control: `touch` the file → `managent done T198 --agent
  DSPro/T196` → exit 0, `T198 done`, status `done`, done timestamp set. ✓
- Holds-fallback: T202 fixture with bundle lacking a `Deliverables:`
  marker and holds=`docs/epistemic/never-created.md` → same refusal,
  exit 1, stays in_progress. ✓
- Traced one evaluation end-to-end: bundle read → marker parse
  (parseDeliverablesFromBundle, main.zig:1363–1438) → path joined to
  repo_root → statFile fails → refusal. Confirmed in the code and by
  the live probes.

## 3. A3 — `managent audit` cross-citation flag — PASS

Requirement: flags done tasks whose deliverable paths are not cited in
CLAIMS.md or PROGRESS.md.

Spec fixture (reconstructed as written): T129 added to sandbox kanban as
done (bundle `docs/infra/dispatch/T129-exp7-4x4-rerun.md`, deliverable
`docs/evidence/QA-027/4x4/PROVENANCE.md`), audited against the
pre-absorption docs (commit a26ffe6, 2026-07-31 01:36 — PROGRESS.md has
only `[QA-027:CLAIMED]`, no 4×4 falsification; CLAIMS.md has no
QA-027/4x4 citation; neither file mentions "T129").

- `managent audit` → `[WARN] T129: done but deliverables not cited in
  CLAIMS.md or PROGRESS.md — promote or cite`. ✓
- Positive control: swap in post-absorption CLAIMS.md/PROGRESS.md (T129
  cited at PROGRESS.md:4; deliverable cited at CLAIMS.md row 567) →
  T129 citation finding disappears; a still-uncited fixture (T198,
  deliverable `src/managent/nonexistent-deliverable.zig`) remains
  flagged. ✓
- Live probe (read-only): `./bin/managent audit` on the real kanban
  emits 18 findings, 16 of them citation WARNs on done tasks — including
  T159 and T160 themselves (their deliverable, the managent
  implementation, is not yet cited/promoted in either register). The
  flag works on live data, i.e. R3 is exercising real gaps, not an
  empty check.
- `--json` output is parseable and carries the citation findings
  (17/18 findings in the post-absorption sandbox run). Note audit exits
  0 even with findings — automation must parse stdout, not exit code.

## 4. Other observations (not spec items)

- Live audit also reports: `zig-out/bin/managent is newer than
  bin/managent — cp it` (standing hygiene WARN, genuine: bin 18:42 vs
  zig-out 09:07, different build modes, same source); T197 in_progress
  with no heartbeat ever recorded (claimed 2026-08-01T07:04:45Z).
- The `_sys.next_id` staleness also means `add --auto` would mint a
  colliding ID today.

## 5. What I could not establish

- Whether a live `suggest` actually clobbers T165: I did not run
  `suggest` on the real kanban (no silent writes to state). The sandbox
  reproduces the identical state bytes and code path; the only
  difference is the path prefix of the state file.
- The exact build configuration of bin/managent vs zig-out/bin/managent
  (Debug vs ReleaseFast) — irrelevant to behaviour, both built from the
  committed source.

## 6. Recommended next step

1. Fix: make `suggest` (and `add --auto`) mint the first free T-ID —
   e.g. recompute `next_id` from max registered T-ID on load, or loop
   past in-use IDs — and refuse/repair a stale `_sys.next_id`. The
   current live value (165) must be corrected before any further
   suggest use.
2. Rerun A1 against the fix (same sandbox harness; the A1 happy-path
   probes above are the known-good, the T165/T202 repros the known-bad).
3. Promote T159/T160 work into CLAIMS.md/PROGRESS.md citations (the
   audit's own nudge) — that clears the T159/T160 citation WARNs and is
   the standing promote-or-cite contract.
