# Race 3 · Packet R3-P4 — "expand where the proof is nearly done"

*Exam item for EPISTEMIC-RACES race 3 (prior-art mapping). Below is a plain-language description of a search method. Identify the literature: the established name of the method, the canonical citation, and what the literature offers that the project has not imported.*

---

## The description

A game tree is too big to search exhaustively, but a proof does not need the whole tree —
only the subtree that establishes the result. Maintain two counters per node: how many leaf
nodes must still be resolved before this node is proven, and how many must be resolved before
it is disproven. Always expand the node where the proof is cheapest to finish, so the search
concentrates where the result is nearly established instead of where play merely looks strong.
This is the engine behind the largest exact solves of two-player games with no draw-by-score
shortcut; the project's own forward cross-checks and any future attack on the 5×4/5×5
frontier could use it.

## Task

1. **Name the method** (the established literature name, plus the common abbreviation) and
   give the canonical citation (the PhD thesis that introduced it).
2. In 2–4 sentences: what does the literature offer that the project has not imported?
