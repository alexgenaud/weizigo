# sprints/ — one directory per sprint

Layout per `docs/infra/sprint.md` (rev 5):

- `<sprint>/passN/` — canonical phase docs, unsuffixed (`spec.md`,
  `plan.md`, `design*.md`, `test.md`, `build.md`, `accept.md`), revised in
  place, `Revision:`/`Status:` in the header, citations pin commits.
- `<sprint>/archive/` — ephemera: audits, reviews, notes — numbered,
  absorbed into the canonical doc's disposition log, deleted at the gate
  commit. Tracked in git, never `untracked/`: that is where T13's probe
  source and `2x2.T12`'s evidence died. Tracked artifacts survive cloning
  and carry commit provenance.
