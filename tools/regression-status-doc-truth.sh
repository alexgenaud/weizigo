#!/usr/bin/env bash
# regression-status-doc-truth.sh — status docs must agree with the task store (T864)
#
# The module: sprint planning documents — `docs/epics/**/STATUS.md` (and future
# siblings that name task IDs and assert a state for them).  The suite this
# script owns is the module's only test suite.
#
# Why this exists: the orchestration seat corrected a sprint STATUS document by
# hand — twice, in one session — with no test.  First its labels were ambiguous
# (RUN), then it showed two work arms in flight after both had closed.  Prose
# documents are modules too, so the module gets a suite like every other module:
# red against the actual historical defect, green at HEAD, and provably able to
# fail (seeded control) and to stay silent (no-false-alarm control).
#
# What the check asserts, per document:
#   1. EXISTENCE — every task ID cited exists in the task store (or the archive,
#      the durable record of retired rows).  A document citing a row that does
#      not exist asserts something unverifiable.
#   2. AGREEMENT — every row that names a store task and carries a state label
#      must agree with the store.  The label -> store-status mapping is derived
#      from the document's OWN declared legend (each label's prose is classified
#      by lifecycle keywords), never from a hardcoded vocabulary.  A document
#      saying a row is in flight while the store says it is closed is the exact
#      defect this row exists to catch.
#   3. DECLARATION — every label used on a task row must be declared in the
#      document's legend.  An undeclared label is how ambiguity enters.
#
# Documents with NO parseable legend are reported as UNKNOWN (rows cannot be
# checked against the store) rather than failed — an unmeasurable document is
# not a lying one (brief constraint; S01 and S06 are such documents).
#
# Four arms, per the acceptance criteria:
#   A. RED against real history — the S11 STATUS.md revision at 2efaac3 (the
#      version committed before the seat's correction) shows T859 and T860 as
#      ACTIVE while the store has both done.  The check MUST fail there, naming
#      both rows and both states.  This is the actual historical defect, not a
#      seeded one.
#   B. GREEN at HEAD — the same check passes against the live documents and the
#      live store, and prints the census the brief asks for (how many status
#      documents exist, how many rows were cross-checked, which documents have
#      no legend).
#   C. Control, still able to fail — one label change seeded into a scratch copy
#      of the HEAD document goes red, naming the row and both states.
#   D. Control, no false alarm — a document whose rows genuinely match the store
#      must be SILENT (exit 0, zero FAIL lines).  Asserted, not just quiet.
#
# Design decisions (each reasoned):
#   - The state-vocabulary legend is detected structurally: backtick-quoted
#     labels whose descriptions are separated by '·', where at least one
#     description names a lifecycle state.  A paragraph of backtick tokens about
#     commits or models is NOT a legend (S06's first paragraph, which contains
#     both '·' and backticks, is correctly reported as having no legend).
#   - The undeclared-label check applies to rows that name a store task.  State
#     cells on rows with no task ID (e.g. S11's "grade (untracked)" rows saying
#     "awaiting dispatch") are prose about the seat's next action, not store
#     assertions; requiring them to be in the legend would fail HEAD, which the
#     brief's acceptance says must pass.
#   - Existence accepts rows in the archive as well as the live store: S06 cites
#     T771, which was retired and lives in archive.json.  A retired row is
#     recorded and verifiable; the archive is the durable record.
#   - A cited "T123-foo" resolves by stripping -suffixes (T556-stats -> T556,
#     T802-consolidation-sprint -> T802); a bare base id with no such row still
#     fails (T441 when only T441-AUDIT exists is a citation of nothing).
#   - Named (non-numeric) task ids like ORCHA-FLASH cannot be distinguished from
#     prose when MISSING from the store, so existence is verified only for the
#     named ids the store itself knows (the vocabulary is the store).  Numeric
#     ids are checked both ways.
#
# Task: T864 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-24
# Landmark: L1 (the dashboard tells the truth) — a module whose changes had no
# gate now has one; a seat edit that lied about the store is a red suite.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
FAIL=0
START="$(python3 -c 'import time; print(time.time())')"

