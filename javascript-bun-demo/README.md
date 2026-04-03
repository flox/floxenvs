# javascript-bun-demo

Demo environment that extends
[javascript-bun](../javascript-bun/) with a sample project
and interactive UI tools.

## What's included

- **Bun** runtime and package manager (from `javascript-bun`)
- **gum** for styled terminal output
- **figlet** sample project (`index.ts`)
- Automatic `bun install` on activation

## Quick start

```bash
flox activate
bun index.ts
```

On activation you will see a styled welcome banner showing
the Bun version and available commands.

## Bun commands

| Command | Description |
| ------- | ----------- |
| `bun install` | Install dependencies from `package.json` |
| `bun run` | Run a script defined in `package.json` |
| `bun <file>` | Execute a TypeScript or JavaScript file |

## Automatic package installation

The base `javascript-bun` environment sets
`BUN_AUTO_INSTALL=true`. When both `package.json` and
a lock file are present, `bun install --frozen-lockfile` runs
automatically on activation if packages have changed.

To disable this behaviour:

```bash
flox edit  # set BUN_AUTO_INSTALL = "false" in [vars]
```

## Customisation

This demo uses Bun's built-in TypeScript support. No
additional configuration is needed.

## Using the minimal layer directly

If you don't need the demo project or gum, include only
the base environment:

```toml
[include]
environments = [
  { dir = "flox/javascript-bun" }
]
```

See [javascript-bun/README.md](../javascript-bun/README.md)
for details.
