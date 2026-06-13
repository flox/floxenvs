# playwright

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fplaywright%2Fdevcontainer.json)

Minimal Playwright environment. Provides the
Playwright library and test runner, browser drivers,
[Microsoft's `playwright-cli`](https://github.com/microsoft/playwright-cli),
the [Playwright MCP server](https://github.com/microsoft/playwright-mcp),
and a Claude Code / OpenCode skill bundle for driving
`playwright-cli` from an agent.

## Quick start

Activate directly:

```bash
flox activate -r flox/playwright
playwright install chromium   # one-time browser fetch
playwright test               # run tests in $PWD
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/playwright" }]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `playwright` | JS framework + `playwright` CLI |
| `playwright-test` | `@playwright/test` runner |
| `playwright-driver` | Browser drivers (chromium, firefox, webkit) |
| `playwright-cli` | Microsoft `playwright-cli` — record / replay |
| `playwright-mcp` | Playwright MCP server (STDIO + HTTP) |
| `skills-playwright-cli` | Claude Code / OpenCode skill for `playwright-cli` |

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `PLAYWRIGHT_MCP_HOST` | `127.0.0.1` | MCP server bind address |
| `PLAYWRIGHT_MCP_PORT` | `18931` | MCP server port (ADR-003 prefix) |
| `PLAYWRIGHT_HEADLESS` | `true` | Default headless flag |
| `PLAYWRIGHT_BROWSERS_PATH` | `$PLAYWRIGHT_DATA_DIR/browsers` | Browser cache |
| `PLAYWRIGHT_DATA_DIR` | `$FLOX_ENV_CACHE/playwright` | State directory |

Override any in your own manifest before
`[include]`-ing this environment.

## Services

The MCP server runs as an opt-in background service:

```bash
flox services start playwright-mcp
flox services status
flox services logs playwright-mcp
flox services stop playwright-mcp
```

Point Claude Desktop, Cursor, or any MCP-aware client
at `http://${PLAYWRIGHT_MCP_HOST}:${PLAYWRIGHT_MCP_PORT}/`.

The service starts a headless Chromium per session.
Run `playwright install chromium` once before starting
the service if the browser binary isn't cached yet.

## Skill auto-pickup

When activated alongside `flox/claude`, the bundled
`SKILL.md` at `$FLOX_ENV/share/claude-code/skills/playwright-cli/`
is discovered by `flox-ai` and surfaced to
Claude Code. Same for OpenCode under
`$FLOX_ENV/share/opencode/skills/playwright-cli/`.

## See also

For an interactive walkthrough with a sample test, see
[playwright-demo](../playwright-demo/).
