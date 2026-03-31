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

echo ">>> rustc version"
rustc --version

echo ">>> cargo version"
cargo --version

echo ">>> Rust toolchain is working"
