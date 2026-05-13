# playwright-demo

Interactive walkthrough for the `flox/playwright`
environment. Ships a tiny sample test that exercises
`demo.playwright.dev/todomvc` so you can verify the
toolchain end-to-end with one command.

## Quick start

```bash
flox activate -r flox/playwright-demo
playwright install chromium
playwright test
```

The activation banner prints the commands above plus
links to the MCP service and `playwright-cli`.

## What's inside

| File                    | Purpose                        |
| ----------------------- | ------------------------------ |
| `tests/example.spec.ts` | todomvc smoke test             |
| `playwright.config.ts`  | One chromium project, headless |

`PLAYWRIGHT_HEADLESS=false playwright test --headed`
opens a real browser window.

## Three things to try

1. Run the sample test:

   ```bash
   playwright test
   ```

2. Drive a browser interactively from the CLI:

   ```bash
   playwright-cli open https://playwright.dev --headed
   playwright-cli type "page object"
   playwright-cli press Enter
   ```

3. Expose Playwright over MCP:

   ```bash
   flox services start playwright-mcp
   ```

   Point Claude Desktop, Cursor, or VS Code's MCP
   client at
   `http://$PLAYWRIGHT_MCP_HOST:$PLAYWRIGHT_MCP_PORT/`.

## See also

For the minimal environment without sample files, see
[playwright](../playwright/).
