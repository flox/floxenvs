# 0005. Expose a single `audit` command with `--report`

Date: 2026-06-18

Status: Accepted

## Context

The `review-skills` binary had five subcommands: `audit` (full 0-100
metrics), `review` (quality score only), `lint` (a deterministic exit
0/1 gate), `report` (raw per-tool output), and `doctor` (tool
availability). Absorbing the engine ([0003](
0003-absorb-audit-engine-in-process.md)) was a chance to simplify the
surface flox-ai exposes rather than copy five commands verbatim.

`doctor` already had a home in `flox-ai doctor` ([0004](
0004-unify-doctor.md)). `review` was just `audit` without the other
dimensions. `report`'s raw output is the same data `audit` now carries
via `IncludeRaw`. `lint`'s gate is one comparison on the overall score.

## Decision

We will expose a single command:

```text
flox-ai audit <path> [--json] [--findings] [--report]
                     [--threshold N] [--kind skill|agent]
                     [--tools <list>] [--disable <list>]
```

`--findings` appends the findings list; `--report` appends raw per-tool
output (and implies findings + raw capture); `--json` emits the machine
document; `--threshold N` exits non-zero when the overall score is below
N (the CI gate). The `review`, `lint`, and standalone `report`
subcommands are dropped; `doctor` folds into `flox-ai doctor`.

Flags may appear on either side of the path: Go's `flag` package stops
at the first positional, so the parser loops — parse, peel one
positional, re-parse — to accept `audit <path> --json` as well as
`audit --json <path>`.

## Consequences

- `+` One command to learn; flags compose instead of multiplying
  subcommands.
- `+` `--threshold` preserves the CI gate without a separate `lint`.
- `-` Anyone scripting the old `review-skills review/lint/report`
  subcommands must migrate to `flox-ai audit` with flags.
