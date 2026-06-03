# sfw-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsfw-demo%2Fdevcontainer.json)

Interactive demo of [`flox/sfw`](../sfw) — Socket Firewall Free
wrapping your package managers to block malicious installs.

It includes the minimal [`sfw`](../sfw) environment (so `npm`,
`yarn`, `pnpm`, `pip`, `uv`, `cargo` route through `sfw`
transparently) and adds:

- `nodejs`, `pip`, and `cargo` so there is something to wrap
  out of the box
- per-environment install targets (`NPM_CONFIG_PREFIX`,
  `CARGO_HOME`, `PIP_TARGET`) so installs land in
  `$FLOX_ENV_CACHE` without `sudo` or `$HOME` pollution
- a `gum` banner with the walkthrough commands

> [!WARNING]
> The walkthrough installs packages that are flagged as
> malicious. They are blocked before any code runs, but it is
> still safest to run this demo inside a container or sandbox.

## Quick start

```bash
flox activate
```

The banner lists the commands below. `npm`, `pip`, and `cargo`
already route through `sfw`, so no special prefix is needed.

### Blocked: a flagged package

```bash
npm install lodahs
```

`lodahs` is a typosquat of `lodash`. Socket Firewall blocks the
download and prints why:

```text
=== Socket Firewall ===

 - blocked npm package: name: lodahs; version: 0.0.1-security;
   reason: malware (critical)
```

The same happens across ecosystems:

```bash
pip install fabrice         # typosquat of "requests"-style names
cargo install rustdecimal   # typosquat of "rust_decimal"
```

### Allowed: a clean package

```bash
npm install lodash
```

A package with no malicious alerts is checked and then installed
normally.

## How it works

`sfw` runs your package manager behind a local proxy that checks
each requested package against Socket's supply-chain
intelligence, rejecting anything flagged before it is fetched.
The wrapping is wired by the included `flox/sfw` env via PATH
shims — see [`../sfw`](../sfw) for the details.

## See also

- [`sfw`](../sfw) — the minimal environment to include in your
  own manifests
- Upstream: <https://github.com/SocketDev/sfw-free>
