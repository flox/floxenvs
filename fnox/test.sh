#!/usr/bin/env bash

set -eo pipefail

if ! command -v fnox >/dev/null 2>&1; then
  echo "Error: 'fnox' command not found."
  exit 1
fi

echo ">>> fnox version: $(fnox --version)"

# Sanity-check a few subcommands so a broken binary fails loudly
# rather than silently here.
fnox --help >/dev/null
fnox provider list --help >/dev/null

echo ">>> fnox environment is working"
