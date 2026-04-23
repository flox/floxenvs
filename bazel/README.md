# Bazel

Minimal Bazel environment providing the Bazel build
system for use as a layer in other environments.

## What is included

- `bazel` -- Google's fast, correct, multi-language
  build system (`flox/bazel` -- a prebuilt of the
  upstream release pinned via `.flox/pkgs/bazel/`)

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
| `flox/bazel` (this env)                   | `9.1.0` |
| Flox catalog (`nixpkgs`) -- `bazel_9`     | `9.0.1` |
| Flox catalog (`nixpkgs`) -- `bazel`       | `7.6.0` |
| Upstream stable on <https://bazel.build/> | `9.1.0` |

The env ships `flox/bazel`, a prebuilt wrapper of
the upstream GitHub release. It gets bumped by
`upgrade_pkgs.yml` each time a new Bazel release
lands, so the env always tracks upstream latest.

If you prefer the nixpkgs-native build, swap the
`[install]` entry:

```toml
[install]
bazel.pkg-path = "bazel_9"     # nixpkgs, 9.0.1
```

## How `flox/bazel` works

`.flox/pkgs/bazel/` in this repo wraps the prebuilt
binary from `github.com/bazelbuild/bazel/releases`.
On Linux it runs inside a minimal FHS chroot so
Bazel's embedded JDK can find `/lib64/ld-linux-*`;
on macOS the signed binary runs directly.

## Demo and sample project

For a runnable example that uses this environment
plus `rules_go` to build a Go binary via `flox build`,
see [bazel-demo](../bazel-demo/).
