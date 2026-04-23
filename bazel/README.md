# Bazel

Minimal Bazel environment providing the Bazel build
system for use as a layer in other environments.

## What is included

- `bazel` -- Google's fast, correct, multi-language
  build system
- `gcc` (Linux only) -- required by `rules_cc` auto-
  configure on first Bazel invocation

## Usage

Activate directly:

```bash
flox activate -r flox/bazel
```

Or include it in your own manifest:

```toml
[include]
environments = ["flox/bazel"]
```

## Environment variables

| Variable           | Description                              |
| ------------------ | ---------------------------------------- |
| `BAZEL_CACHE_DIR`  | `$FLOX_ENV_CACHE/bazel` (created on activate) |

Point Bazel's output at this directory to keep build
state isolated per environment:

```bash
bazel --output_user_root="$BAZEL_CACHE_DIR" build //...
```

## Versions

The env ships different Bazel builds per system:

| System       | Source                            | Version |
| ------------ | --------------------------------- | ------- |
| `*-darwin`   | `flox/bazel` (upstream prebuilt)  | `9.1.0` |
| `*-linux`    | `bazel_9` from nixpkgs catalog    | `9.0.1` |

On macOS the upstream release binary works out of the
box, so the env picks `flox/bazel` (packaged from
`.flox/pkgs/bazel/`) and tracks every new Bazel
release via `upgrade_pkgs.yml`.

On Linux the upstream prebuilt binary's embedded JDK
is pinned to `/lib64/ld-linux-*`, which is absent on
NixOS-style hosts, so the env falls back to
`nixpkgs`' source-built `bazel_9` (currently `9.0.1`)
which is built against the nixpkgs glibc/JDK and
works everywhere.

Upstream stable on <https://bazel.build/> is `9.1.0`.

| Alternative    | Version |
| -------------- | ------- |
| `bazel` from nixpkgs (older major) | `7.6.0` |

## Demo and sample project

For a runnable example that uses this environment
plus `rules_go` to build a Go binary via `flox build`,
see [bazel-demo](../bazel-demo/).
