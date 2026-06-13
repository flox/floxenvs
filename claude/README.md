# Claude Code

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fclaude%2Fdevcontainer.json)

Ready-to-use Claude Code environment with
managed configuration.

## Quick start

Include in your manifest:

```toml
[include]
environments = [{ remote = "flox/claude" }]
```

## What it provides

- `claude` -- the Claude Code CLI
- `flox-ai` -- config fragment assembly

On `flox activate`, `flox-ai setup` runs
automatically and:

- Scans `$FLOX_ENV/share/claude-code/` for config
  fragments from other packages
- Assembles settings, MCP servers, and instructions
- Creates a `claude()` shell function with the
  assembled config

## Isolated mode

For full isolation from `~/.claude/`:

```toml
[vars]
FLOX_AI_ISOLATED = "1"
```

Requires `ANTHROPIC_API_KEY` in the environment.

## Commands

- `flox-ai setup` -- assemble and print shell
  code
- `flox-ai doctor` -- show assembled state and
  validate fragments

## See also

- [claude-demo](../claude-demo/) -- interactive demo
