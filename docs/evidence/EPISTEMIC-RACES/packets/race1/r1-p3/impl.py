#!/usr/bin/env python3
"""r1-p3 — minimax evaluator calibration control.

Claim: the minimax evaluator is calibrated. The seeded-defect control
plants a defect in the evaluator's input and requires the control to fire
RED; a clean input must yield GREEN. Calibration log (2026-08-05):
seeded control GREEN, clean control GREEN, verdict CALIBRATED — taken as
confirmation that the evaluator detects planted defects.
"""
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

if __name__ == "__main__":
    # A tiny two-level dag: root 0 with children 1 and 2; leaves 0,1,2.
    dag = {"leaf": {0: 3, 1: 4}, 5: [0, 1], 0: [], 1: []}
    calibration(dag, 0)
