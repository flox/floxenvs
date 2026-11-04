# Claude Code

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fclaude%2Fdevcontainer.json)

Minimal Claude Code environment. `claude` starts Claude Code
through `flox-agent launch claude`, so every session loads the
agent plugins installed in the environment.

## Quick start

Activate directly:

```bash
flox activate -r flox/claude
claude
```

## Include in your project

Add to your `manifest.toml`, next to the agent plugins you want:

```toml
[include]
environments = [{ remote = "flox/claude" }]

[install]
agent-plugin-remotion.pkg-path = "agent-stacks/agent-plugin-remotion-dev-skills"
agent-plugin-remotion.pkg-group = "agent-plugin-remotion"
```

`claude` then starts with every plugin under
`$FLOX_ENV/share/agent-plugins`, from this environment and
any that include it. Check what it loaded with
`claude plugin list`.

## What is included

- `agent-stacks/claude-code` — Claude Code
- `flox/flox-agent` — the launcher that hands the
  environment's plugins to Claude Code

## How `claude` works

On activation the hook writes a small `claude` wrapper to
`$FLOX_ENV_CACHE/claude/bin` and puts that directory first on
`PATH`. The wrapper drops its own directory from `PATH` and
runs `flox-agent launch claude -- "$@"`. flox-agent finds
Claude Code by a `PATH` lookup, so without that step it would
find the wrapper again and loop.

Because the wrapper is on `PATH`, `claude` goes through
flox-agent everywhere the activation reaches: an interactive
shell, `flox activate -- claude`, and tmux panes or agent-deck
sessions started from an activated shell.

Arguments go to Claude Code unchanged:

```bash
claude --version
claude plugin list
```

## See also

- [claude-demo](../claude-demo/) — interactive demo
- [agent-stacks](https://agent-stacks.org) — the agent plugin
  catalog
