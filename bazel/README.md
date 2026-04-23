# Bazel

Minimal Bazel environment providing the Bazel build
system for use as a layer in other environments.

## What is included

- `bazel` -- Google's fast, correct, multi-language
  build system (provided by `bazel_9` from the
  Flox catalog)

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

Or persist it by adding to `.bazelrc`:

```text
startup --output_user_root=${BAZEL_CACHE_DIR}
```

## Versions

| Source                       | Version |
| ---------------------------- | ------- |
| Flox catalog (`nixpkgs`) -- `bazel_9`    | `9.0.1` (shipped by this env) |
| Flox catalog (`nixpkgs`) -- `bazel`      | `7.6.0` (older major)         |
| Flox org publish -- `flox/bazel`         | `9.1.0` (prebuilt from upstream, built from `.flox/pkgs/bazel/`) |
| Upstream stable on <https://bazel.build/> | `9.1.0` |

This env ships `bazel_9` (9.0.1) because it is
available in the nixpkgs-backed catalog and needs no
extra publish step. For the absolute upstream latest
(`9.1.0`) install `flox/bazel` instead -- it wraps
the prebuilt binary from the upstream GitHub release
and gets bumped by `upgrade_pkgs.yml` every time a
new Bazel release lands.

```toml
[install]
# Pick one:
bazel.pkg-path = "bazel_9"     # nixpkgs, 9.0.1
bazel.pkg-path = "flox/bazel"  # upstream prebuilt, 9.1.0
```

## Demo and sample project

For a runnable example that uses this environment
plus `rules_go` to build a Go binary via `flox build`,
see [bazel-demo](../bazel-demo/).