# GIT_DIR-leak guard (T848 precedent): never depend on the pre-commit hook
# having already unset the redirects before we call git.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_NAMESPACE

command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 required"; exit 0; }
command -v git >/dev/null 2>&1 || { echo "SKIP: git required"; exit 0; }
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "SKIP: not a git repo"; exit 0; }
if [ "$ROOT" != "$PROJECT" ]; then
    echo "SKIP: must run inside the repository checkout (found $ROOT)"
    exit 0
fi

mkdir -p /tmp/weizigo
WORK="$(mktemp -d /tmp/weizigo/T864-status-doc-truth.XXXXXX)" || { echo "FAIL: cannot create scratch dir"; exit 1; }
trap 'rm -rf "$WORK"' EXIT

STORE="$PROJECT/docs/infra/managent/tasks.json"
ARCHIVE="$PROJECT/docs/infra/managent/archive.json"
[ -f "$STORE" ] || { echo "FAIL: task store missing: $STORE"; exit 1; }
[ -f "$ARCHIVE" ] || { echo "FAIL: archive missing: $ARCHIVE"; exit 1; }

S11="$PROJECT/docs/epics/E1-markovian/L1-dashboard/S11-honest-instruments/STATUS.md"
HIST_COMMIT=2efaac3   # the S11 revision committed before the seat's correction
HIST_PATH="docs/epics/E1-markovian/L1-dashboard/S11-honest-instruments/STATUS.md"

# ── the checker (embedded; the instrument and its test travel together) ──────
CHECKER="$WORK/status-doc-truth-check.py"
cat > "$CHECKER" <<'PYEOF'
#!/usr/bin/env python3
"""status-doc-truth checker (T864).  Usage: check.py <store.json> <doc.md>...
Exit 0 iff no failures; 1 on failures; 2 on usage/IO errors.
stdout carries the per-document report and the SUMMARY census line."""
import json, re, sys, time

NOT_STARTED_KW = ["not started", "pending", "queued", "unstarted", "not begun",
                  "to be run", "to-be-run", "waiting", "not yet"]
IN_PROGRESS_KW = ["execut", "in flight", "in progress", "running", "claimed",
                  "working on"]
DONE_KW = ["landed", "done", "complete", "completed", "audited", "graded",
           "accepted", "closed", "finished", "final", "reconciled", "merged"]

def class_of(desc):
    d = desc.lower()
    if any(k in d for k in NOT_STARTED_KW): return "not_started"
    if any(k in d for k in IN_PROGRESS_KW): return "in_progress"
    if any(k in d for k in DONE_KW): return "done"
    return "unknown"

TID_RE = re.compile(r"\bT\d+(?:-[A-Za-z0-9]+)*\b")

def resolve_tid(tok, store_keys, arch_keys):
    parts = tok.split("-")
    for i in range(len(parts), 0, -1):
        cand = "-".join(parts[:i])
        if cand in store_keys: return cand, "store"
        if cand in arch_keys: return cand, "archive"
    return None, None

def load_store(path):
    try:
        d = json.load(open(path, encoding="utf-8"))
    except Exception as e:
        sys.stderr.write(f"status-doc-truth: cannot read store {path}: {e}\n")
        sys.exit(2)
    return {k: v for k, v in d.items() if not k.startswith("_")}

def is_legend_line(s, prev_legend):
    """A legend line carries backtick-quoted labels whose descriptions are
    separated by '·' (a state-vocabulary signature), or continues a legend run."""
    spans = list(re.finditer(r"`([^`]+)`", s))
    if not spans:
        return False
    for i in range(len(spans) - 1):
        between = s[spans[i].end():spans[i + 1].start()]
        if "·" in between:
            return True
    return prev_legend and s.startswith("`")

