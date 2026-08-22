#!/usr/bin/env python3
"""T637 — the complementarity reduction.

Reads race artifacts (per-lane finding sets plus a graded reference union)
and reduces them to a standing complementarity record: per-lane unique-catch
rates, the pairwise overlap matrix, and the best-subset-of-size-k table,
grouped by (task_type, epoch).  Deterministic: identical inputs produce
byte-identical output (no clock, no randomness); `check` pins that.

WHY THIS INSTRUMENT EXISTS (ruling 34, T637 brief).  A race ranking answers
"who is best".  For union-valued work the useful question is "who should sit
together": two mid-ranked models with disjoint blind spots can beat the
top-ranked model paired with its own near-duplicate.  That fact is
recoverable only from per-item, per-lane data — which lane caught which
finding — which a rank discards.  This tool is the reduction from race
artifacts to the standing complementarity record T636's panel selection
reads.  The schema below IS the interface; it is written down here and in
`--schema` so a consumer never has to guess a field name.

─────────────── HONESTY RULES (the hard part of the brief) ───────────────

1. UNION COVERAGE IS COVERAGE OF THE UNION WE FOUND, NEVER OF THE TRUTH.
   Every coverage fraction in the output is over n, the graded reference
   union this run was given.  A finding every lane missed is invisible
   here.  The record repeats this disclaimer in every group and in the
   record header.  To absorb a later-audit finding nobody caught, add it to
   the union input with no lane in `caught_by` (or no mapping onto it):
   it moves the denominator and is reported in `uncaught_items`.

2. COMPLEMENTARITY AND RANK ARE NOT BLENDED.  Unique-catch rate and cost
   are reported as separate numbers.  Selection combines them explicitly;
   this tool never folds the trade into an index.

3. MERGES ARE COUNTED AND THEIR RULE IS STATED.  Two lanes phrasing one
   defect differently are one finding only through an explicit mapping
   decision (the race input's `mappings` + `merge_policy`).  The tool
   derives the merge/split counts from the mappings mechanically and
   reports them; it never guesses a match.  A reduction that silently
   merges aggressively manufactures overlap and makes every model look
   redundant — the counts are the tripwire.

4. A NUMBER FROM ONE RACE IS A PRIOR, LABELLED ONE.  Each group states how
   many races contributed (`race_ids`); with one race the sample_note says
   the numbers are a prior, not a measurement.

─────────────── RATE DEFINITIONS (pinned by the controls) ────────────────

For a lane L, let U_L be the set of union items L caught, n the number of
real union items, and unique(L) = {i in U_L : no other lane caught i}.

  unique_catch_rate(L)         = |unique(L)| / |U_L|
       fraction of what L itself found that only L found.  The controls
       pin this: two lanes with disjoint finding sets both score 1.0.
       If U_L is empty the rate is null (0/0) with a note, never 0.
  unique_catch_over_union(L)   = |unique(L)| / n
       the brief's literal "over the union" reading, reported alongside
       so both honest readings are on the table.  Disjoint lanes on a
       two-lane race score |U_L|/n each, NOT 1.0 — that is why the
       within-lane definition above is the headline.
  overlap(A,B)                 = |U_A ∩ U_B| / |U_A ∪ U_B|   (Jaccard)
  best subset of size k        = the k lanes whose UNION of catches covers
       the most real items; coverage fraction = covered / n.  Ties are all
       reported, sorted.  Exact search for L <= 20 lanes (max C(20,10) =
       184756 subsets); beyond that a greedy first-fit with a loud note.
  false_raises(L)              = items with verdict != real that L raised;
       reported as a cost-side census, never subtracted from catches.

─────────────── INPUT: a race file (one JSON per race) ──────────────────

{
  "schema": "race-input",
  "schema_version": 1,
  "race_id": "race-a",                  # unique across the record
  "task_type": "spec-audit",            # free string; groups the record
  "epoch": "2026-08-22",                # free string; groups the record
  "spec": "S04-orchestrator-retirement",# optional subject artifact
  "notes": "provenance; cite sources",  # optional, free text
  "merge_policy": "one sentence stating how two differently worded items
                   were decided to be one finding; the record repeats it",

  "union": [                            # the graded reference union
    {"id": "A1", "statement": "...", "verdict": "real"}
                                        # verdict: "real" | "false" |
                                        # "uncertain" (default "real").
                                        # n counts "real" only; false and
                                        # uncertain items are excluded from
                                        # every rate and reported separately.
  ],

  "lanes": [                            # one entry per lane
    {"id": "lane-1",
     "model": "deepseek-v4-flash",      # canonical model label or opaque
     "task_id": "T590",                 # optional
     "source": "findings/T590-...json", # optional; verified when readable
     "source_sha256": "...",            # optional; verified when given
     "cost": null,                      # optional measured cost (number);
     "cost_unit": "tokens",             #   null = unknown, stated as such
     "cost_note": "deepseek lane: no structured usage (untracked/tokens)",
     "findings": [                      # form A only; optional
       {"id": "N1", "statement": "..."}
     ]}
  ],

  "mappings": [                         # form A: finding -> canonical item
    {"lane": "lane-1", "finding": "N1", "item": "A1"}
  ]
}

Two forms, both supported, both validated:
  Form A (explicit mappings): lanes carry `findings`; `mappings` maps each
    finding to exactly one union item.  Every finding must be mapped (a
    finding with no union home is an input error, not a silent drop).  The
    tool derives caught sets, merge counts and split counts from these
    mappings.  This is the form for raw audits (Race A).
  Form B (direct caught sets): union items carry
    "caught_by": ["lane-1", ...]        # per item, the lanes that caught it
    and lanes carry no `findings`.  Merge decisions were made upstream
    (the race's own grader documented them); `merges` is recorded as
    declared-with-zero-reduction-merges and the input's `notes` must say
    where the upstream dedup is documented.  This is the form for a graded
    race whose grader already canonicalized (Race F via T632).
If both forms are present they must agree exactly (the tool cross-checks).

Cost: a lane's measured cost travels as `cost` + `cost_unit`.  It is
reported per lane and per best-subset (sum when every lane in the subset
has a known cost, null + `cost_unknown: true` otherwise).  It is never
blended with unique-catch rates; selection combines them explicitly.

─────────────── OUTPUT: the standing complementarity record ─────────────

One JSON document, grouped by "task_type/epoch".  Each group carries:
  n, n_false_excluded, n_uncertain_excluded
  uncaught_items            # union items no lane caught (absorption path)
  per_lane                  # catches, unique catches, both rates, cost
  overlap_matrix            # shared count + jaccard per pair (null if 1 lane)
  best_subsets              # per k: coverage, covered, argmax subsets, cost
  merges                    # merge_decisions, split_decisions, raw_findings,
                            # mappings, policy (the stated rule)
  caught_matrix             # per item: the lanes that caught it (raw data,
                            # for T636-style marginal computation)
  false_raises              # per lane: excluded items it raised (cost side)
  sample_note               # "one race; numbers are a prior, labelled one"
The record header repeats the disclaimer and names every input file with
its sha256, so the record is verifiably the reduction of exactly the files
it says.

─────────────── CONTROLS (`check`, pinned by the brief) ─────────────────

  1. seeded disjoint: lanes A,B with known disjoint finding sets ->
     overlap 0, both unique_catch_rate 1.0, best-subset-of-2 reaches the
     full union.
  2. seeded subset: lane B's findings a strict subset of lane A's (with a
     third lane C disjoint from A) -> B's unique_catch_rate 0, and
     best-subset-of-2 does not pick {A,B}.
  3. null: a single-lane race -> overlap matrix undefined and reported as
     null with a note, not a 1x1 matrix of 1.0.
  4. determinism: the same race fed twice -> byte-identical output.

Run `tools/complementarity.py check` for the self-tests and
`tools/regression-complementarity.sh` for the wired suite (zig build test).

Identifier: deepseek-v4-flash/T637.  Stdlib only (Python 3.8+).
"""

