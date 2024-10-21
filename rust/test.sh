#!/usr/bin/env bash

set -eo pipefail

check_command() {
    if ! command -v $1 2>&1 >/dev/null
    then
        echo "Error: '$1' command could not be found."
        exit 1
    fi
}

check_command rustc
check_command rustfmt
check_command cargo
check_command cargo-fmt
check_command cargo-clippy


cargo fmt
echo ">>> Formatting code"

cargo clippy
echo ">>> Linting code"

cargo run
echo ">>> Building and running code"