def parse_legend(text):
    """Find the document's declared state vocabulary.  Returns (label->desc, ok)."""
    cand, prev = [], False
    for ln in text.splitlines():
        s = ln.strip()
        if s.startswith("|"):
            prev = False
            continue
        if is_legend_line(s, prev):
            cand.append(s)
            prev = True
        else:
            prev = False
    if not cand:
        return {}, False
    joined = " ".join(cand)
    spans = [(m.start(), m.end(), m.group(1))
             for m in re.finditer(r"`([^`]+)`", joined)]
    if len(set(lab for _, _, lab in spans)) < 2:
        return {}, False
    legend = {}
    for i, (st, en, lab) in enumerate(spans):
        desc = joined[en:spans[i + 1][0]] if i + 1 < len(spans) else joined[en:]
        desc = re.sub(r"^[\s·|,;:]+", "", desc)
        desc = re.sub(r"[\s·|,;:]+$", "", desc)
        legend[lab] = desc
    # a state vocabulary must describe at least one lifecycle state
    if not any(class_of(d) != "unknown" for d in legend.values()):
        return {}, False
    return legend, True

def extract_label(cell):
    c = cell.strip()
    m = re.match(r"\*\*([^*]+)\*\*", c)
    if m: return m.group(1).strip()
    m = re.match(r"`([^`]+)`", c)
    if m: return m.group(1).strip()
    w = c.split()[0] if c.split() else ""
    return w.strip("*`")

def split_row(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def parse_tables(text):
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith("|"):
            header = split_row(lines[i])
            j, rows = i + 1, []
            while j < len(lines) and lines[j].strip().startswith("|"):
                cells = split_row(lines[j])
                if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells if c):
                    rows.append(cells)
                j += 1
            yield header, rows
            i = j
        else:
            i += 1

def check_doc(path, store, arch_keys, store_keys):
    try:
        text = open(path, encoding="utf-8").read()
    except Exception as e:
        sys.stderr.write(f"status-doc-truth: cannot read document {path}: {e}\n")
        sys.exit(2)
    legend, legend_ok = parse_legend(text)
    legend_labels = set(legend) if legend_ok else set()
    fails, unknowns = [], []
    verified = 0
    # 1. existence — whole document
    for tok in sorted(set(TID_RE.findall(text))):
        r, _ = resolve_tid(tok, store_keys, arch_keys)
        if r is None:
            fails.append(f"missing task id '{tok}' cited in {path}: no such row in store or archive")
    # 2 + 3. agreement + declaration — table rows that name a store task
    for header, rows in parse_tables(text):
        hlow = [h.lower() for h in header]
        if "state" not in hlow:
            continue
        state_idx = hlow.index("state")
        for cells in rows:
            if len(cells) <= state_idx:
                continue
            tids = []
            for c in cells:
                for tok in TID_RE.findall(c):
                    r, where = resolve_tid(tok, store_keys, arch_keys)
                    if r and r not in [t[0] for t in tids]:
                        tids.append((r, where))
            if not tids:
                continue
            label = extract_label(cells[state_idx])
            for tid, where in tids:
                if where == "archive":
                    unknowns.append(f"{path}: row {cells[0]!r} ({tid}) cites an archived row — no live status to agree with")
                    continue
                if not legend_ok:
                    unknowns.append(f"{path}: row {cells[0]!r} ({tid}) label '{label}' — no parseable legend; state unchecked")
                    continue
                if label not in legend_labels:
                    fails.append(f"{path}: row {cells[0]!r} ({tid}) uses label '{label}' not declared in legend {sorted(legend_labels)}")
                    continue
                cls = class_of(legend[label])
                if cls == "unknown":
                    unknowns.append(f"{path}: row {cells[0]!r} ({tid}) label '{label}' — legend description '{legend[label]}' unclassifiable")
                    continue
                st = store.get(tid, {}).get("status", "MISSING")
                ok = {"not_started": {"dispatchable", "blocked"},
                      "in_progress": {"in_progress"},
                      "done": {"done", "failed"}}[cls]
                verified += 1
                if st not in ok:
                    fails.append(f"{path}: row {cells[0]!r} ({tid}): doc label '{label}' ({cls}) disagrees with store status '{st}'")
    return legend_ok, legend_labels, verified, unknowns, fails

