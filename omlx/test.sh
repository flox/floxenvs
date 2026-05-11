#!/usr/bin/env bash

set -eo pipefail

if ! command -v omlx >/dev/null 2>&1; then
  echo "Error: 'omlx' command not found."
  exit 1
fi
echo ">>> omlx command present"

# Confirm the CLI is wired up (no --version flag exists; --help works).
if ! omlx --help >/dev/null 2>&1; then
  echo "Error: 'omlx --help' failed."
  exit 1
fi
echo ">>> omlx --help ... OK"

if ! omlx serve --help >/dev/null 2>&1; then
  echo "Error: 'omlx serve --help' failed."
  exit 1
fi
echo ">>> omlx serve --help ... OK"

if ! python3 -c "import omlx" 2>/dev/null; then
  echo "Error: failed to 'import omlx'"
  exit 1
fi
echo ">>> import omlx ... OK"

echo ">>> omlx environment is working"
