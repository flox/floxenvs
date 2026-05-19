# serena

Minimal Serena environment. Provides the
[Serena](https://github.com/oraios/serena) CLI and the
`serena-mcp` background service for exposing Serena's MCP
server over SSE.

Serena is an MCP toolkit that gives coding agents IDE-grade
semantic tools (find symbol, find references, rename,
symbolic edit, …) backed by language servers.

## Quick start

Activate directly:

```bash
flox activate -r flox/serena --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/serena"]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `flox/serena` | The `serena` and `serena-hooks` CLIs |
| `nodejs_20`   | Runtime for Serena's bundled Pyright LSP |

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `SERENA_MCP_HOST`  | `127.0.0.1` | MCP server bind address |
| `SERENA_MCP_PORT`  | `19121`     | MCP server port (ADR-003) |
| `SERENA_TRANSPORT` | `sse`       | `sse` or `stdio` |
| `SERENA_DATA_DIR`  | `$FLOX_ENV_CACHE/serena` | State / cache root |

Override any in your own manifest before
`[include]`-ing this environment.

## Services

The MCP server runs as a background service:

```bash
flox services start serena-mcp
flox services status
flox services logs serena-mcp
flox services stop serena-mcp
```

Point Claude Desktop, Cursor, Codex, or any MCP-aware client
at `http://${SERENA_MCP_HOST}:${SERENA_MCP_PORT}/sse`.

Run the server from inside the project you want indexed:

```bash
cd path/to/project
flox services start serena-mcp
```

## See also

For an interactive walkthrough with a sample project, see
[serena-demo](../serena-demo/).
