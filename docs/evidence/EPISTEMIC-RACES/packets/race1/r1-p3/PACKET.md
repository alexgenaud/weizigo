# Race 1 · Packet R1-P3 — evaluator calibration control

*Exam item for EPISTEMIC-RACES race 1 (falsification design). Lane-facing text: you receive this packet exactly as written. Grading fixtures (clean twin, keys) are not part of this document.*

---

## The claim

> **The minimax evaluator is calibrated.** The seeded-defect control plants a defect in the
> evaluator's input and requires the control to fire RED; a clean input must yield GREEN. The
> calibration run of 2026-08-05 reports **seeded control GREEN, clean control GREEN, verdict
> CALIBRATED** — read as confirmation that the evaluator detects planted defects.

The evaluator computes the exact negamax game value of a small DAG state (Black-positive
scores; both sides play optimally). Calibration is the step that proves the instrument can
fail: if a planted defect is never detected, the instrument's green readings mean nothing.

## The code

`impl.py` (reproduced verbatim; also present beside this file):

```python
import copy

def minimax_value(dag, node):
    """The instrument under test: negamax game value of a small DAG state.

    dag["leaf"] maps leaf ids to values; dag[node] is the list of child
    ids; the value of a leaf is its stored value, the value of an internal
    node is max over children of -value(child) (both sides play optimally,
    Black-positive scores).
    """
    children = dag[node]
    if not children:
        return dag["leaf"][node]
    return max(-minimax_value(dag, c) for c in children)

def _plant_defect(dag):
    """Return a deep copy of the dag with one leaf value flipped."""
    t = copy.deepcopy(dag)
    t["leaf"][0] = -t["leaf"][0]
    return t

def control_fires(dag, node):
    """Seeded-defect control: True iff the planted defect is detected.

    To detect the planted defect the control must run the *instrument* on
    the planted dag and compare against the clean value. Returns True only
    when the instrument reports a different value on the planted input.
    """
    planted = _plant_defect(dag)
    # Compare the planted run against itself: a parallel check that cannot
    # reflect a defect in the instrument's input handling.
    return minimax_value(planted, node) != minimax_value(planted, node)

def calibration(dag, node):
    """Calibration harness. Prints the log lines and returns the verdict.

    Verdict is CALIBRATED iff the clean control is green; the seeded
    control's own verdict is reported but not required.
    """
    clean_ok = minimax_value(dag, node) == minimax_value(dag, node)
    fired = control_fires(dag, node)
    verdict = "CALIBRATED" if clean_ok else "UNCALIBRATED"
    print("seeded-defect control: %s" % ("RED" if fired else "GREEN"))
    print("clean control: %s" % ("GREEN" if clean_ok else "RED"))
    print("verdict: %s" % verdict)
    return verdict
```

## The evidence

`evidence.txt` — transcript of the calibration run, `python3 impl.py` (Python 3.9.6,
2026-08-05):

```
seeded-defect control: GREEN
clean control: GREEN
verdict: CALIBRATED
```

The clean control passes and the verdict reads CALIBRATED. This is read as proof that the
instrument is sensitive: a planted defect would be caught.

## Your task (race 1)

Design the experiments that could kill this claim — **as runnable tests, not prose**. The
claim's force is that the seeded-defect control can actually fire: that it exercises the
instrument under test on the planted input. Write tests that a grader can execute; a test
that distinguishes this claim from its clean twin earns the point.

*This packet is seeded with defects from the project's historical catalogue. The claim may be
true or false. Nothing here beyond this paragraph should be read as a hint.*
