VERDICT: CLEAN

Auditor: claude-sonnet-5/T960 · audit round 2 of the 7c.21 cap · date 2026-08-25.
I read `untracked/T953-three-red-gate-arms.md` (rev 2) and round 1's audit
(`untracked/audit/T959-t953-spec-audit.md`, `VERDICT: BLOCKERS (3)`), then checked rev 2's
claims against the repository at HEAD (live script runs, `git log`/`git show`, source reads).

---

## Round 1's three blockers, checked

**BLOCKER 1 (title-gate arm was already compliant) — fixed, and the fix predates this audit.**
`tools/pop-next.sh:157-163` no longer pipes `bin/dispatch`'s output through `tail -1`; on a
non-zero exit it prints the full message with the task id, one line prefixed at a time, and
keeps the one-line summary only on success. Committed at `9b5f20a` ("pop-next: print the whole
refusal, not the last line"), whose message explicitly credits round 1 (dspro/T959) for finding
the gate was fine and the reader was the defect. `bin/dispatch:391-395` matches rev 2's citation
(off by one line only). The title-gate arm is gone from rev 2's evidence table and from
"Controls" — round 1's fix applied cleanly (NOTE 8 is correctly moot).

**BLOCKER 2 (`assign --exclude` arm vs the out-of-scope clause) — contradiction is gone.**
`filterQualified` (`src/managent/main.zig:728-777`) still matches an exclusion token only against
an exact family or canonical-model string, and `assign`'s flag handling (line 8619-8625) still
does not refuse an unmatched token — the code hasn't changed, and rev 2 doesn't claim it has. What
changed is the spec: "Explicit decision, resolving round-1 BLOCKER 2" states the new behavior
plainly (unknown token → refused, names the token and the valid families) and "Out of scope" now
reads "any gate's decision **other than the one recorded above**" — round 1's option (b). The
self-contradiction round 1 flagged (fix the silence vs. never change a decision) is resolved.

**BLOCKER 3 (ollama-dispatcher control 4's premise) — confirmed correct, live, during this audit.**
I ran `sh tools/regression-ollama-dispatcher.sh` with two lanes actually running on this host
(this task, T960, plus T952/gemini-3.7-flash — `ps` shows both `tools/runner --ram-mb 4608
--arbiter-id T9{52,60}`). Control 4 failed with exactly the message rev 2 quotes:
`ARBITER WOULD REFUSE T996: declared need 18432 MB does not fit: avail 26055 MB - committed 9216
MB - candidate 18432 MB = -1593 MB < reserve 4608 MB` — 9216 MB committed is precisely 2 × 4608 MB,
i.e. this task's own lane plus T952's. Round 1 ran it on a quiet host and saw all 7 controls pass;
I ran it busy and saw control 4 fail for the reason rev 2 names. Both readings are correct — the
control is fleet-dependent, exactly as rev 2 says — and it is a real dry-run RAM-admission refusal,
not a stale mapping. Scope item 3's remedy (declare the precondition: SKIP-when-busy or force past
admission, then drop the `known-red` line) is the right fix and is left as an implementation choice,
which is appropriate for a spec.

## Round 1's fourth option — "taken in substance, refused as a three-row split"

Round 1's split (D1 wording / D2 silent-acceptance / D3 gate-robustness) is adopted verbatim as
the row's three named parts, each with its own commit. Keeping it one row is a defensible judgment
call: the three parts share one regression file (`tools/regression-refusal-names-subject.sh`) and
one rule, and the acceptance criteria (one `known-red` line removed per commit, findings listing
anything unrepaired) work the same whether it's one row or three. I could not independently verify
the cited "operator has asked to consolidate related work into single well-specified tasks" against
any committed doc — it isn't in `docs/infra/sprint.md`, `AGENTS.md`, or `DELEGATOR.md` — but the
structural justification (shared file, shared rule) stands on its own regardless, so I'm not
treating the unverified attribution as a blocker.

## Judging rev 2 on its own

- **Buildable without a question:** yes. D1/D2/D3 are concretely scoped; the one open design choice
  (control 4's SKIP vs. force-past-admission) is explicitly left to the worker with instructions to
  choose and justify, not a gap.
- **Controls genuinely red-first, with null and seeded defect:** yes, per row of "Controls" and
  scope item 1 ("each arm seeds the real failure... define per arm what counts as cause and action
  — round-1 NOTE 7").
- **Scope coherent as three parts:** yes — see above.
- **Nothing over-built:** D3 (declared-and-absent contract check) is the one part that could read as
  scope creep, but it's owed, not invented — commit `a2ffe87`'s message says outright "T953 owes
  the loud contract-level failure that would have caught all three [incidents]," and I confirmed
  today's pre-commit hook has no such check yet.
- **Facts checked against the repo, not taken on faith:** the pop-next fix, the `assign --exclude`
  code, the ollama-dispatcher control-4 failure (live, under real fleet load), the
  `regression-managent-duty.sh` arm-B string (`tools/regression-managent-duty.sh:150` still greps
  literal `"duties (1)"` against a board that now prints `"duties & standing triggers (1)"` since
  `b27c7f0`/T894 — reproduced: `FAIL: DCLAIM misrendered`), and `regression-store-census.sh`
  (all 4 arms pass at HEAD, `a2ffe87`) all match rev 2's claims.

## One residual imprecision (not a blocker)

D1 still describes the claimlint C2 example using round 1's original framing ("the cause is
produced and then lost") rather than round 1's own correction that, for C2 specifically, the cause
*is* named (even in the folded-into-summary case, under the C10-NEW section) and the genuine gap is
the missing *action* line (round 1 RED FLAG 4). I re-verified this at `src/claimlint.zig:2027-2065`:
genuine C2 hits print the path, `named in:`, and `reachable from N register row(s)` — never a "what
to do" line, in either the C10-NEW-folded case or the direct case. Scope item 1's general
requirement ("asserts... an action... define per arm what counts as each") and the instruction to
read round 1 in full should steer the C2 arm correctly regardless, so I'm flagging this as a note
for the implementer, not a blocker: build the C2 arm's seeded defect around the missing action, not
around the summary/detail count mismatch the table row illustrates.
