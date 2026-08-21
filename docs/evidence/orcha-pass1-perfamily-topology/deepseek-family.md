# DeepSeek CLI family — session topology (measured 2026-08-21)

**Seat:** deepseek-v4-pro / T556 · **Status:** CLAIMED (single-seat, mechanical;
reproducible below) · **Method:** dispatch a real DeepSeek worker that invokes a tool,
snapshot `ps` + `getsid(2)` while the tool is mid-run.

## Probe

```
tools/runner --max-wall 600 -- pi --provider deepseek --model deepseek-v4-flash \
  --no-session -p "Use your bash/shell tool to run: sleep 75 && echo probe-done …"
```

Worker exit 0 in 77.9 s, output `probe-done` — the tool ran for real.

## Measurement (mid-run snapshot)

| pid | role | ppid | sid | pgid | session leader? |
|---|---|---|---|---|---|
| 24770 | `tools/runner` (python) | (shell) | 24767 | 24767 | no — inherits caller's session |
| 24775 | `pi` (the worker) | 24770 | 24775 | 24775 | **yes** — runner's `setsid` at spawn (`tools/runner:1210`) |
| 24800 | `/bin/bash` (the tool shell) | 24775 | 24800 | 24800 | **yes** — `pi` setsids its tool command |
| 24801 | `sleep` | 24800 | 24800 | 24800 | no — in the tool shell's session/group |

## Answers to the §3 questions

- **(a) tool-command root is a session leader?** **Yes** — `bash` has `sid == pgid == pid` (24800).
- **(b) runner's child is a session leader at spawn?** **Yes** — `pi` has `sid == pgid == pid` (24775).
- **(c) session changes in the chain?** Two `setsid` boundaries: runner → pi, pi → tool shell.
- **(d) tree depth to the tool child?** `runner → pi → bash → sleep` = 4 levels (deeper if the tool spawns children).

## Conclusion

The DeepSeek CLI family behaves **identically to the measured `claude -p` family**: every
tool command is a fresh session leader, so group- and session-level kills are structurally
insufficient and only descendant enumeration reaches escapees — exactly the mechanism the
verb is built for. **No design change for this family.** The sid catch-all (OWN-2) and the
`--seed` term contribute members exactly as specified.

Reproduce:
```sh
ps -axo pid=,ppid=,pgid=,uid=,comm= | grep -E 'pi$|/bin/bash|sleep'
# then, for each pid:
python3 -c 'import os,sys; print(os.getsid(int(sys.argv[1])), os.getpgid(int(sys.argv[1])))' <pid>
```
