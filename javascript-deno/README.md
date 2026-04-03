# javascript-deno

Minimal Deno environment with automatic dependency
installation. Designed for use as an `[include]` base layer.

## What it provides

- Deno runtime
- Automatic `deno install` on activation
- Hash-based dependency caching

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../javascript-deno" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/javascript-deno"]
```

## Automatic dependency installation

When `DENO_AUTO_INSTALL` is `"true"` (the default) and both
`deno.json` and `deno.lock` exist in the project directory,
the hook runs `deno install` automatically on activation.

To skip automatic installation, set the variable in your
manifest:

```toml
[vars]
DENO_AUTO_INSTALL = "false"
```

## Dependency caching

The hook computes a SHA-256 hash of `deno.json` and
`deno.lock` combined, then stores the result in
`$FLOX_ENV_CACHE/javascript-deno/packages-hash`. On subsequent
activations, packages are only reinstalled when the hash
changes. This keeps activation fast when dependencies have not
changed.

## See also

- [javascript-deno-demo](../javascript-deno-demo) -- demo
  project that includes this environment and adds sample
  dependencies
