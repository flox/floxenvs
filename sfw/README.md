# sfw

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsfw%2Fdevcontainer.json)

Minimal [Socket Firewall Free](https://github.com/SocketDev/sfw-free)
environment. `sfw` wraps your package manager and blocks
installation of known-malicious packages, checking each install
against Socket's supply-chain intelligence. This environment
installs `flox/sfw` and wires its PATH shims so that `npm`, `yarn`,
`pnpm`, `pip`, `uv`, and `cargo` are routed through `sfw`
transparently. Designed to be included as a base layer in other
Flox environments.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [{ remote = "flox/sfw" }]
```

Bring your own package managers — from the system, a layered env,
or another included environment. Whichever of `npm`, `yarn`,
`pnpm`, `pip`, `uv`, `cargo` end up on `PATH` are wrapped
automatically. After that, a plain call routes through Socket
Firewall:

```bash
npm install lodash      # checked, then installed
pip install requests    # checked, then installed
```

A package flagged as malicious is blocked before it runs.

## How the wrapping works

The `flox/sfw` package ships per-ecosystem shims at
`$FLOX_ENV/libexec/sfw-shims/`. Each shim resolves the real
binary on `PATH` and execs `sfw <real-bin> "$@"`, so the
wrapping survives in scripts, child processes,
`flox activate -- cmd`, CI, and agent-driven invocations — places
a shell alias would not reach. A `_SFW_WRAPPING` sentinel breaks
the recursion when `sfw` itself execs the real command.

This environment puts the shim dir on `PATH` two ways, so the
wrapping holds across activation styles:

- `[hook] on-activate` — covers `flox activate -- cmd`, scripts,
  and CI.
- `[profile.common]` plus the shipped `activate.bash` /
  `activate.zsh` helpers — covers interactive shells, and
  re-prepend the shim dir on every prompt so it stays in front of
  `PATH` even after you source a third-party activate script (e.g.
  a Python venv's `bin/activate`).

## Running package managers without sfw

Call the real binary by its absolute path, or temporarily drop
the shim dir from `PATH`. The shim only intercepts the bare
command name resolved through `PATH`.

## Packages

- `sfw` — the Socket Firewall Free CLI plus its PATH shims (custom
  Flox package, prebuilt upstream binary)

## See also

- [`sfw-demo`](../sfw-demo) — interactive demo that pre-installs
  `nodejs`, `pip`, and `cargo` and walks through blocked-package
  examples
- Upstream: <https://github.com/SocketDev/sfw-free>
