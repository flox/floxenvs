# 0003. Absorb the review-skills audit engine in-process

Date: 2026-06-18

Status: Accepted

## Context

Skill and agent quality scoring lived in a separate Go binary,
`review-skills` (`.flox/pkgs/review-skills`, ~2600 LOC: `detect`,
`tools`, `doctor`, `score`, `audit`, `findings`, `report`). The TUI
shelled out to it: it ran the binary once per fragment, parsed its
CLI/JSON text, and kept a separate doctor flow in sync with a tool it
could not see inside.

We wanted a tight loop between the audit engine and the TUI's report —
a four-pane drill-down from skills to per-tool findings to raw output
(see [0006](0006-four-pane-review-report.md)). That is only practical
if the TUI calls the engine directly and the engine can return scores,
findings, and raw output from a single execution.

The engine was already well factored and dependency-clean: its only
external dependency was `gopkg.in/yaml.v3`, which flox-ai already
vendored. The six quality tools it orchestrates (`skill-tools`,
`skill-validator`, `claudelint`, `agnix`, `cclint`, `skillcheck`,
`skillspector`) remain separate binaries either way.

## Decision

We will move `review-skills/internal/{detect,score,findings,tools,
report,audit}` into `flox-ai/internal/audit/*` and call them in-process.
`audit.Run` gains an `IncludeRaw` option so one execution yields scores,
findings, and per-tool raw output (reusing the engine's existing
per-tool output cache — no extra tool runs). The standalone
`review-skills` package, its two demo environments, and its flake wiring
are deleted.

## Consequences

- `+` The TUI calls `audit.Run` directly; no subprocess, no text
  parsing, no version skew between the TUI and the engine.
- `+` One tool execution feeds every pane of the report.
- `+` One codebase, one binary, one test suite to maintain.
- `-` flox-ai now owns the engine's code and tests.
- `-` The six external quality tools are still required at runtime for
  real scores; their availability is surfaced by doctor
  ([0004](0004-unify-doctor.md)) and an install prompt in the TUI.
- The `flox/review-skills` catalog package is retired; environments that
  installed it (e.g. the brain env) must drop it and re-lock.