import argparse
import hashlib
import itertools
import json
import os
import sys

SCHEMA_VERSION = 1
RECORD_VERSION = 1

DISCLAIMER = (
    "Union coverage is coverage of the union we found, never of the truth. "
    "Every coverage fraction in this record is over n, the graded reference "
    "union this run was given; a finding every lane missed is invisible here "
    "and a reader who forgets that will over-trust a 95% figure. To absorb a "
    "later-audit finding nobody caught, add it to the union input with no "
    "lane catching it: it moves the denominator and is reported in "
    "uncaught_items."
)

RATE_DEFINITIONS = {
    "unique_catch_rate": (
        "|findings this lane alone caught| / |findings this lane caught|. "
        "Fraction of what the lane itself found that only it found; 0/0 is "
        "null, never 0. Pinned by the controls: two lanes with disjoint "
        "finding sets both score 1.0."
    ),
    "unique_catch_over_union": (
        "|findings this lane alone caught| / n. The brief's literal 'over "
        "the union' reading, reported alongside the headline rate because "
        "both honest readings belong on the table."
    ),
    "overlap": (
        "Jaccard |A∩B| / |A∪B| over the lanes' caught sets, with the shared "
        "count alongside."
    ),
}


# ────────────────────────────────────────────────────────────────────────
# input validation
# ────────────────────────────────────────────────────────────────────────

class InputError(ValueError):
    """A race input file failed validation."""


def _require(cond, msg):
    if not cond:
        raise InputError(msg)


