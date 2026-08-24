#!/usr/bin/env bash
# regression-task-taxonomy.sh — T786: the frozen taxonomy gate.
#
# The corpus run (T817 brief-aware, T818/T820 blind + T819 adjudication)
# measured the classification law this gate encodes: where the vocabulary was
# closed, agreement was computable and a deterministic reader was perfect;
# where it was open, two capable models produced answers that could not even
# be compared.  So the taxonomy is FROZEN, not derived per-task:
#
#   type   — 9 legal values (audit, infra, orchestration, implement, battery,
#            integration, research, spec, UNKNOWN).  `managent add`/`suggest`
#            refuse a row without one; the error names the legal values.
#   scope  — S1..S5 bins computed by the mechanical rule in the taxonomy doc
#            (docs/infra/task-taxonomy.md), from the row's OWN facts
#            (deliverables= ∪ holds= path prefixes + type + title words).
#            UNKNOWN is a named residue, never a forced bin.
#   capabilities — adopted from docs/infra/races/capability-metrics.md (T900);
#            never backfilled onto unraced rows (this gate does not touch caps).
#   backfill — `managent backfill-taxonomy` joins the committed corpus's
#            type.brief onto store rows that carry none (bundle-declared
#            type= wins over corpus; UNKNOWN propagates; never guessed) and
#            recomputes scope_class for every row.
#
# Controls (scratch repo + scratch MANAGENT_STORE only — the live kanban is
# never written):
#   seeded    bundle with no type=            -> add refused, naming the legal
#             values; no row registered.
#   seeded2   bundle with type=bogus          -> add refused, naming the legal
#             values.
#   seeded3   suggest without --type          -> refused, naming --type.
#   null      add with a legal type registers and show prints type + scope.
#   scope     the binning matrix: findings-only S4 / lone docs S1 / two src
#             S3 / docs+findings S4 / orchestration+seat S5 / empty facts
#             UNKNOWN.
#   flag      --type <legal> registers a bundle with no type= key.
#   backfill  fixture corpus JSONL joins type onto store rows (real types
#             only, UNKNOWN propagates, absent rows stay UNKNOWN) and scope
#             is binned; counts are exact.
#   null-ctrl the discriminator: two rows with materially different facts
#             land in different bins, and re-running the backfill reproduces
#             the type/scope of every row exactly (idempotence).
#
# Task: T786 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-24

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
MG="$PROJECT/bin/managent"
FAIL=0

# T849: the scratch repo is created by the ONE helper that isolates the git
# env (unset GIT_DIR GIT_WORK_TREE …) before `git init`.
. "$PROJECT/tools/lib/scratch-repo.sh"

if [ ! -x "$MG" ]; then
    echo "SKIP: no managent binary (build with 'zig build') — T786 needs it"
    exit 0
fi

weizigo_scratch_repo managent-taxonomy WORK   # T849: isolated scratch repo
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git config user.email t786@test
mkdir -p "$WORK/untracked"
export MANAGENT_TEST=1
STORE="$WORK/tasks.json"
export MANAGENT_STORE="$STORE"

# make_bundle <id> <meta-extra> <title-words> — fixture brief with a valid
# **Landmark:** line (the T682 registration gate demands one).
make_bundle() {
    printf '<!--managent set=A %s-->\n# %s — %s\n**Landmark:** advances `L1 (the dashboard tells the truth)` — fixture\n' \
        "$2" "$1" "$3" > "$WORK/untracked/$1-bundle.md"
}

row_type() {   # $1=id — the type: line of `managent show`
    "$MG" show "$1" 2>/dev/null | sed -n 's/^    type: //p'
}
row_scope() {  # $1=id — the scope_class: line of `managent show`
    "$MG" show "$1" 2>/dev/null | sed -n 's/^    scope_class: //p'
}

echo "=== managent taxonomy gate (T786) ==="

