# Refusal fixtures — the four shapes the per-family detectors must get right (T630)

Each `.fixture` file is a faithful extract of a REAL dispatch log (the load-bearing
structure preserved verbatim; brief text and worker middle sections elided with a
marker line).  The regression (`tools/regression-dispatch-verification.sh`) extracts
these from HEAD into its scratch repo and seeds each as a worker log, so every run
of the suite exercises all four fixtures in both directions.

| fixture | real source (gitignored) | shape it pins | detector answer |
|---|---|---|---|
| `refusal-claude-session-limit.fixture` | `untracked/log/t615.log` (run 1, 2026-08-22 ~12:47Z) | the Claude client message `You've hit your session limit` immediately followed by the RUNNER'S OWN envelope diagnostic `[runner] tokens: no reading — claude api error (is_error=true, zero usage)` | `provider-limit` |
| `refusal-ollama-session-limit.fixture` | `untracked/log/t496.log` (2026-08-20 ~11:00Z, the session-usage-limit fleet incident) | the ollama CLI's structured api_error block: a line starting with the HTTP status `429: {"message":...,"type":"api_error",...}` immediately followed by `Error: exit status 1`, preceded only by pi's own startup messages, with NO worker content anywhere | `provider-limit` |
| `refusal-quoted-429-watchdog.fixture` | `untracked/log/t526.log` (2026-08-22) | a worker QUOTING the 2026-08-20 refusal out of a two-day-old document (mid-log, followed by worker content), dying of the runner's own progress-timeout watchdog | `watchdog`, never a refusal |
| `refusal-quota-prose.fixture` | `untracked/log/t601.log` (2026-08-22) | the bare word `quota` inside the prose `provider quota/appetite 7` of a document the worker read; mid-stream death (rc=-15); no refusal emission anywhere | not a refusal at all |

## Fixture #4 provenance — the Ollama refusal (brief step 0)

The brief asked for a deliberate probe lane against a blocked Ollama model to capture
the real refusal verbatim.  The probe was run 2026-08-22 ~21:2xZ with the exact
dispatch shape `tools/runner --max-wall 90 -- ollama launch pi --model <tag> -y -- -p
"Reply with exactly: PROBE-OK"` against all three cloud tags — `glm-5.2:cloud`,
`minimax-m3:cloud`, `kimi-k2.7-code:cloud`.  **All three returned `PROBE-OK`**: the
account is no longer at its session limit, so no fresh refusal could be captured.

The real first-hand refusal therefore comes from the incident day, captured verbatim:

- 2026-08-20 ~11:00Z: the fleet refusals, `429: {"message":"you
  (infallible_moser_218) have reached your session usage limit, ...","type":
  "api_error","param":null,"code":null}` + `Error: exit status 1` — verbatim in
  `untracked/log/t496.log` (and t511/t512/t517/t518/t519).  This is the shape
  `refusal-ollama-session-limit.fixture` pins.
- 2026-08-20 ~13:05Z: the T529 go/no-go re-probe, `$ ollama run glm-5.2:cloud
  "Reply with the single word: ok"` → `Error: 429 Too Many Requests: you
  (infallible_moser_218) have reached your session usage limit, upgrade for higher
  limits` — verbatim and committed in
  `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/grand-race-p0.md`.

Both are first-hand (captured from a live lane / live probe by the operator's own
row), not quotations.  The dispatch harness (`ollama launch pi`) emits the first
shape; the second is the `ollama run` CLI form, which no dispatched lane emits and
which the detectors deliberately do NOT match (it is worker-printable prose; the
structured `NNN: {…"type":"api_error"…}` block is the client's own emission shape).
