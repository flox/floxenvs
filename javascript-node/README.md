# javascript-node

Minimal Node.js + npm environment with automatic dependency
installation. Designed for use as an `[include]` base layer.

## What it provides

- Node.js interpreter
- npm package manager
- Automatic `npm install` on activation
- Hash-based dependency caching

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../javascript-node" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/javascript-node"]
```

## Node version

There are three ways to control the Node.js version in your
manifest:

1. **Latest available** (default):

   ```toml
   [install]
   nodejs.pkg-path = "nodejs"
   ```

2. **Specific major version**:

   ```toml
   [install]
   nodejs.pkg-path = "nodejs_22"
   ```

3. **Exact version pin**:

   ```toml
   [install]
   nodejs.pkg-path = "nodejs_20"
   nodejs.version = "20.11.1"
   ```

## Automatic dependency installation

When `NODE_AUTO_INSTALL` is `"true"` (the default) and both
`package.json` and `package-lock.json` exist in the project
directory, the hook runs `npm install` automatically on
activation.

To skip automatic installation, set the variable in your
manifest:

```toml
[vars]
NODE_AUTO_INSTALL = "false"
```

## Dependency caching

The hook computes a SHA-256 hash of `package.json` and
`package-lock.json` combined, then stores the result in
`$FLOX_ENV_CACHE/javascript-node/packages-hash`. On subsequent
activations, packages are only reinstalled when the hash
changes. This keeps activation fast when dependencies have not
changed.

## See also

- [javascript-node-demo](../javascript-node-demo) -- demo
  project that includes this environment and adds sample
  dependencies
