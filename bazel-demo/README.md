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

| File           | Purpose                                     |
| -------------- | ------------------------------------------- |
| `MODULE.bazel` | Bzlmod module with a `rules_go` dependency  |
| `BUILD.bazel`  | `go_binary` target named `hello`            |
| `.bazelrc`     | Reproducible defaults (bzlmod on, pure Go)  |
| `main.go`      | The sample Go program                       |

The manifest's `[build.hello]` table runs:

```bash
bazel_cache="$(mktemp -d)"
bazel --output_user_root="$bazel_cache" \
  build //:hello --repo_contents_cache=
cp -L bazel-bin/hello_/hello "$out/bin/hello"
```

`--repo_contents_cache=` disables Bazel 9's new repo
contents cache so it doesn't land inside the
worktree. `mktemp -d` keeps the Bazel install tree
outside `$FLOX_ENV_CACHE`, which isn't exported by
`flox build`'s local mode.

## Versions

| Source                                    | Version |
| ----------------------------------------- | ------- |
| `bazel_9` from catalog (used by this env) | `9.0.1` |
| Upstream on <https://bazel.build/>        | `9.1.0` |
| `rules_go`                                | `0.60.0` (pinned in `MODULE.bazel`) |
| Go SDK                                    | `1.24.0` (pinned via `go_sdk.download`) |

To try the upstream-latest 9.1.0 on macOS or a
standard-glibc Linux, swap the minimal env to the
custom `flox/bazel` package -- see
[../bazel/README.md](../bazel/README.md).

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
