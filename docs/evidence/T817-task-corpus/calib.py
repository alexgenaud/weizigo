#!/usr/bin/env python3
"""T817 — calibration (task-corpus.md §2).

Ground truth A: 24 briefs that self-declare their type in first-person prose
(hand-verified; each quoted in task-corpus.md §2.1).
Ground truth B: A + race organizers T447, T529, T626 (protocol-known audit).
Ground truth C (negative result): Landmark-line-mapped types — the Landmark
line names the work-stream (domain), not the D027 task type; reported to show
why it cannot serve as type ground truth.
"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib as L
import classify as C

tasks = L.load_store()
briefs = L.load_briefs()

SELF_DECLARED = {
    "T323": "spec", "T443": "spec", "T776": "spec", "T785": "spec", "T803": "spec",
    "T382": "research", "T471": "research", "T592": "research",
    "T408": "infra",
    "T270": "battery",
    "T615": "audit", "T616": "audit", "T617": "audit", "T618": "audit",
    "T619": "audit", "T620": "audit", "T621": "audit", "T622": "audit",
    "T623": "audit", "T624": "audit", "T674": "audit", "T683": "audit",
    "T685": "audit", "T687": "audit",
}

# T557 excluded from race organizers: its store bundle is a pass-1 owner seat
# (orchestration); the race was its work product, not its type.
RACE_ORGS = {"T447", "T529", "T626"}


def landmark_type(tid):
    b = briefs.get(tid)
    if not b or not b["landmark"]:
        return None
    lm = b["landmark"]
    if re.search(r"\bL2\b", lm):
        return "research"
    if re.search(r"\bL5\b", lm):
        return "spec"
    if re.search(r"\bL1\b", lm) or re.search(r"\bL4\b", lm):
        return "infra"
    return None


def acc(classifier, ground):
    right = wrong = 0
    detail = []
    for tid, gt in ground.items():
        if tid not in tasks:
            continue
        pred = classifier(tid, tasks[tid])
        if pred == gt:
            right += 1
        else:
            wrong += 1
            detail.append((tid, gt, pred))
    return right, wrong, detail


def cl_legacy(tid, t):
    return C.classify_legacy(tid, t)[0]


def cl_brief(tid, t):
    return C.classify_brief(tid, t, briefs)[0]


ra, wa, da = acc(cl_legacy, SELF_DECLARED)
rb, wb, db = acc(cl_brief, SELF_DECLARED)
print(f"Self-declared (n={len(SELF_DECLARED)}):")
print(f"  legacy: {ra}/{ra+wa} = {ra/(ra+wa):.0%}   brief: {rb}/{rb+wb} = {rb/(rb+wb):.0%}")
print(f"  brief misses: {db}")

GT_AB = dict(SELF_DECLARED)
for t in RACE_ORGS:
    GT_AB[t] = "audit"
ra2, wa2, da2 = acc(cl_legacy, GT_AB)
rb2, wb2, db2 = acc(cl_brief, GT_AB)
print(f"\nSelf-declared + race orgs (n={len(GT_AB)}):")
print(f"  legacy: {ra2}/{ra2+wa2} = {ra2/(ra2+wa2):.0%}   brief: {rb2}/{rb2+wb2} = {rb2/(rb2+wb2):.0%}")
print(f"  brief misses: {db2}")

LM = {}
for tid in tasks:
    lt = landmark_type(tid)
    if lt:
        LM[tid] = lt
rl, wl, dl = acc(cl_legacy, LM)
rbl, wbl, dbl = acc(cl_brief, LM)
print(f"\nLandmark-mapped (soft, n={len(LM)}):")
print(f"  legacy: {rl}/{rl+wl} = {rl/(rl+wl):.0%}   brief: {rbl}/{rbl+wbl} = {rbl/(rbl+wbl):.0%}")
print("  negative result: the Landmark line names the work-stream, not the type")
print(f"  (e.g. race lanes T717-T729 carry 'L2 (go science)' but are audit)")
