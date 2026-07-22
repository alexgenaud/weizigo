# 0003 — Ruleset: Chinese/area canonical, positional superko

Date: 2026-07-14 · Status: accepted

## Context

The value of a Go position depends on the ruleset. The solver needs one
canonical ruleset for the perfect database, but we also want to score real
games (with real histories) in the traditional way.

## Decision

- **Canonical database: Chinese / area scoring.** Area score is a pure
  function of the terminal snapshot (each point counts for whoever's stones
  or sole-reaching territory it is), so no history is needed — the natural
  fit for a position database.
- **Ko rule: positional superko (PSK)** — "no whole-board position may ever
  recur". This is the rule the project has always used; it guarantees finite
  games and matches Tromp-Taylor / the setting in which 5×5 is known solved
  (Black wins by 25), giving a correctness oracle.
- **Also compute Japanese / territory scoring for real terminal positions.**
  Territory score needs prisoner counts, which are path-dependent and NOT
  recoverable from a snapshot — so this requires tracking captured stones as
  extra state (see TODO "captured-stone tracking"). Not used for the DB.

## Why

Area+PSK is the complete, unambiguous, snapshot-scorable, history-free choice
for a solver. Territory scoring is kept as a reporting feature for actual
games, where the history exists.

## Alternatives considered

- Situational superko (SSK, ko+side): nearly identical implementation cost
  (one extra bit in the ko hash) and aligns with the (board,side)-keyed TT,
  but PSK is our tradition and the literature oracle. SSK remains a near-free
  switch if AGA compatibility is ever wanted.
- Basic ko + Japanese "no result": avoids the GHI problem but leaves some
  positions with no defined winner — unacceptable for a perfect DB.

See `research/go-rules-ko-and-scoring.md`.
