# Rust

Minimal Rust toolchain environment designed for use as an
`[include]` base in other Flox environments.

## What it provides

- **rustc** -- the Rust compiler
- **cargo** -- package manager and build tool
- **clippy** -- linter
- **rustfmt** -- code formatter
- **rust-lib-src** -- standard library source for IDE support
- **clang** (macOS) / **gcc** (Linux) -- platform linker

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/rust"]
```

Then add project-specific packages (rust-analyzer, cargo
tools, etc.) in your local manifest.

## Package groups

All toolchain packages belong to the `rust-toolchain`
pkg-group. This ensures that rustc, cargo, clippy, and
rustfmt are resolved to compatible versions from the same
Nixpkgs revision.

When adding packages that must match the compiler version
(e.g. rust-analyzer), place them in the same group:

```toml
rust-analyzer.pkg-path = "rust-analyzer"
rust-analyzer.pkg-group = "rust-toolchain"
```

## Platform-specific notes

| Platform | Linker | Extra libraries |
| -------- | ------ | --------------- |
| macOS    | clang  | libiconv        |
| Linux    | gcc    | (none)          |

These are included automatically and scoped to the correct
systems via `pkg.systems`.

## See also

For a full development environment with rust-analyzer,
cargo tools, and a sample application, see
[rust-demo](../rust-demo/).
