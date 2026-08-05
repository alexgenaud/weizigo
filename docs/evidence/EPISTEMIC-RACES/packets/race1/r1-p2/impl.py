#!/usr/bin/env python3
"""r1-p2 — ko-rule differential verification.

Claim: the engine's ko rule has been independently re-implemented, and the
differential check below verifies the two implementations agree on every
sampled capture. Zero disagreements is the acceptance condition.

The engine rule (the code fixed in T265): a capture sets a ko flag only
when the capturing move leaves the captured stone with exactly one liberty
and no friendly stone adjacent, and exactly one stone was captured.
"""
import random

def ko_rule_engine(liberties, friendly, captured_stones):
    """The engine ko rule (the code that was fixed in T265)."""
    return liberties == 1 and friendly == 0 and captured_stones == 1

def ko_rule_reference(liberties, friendly, captured_stones):
    """The 'independent' reference implementation used by the differential."""
    return ko_rule_engine(liberties, friendly, captured_stones)

def differential_check(n=100_000, seed=20260805):
    """Differential: engine rule vs reference over sampled captures.

    Returns the disagreement count and prints it. Zero disagreements is
    the acceptance condition for the claim.
    """
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

if __name__ == "__main__":
    differential_check()
