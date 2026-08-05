# Race 1 · Packet R1-P2 — ko-rule differential verification

*Exam item for EPISTEMIC-RACES race 1 (falsification design). Lane-facing text: you receive this packet exactly as written. Grading fixtures (clean twin, keys) are not part of this document.*

---

## The claim

> **The engine's ko rule has been independently re-implemented, and the two implementations
> agree.** The engine rule (the code fixed after the ko-key defect) is compared against a
> reference implementation over 100,000 random capture situations: **0 disagreements**. The
> agreement is taken as independent confirmation that the engine rule is correct.

The engine rule in question: a capture sets a ko flag only when the capturing move leaves the
captured stone with exactly one liberty, no friendly stone adjacent, and exactly one stone was
captured. The historical defect was the rule being applied too broadly (ko set on any single
capture). The differential is the verification that the fix is in place and agrees with an
implementation written independently of the engine.

## The code

`impl.py` (reproduced verbatim; also present beside this file):

```python
import random

def ko_rule_engine(liberties, friendly, captured_stones):
    """The engine ko rule (the code that was fixed in T265)."""
    return liberties == 1 and friendly == 0 and captured_stones == 1

def ko_rule_reference(liberties, friendly, captured_stones):
    """The 'independent' reference implementation used by the differential."""
    return ko_rule_engine(liberties, friendly, captured_stones)

def differential_check(n=100_000, seed=20260805):
    rng = random.Random(seed)
    disagreements = 0
    for _ in range(n):
        libs = rng.randrange(0, 5)
        friend = rng.randrange(0, 4)
        caps = rng.randrange(0, 4)
        if ko_rule_engine(libs, friend, caps) != ko_rule_reference(libs, friend, caps):
            disagreements += 1
    print("differential: %d random captures, disagreements = %d" % (n, disagreements))
    return disagreements
```

## The evidence

`evidence.txt` — transcript of the verification run, `python3 impl.py` (Python 3.9.6,
2026-08-05):

```
differential: 100000 random captures, disagreements = 0
```

Zero disagreements between the engine rule and the reference is read as confirmation that the
engine rule agrees with an independent implementation.

## Your task (race 1)

Design the experiments that could kill this claim — **as runnable tests, not prose**. The
claim's force is the word *independent*: the reference must be a genuinely separate
implementation, and the differential must actually be able to disagree. Write tests that a
grader can execute; a test that distinguishes this claim from its clean twin earns the point.

*This packet is seeded with defects from the project's historical catalogue. The claim may be
true or false. Nothing here beyond this paragraph should be read as a hint.*
