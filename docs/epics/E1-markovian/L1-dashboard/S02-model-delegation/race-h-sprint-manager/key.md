# Race H (sprint-manager battery) — key seal

`faa89e3f989e53d9e050706d1d4b4135dea2cf3f594512d44154184271076289  untracked/race-grading/race-h/KEY.json`

- **Sealed:** 2026-08-22 · **Sealed by:** deepseek-v4-pro/T672 · **Instrument:** `battery.md` (this directory).
- **What is sealed:** the answer key for the five axes (S1–S5). It lives in
  `untracked/race-grading/race-h/KEY.json` (gitignored, outside lane reach — lanes run in
  worktrees containing only committed content, per `untracked/race-grading/README.md`).
- **This file is the committed seal record, not the key.** The key itself must not be copied
  into committed content anywhere a lane could read it.
- **Unseal rule:** opened only after every lane's score is recorded, per the T447 sealed-key
  precedent. Any change to the key file requires re-hashing and a new seal commit *before* any
  lane runs; a hash that no longer matches voids the run.
- **Verify:** `sha256sum untracked/race-grading/race-h/KEY.json` must equal the line above.