def load_race(path):
    """Load and validate one race input file; return the dict."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except OSError as e:
        raise InputError("cannot read %s: %s" % (path, e))
    except json.JSONDecodeError as e:
        raise InputError("%s is not valid JSON: %s" % (path, e))
    _require(isinstance(data, dict), "%s: race input must be a JSON object" % path)
    _require(data.get("schema") == "race-input", "%s: missing schema==\"race-input\"" % path)
    _require(data.get("schema_version") == SCHEMA_VERSION,
             "%s: schema_version must be %d" % (path, SCHEMA_VERSION))
    for field in ("race_id", "task_type", "epoch"):
        _require(isinstance(data.get(field), str) and data[field].strip(),
                 "%s: missing non-empty string field %r" % (path, field))
    union = data.get("union")
    _require(isinstance(union, list) and union, "%s: union must be a non-empty list" % path)
    lanes = data.get("lanes")
    _require(isinstance(lanes, list) and lanes, "%s: lanes must be a non-empty list" % path)

    # union items
    item_ids = set()
    for it in union:
        _require(isinstance(it, dict) and it.get("id"), "%s: union item without id" % path)
        iid = it["id"]
        _require(iid not in item_ids, "%s: duplicate union item id %r" % (path, iid))
        item_ids.add(iid)
        it.setdefault("verdict", "real")
        _require(it["verdict"] in ("real", "false", "uncertain"),
                 "%s: item %s verdict must be real|false|uncertain, got %r"
                 % (path, iid, it["verdict"]))
        if not it.get("statement"):
            raise InputError("%s: union item %s needs a statement" % (path, iid))

    # lanes
    lane_ids = set()
    form_b_present = False
    for ln in lanes:
        _require(isinstance(ln, dict) and ln.get("id"), "%s: lane without id" % path)
        lid = ln["id"]
        _require(lid not in lane_ids, "%s: duplicate lane id %r" % (path, lid))
        lane_ids.add(lid)
        if not ln.get("model"):
            ln["model"] = lid  # opaque lane label is legal; documented
        findings = ln.get("findings")
        if findings is not None:
            _require(isinstance(findings, list),
                     "%s: lane %s findings must be a list" % (path, lid))
            fids = set()
            for f in findings:
                _require(isinstance(f, dict) and f.get("id"),
                         "%s: lane %s finding without id" % (path, lid))
                _require(f["id"] not in fids,
                         "%s: lane %s duplicate finding id %r" % (path, lid, f["id"]))
                fids.add(f["id"])
        cost = ln.get("cost")
        if cost is not None:
            _require(isinstance(cost, (int, float)) and cost >= 0,
                     "%s: lane %s cost must be a non-negative number or null" % (path, lid))
            _require(ln.get("cost_unit"),
                     "%s: lane %s cost present without cost_unit" % (path, lid))

    # caught_by on union items (form B)
    for it in union:
        cb = it.get("caught_by")
        if cb is not None:
            form_b_present = True
            _require(isinstance(cb, list), "%s: item %s caught_by must be a list" % (path, it["id"]))
            for lid in cb:
                _require(lid in lane_ids,
                         "%s: item %s caught_by names unknown lane %r" % (path, it["id"], lid))

    # mappings (form A)
    mappings = data.get("mappings", [])
    if mappings:
        _require(isinstance(mappings, list), "%s: mappings must be a list" % path)
        for m in mappings:
            _require(isinstance(m, dict), "%s: mapping entry must be an object" % path)
            _require(m.get("lane") in lane_ids,
                     "%s: mapping names unknown lane %r" % (path, m.get("lane")))
            _require(m.get("item") in item_ids,
                     "%s: mapping names unknown union item %r" % (path, m.get("item")))
    # every finding must be mapped exactly once
    if mappings:
        seen = set()
        for ln in lanes:
            for f in (ln.get("findings") or []):
                key = (ln["id"], f["id"])
                _require(key not in seen, "%s: duplicate mapping key %r" % (path, key))
                seen.add(key)
        mapped = set((m["lane"], m["finding"]) for m in mappings)
        for key in seen:
            _require(key in mapped,
                     "%s: lane %s finding %s is unmapped (input must declare every "
                     "merge decision; an unmapped finding is not silently dropped)"
                     % (path, key[0], key[1]))
        for m in mappings:
            _require((m["lane"], m["finding"]) in seen,
                     "%s: mapping references unknown finding %r in lane %r"
                     % (path, m.get("finding"), m.get("lane")))

    # both forms must agree
    if mappings and form_b_present:
        by_item = {}
        for m in mappings:
            by_item.setdefault(m["item"], set()).add(m["lane"])
        for it in union:
            declared = set(it.get("caught_by") or [])
            derived = by_item.get(it["id"], set())
            _require(declared == derived,
                     "%s: caught_by and mappings disagree on item %s "
                     "(declared %s, derived %s)" % (path, it["id"],
                                                    sorted(declared), sorted(derived)))
    data["_item_ids"] = item_ids
    data["_lane_ids"] = lane_ids
    return data


# ────────────────────────────────────────────────────────────────────────
# caught-matrix derivation
# ────────────────────────────────────────────────────────────────────────

def derive_caught(race):
    """Return (caught_by_item, merges).

    caught_by_item: dict item_id -> sorted list of lane ids that caught it
                    (real+uncertain+false items all included; verdict
                    filtering happens in the stats).
    merges: dict with raw_findings / mappings / merge_decisions /
            split_decisions / policy / note.
    """
    item_ids = [it["id"] for it in race["union"]]
    lanes = race["lanes"]
    lane_ids = [ln["id"] for ln in lanes]
    policy = race.get("merge_policy") or ""
    mappings = race.get("mappings") or []
    caught = {iid: set() for iid in item_ids}

    if mappings:
        raw_findings = sum(len(ln.get("findings") or []) for ln in lanes)
        # completeness: every finding mapped exactly once, no dangling refs
        finding_ids = {}
        for ln in lanes:
            finding_ids[ln["id"]] = {f["id"] for f in (ln.get("findings") or [])}
        seen = set()
        for ln in lanes:
            for f in (ln.get("findings") or []):
                key = (ln["id"], f["id"])
                if key in seen:
                    raise InputError(
                        "lane %s has duplicate finding id %r" % (ln["id"], f["id"]))
                seen.add(key)
        mapped = set((m["lane"], m["finding"]) for m in mappings)
        for key in sorted(seen):
            if key not in mapped:
                raise InputError(
                    "lane %s finding %s is unmapped (every merge decision must "
                    "be declared; an unmapped finding is not silently dropped)"
                    % (key[0], key[1]))
        for m in mappings:
            if m["finding"] not in finding_ids.get(m["lane"], set()):
                raise InputError(
                    "mapping references unknown finding %r in lane %r"
                    % (m["finding"], m["lane"]))
        # per canonical item: how many findings mapped onto it
        per_item = {}
        for m in mappings:
            per_item.setdefault(m["item"], []).append((m["lane"], m["finding"]))
        merge_decisions = 0
        split_decisions = 0
        for iid, hits in per_item.items():
            if len(hits) > 1:
                merge_decisions += len(hits) - 1
            for (lid, _fid) in hits:
                caught[iid].add(lid)
        # split: a single finding mapped to >= 2 items
        per_finding = {}
        for m in mappings:
            per_finding.setdefault((m["lane"], m["finding"]), []).append(m["item"])
        for key, items in per_finding.items():
            if len(items) > 1:
                split_decisions += 1
        merges = {
            "form": "A (explicit mappings)",
            "raw_findings": raw_findings,
            "mappings": len(mappings),
            "merge_decisions": merge_decisions,
            "split_decisions": split_decisions,
            "policy": policy,
            "note": ("merge/split counts derived mechanically from the input "
                     "mappings: a merge is a second-or-later finding mapped "
                     "onto an already-mapped canonical item; a split is one "
                     "finding mapped onto two or more items."),
        }
    else:
        for it in race["union"]:
            for lid in (it.get("caught_by") or []):
                caught[it["id"]].add(lid)
        merges = {
            "form": "B (caught_by declared; merges upstream)",
            "raw_findings": None,
            "mappings": None,
            "merge_decisions": 0,
            "split_decisions": 0,
            "policy": policy,
            "note": ("no merge decisions were made by this reduction: the "
                     "input declared caught sets directly and the race's own "
                     "grader documented the dedup. The input notes must name "
                     "that documentation."),
        }
    for iid in caught:
        caught[iid] = sorted(caught[iid])
    return caught, merges


# ────────────────────────────────────────────────────────────────────────
# statistics
# ────────────────────────────────────────────────────────────────────────

def _frac(num, den):
    if den == 0:
        return None
    return round(num / den, 6)


def compute_group(races):
    """One (task_type, epoch) group from one or more race dicts."""
    # Pool union items across races by id.  Same id = same finding (the input
    # producer's responsibility, documented).  Conflicting verdicts error.
    union = {}
    for race in races:
        for it in race["union"]:
            prev = union.get(it["id"])
            if prev is not None and prev["verdict"] != it["verdict"]:
                raise InputError(
                    "races %s and %s disagree on verdict of union item %s "
                    "(%s vs %s)" % (prev["_race"], race["race_id"], it["id"],
                                    prev["verdict"], it["verdict"]))
            union[it["id"]] = dict(it)
    items = [union[iid] for iid in sorted(union)]

    real_ids = [it["id"] for it in items if it["verdict"] == "real"]
    n = len(real_ids)
    n_false = sum(1 for it in items if it["verdict"] == "false")
    n_uncertain = sum(1 for it in items if it["verdict"] == "uncertain")

    caught = {iid: set() for iid in union}
    for race in races:
        c, _m = derive_caught(race)
        for iid, lanes in c.items():
            caught[iid] |= set(lanes)
    for iid in caught:
        caught[iid] = sorted(caught[iid])

    lane_ids = []
    for race in races:
        for ln in race["lanes"]:
            if ln["id"] not in lane_ids:
                lane_ids.append(ln["id"])
    lane_ids.sort()

    def catches_of(lid):
        return set(i for i in union if lid in caught[i])

    def unique_of(lid):
        mine = catches_of(lid)
        others = set()
        for o in lane_ids:
            if o != lid:
                others |= catches_of(o)
        return mine - others

    # per-lane stats over real items only
    real_set = set(real_ids)
    per_lane = {}
    for lid in lane_ids:
        mine_real = catches_of(lid) & real_set
        uniq_real = unique_of(lid) & real_set
        n_catches = len(mine_real)
        n_unique = len(uniq_real)
        model = None
        cost = None
        cost_unit = None
        cost_note = None
        task_id = None
        source = None
        source_sha256 = None
        for race in races:
            for ln in race["lanes"]:
                if ln["id"] == lid:
                    model = ln.get("model")
                    cost = ln.get("cost")
                    cost_unit = ln.get("cost_unit")
                    cost_note = ln.get("cost_note")
                    task_id = ln.get("task_id")
                    source = ln.get("source")
                    source_sha256 = ln.get("source_sha256")
        per_lane[lid] = {
            "model": model,
            "task_id": task_id,
            "source": source,
            "source_sha256": source_sha256,
            "catches": n_catches,
            "unique_catches": n_unique,
            "unique_catch_rate": _frac(n_unique, n_catches) if n_catches else None,
            "unique_catch_over_union": _frac(n_unique, n) if n else None,
            "cost": cost,
            "cost_unit": cost_unit,
            "cost_note": cost_note,
        }

    # overlap matrix (real items)
    overlap = {}
    if len(lane_ids) >= 2:
        for a in lane_ids:
            row = {}
            for b in lane_ids:
                if a == b:
                    continue
                ia = catches_of(a) & real_set
                ib = catches_of(b) & real_set
                shared = len(ia & ib)
                jac = _frac(shared, len(ia | ib)) if (ia | ib) else None
                row[b] = {"shared": shared, "jaccard": jac}
            overlap[a] = row
    overlap_note = None if overlap else (
        "undefined: %d lane(s); overlap needs at least two lanes" % len(lane_ids))

    # best subsets of size k over real items
    L = len(lane_ids)
    best_subsets = {}
    if n == 0:
        for k in range(1, L + 1):
            best_subsets[str(k)] = {"coverage": None, "covered": 0,
                                    "best": [], "cost": None,
                                    "cost_unknown": True,
                                    "note": "no real items; coverage undefined"}
    elif L <= 20:
        for k in range(1, L + 1):
            best_cov = -1
            best_list = []
            for combo in itertools.combinations(lane_ids, k):
                covered = set()
                for lid in combo:
                    covered |= (catches_of(lid) & real_set)
                cov = len(covered)
                if cov > best_cov:
                    best_cov = cov
                    best_list = [combo]
                elif cov == best_cov:
                    best_list.append(combo)
            best_list = sorted(tuple(sorted(c)) for c in best_list)
            cost, unknown = _subset_cost(best_list[0], races)
            best_subsets[str(k)] = {
                "coverage": _frac(best_cov, n),
                "covered": best_cov,
                "best": [list(c) for c in best_list],
                "cost": cost,
                "cost_unit": "tokens" if cost is not None else None,
                "cost_unknown": unknown,
            }
    else:
        # greedy first-fit with a loud note; exact search is exponential
        remaining = set(lane_ids)
        chosen = []
        covered = set()
        while remaining:
            best_lid, best_gain = None, -1
            for lid in remaining:
                gain = len((catches_of(lid) & real_set) - covered)
                if gain > best_gain:
                    best_gain, best_lid = gain, lid
            chosen.append(best_lid)
            covered |= (catches_of(best_lid) & real_set)
            remaining.discard(best_lid)
        for k in range(1, L + 1):
            sub = chosen[:k]
            cov = len(set().union(*[(catches_of(l) & real_set) for l in sub]))
            cost, unknown = _subset_cost(sub, races)
            best_subsets[str(k)] = {
                "coverage": _frac(cov, n),
                "covered": cov,
                "best": [list(sub)],
                "cost": cost,
                "cost_unit": "tokens" if cost is not None else None,
                "cost_unknown": unknown,
                "note": ("greedy first-fit (exact search not attempted: "
                         "%d lanes)" % L),
            }

    # uncaught items + false raises
    uncaught = [iid for iid in real_ids if not caught[iid]]
    false_raises = {}
    for lid in lane_ids:
        fr = []
        for iid in sorted(union):
            if union[iid]["verdict"] != "real" and lid in caught[iid]:
                fr.append(iid)
        false_raises[lid] = fr

    # caught matrix (real items) — the raw data T636-style consumers need
    caught_matrix = {iid: caught[iid] for iid in real_ids}

    race_ids = [r["race_id"] for r in races]
    return {
        "task_type": races[0]["task_type"],
        "epoch": races[0]["epoch"],
        "race_ids": sorted(race_ids),
        "spec": races[0].get("spec"),
        "n": n,
        "n_false_excluded": n_false,
        "n_uncertain_excluded": n_uncertain,
        "prior_warning": True,
        "sample_note": (
            "numbers from %d race(s) (%s); a complementarity number from one "
            "race is a PRIOR, labelled one, not a measurement — re-run as "
            "more races are absorbed." % (len(race_ids), ", ".join(sorted(race_ids)))),
        "uncaught_items": sorted(uncaught),
        "per_lane": per_lane,
        "overlap_matrix": overlap or None,
        "overlap_note": overlap_note,
        "best_subsets": best_subsets,
        "false_raises": false_raises,
        "caught_matrix": caught_matrix,
        "merges": derive_caught(races[0])[1] if len(races) == 1 else _pooled_merges(races),
    }


def _pooled_merges(races):
    total = {"form": "A (explicit mappings)" if races[0].get("mappings") else "B",
             "raw_findings": 0, "mappings": 0,
             "merge_decisions": 0, "split_decisions": 0,
             "policy": races[0].get("merge_policy") or "",
             "note": "merged across %d races; per-race counts summed" % len(races)}
    for race in races:
        m = derive_caught(race)[1]
        for k in ("raw_findings", "mappings", "merge_decisions", "split_decisions"):
            v = m.get(k)
            if isinstance(v, int):
                total[k] += v
    return total


def _subset_cost(subset, races):
    """Sum of lane costs for a subset; (sum, unknown_flag)."""
    total = 0
    unknown = False
    found = {}
    for race in races:
        for ln in race["lanes"]:
            found[ln["id"]] = ln
    for lid in subset:
        c = found.get(lid, {}).get("cost")
        if c is None:
            unknown = True
        else:
            total += c
    return (None if unknown else total), unknown


# ────────────────────────────────────────────────────────────────────────
# rendering
# ────────────────────────────────────────────────────────────────────────

def _sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def reduce_inputs(paths):
    """Load inputs, verify optional source hashes, compute the record."""
    races = []
    for p in paths:
        race = load_race(p)
        races.append(race)
        race["_race"] = race["race_id"]
        for ln in race["lanes"]:
            src = ln.get("source")
            want = ln.get("source_sha256")
            if src and want and os.path.isfile(src):
                got = _sha256(src)
                if got != want:
                    raise InputError(
                        "%s: lane %s source %s sha256 mismatch (input says %s, "
                        "disk has %s)" % (p, ln["id"], src, want, got))
    groups = {}
    for race in races:
        key = "%s/%s" % (race["task_type"], race["epoch"])
        groups.setdefault(key, []).append(race)
    groups_out = {}
    for key in sorted(groups):
        groups_out[key] = compute_group(groups[key])
    record = {
        "record_version": RECORD_VERSION,
        "disclaimer": DISCLAIMER,
        "rate_definitions": RATE_DEFINITIONS,
        "generated_from": [
            {"race_id": r["race_id"], "input": p, "sha256": _sha256(p)}
            for p, r in zip(paths, races)
        ],
        "groups": groups_out,
    }
    return record


def render(record):
    return json.dumps(record, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


# ────────────────────────────────────────────────────────────────────────
# controls (the brief's four, plus schema-validation)
# ────────────────────────────────────────────────────────────────────────

def _synthetic_race(race_id, task_type, union, lanes, mappings=None):
    """Build a race dict exactly as load_race would validate it."""
    for it in union:
        it.setdefault("verdict", "real")
    return {
        "schema": "race-input",
        "schema_version": SCHEMA_VERSION,
        "race_id": race_id,
        "task_type": task_type,
        "epoch": "synthetic",
        "merge_policy": "synthetic control: one finding per union item per lane.",
        "union": union,
        "lanes": lanes,
        "mappings": mappings or [],
    }


def _disjoint_race():
    """Control 1: A and B have known disjoint finding sets."""
    union = [
        {"id": "F1", "statement": "defect one"},
        {"id": "F2", "statement": "defect two"},
        {"id": "F3", "statement": "defect three"},
        {"id": "F4", "statement": "defect four"},
    ]
    lanes = [
        {"id": "A", "model": "m-a",
         "findings": [{"id": "a1", "statement": "defect one"},
                      {"id": "a2", "statement": "defect two"}]},
        {"id": "B", "model": "m-b",
         "findings": [{"id": "b1", "statement": "defect three"},
                      {"id": "b2", "statement": "defect four"}]},
    ]
    mappings = [
        {"lane": "A", "finding": "a1", "item": "F1"},
        {"lane": "A", "finding": "a2", "item": "F2"},
        {"lane": "B", "finding": "b1", "item": "F3"},
        {"lane": "B", "finding": "b2", "item": "F4"},
    ]
    return _synthetic_race("race-disjoint", "audit", union, lanes, mappings)


def _subset_race():
    """Control 2: B's findings a strict subset of A's; C disjoint from A."""
    union = [
        {"id": "F1", "statement": "defect one"},
        {"id": "F2", "statement": "defect two"},
        {"id": "F3", "statement": "defect three"},
        {"id": "F4", "statement": "defect four"},
        {"id": "F5", "statement": "defect five"},
        {"id": "F6", "statement": "defect six"},
    ]
    lanes = [
        {"id": "A", "model": "m-a",
         "findings": [{"id": "a%d" % i, "statement": "defect %d" % i}
                      for i in range(1, 5)]},
        {"id": "B", "model": "m-b",
         "findings": [{"id": "b1", "statement": "defect one"},
                      {"id": "b2", "statement": "defect two"}]},
        {"id": "C", "model": "m-c",
         "findings": [{"id": "c1", "statement": "defect five"},
                      {"id": "c2", "statement": "defect six"}]},
    ]
    mappings = ([{"lane": "A", "finding": "a%d" % i, "item": "F%d" % i}
                 for i in range(1, 5)]
                + [{"lane": "B", "finding": "b1", "item": "F1"},
                   {"lane": "B", "finding": "b2", "item": "F2"}]
                + [{"lane": "C", "finding": "c1", "item": "F5"},
                   {"lane": "C", "finding": "c2", "item": "F6"}])
    return _synthetic_race("race-subset", "audit", union, lanes, mappings)


def _null_race():
    """Control 3: a single-lane race."""
    union = [
        {"id": "F1", "statement": "defect one"},
        {"id": "F2", "statement": "defect two"},
    ]
    lanes = [{"id": "A", "model": "m-a",
              "findings": [{"id": "a1", "statement": "defect one"},
                           {"id": "a2", "statement": "defect two"}]}]
    mappings = [{"lane": "A", "finding": "a%d" % i, "item": "F%d" % i}
                for i in (1, 2)]
    return _synthetic_race("race-null", "audit", union, lanes, mappings)


def _run_checks():
    fails = []

    def ok(cond, msg):
        if cond:
            print("  PASS: %s" % msg)
        else:
            print("  FAIL: %s" % msg)
            fails.append(msg)

    # control 1: disjoint
    print("1. seeded disjoint: overlap 0, both unique_catch_rate 1.0, "
          "subset-of-2 reaches the full union")
    g = compute_group([_disjoint_race()])
    pl = g["per_lane"]
    ok(pl["A"]["unique_catch_rate"] == 1.0, "A unique_catch_rate == 1.0")
    ok(pl["B"]["unique_catch_rate"] == 1.0, "B unique_catch_rate == 1.0")
    ok(pl["A"]["unique_catch_over_union"] == 0.5,
       "A unique_catch_over_union == 0.5 (4-item union, 2 unique)")
    ok(g["overlap_matrix"]["A"]["B"]["jaccard"] == 0.0,
       "overlap(A,B) jaccard == 0")
    ok(g["overlap_matrix"]["A"]["B"]["shared"] == 0, "overlap(A,B) shared == 0")
    ok(g["best_subsets"]["2"]["coverage"] == 1.0,
       "best-subset-of-2 coverage == 1.0 (full union)")
    ok(set(map(tuple, g["best_subsets"]["2"]["best"])) == {("A", "B")},
       "best-subset-of-2 is {A,B}")

    # control 2: subset
    print("2. seeded subset: B ⊂ A (C disjoint) -> B unique_catch_rate 0, "
          "{A,B} not picked")
    g = compute_group([_subset_race()])
    ok(g["per_lane"]["B"]["unique_catch_rate"] == 0.0,
       "B unique_catch_rate == 0")
    ok(g["per_lane"]["B"]["unique_catch_over_union"] == 0.0,
       "B unique_catch_over_union == 0")
    best2 = set(map(tuple, g["best_subsets"]["2"]["best"]))
    ok(("A", "B") not in best2, "best-subset-of-2 does not pick {A,B}")
    ok(("A", "C") in best2 and g["best_subsets"]["2"]["coverage"] == 1.0,
       "best-subset-of-2 is {A,C} at full union")

    # control 3: null single-lane
    print("3. null: single-lane race -> overlap matrix undefined, says so")
    g = compute_group([_null_race()])
    ok(g["overlap_matrix"] is None, "overlap_matrix is null")
    ok(g["overlap_note"] is not None and "needs at least two lanes" in g["overlap_note"],
       "overlap_note says undefined (one lane)")
    ok(g["best_subsets"]["1"]["coverage"] == 1.0, "best-subset-of-1 still computed")

    # control 4: determinism — same race fed twice -> byte-identical
    print("4. determinism: same race fed twice -> byte-identical output")
    r1 = reduce_inputs_from_dicts([_disjoint_race(), _subset_race()])
    r2 = reduce_inputs_from_dicts([_disjoint_race(), _subset_race()])
    ok(r1 == r2, "record bytes identical across two runs of the same input")
    out = render(r1)
    ok("generated_from" in json.loads(out), "output parses as JSON")

    # schema validation: a bad input is refused loudly
    print("5. validation: an unmapped finding is an input error, not a drop")
    bad = _subset_race()
    del bad["mappings"][-1]  # leave c2 unmapped
    try:
        compute_group([bad])
        ok(False, "unmapped finding refused")
    except InputError:
        ok(True, "unmapped finding refused with InputError")

    print("")
    if fails:
        print("=== complementarity check: %d FAILURE(S) ===" % len(fails))
        return 1
    print("=== complementarity check: ALL CONTROLS PASSED ===")
    return 0


def reduce_inputs_from_dicts(race_dicts):
    """reduce over in-memory race dicts (used by the self-tests)."""
    groups = {}
    for race in race_dicts:
        race["_race"] = race["race_id"]
        key = "%s/%s" % (race["task_type"], race["epoch"])
        groups.setdefault(key, []).append(race)
    record = {
        "record_version": RECORD_VERSION,
        "disclaimer": DISCLAIMER,
        "rate_definitions": RATE_DEFINITIONS,
        "generated_from": [
            {"race_id": r["race_id"], "input": "<synthetic>", "sha256": None}
            for r in race_dicts
        ],
        "groups": {k: compute_group(v) for k, v in sorted(groups.items())},
    }
    return record


SCHEMA_TEXT = """INPUT SCHEMA (race file, one JSON per race) — schema==\"race-input\", schema_version==%d

  race_id        string, unique across the record
  task_type      string; groups the record (e.g. \"spec-audit\", \"adjudication\")
  epoch          string; groups the record (e.g. \"2026-08-22\")
  spec           optional string naming the subject artifact
  notes          optional free text; cite provenance
  merge_policy   one sentence stating how two differently worded items were
                 decided to be one finding (the record repeats it)
  union[]        the graded reference union:
    id           string
    statement    string
    verdict      \"real\" | \"false\" | \"uncertain\" (default \"real\")
    caught_by    [lane ids]  -- form B (direct caught sets); optional
  lanes[]:
    id, model    lane id; model (canonical label or opaque)
    task_id, source, source_sha256   optional provenance (sha256 verified
                 against disk when the file exists)
    cost, cost_unit, cost_note       optional measured cost; null = unknown
    findings[]   {id, statement}     -- form A (raw finding sets); optional
  mappings[]     {lane, finding, item}  -- form A; every finding mapped
                 exactly once; the merge/split counts derive from this list

Both forms may coexist only if they agree exactly (cross-checked).

OUTPUT SCHEMA (the standing complementarity record) — record_version %d
  disclaimer            repeated honesty rule (union-of-found, never truth)
  rate_definitions      the two rate definitions + overlap, verbatim
  generated_from[]      {race_id, input path, sha256} — verifiable provenance
  groups[\"task_type/epoch\"]:
    n, n_false_excluded, n_uncertain_excluded
    prior_warning, sample_note      (one race = a prior, labelled one)
    uncaught_items[]    union items no lane caught (absorption path)
    per_lane[lane]      model, task_id, source, source_sha256,
                        catches, unique_catches, unique_catch_rate,
                        unique_catch_over_union, cost, cost_unit, cost_note
    overlap_matrix[lane][other]     {shared, jaccard}  (null for 1 lane)
    best_subsets[k]     coverage (over n), covered, best[] (all tied,
                        sorted), cost, cost_unit, cost_unknown
    false_raises[lane]  excluded items the lane raised (cost-side census)
    caught_matrix[item] lanes that caught it — the raw matrix for
                        marginal-complementarity consumers (T636)
    merges              form, raw_findings, mappings, merge_decisions,
                        split_decisions, policy, note
""" % (SCHEMA_VERSION, RECORD_VERSION)


def main(argv):
    ap = argparse.ArgumentParser(
        prog="tools/complementarity.py",
        description="T637: race artifacts -> standing complementarity record.")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p_reduce = sub.add_parser("reduce", help="reduce race files to the record")
    p_reduce.add_argument("--input", action="append", required=True,
                          metavar="FILE", help="race input file (repeatable)")
    p_reduce.add_argument("--out", metavar="FILE", help="write record here "
                          "(default: stdout)")
    sub.add_parser("check", help="run the controls (the brief's four)")
    sub.add_parser("schema", help="print the input/output schema (the interface)")
    args = ap.parse_args(argv)

    if args.cmd == "check":
        return _run_checks()
    if args.cmd == "schema":
        sys.stdout.write(SCHEMA_TEXT)
        return 0
    # reduce
    for p in args.input:
        if not os.path.isfile(p):
            sys.stderr.write("complementarity: no such input file: %s\n" % p)
            return 2
    try:
        record = reduce_inputs(args.input)
    except InputError as e:
        sys.stderr.write("complementarity: %s\n" % e)
        return 2
    out = render(record)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(out)
        sys.stderr.write("complementarity: wrote %s\n" % args.out)
    else:
        sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
