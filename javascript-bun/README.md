# javascript-bun

Minimal Bun environment with automatic dependency
installation. Designed for use as an `[include]` base layer.

## What it provides

- Bun runtime and package manager
- Automatic `bun install` on activation
- Hash-based dependency caching

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../javascript-bun" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/javascript-bun"]
```

## Automatic dependency installation

When `BUN_AUTO_INSTALL` is `"true"` (the default) and both
`package.json` and a lock file (`bun.lockb` or `bun.lock`)
exist in the project directory, the hook runs
`bun install --frozen-lockfile` automatically on activation.

To skip automatic installation, set the variable in your
manifest:

```toml
[vars]
BUN_AUTO_INSTALL = "false"
```

## Dependency caching

The hook computes a SHA-256 hash of `package.json` and
the lock file combined, then stores the result in
`$FLOX_ENV_CACHE/javascript-bun/packages-hash`. On subsequent
activations, packages are only reinstalled when the hash
changes. This keeps activation fast when dependencies have not
changed.

## See also

- [javascript-bun-demo](../javascript-bun-demo) -- demo
  project that includes this environment and adds sample
  dependencies
