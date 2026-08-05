# Race 1 · Packet R1-P1 — state-table key agreement

*Exam item for EPISTEMIC-RACES race 1 (falsification design). Lane-facing text: you receive this packet exactly as written. Grading fixtures (clean twin, keys) are not part of this document.*

---

## The claim

> **The state-table key separates all four state dimensions (position, side, passes, ko).** A
> lookup for a passes=1 row can never land on the slot of the passes=0 row of the same
> position, because the key carries the passes bit. This was verified by a writer-vs-reader
> key-agreement differential over 1,000,000 random states: **0 mismatches**.

The table is keyed by `(position mask, side, passes, ko)`. If the key failed to carry any one
dimension, two distinct rows would share a slot, and lookups would return the wrong row's
value. The claim is that this cannot happen.

## The code

`impl.py` (reproduced verbatim; also present beside this file):

```python
import random

def table_key(board, side, passes, ko):
    """Writer-side key. board: 16-bit position mask; side/passes/ko: 0 or 1."""
    return (board << 3) | (side << 2) | (ko << 1)

def lookup_key(board, side, passes, ko):
    """Reader-side key. Must agree with table_key on every legal state."""
    return (board << 3) | (side << 2) | (ko << 1)

def key_agreement_check(n=1_000_000, seed=20260805):
    rng = random.Random(seed)
    mismatches = 0
    for _ in range(n):
        board = rng.getrandbits(16)
        side, passes, ko = rng.randrange(2), rng.randrange(2), rng.randrange(2)
        if table_key(board, side, passes, ko) != lookup_key(board, side, passes, ko):
            mismatches += 1
    print("key agreement: %d sampled states, mismatches = %d" % (n, mismatches))
    return mismatches
```

## The evidence

`evidence.txt` — transcript of the verification run, `python3 impl.py` (Python 3.9.6,
2026-08-05):

```
key agreement: 1000000 sampled states, mismatches = 0
```

Zero mismatches between the writer-side and reader-side key functions is read as
confirmation that the key distinguishes all four dimensions, including the passes bit.

## Your task (race 1)

Design the experiments that could kill this claim — **as runnable tests, not prose**. The
claim stands or falls on whether the key really carries the passes bit. Write tests that a
grader can execute; a test that distinguishes this claim from its clean twin earns the point.

*This packet is seeded with defects from the project's historical catalogue. The claim may be
true or false. Nothing here beyond this paragraph should be read as a hint.*
