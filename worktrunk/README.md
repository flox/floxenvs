# Worktrunk

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fworktrunk%2Fdevcontainer.json)

Ready-to-use [Worktrunk](https://worktrunk.dev) environment.
Worktrunk is a CLI for git worktree management, designed for
running AI coding agents (Claude Code, Codex, Gemini CLI, ...)
in parallel.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/worktrunk"]
```

Or activate directly:

```bash
flox activate -r flox/worktrunk
wt switch -c feat
```

## What it provides

- `wt` — the worktrunk CLI
- `git-wt` — same CLI exposed as a `git wt` subcommand
- `git` — required runtime dependency

The `wt` binary is wrapped so `git` is always on its `PATH`,
regardless of what the consuming environment provides.

## Configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `WORKTRUNK_CACHE` | `$FLOX_ENV_CACHE/worktrunk` | Scratch dir for this env |

Worktrunk's own configuration lives in the host repo's
`.git/config` and in user-level files under
`$XDG_CONFIG_HOME/worktrunk`. See the
[upstream config docs](https://worktrunk.dev/config/) for
details.

To pair Worktrunk with a coding agent, include both
environments:

```toml
[include]
environments = [
  "flox/worktrunk",
  "flox/claude",
]
```

## See also

- [worktrunk-demo](../worktrunk-demo/) — interactive demo
  with a welcome banner
- [Upstream docs](https://worktrunk.dev)
- [Upstream repo](https://github.com/max-sixty/worktrunk)
