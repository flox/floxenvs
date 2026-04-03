# 1Password Demo

Interactive demo of the 1Password CLI environment. This
environment includes the minimal `1password` base layer
and adds a welcome banner with usage instructions.

## Quick Start

```sh
flox activate -d 1password-demo
```

## What It Does

On activation, a styled banner shows the `op` version and
common commands for working with 1Password vaults and items.

Session caching is inherited from the base `1password`
layer. See `../1password/README.md` for details on how
`OP_SESSION_TOKEN` is managed.

## Fetching Secrets

Use `op` in your own hooks or scripts:

```sh
export API_KEY=$(op item get "MyService" \
  --field "credential")
```

## Packages

- `op` (`_1password`) -- 1Password CLI (from base layer)
- `gum` -- terminal UI toolkit (for the welcome banner)
