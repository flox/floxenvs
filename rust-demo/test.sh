#!/usr/bin/env bash

set -eo pipefail

if ! command -v rustc >/dev/null 2>&1; then
  echo "Error: 'rustc' command not found."
  exit 1
fi
if ! command -v cargo >/dev/null 2>&1; then
  echo "Error: 'cargo' command not found."
  exit 1
fi

echo ">>> cargo fmt --check"
cargo fmt --check
echo ">>> Formatting ... OK"

echo ">>> cargo clippy"
cargo clippy -- -D warnings
echo ">>> Linting ... OK"

echo ">>> cargo run"
cargo run
echo ">>> Build and run ... OK"

echo ">>> cargo test"
cargo test
echo ">>> Tests ... OK"
