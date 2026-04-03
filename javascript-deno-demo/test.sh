#!/usr/bin/env bash

set -eo pipefail

if ! command -v deno >/dev/null 2>&1; then
  echo "Error: 'deno' command not found."
  exit 1
fi

echo ">>> deno version: $(deno --version | head -1)"

# Verify figlet installed from deno.json
if [ -f deno.json ]; then
  echo ">>> Verifying packages..."
  deno eval "import 'figlet'"
  echo ">>> Package import ... OK"
fi

# Run sample script
if [ -f main.ts ]; then
  deno run --allow-read main.ts
  echo ">>> main.ts ... OK"
fi

echo ">>> javascript-deno-demo environment is working"
