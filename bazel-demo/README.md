# Bazel Demo

Full Bazel environment with a sample Go application
built via `rules_go` and wrapped in a Flox manifest
build.

Builds on the minimal [bazel](../bazel/) environment
via `[include]`.

## Quick start

```bash
flox activate
flox build hello
./result-hello/bin/hello
```

Expected output:

```text
Hello from Bazel + Go + Flox!
```

## What's in here

| File            | Purpose                                    |
| --------------- | ------------------------------------------ |
| `MODULE.bazel`  | Bzlmod module with a `rules_go` dependency |
| `BUILD.bazel`   | `go_binary` target named `hello`           |
| `.bazelrc`      | Reproducible defaults (bzlmod on, quiet)   |
| `.bazelversion` | Pins Bazel to the env-provided version     |
| `main.go`       | The sample Go program                      |

The manifest's `[build.hello]` table runs:

```bash
bazel --output_user_root="$BAZEL_CACHE_DIR" build //:hello
cp -L bazel-bin/hello_/hello "$out/bin/hello"
```

`$BAZEL_CACHE_DIR` comes from the included `bazel`
env and defaults to `$FLOX_ENV_CACHE/bazel` so
repeated builds reuse Bazel's action cache.

## Versions

| Source                                    | Version |
| ----------------------------------------- | ------- |
| `flox/bazel` (used by this env)           | `9.1.0` |
| Upstream on <https://bazel.build/>        | `9.1.0` |
| `rules_go`                                | `0.50.1` (pinned in `MODULE.bazel`) |

`flox/bazel` tracks upstream latest and is rebuilt
by `upgrade_pkgs.yml` whenever a new Bazel release
lands.

## Customization

Fork this environment and edit
`.flox/env/manifest.toml` to add more `[build.*]`
targets, extra tooling (e.g. `buildifier`), or to
pin a different Bazel version.

## Minimal environment

If you only need Bazel itself without the sample
project, use [bazel](../bazel/) directly or include
it in your own manifest:

```toml
[include]
environments = ["flox/bazel"]
```
