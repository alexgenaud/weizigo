# Race H (sprint-manager battery) — key seal

`fbb29ac1c4059c664fd14a141878ab0aaab9c39505ae59c0772ca2ae0520af63  untracked/race-grading/race-h/KEY.json`

- **Sealed:** 2026-08-22 · **Sealed by:** deepseek-v4-pro/T672 · **Instrument:** `battery.md` (this directory).
- **Re-sealed (round 1):** 2026-08-23 · **Re-sealed by:** deepseek-v4-pro/T707 — resolved the T696 grader's
  key defects KD-2/KD-3/KD-4 (coverage bar, direct-vs-ancestor edge, directory holds) so S1 is
  scoreable consistently. The three one-sentence resolutions are recorded in the key's `reseal`
  field.
- **Re-sealed (round 2):** 2026-08-23 · **Re-sealed by:** deepseek-v4-flash/T708 — folded the T708
  battery amendment (KD-8/KD-11): S2 gained S2-NO-RECORD (the one item where abstention is
  correct; killed_by=unknown is the ground truth) and S4's S4-TRAP/S4-ACT were replaced by
  S4-REBASE / S4-STALE-DIRECTIVE (boundary situations the mandate underdetermines). T707's round-1
  fixes are preserved; the round-2 hash supersedes round 1 because round 1 sealed before the T708
  delta existed. Both reseal entries are recorded in the key's `reseal` field.
- **What is sealed:** the answer key for the five axes (S1–S5). It lives in
  `untracked/race-grading/race-h/KEY.json` (gitignored, outside lane reach — lanes run in
  worktrees containing only committed content, per `untracked/race-grading/README.md`).
- **This file is the committed seal record, not the key.** The key itself must not be copied
  into committed content anywhere a lane could read it.
- **Unseal rule:** opened only after every lane's score is recorded, per the T447 sealed-key
  precedent. Any change to the key file requires re-hashing and a new seal commit *before* any
  lane runs; a hash that no longer matches voids the run.
- **Verify:** `sha256sum untracked/race-grading/race-h/KEY.json` must equal the line above.
