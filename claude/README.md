# Claude Code

Ready-to-use Claude Code environment with
managed configuration.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/claude"]
```

## What it provides

- `claude` -- the Claude Code CLI
- `claude-managed` -- config fragment assembly

On `flox activate`, `claude-managed setup` runs
automatically and:

- Scans `$FLOX_ENV/share/claude/` for config
  fragments from other packages
- Assembles settings, MCP servers, and instructions
- Creates a `claude()` shell function with the
  assembled config

## Isolated mode

For full isolation from `~/.claude/`:

```toml
[vars]
CLAUDE_MANAGED_ISOLATED = "1"
```

Requires `ANTHROPIC_API_KEY` in the environment.

## Commands

- `claude-managed setup` -- assemble and print shell
  code
- `claude-managed status` -- show assembled state
- `claude-managed doctor` -- validate fragments

## See also

- [claude-demo](../claude-demo/) -- interactive demo
