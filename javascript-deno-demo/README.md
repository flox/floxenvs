# javascript-deno-demo

Demo environment that extends
[javascript-deno](../javascript-deno/) with a sample project
and interactive UI tools.

## What's included

- **Deno** runtime (from `javascript-deno`)
- **gum** for styled terminal output
- **figlet** sample project (`main.ts`)
- Automatic `deno install` on activation

## Quick start

```bash
flox activate
deno run --allow-read main.ts
```

On activation you will see a styled welcome banner showing
the Deno version and available commands.

## Deno commands

| Command | Description |
| ------- | ----------- |
| `deno install` | Install dependencies from `deno.json` |
| `deno run <file>` | Execute a TypeScript or JavaScript file |
| `deno task` | Run a task defined in `deno.json` |

## Automatic package installation

The base `javascript-deno` environment sets
`DENO_AUTO_INSTALL=true`. When both `deno.json` and
`deno.lock` are present, `deno install` runs automatically
on activation if packages have changed.

To disable this behaviour:

```bash
flox edit  # set DENO_AUTO_INSTALL = "false" in [vars]
```

## Customisation

Deno has built-in TypeScript support. No additional
configuration is needed.

## Using the minimal layer directly

If you don't need the demo project or gum, include only
the base environment:

```toml
[include]
environments = [
  { dir = "flox/javascript-deno" }
]
```

See [javascript-deno/README.md](../javascript-deno/README.md)
for details.
