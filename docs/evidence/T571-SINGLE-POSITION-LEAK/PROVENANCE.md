# T571 — provenance: commands, hashes, and how to re-run

**Task:** T571 · **Worker:** claude-opus-5/T571 · **Date:** 2026-08-22
**Analysis:** `leak-resolution-2026-08-22.md` (this directory)

Every number in the analysis is reproducible from the commands below on a host
that still holds `data/oracle-4x4-v2.wzo2` (`data/` is git-ignored,
`.gitignore:4`, so the table is not in the repository).

## Host / toolchain

```
zig version                     # 0.16.0
git rev-parse --short HEAD       # 5815b45 (working tree carries this row's additions)
uname -sr                        # Darwin 25.5.0
```

All runs `-O ReleaseFast` under `tools/runner` (RSS / wall / CPU guards). The
2026-07-29 host panic was a Debug `zig` build; nothing here is built in Debug.

## Step 1 — reproduce T412's 7 games at HEAD

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t412_loop_onset.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t571/cache \
  --global-cache-dir /tmp/weizigo/t571/global --name weizigo-t412-loop \
  -femit-bin=/tmp/weizigo/t571/t412-loop

MANAGENT_TASK_ID=T571 tools/runner --rss-cap-mb 4096 --max-wall 3600 -- \
  /tmp/weizigo/t571/t412-loop --size 4 --sample 500 --seed 42 \
  --json /tmp/weizigo/t571/repro-4x4-opt.json
```

Observed: exit 0, wall 0.9 s, peak RSS 511 MB. Every aggregate field and all 232
capped-game `(colex, side)` witnesses are identical to
`docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json`, including the 7 rows
with `pos_sg > 0`.

Diff check used:

```
python3 - <<'EOF'
import json
old=json.load(open('docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json'))
new=json.load(open('/tmp/weizigo/t571/repro-4x4-opt.json'))
keys=[k for k in old if k!='capped_games']
print('aggregates identical:', all(old[k]==new.get(k) for k in keys))
sel=lambda d:sorted((x['colex'],x['side'],x['pos_sg'],x['first_single'],x['distinct'])
                    for x in d['capped_games'] if x['pos_sg']>0)
print('7 leaking games identical:', sel(old)==sel(new))
EOF
```

## Step 2 — the probe (pin the entries, re-derive them, and vary the tie-break)

```
zig build-exe -O ReleaseFast --dep version -Mroot=src/t571_leak_probe.zig \
  -Mversion=src/version.zig --cache-dir /tmp/weizigo/t571/cache \
  --global-cache-dir /tmp/weizigo/t571/global --name weizigo-t571-leak \
  -femit-bin=/tmp/weizigo/t571/t571-leak

for sd in 42 997; do
  MANAGENT_TASK_ID=T571 tools/runner --rss-cap-mb 4096 --max-wall 3600 -- \
    /tmp/weizigo/t571/t571-leak --wzo2 data/oracle-4x4-v2.wzo2 \
    --nullctl 5000 --sample 500 --seed $sd \
    --json docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed$sd.json
done
```

Observed both seeds: exit 0, wall 0.9 s, peak RSS 511 MB.

Headline readings (seed 42 / seed 997):

| reading | seed 42 | seed 997 | denominator |
|---|---|---|---|
| `L == H` arrivals over the 7 pinned games | 1,203 | 1,203 | 2,800 plies (7 × 400) |
| distinct `L == H` states | 45 | 45 | — |
| Bellman residual violations | 0 | 0 | 45 |
| S1 seeded defect detected / shift exactly +1 | 45 / 45 | 45 / 45 | 45 |
| N1 null-control violations | 0 | 0 | 5,000 |
| capped games visiting `L == H`, first-index tie-break | 7 | 3 | 232 / 250 capped |
| capped games visiting `L == H`, min-DTT tie-break | 0 | 0 | 87 / 84 capped |
| capped games visiting `L == H`, random tie-break (ctl) | 0 | 1 | 89 / 86 capped |

The 7 pinned games are the same in both runs (`STARTS` is fixed in the
instrument); only the T3 population arm depends on `--seed`.

## Step 3 — the guard is not in the WZO2 build path

```
grep -n 'ctx.memo_writes and ko_ref >= d' src/oracle.zig src/retro.zig
grep -c 'ko_ref\|memo_writes'  src/exp6_solve.zig src/oracle_v2_build.zig   # 0 and 0
grep -n '@import' src/oracle_v2_build.zig src/exp6_solve.zig
grep -n 'openFile\|readFile\|cwd()' src/exp6_solve.zig                      # write path only
```

Observed: the guard is at `src/oracle.zig:253` and `src/retro.zig:593`;
`src/exp6_solve.zig` and `src/oracle_v2_build.zig` contain neither token; the
WZO2 producer's import closure is `oracle_v2_build → {exp6_solve, artifact2,
colex}` and `exp6_solve → {artifact, rules, qa023_brute_2x2}` — no `oracle.zig`,
no `retro.zig`.

## Step 4 — artifact hashes

```
for f in untracked/oracle-4x4-writesoff-bracket.wzo \
         untracked/oracle-4x4-writesoff-checkpoint.wzo \
         data/oracle-4x4.checkpoint.wzo \
         data/oracle-4x4-parallel.checkpoint.wzo \
         data/oracle-4x4-basicko-tie-area.wzo \
         data/oracle-4x4-v2.wzo2 ; do shasum -a 256 "$f" ; done
