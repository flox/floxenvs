# Bazel

Minimal Bazel environment providing the Bazel build
system for use as a layer in other environments.

## What is included

- `bazel` -- Google's fast, correct, multi-language
  build system (`bazel_9` from the Flox catalog)

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

| Source                                    | Version |
| ----------------------------------------- | ------- |
| Flox catalog (`nixpkgs`) -- `bazel_9`     | `9.0.1` (shipped by this env) |
| Flox catalog (`nixpkgs`) -- `bazel`       | `7.6.0` (older major)         |
| Flox org publish -- `flox/bazel`          | `9.1.0` (prebuilt upstream, `.flox/pkgs/bazel/`) |
| Upstream stable on <https://bazel.build/> | `9.1.0` |

This env ships `bazel_9` (9.0.1) because the
nixpkgs-backed source build works on every system,
including NixOS builders where `/lib64/ld-linux-*`
is absent.

`flox/bazel` (9.1.0) wraps the upstream prebuilt
release binary from
<https://github.com/bazelbuild/bazel/releases> and
is refreshed by `upgrade_pkgs.yml` on every new
Bazel release. It works out of the box on macOS and
on Linux hosts where glibc ships at the standard
`/lib64/ld-linux-*` path (Debian, Ubuntu, Fedora,
etc.). To swap it in:

```toml
[install]
bazel.pkg-path = "flox/bazel"
```

## Demo and sample project

For a runnable example that uses this environment
plus `rules_go` to build a Go binary via `flox build`,
see [bazel-demo](../bazel-demo/).
