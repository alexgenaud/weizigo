# ollama family — topology: the model is daemon-owned, outside the dispatched tree

**Seat:** deepseek-v4-pro / T556 · **Status:** CLAIMED (observed twice, one seat lineage;
reproducible below) · **Dates:** 2026-08-20 (D14), 2026-08-21 (gem12) ·
**Predecessor corroboration:** sonnet/T555's D12 (qwen orphan).

## The load-bearing fact

`ollama launch pi --model X` spawns `pi` (the agent client) as its child, but the **model
runs in an `ollama runner` process parented to `ollama serve` (the long-running daemon),
not to the dispatch**. The heavy process is a *sibling* of the dispatched tree under the
daemon — not a descendant of the anchor. Consequence: `tools/runner`'s descendant walk
(which feeds both its RSS accounting and its kill path) cannot see or kill the model.

## Evidence

1. **ppid walk (2026-08-20, D14).** The orphaned qwen client (pid 72197, `pi`) held an
   ESTABLISHED TCP connection to `localhost:11434` (ollama serve), and the resident
   `ollama runner --mlx-engine --model qwen3.8:27b-mlx` had `ppid 67229` = `ollama serve`,
   *not* the killed dispatch. Killing the runner alone respawned it (new port) because the
   orphaned client kept the session alive — the runner had to be swept by hand.
2. **Peak-RSS blindness (2026-08-21, gem12).** `gemma4:12b-mlx` trailer:
   `[runner] peak RSS by PID: pid 61359 272 MB` while the 7.7 GB model runner (pid 61375,
   `ppid 67229`) was resident. The walker's largest tracked member was the 272 MB pi
   client, not the model. The host-floor guard then killed 258 MB to relieve ~6 GB of
   pressure, failed (pressure unchanged), and crashed at `tools/runner:1554`
   `os.killpg` (EPERM) — the 4th reproduction of the C1 call site.
3. **Resulting crash is the pass-1 target.** `PermissionError: [Errno 1]` at
   `os.killpg(proc.pid, signal.SIGKILL)` in every shell-dispatched ollama lane that hit
   memory pressure (qwen ×3, gemma4:12b ×1). The guard fires on global pressure it cannot
   relieve (the model is out of reach), kills the wrong process, then crashes.

## Answers to the §3 questions

- **(a) tool-command root is a session leader?** Expected **yes** — it is the same `pi`
  binary measured for DeepSeek (which setsids its tool commands); not separately measured
  on the ollama path.
- **(b) runner's child is a session leader at spawn?** **Yes** (`tools/runner:1210`
  setsids the `ollama launch pi` client).
- **(c) session changes in the chain?** `runner → (setsid) → ollama launch pi client`;
  `pi` setsids its tool shells (expected, per DeepSeek measurement).
- **(d) tree depth / heaviest child?** The dispatched tree (`runner → ollama launch pi →
  pi → tool shell`) is shallow and light (~250–300 MB). **The heaviest process — the model
  (7.7–18 GB file, up to ~2× loaded) — is NOT in the tree; it is under `ollama serve`.**

## Design consequence for the pass

This is the one family where the verb as specified **cannot do its job by descendant
enumeration alone**: the resource that must be released (the model residency) is
daemon-owned. Two implications for the design-phase (§10 Q7 territory):

1. **The runner's host-floor guard is structurally blind for ollama** — it cannot account
   for or kill the model. This is why every shell-dispatched local model either tripped the
   floor or crashed, while hand consoles (no `tools/runner`) worked. The pass-1 fix for the
   compile family (descendant enumeration) does **not** close this; the ollama family needs
   either a call to `ollama stop <model>` (or equivalent) at the call sites, or the runner
   must learn the daemon-owned runner's pid out-of-band (e.g. from `ollama ps`).
2. **It is a per-family branch, not a verb change.** §7.3's "family variation lives in
   data, not code" holds for *enumerability*; but *release of a daemon-owned resource* is a
   capability the verb cannot express as a pid set — the call sites (C1–C4) must stop the
   model via ollama's own interface in addition to `own --anchor`. Recorded as a design
   finding, not a spec rewrite (phase-4 output → phase-5 scope).

Reproduce (while any ollama model is loaded):
```sh
ps -eo pid,ppid,pgid,rss,command | grep -E 'ollama runner --mlx|ollama launch pi|ollama serve'
# observe: the `ollama runner` ppid is `ollama serve`'s pid, not the `ollama launch pi` pid
```