# ── seeded: no type= -> add refused, legal values named, no row ──────────
make_bundle T7860 "deliverables=docs/a.md" "no-type fixture"
OUT=$("$MG" add T7860 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "type" \
   && echo "$OUT" | grep -q "audit" \
   && echo "$OUT" | grep -q "UNKNOWN"; then
    echo "    PASS: add without type= refused, legal values named (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected refusal naming legal types; got: $OUT"; FAIL=1
fi
if [ ! -s "$STORE" ] || ! grep -q '"T7860"' "$STORE" 2>/dev/null; then
    echo "    PASS: no row registered for the refused bundle"
else
    echo "    FAIL: T7860 was registered despite the refusal"; FAIL=1
fi

# ── seeded2: type=bogus -> refused, legal values named ───────────────────
make_bundle T7861 "deliverables=docs/b.md type=bogus" "bogus-type fixture"
OUT=$("$MG" add T7861 2>&1); RC=$?
if [ "$RC" -ne 0 ] \
   && echo "$OUT" | grep -q "bogus" \
   && echo "$OUT" | grep -q "implement"; then
    echo "    PASS: add with type=bogus refused, naming the value and legal set (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected refusal naming bogus + legal types; got: $OUT"; FAIL=1
fi

# ── null: legal type registers; show carries type + scope_class ─────────
make_bundle T7862 "deliverables=src/foo.zig type=implement" "leaf fixture"
"$MG" add T7862 >/dev/null 2>&1 || { echo "    FAIL: legal add refused"; FAIL=1; }
T=$(row_type T7862); S=$(row_scope T7862)
if [ "$T" = "implement" ] && [ "$S" = "S2" ]; then
    echo "    PASS: type=implement stored; scope_class=S2 for one src deliverable"
else
    echo "    FAIL: type='$T' scope='$S' (expected implement / S2)"; FAIL=1
fi

# ── scope matrix: the binning rule on materially different facts ─────────
# findings-only -> S4
make_bundle T7863 "deliverables=findings/T7863.json type=audit" "findings-only"
"$MG" add T7863 >/dev/null 2>&1
[ "$(row_scope T7863)" = "S4" ] && echo "    PASS: findings-only -> S4" || { echo "    FAIL: findings-only not S4"; FAIL=1; }
# lone docs deliverable -> S1
make_bundle T7864 "deliverables=docs/c.md type=spec" "lone-doc"
"$MG" add T7864 >/dev/null 2>&1
[ "$(row_scope T7864)" = "S1" ] && echo "    PASS: lone docs deliverable -> S1" || { echo "    FAIL: lone docs not S1"; FAIL=1; }
# two src deliverables -> S3
make_bundle T7865 "deliverables=src/a.zig,src/b.zig type=implement" "two-src"
"$MG" add T7865 >/dev/null 2>&1
[ "$(row_scope T7865)" = "S3" ] && echo "    PASS: two src deliverables -> S3" || { echo "    FAIL: two src not S3"; FAIL=1; }
# docs + findings -> S4
make_bundle T7866 "deliverables=docs/d.md,findings/T7866.json type=research" "docs-and-findings"
"$MG" add T7866 >/dev/null 2>&1
[ "$(row_scope T7866)" = "S4" ] && echo "    PASS: docs+findings -> S4" || { echo "    FAIL: docs+findings not S4"; FAIL=1; }
# orchestration type + seat word in title -> S5 (even with a lone doc)
make_bundle T7867 "deliverables=docs/e.md type=orchestration" "seat triage fixture"
"$MG" add T7867 >/dev/null 2>&1
[ "$(row_scope T7867)" = "S5" ] && echo "    PASS: orchestration + seat title -> S5" || { echo "    FAIL: orchestration+seat not S5"; FAIL=1; }
# empty file facts -> UNKNOWN residue (named, not forced)
make_bundle T7868 "deliverables= holds= type=infra" "no-facts"
"$MG" add T7868 >/dev/null 2>&1
[ "$(row_scope T7868)" = "UNKNOWN" ] && echo "    PASS: no file facts -> scope UNKNOWN (residue)" || { echo "    FAIL: empty facts not UNKNOWN"; FAIL=1; }

# ── flag: --type overrides the bundle's type= key (mirrors --set) ─────
make_bundle T7869 "deliverables=docs/f.md type=spec" "flag-typed"
"$MG" add T7869 --type infra >/dev/null 2>&1 || { echo "    FAIL: add --type infra refused"; FAIL=1; }
[ "$(row_type T7869)" = "infra" ] && echo "    PASS: --type flag overrides the bundle type (infra)" || { echo "    FAIL: --type not stored"; FAIL=1; }

# ── flag2: --type rescues a legacy bundle with no type= key at all ──────
make_bundle T786A "deliverables=docs/fa.md" "flag-rescue"
"$MG" add T786A --type research >/dev/null 2>&1 || { echo "    FAIL: add --type research (missing key) refused"; FAIL=1; }
[ "$(row_type T786A)" = "research" ] && echo "    PASS: --type rescues a bundle with no type= key" || { echo "    FAIL: rescue type not stored"; FAIL=1; }

# ── suggest: requires --type; with it, bundle + store both carry it ──────
OUT=$("$MG" suggest t786sug --set A 2>&1); RC=$?
if [ "$RC" -ne 0 ] && echo "$OUT" | grep -q -- "--type"; then
    echo "    PASS: suggest without --type refused, naming the flag (rc=$RC)"
else
    echo "    FAIL: rc=$RC; expected suggest to demand --type; got: $OUT"; FAIL=1
fi
OUT=$("$MG" suggest t786sug2 --set A --type audit 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    DISPATCH_LINE=$(echo "$OUT" | tail -1)
    BUNDLE="${DISPATCH_LINE#Follow }"
    SUG_ID="$(basename "$BUNDLE" | sed 's/-.*//')"
    if grep -q 'type=audit' "$WORK/$BUNDLE" && [ "$(row_type "$SUG_ID")" = "audit" ]; then
        echo "    PASS: suggest --type audit writes the header and stores the type"
    else
        echo "    FAIL: suggest --type did not carry the type (id=$SUG_ID)"; FAIL=1
    fi
else
    echo "    FAIL: suggest --type audit rc=$RC"; FAIL=1
fi

# ── backfill: corpus join (real types only, UNKNOWN propagates) + scope ─
# Precedence: stored type wins (skipped); bundle real type wins; corpus real
# type fills; bundle-UNKNOWN falls through to corpus; else UNKNOWN (named).
# Fixture corpus: T7901 audit, T7902 UNKNOWN; T7903/T7904 absent.
make_bundle T7901 "deliverables=findings/T7901.json type=UNKNOWN" "backfill-audit"
"$MG" add T7901 >/dev/null 2>&1      # bundle says UNKNOWN, corpus says audit
make_bundle T7902 "deliverables=docs/g.md type=UNKNOWN" "backfill-unknown"
"$MG" add T7902 >/dev/null 2>&1
make_bundle T7903 "deliverables=docs/h.md type=implement" "backfill-absent"
"$MG" add T7903 >/dev/null 2>&1
make_bundle T7904 "deliverables=docs/i.md type=infra" "backfill-legacy"
"$MG" add T7904 >/dev/null 2>&1
# Simulate LEGACY bundles for T7902/T7903: remove the type= key from the
# brief (pre-T786 bundles never had one) so the backfill sees no bundle type.
sed -i '' 's/ type=UNKNOWN//' "$WORK/untracked/T7902-bundle.md"
sed -i '' 's/ type=implement//' "$WORK/untracked/T7903-bundle.md"
# Fresh store rows WITHOUT stored type (drop the type fields by hand) so the
# backfill sees the legacy shape: T7901..T7904 all carry no stored type now.
python3 - "$STORE" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
for tid in ("T7901", "T7902", "T7903", "T7904"):
    doc[tid].pop("task_type", None)
json.dump(doc, open(sys.argv[1], "w"), indent=1)
PY

FIXCORPUS="$WORK/corpus.jsonl"
cat > "$FIXCORPUS" <<'EOF'
{"id": "T7901", "type": {"brief": "audit"}}
{"id": "T7902", "type": {"brief": "UNKNOWN"}}
EOF

OUT=$("$MG" backfill-taxonomy --corpus "$FIXCORPUS" 2>&1); RC=$?
if [ "$RC" -eq 0 ]; then
    [ "$(row_type T7901)" = "audit" ] && echo "    PASS: bundle-UNKNOWN falls through to corpus; T7901 typed audit" \
        || { echo "    FAIL: T7901 type=$(row_type T7901) (expected audit)"; FAIL=1; }
    [ "$(row_type T7904)" = "infra" ] && echo "    PASS: bundle real type beats corpus absence; T7904 typed infra" \
        || { echo "    FAIL: T7904 type=$(row_type T7904) (expected infra)"; FAIL=1; }
    [ "$(row_type T7902)" = "UNKNOWN" ] && [ "$(row_type T7903)" = "UNKNOWN" ] \
        && echo "    PASS: corpus-UNKNOWN (T7902) and absent (T7903) both left UNKNOWN" \
        || { echo "    FAIL: T7902=$(row_type T7902) T7903=$(row_type T7903) (expected UNKNOWN)"; FAIL=1; }
    echo "$OUT" | grep -q "corpus-typed 1" && echo "    PASS: corpus-typed count = 1" || { echo "    FAIL: corpus-typed count; $OUT"; FAIL=1; }
    echo "$OUT" | grep -q "bundle-typed 1" && echo "    PASS: bundle-typed count = 1" || { echo "    FAIL: bundle-typed count; $OUT"; FAIL=1; }
    echo "$OUT" | grep -q "left-UNKNOWN 2 (1 corpus-UNKNOWN, 0 bundle-UNKNOWN, 1 absent" && echo "    PASS: left-UNKNOWN split exact (1 corpus-UNKNOWN, 1 absent)" \
        || { echo "    FAIL: left-UNKNOWN split; $OUT"; FAIL=1; }
    [ "$(row_scope T7901)" = "S4" ] && echo "    PASS: backfill recomputed scope S4 for T7901" \
        || { echo "    FAIL: backfill scope for T7901 = $(row_scope T7901)"; FAIL=1; }
    [ "$(row_scope T7903)" = "S1" ] && echo "    PASS: backfill recomputed scope S1 for T7903" \
        || { echo "    FAIL: backfill scope for T7903 = $(row_scope T7903)"; FAIL=1; }
else
    echo "    FAIL: backfill-taxonomy rc=$RC: $OUT"; FAIL=1
fi

# ── null control: re-running reproduces every row's type/scope exactly ──
snapshot() {
    python3 - "$STORE" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
for tid in sorted(doc):
    if tid.startswith("T"):
        print(tid, doc[tid].get("type"), doc[tid].get("scope_class"))
PY
}
A=$(snapshot)
"$MG" backfill-taxonomy --corpus "$FIXCORPUS" >/dev/null 2>&1
B=$(snapshot)
if [ "$A" = "$B" ]; then
    echo "    PASS: re-running the rule reproduces every bin exactly (idempotent)"
else
    echo "    FAIL: bins differ across runs:"
    echo "$A" > "$WORK/snap-a.txt"
    echo "$B" > "$WORK/snap-b.txt"
    diff "$WORK/snap-a.txt" "$WORK/snap-b.txt" | head
    FAIL=1
fi

if [ "$FAIL" -eq 0 ]; then
    echo "=== task-taxonomy regression: PASS ==="
else
    echo "=== task-taxonomy regression: FAIL ($FAIL) ==="
    exit 1
fi
