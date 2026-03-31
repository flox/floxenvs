# Rust Demo

Full Rust development environment with editor tooling and
a sample application. Built on top of the minimal
[rust](../rust/) environment via `[include]`.

## Quick start

```bash
flox activate
cargo run
```

## Included tools

From the base `rust` environment (via [include]):

- **rustc** -- compiler
- **cargo** -- package manager and build tool
- **clippy** -- linter
- **rustfmt** -- code formatter
- **rust-lib-src** -- standard library source

Added by this environment:

- **rust-analyzer** -- language server (matched to the
  compiler version via the `rust-toolchain` pkg-group)
- **cargo-nextest** -- fast test runner
- **cargo-watch** -- file watcher for iterative development
- **cargo-semver-checks** -- semver compatibility linter

## Development workflow

Format the code:

```bash
cargo fmt
```

Run the linter:

```bash
cargo clippy -- -D warnings
```

Build and run:

```bash
cargo run
```

Run tests:

```bash
cargo test
```

Or use the included test script to run all checks:

```bash
./test.sh
```

## See also

For a minimal, includable Rust toolchain without editor
tooling or sample code, see [rust](../rust/).
