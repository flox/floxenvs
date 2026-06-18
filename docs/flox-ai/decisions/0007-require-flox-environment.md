# 0007. Require a Flox environment to run the TUI

Date: 2026-06-18

Status: Accepted

## Context

The TUI installs and removes plugins, skills, agents, and rules by
editing the active environment's manifest, and it launches agents with
that environment's fragments injected. Run outside a Flox environment,
it has no manifest to act on and no fragments to inject, so it would
either fail obscurely or operate on the wrong directory.

Flox sets `FLOX_ENV` (the active environment path) when an environment
is activated.

## Decision

We will refuse to start `flox-ai tui` when `FLOX_ENV` is unset, exiting
with a clear message that points at `flox activate`, before any catalog
load or terminal setup. The check lives in the `tui` command branch of
`main.go`.

## Consequences

- `+` Users get an actionable error instead of a confusing failure or
  edits to an unintended directory.
- `+` The TUI's later logic can assume an active environment.
- `-` The TUI cannot be demoed outside a Flox environment; the `audit`
  and `doctor` subcommands remain usable without one.