def main():
    if len(sys.argv) < 3:
        sys.stderr.write("usage: status-doc-truth-check.py <store.json> <doc.md>...\n")
        sys.exit(2)
    store_path, doc_paths = sys.argv[1], sys.argv[2:]
    t0 = time.perf_counter()
    store = load_store(store_path)
    store_keys = set(store)
    arch_keys = set(load_store(store_path.replace("tasks.json", "archive.json")))
    total_verified = total_unknown = total_fails = 0
    n_legend = 0
    no_legend = []
    for p in doc_paths:
        legend_ok, labels, verified, unknowns, fails = check_doc(p, store, arch_keys, store_keys)
        total_verified += verified
        total_unknown += len(unknowns)
        total_fails += len(fails)
        n_legend += 1 if legend_ok else 0
        if not legend_ok:
            no_legend.append(p)
        print(f"== {p}")
        if legend_ok:
            print(f"   legend: yes ({', '.join(sorted(labels))})")
        else:
            print("   legend: NO")
        print(f"   rows verified: {verified}; rows unknown: {len(unknowns)}; failures: {len(fails)}")
        for f in fails: print("   FAIL: " + f)
        for u in unknowns: print("   UNKNOWN: " + u)
    dt = time.perf_counter() - t0
    print(f"SUMMARY: docs={len(doc_paths)} with_legend={n_legend} without_legend={len(no_legend)} "
          f"rows_verified={total_verified} rows_unknown={total_unknown} failures={total_fails} wall_s={dt:.3f}")
    for p in no_legend:
        print(f"NO_LEGEND: {p}")
    sys.exit(1 if total_fails else 0)

main()
PYEOF

echo "=== regression-status-doc-truth: status docs must agree with the task store (T864) ==="

# ══════════════════════════════════════════════════════════════════════════
# Arm A — RED against real history: the 2efaac3 S11 revision (before the
# seat's correction) showed T859 and T860 as ACTIVE while the store has both
# done.  The check MUST fail there, naming both rows and both states.
# ══════════════════════════════════════════════════════════════════════════
echo "  A. historical defect (2efaac3): must FAIL naming T859/T860 + ACTIVE/done"
git show "$HIST_COMMIT:$HIST_PATH" > "$WORK/historical.md" 2>/dev/null
if [ ! -s "$WORK/historical.md" ]; then
    echo "    FAIL: git show $HIST_COMMIT:$HIST_PATH produced nothing — the historical evidence is gone"
    FAIL=1
else
    for t in T859 T860; do
        st="$(python3 -c "import json,sys; print(json.load(open('$STORE')).get('$t',{}).get('status','MISSING'))")"
        if [ "$st" != "done" ]; then
            echo "    FAIL: precondition drift — live store row $t is '$st', expected 'done'; the historical arm's evidence changed"
            FAIL=1
        fi
    done
    out="$(python3 "$CHECKER" "$STORE" "$WORK/historical.md" 2>&1)"
    rc=$?
    if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'T859' \
       && printf '%s\n' "$out" | grep -q 'T860' \
       && printf '%s\n' "$out" | grep -q "label 'ACTIVE'" \
       && printf '%s\n' "$out" | grep -q "store status 'done'"; then
        echo "    PASS: historical revision red, naming both rows (T859, T860) and both states (ACTIVE vs done)"
    else
        echo "    FAIL: historical check rc=$rc; expected red naming T859/T860/ACTIVE/done:"
        printf '%s\n' "$out" | sed 's/^/      /'
        FAIL=1
    fi
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm B — GREEN at HEAD: the live documents against the live store.  Prints
# the census the brief asks for: documents, rows cross-checked, no-legend docs.
# ══════════════════════════════════════════════════════════════════════════
echo "  B. live documents at HEAD: must be green and print the census"
DOCS="$(find "$PROJECT/docs/epics" -name STATUS.md | sort)"
N_DOCS="$(printf '%s\n' "$DOCS" | grep -c .)"
out="$(python3 "$CHECKER" "$STORE" $DOCS 2>&1)"
rc=$?
printf '%s\n' "$out" | sed 's/^/    /'
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q "SUMMARY: docs=$N_DOCS" \
   && printf '%s\n' "$out" | grep -qE 'rows_verified=[1-9][0-9]*' \
   && printf '%s\n' "$out" | grep -q "NO_LEGEND: .*S01-process-ownership/pass1/STATUS.md" \
   && printf '%s\n' "$out" | grep -q "NO_LEGEND: .*S06-orchestration-refactor/STATUS.md"; then
    echo "    PASS: $N_DOCS status documents green at HEAD; rows cross-checked per SUMMARY above"
