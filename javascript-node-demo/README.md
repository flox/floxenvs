# javascript-node-demo

Demo environment that extends
[javascript-node](../javascript-node/) with a sample project
and interactive UI tools.

## What's included

- **Node.js 20** and **npm** (from `javascript-node`)
- **gum** for styled terminal output
- **figlet** sample project (`index.js`)
- Automatic `npm install` on activation

## Quick start

```bash
flox activate
npm start        # or: node index.js
```

On activation you will see a styled welcome banner showing
the Node.js version and available commands.

## npm commands

| Command | Description |
| ------- | ----------- |
| `npm install` | Install dependencies from `package.json` |
| `npm start` | Run the main script |
| `npm test` | Run tests (if configured) |
| `node <file>` | Execute a JavaScript file |

## Automatic package installation

The base `javascript-node` environment sets
`NODE_AUTO_INSTALL=true`. When both `package.json` and
`package-lock.json` are present, `npm install` runs
automatically on activation if packages have changed.

To disable this behaviour:

```bash
flox edit  # set NODE_AUTO_INSTALL = "false" in [vars]
```

## Customisation

Override the Node.js version in your own manifest:

```toml
[install]
nodejs.pkg-path = "nodejs_22"
```

## Using the minimal layer directly

If you don't need the demo project or gum, include only
the base environment:

```toml
[include]
environments = [
  { dir = "flox/javascript-node" }
]
```

See [javascript-node/README.md](../javascript-node/README.md)
for details.
