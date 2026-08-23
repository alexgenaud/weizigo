# Discuss-dispatch protocol

**Status: living protocol. [Current — operator prescriptions encoded 2026-08-23.]**

A discussion console exists to EMPTY itself: every topic ends dispatched, decided, or
deferred, and the session closes with a handover. The human is not the tracker, not the
relay, and not the audience for detail.

## What deserves discussion at all

Bring the human ONLY decisions where you could not have made a better evidence-based
decision yourself — intent, taste, appetite, irreversible direction. Everything else:
decide, record, act, and report the outcome. If the path forward is known (we know what
we want, or we know research is needed), it is not a topic — it is a dispatch.

## Order

Priority-sort the topic list twice: **most important first**, and within that,
**dispatchable-first** — a topic that one ruling turns into a queued row leaves the
discussion before a topic that needs exploration.

## One topic at a time, with context

The human tracks NOTHING between messages — no task numbers, no point numbers from prior
replies, no memory of his own last answer. Every time a topic is raised (or returns):

1. **Recap first**: one or two sentences of what this is, what is already agreed, and
   what is open. Human-friendly words, not IDs — an ID may appear only next to its
   meaning ("T778 — the fresh audit of the orchestration blueprint").
2. **Then the ask**: exactly one decision, framed with a recommendation and why.
3. **Then stop.** No second topic in the same ask.

A reply the human answers with "I do not understand" or "I do not remember" is a protocol
failure by the agent, not a memory failure by the human.

## Per-topic exits — conclude or kill

Every topic ends, same message it resolves in, as one of:
- **Resolved** — ruling recorded to a committed artifact (seed/findings/doc), then acted on;
- **Delegated** — a brief written, one registration, dispatched if ready;
- **Deferred** — with an owner and a wake condition, never "later";
- **Killed** — not worth deciding; say so and why.

Track the outline (states `[ ]` `[~]` `[✓]` `[✗]`, one `[~]` at a time); prune dead
topics; the outline must shrink toward zero across the session.

## Closing the session

When the outline is empty (or the human calls time): dispatch everything sufficiently
specified, then hand over to **zero** (close — nothing remains), **one** (a single
continuation prompt for a cleared session), or **a few** consoles — each with an
isolated, completely non-conflicting, distinct topic. A handover prompt is self-carrying:
committed context paths, open items, and the claim line.

## The bookends (why this shape)

The human's role is the two bookends — "what I want and what I will get" before, "did I
get what I wanted" after. Between them, sprints run on evidence and best practices
without him. Discussion that drifts from a bookend toward implementation detail is the
signal to dispatch and stop talking. (Operator ruling, 2026-08-23, recorded in
docs/status/landmark-waypoints-seed-2026-08-23.md §5.)

## Tempo

The human sets the pace — quick (triage, one exchange per topic), deep (design, explore
to exhaustion), or mixed (breadth-first for quick wins, then depth on what remains). The
agent mirrors it: terse begets terse.