else
    echo "    FAIL: live check rc=$rc (docs=$N_DOCS); expected green with S01+S06 reported as no-legend"
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm C — control, still able to fail: one label change seeded into a scratch
# copy of the HEAD document must go red, naming the row and both states.
# Hermetic: scratch store mirrors the four S11 arm rows as done.
# ══════════════════════════════════════════════════════════════════════════
echo "  C. seeded control: one label change in a scratch copy must FAIL naming T857"
cat > "$WORK/armC-store.json" <<'JSONEOF'
{
  "T857": {"status": "done"},
  "T858": {"status": "done"},
  "T859": {"status": "done"},
  "T860": {"status": "done"}
}
JSONEOF
cp "$S11" "$WORK/armC-seeded.md"
python3 - "$WORK/armC-seeded.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
before = "| arm A (untracked) | T857 | oxalpha | **ARMS**"
after = "| arm A (untracked) | T857 | oxalpha | **ACTIVE**"
assert before in s, "seeded doc no longer matches the expected row shape — S11 changed"
open(p, "w", encoding="utf-8").write(s.replace(before, after))
PYEOF
out="$(python3 "$CHECKER" "$WORK/armC-store.json" "$WORK/armC-seeded.md" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -q 'T857' \
   && printf '%s\n' "$out" | grep -q "label 'ACTIVE'" \
   && printf '%s\n' "$out" | grep -q "store status 'done'"; then
    echo "    PASS: seeded label change red, naming the row (T857) and both states (ACTIVE vs done)"
else
    echo "    FAIL: seeded control rc=$rc; expected red naming T857/ACTIVE/done:"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=1
fi

# ══════════════════════════════════════════════════════════════════════════
# Arm D — control, no false alarm: a document whose rows genuinely match the
# store must be SILENT (exit 0, zero FAIL lines).  Hermetic scratch store.
# ══════════════════════════════════════════════════════════════════════════
echo "  D. silence control: a document that genuinely matches the store must be silent"
cat > "$WORK/armD-store.json" <<'JSONEOF'
{
  "T9001": {"status": "done"},
  "T9002": {"status": "in_progress"},
  "T9003": {"status": "dispatchable"}
}
JSONEOF
cat > "$WORK/armD-doc.md" <<'MDEOF'
# Scratch STATUS
**Legend:** `—` not started · `ACTIVE` a worker is executing it right now · `DONE` completed and verified.
| item | owner | state |
|---|---|---|
| task one | T9001 | **DONE** |
| task two | T9002 | **ACTIVE** |
| task three | T9003 | **—** |
MDEOF
out="$(python3 "$CHECKER" "$WORK/armD-store.json" "$WORK/armD-doc.md" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && ! printf '%s\n' "$out" | grep -q 'FAIL:'; then
    echo "    PASS: matching document silent (exit 0, no FAIL lines)"
else
    echo "    FAIL: silence control rc=$rc; a matching document must be silent:"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAIL=1
fi

# ── measured wall time ─────────────────────────────────────────────────────
END="$(python3 -c 'import time; print(time.time())')"
WALL="$(python3 -c "import sys; print(round(float(sys.argv[1]) - float(sys.argv[2]), 3))" "$END" "$START")"
echo ""
echo "  measured wall time: ${WALL}s (fast tier; brief budget 45s)"
if [ "$FAIL" -eq 0 ]; then
    echo "=== regression-status-doc-truth: ALL 4 ARMS PASSED ==="
    exit 0
else
    echo "=== regression-status-doc-truth: FAILURES ==="
    exit 1
fi