```

| sha256 | bytes | `rules_id` | file |
|---|---|---|---|
| `73b9c27e97eb27e2f197eaaf3ec46f8a50f06caa6025c4ab399b8c5898f92232` | 258,280,358 | 1 | `untracked/oracle-4x4-writesoff-bracket.wzo` |
| `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a` | 258,280,358 | 1 | `untracked/oracle-4x4-writesoff-checkpoint.wzo` |
| `28afa11bf095554ed313a400a3a5eb871cc49c4bfdefe07e1f2e8f3037f3fc4a` | 258,280,358 | 1 | `data/oracle-4x4-parallel.checkpoint.wzo` |
| `a2174fedd6a0591dc66b0b42ef1f52bdc28b97c448dbc5b043d96de3a3b1e118` | 258,280,358 | 1 | `data/oracle-4x4.checkpoint.wzo` |
| `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc` | 258,280,358 | 2 | `data/oracle-4x4-basicko-tie-area.wzo` |
| `0c3366f07fb33c6f2838ead48ad3080b64dbe55935b87af4f140d81a29e4e15a` | 518,123,097 | — (WZO2) | `data/oracle-4x4-v2.wzo2` |

The first two match `docs/evidence/README.md:165-166` exactly. Rows 2 and 3 are
the byte-identity finding (F1 in the analysis).

WZO1 headers read with:

```
python3 -c "
import struct
for f in ['untracked/oracle-4x4-writesoff-bracket.wzo',
          'untracked/oracle-4x4-writesoff-checkpoint.wzo',
          'data/oracle-4x4.checkpoint.wzo',
          'data/oracle-4x4-parallel.checkpoint.wzo',
          'data/oracle-4x4-basicko-tie-area.wzo']:
    h=open(f,'rb').read(32)
    print(f, 'rules_id', h[9], 'layout', h[5], 'crc', hex(struct.unpack('<I',h[28:32])[0]))
"
```

## Step 5 — the 26 fresh-start leak states across the WZO1 artifacts

Direct byte reads, no tool and no engine. WZO1 layout is a 32-byte header then
`vb | vw | fb | fw | db | dw`, each `3^16 = 43,046,721` bytes, colex-addressed:

```
python3 - <<'EOF'
import json
TOT=3**16
d=json.load(open('docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json'))
fresh=[s for s in d['leak_states'] if s['ko']==16 and s['passes']==0]   # 26 of 45
def rd(f,colex,side):
    off=32+(0 if side>0 else TOT)+colex
    fh=open(f,'rb'); fh.seek(off); b=fh.read(1)[0]
    return b-256 if b>127 else b
for f in ['data/oracle-4x4.checkpoint.wzo','data/oracle-4x4-parallel.checkpoint.wzo',
          'untracked/oracle-4x4-writesoff-checkpoint.wzo',
          'untracked/oracle-4x4-writesoff-bracket.wzo',
          'data/oracle-4x4-basicko-tie-area.wzo']:
    vals=[rd(f,s['colex'],s['side']) for s in fresh]
    agree=sum(1 for s,v in zip(fresh,vals) if v==s['L'])
    undef=sum(1 for v in vals if v==-128)
    print(f'{agree:2}/26 agree  {undef:2}/26 UNDEF  {f}')
EOF
```

Observed: 26/26, 26/26, 26/26, 1/26 (25 UNDEF), 0/26 (10 UNDEF) in that order.

`data/oracle-4x4-basicko-tie-area.wzo` value-column histogram (stride 401,
n = 107,349): 46,833 UNDEF + 18,335 at −16 + 35,955 at +16 = 94.2 % of samples.

## Deliverables written by this row

| path | kind |
|---|---|
| `docs/evidence/T571-SINGLE-POSITION-LEAK/leak-resolution-2026-08-22.md` | analysis |
| `docs/evidence/T571-SINGLE-POSITION-LEAK/PROVENANCE.md` | this file |
| `docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json` | probe evidence |
| `docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed997.json` | probe evidence |
| `src/t571_leak_probe.zig` | new instrument (additive; reads only) |
| `findings/T571-single-position-leak.json` | findings (schema) |
| `findings/T571-context.json` | context dump |
