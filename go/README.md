# Go

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgo%2Fdevcontainer.json)

Minimal Go environment providing the Go compiler and
standard toolchain.

## What is included

- `go` -- compiler, build tool, and standard library
- `clang` -- C compiler and linker, so that cgo builds work
- `darwin.libresolv` (macOS only) -- required by the Go runtime when
  linking with cgo

## Usage

Activate directly:

```bash
flox activate -r flox/go
```

Or include it in your own manifest:

```toml
[include]
environments = [{ remote = "flox/go" }]
```

## Environment variables

| Variable | Description                              |
| -------- | ---------------------------------------- |
| `GOENV`  | Set to `$FLOX_ENV_CACHE/go` on activate  |

## Why a C toolchain is included

cgo is on by default, and it is not an exotic case: a dependency that
imports `"C"` pulls it in, which covers sqlite drivers, many crypto and
image bindings, and parts of the standard library on macOS. An environment
with only `go` builds those packages against whatever compiler happens to be
on the host, which defeats the point of using Flox for the toolchain.

On macOS this also produced a confusing warning. Flox activates in dev mode
by default, which exports `CPATH`, `LIBRARY_PATH`, and `PKG_CONFIG_PATH`
pointing into the environment so that C toolchains find libraries installed
by Flox:

```
LIBRARY_PATH="$FLOX_ENV/lib"
```

With only `go` installed, nothing ever creates `$FLOX_ENV/lib`, and Apple's
linker warns about every search path that does not exist:

```
ld: warning: search path '.../.flox/run/aarch64-darwin.<env>-dev/lib' not found
```

The build still succeeded, but the warning appeared on every cgo build and
gave the impression that the environment was broken. Installing `clang` makes
`$FLOX_ENV/lib` a real directory (the libSystem libraries that ship with the
compiler), so the path exists and the warning is gone for the right reason.

`darwin.libresolv` is installed alongside it because the Go runtime links
`-lresolv` on macOS, which the libSystem from `clang` does not provide. Without
it the link fails outright:

```
ld: library not found for -lresolv
```

With both packages, a cgo build works entirely from Flox-provided components,
including on a Mac where Xcode or the Command Line Tools are not set up.

If a project is pure Go and the extra compiler is unwanted, activation in run
mode skips the dev-mode toolchain paths entirely:

```toml
[options.activate]
mode = "run"
```

Note that Go caches build output including compiler stderr, so run
`go clean -cache` when checking whether a warning is really gone.

## Editor tooling and sample app

For a full development setup with `gopls`, `gotools`,
`go-task`, and a sample "Hello World" app, see
[go-demo](../go-demo/).
