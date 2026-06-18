# The audit engine

`internal/audit` scores a skill or agent on a 0-100 scale by
orchestrating external quality tools and fusing four dimensions. It runs
in-process ([ADR 0003](
../decisions/0003-absorb-audit-engine-in-process.md)) and backs both
`flox-ai audit` and the TUI's review report.

## The four dimensions

`audit.Run` produces a `Result` with an overall score, a status pill,
and four dimensions:

- **quality** — a weighted ensemble of per-tool checks (the bulk of the
  signal).
- **reliability** — a gate pass/fail, floored by the claudelint score.
- **security** — the highest severity across the security scanners,
  applied as a cap on the overall score.
- **impact** — estimated by default (70), or measured when the
  behavioral stage is enabled.

`score.Fuse` combines them and `score.ApplyCap` enforces the security
cap; `score.Pill` maps the result to a status word (e.g. `good`,
`warn`, `risk`).

## The tool ensemble

`internal/audit/tools` defines the registry. Each `Tool` knows its
binary, the kinds it applies to, its per-kind weight, whether it needs a
staged `.claude` project, how to build its argv, how to score its
output, and how to collect findings. The default quality ensemble per
kind:

- **skill** → `skill-tools` (w40), `skill-validator` (w30),
  `claudelint` (w30)
- **agent** → `claudelint`, `agnix`, `cclint`

Security scanning uses `skillcheck` (and `skillspector`). The six tools
are separate binaries; they must be on PATH for real scores.

## Findings and raw output

With `Findings: true`, a run also returns `[]findings.Finding`
(`tool, severity, rule, message, file, line`). With `IncludeRaw: true`,
the `Result` carries `RawByTool` — each tool's raw stdout — captured
from the engine's existing per-tool output cache, so no tool runs twice.
These feed the findings and raw panes of the review report
([ADR 0006](../decisions/0006-four-pane-review-report.md)).

## Availability and the dry-run mode

`internal/doctor` (`Probe`/`Resolve`) reports which tools are present,
their versions, and a smoke test, and resolves the default ensemble per
kind. The TUI checks this before a review and prompts to install any
missing `flox/<tool>` packages.

Setting `REVIEW_SKILLS_DRY_RUN=1` makes the engine emit fixed stub
scores without executing any tool — used by the e2e tests so they are
hermetic.

## Public entry points

- `audit.Run(RunOptions) (Result, error)` — one run for one artifact.
- `doctor.Probe() []Row` / `doctor.Resolve(kind, avail) ResolveResult`
  — tool availability and the resolved ensemble.

The CLI shape and flags are in [ADR 0005](
../decisions/0005-single-audit-command.md).
