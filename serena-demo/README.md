# serena-demo

Interactive walkthrough for the
[`flox/serena`](../serena/) environment. Ships a two-file
sample Python project so you can exercise Serena's semantic
tools end-to-end with one command.

## Quick start

```bash
flox activate -r flox/serena-demo
cd sample-project
flox services start serena-mcp
```

The activation banner prints the commands above plus the MCP
endpoint URL.

## What's inside

| File | Purpose |
| ---- | ------- |
| `sample-project/main.py` | Tiny entry point that calls `utils` |
| `sample-project/utils.py` | Two functions Serena can index |

## Three things to try

1. Inspect the project structure via Serena's CLI:

   ```bash
   serena project list
   serena project index sample-project
   ```

2. Start the MCP server and point a client at it:

   ```bash
   cd sample-project
   flox services start serena-mcp
   ```

   The server listens on
   `http://$SERENA_MCP_HOST:$SERENA_MCP_PORT/sse`. Point
   Claude Desktop, Cursor, Codex, or any MCP-aware client
   at that URL.

3. Ask the agent to *"find references to greet"* — Serena
   uses Pyright (bundled via `nodejs_20`) to answer
   symbol-level questions instead of a regex grep.

## See also

For the minimal environment without sample files, see
[serena](../serena/).
