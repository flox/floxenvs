#!/usr/bin/env bash

set -eo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: 'python3' command not found."
  exit 1
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: 'claude' command not found."
  exit 1
fi
if ! command -v flox-ai >/dev/null 2>&1; then
  echo "Error: 'flox-ai' command not found."
  exit 1
fi
if ! command -v graphify >/dev/null 2>&1; then
  echo "Error: 'graphify' command not found."
  exit 1
fi
if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' command not found."
  exit 1
fi

echo ">>> python3 version: $(python3 --version)"
echo ">>> claude version: $(claude --version 2>&1 | head -1)"
echo ">>> flox-ai version: $(flox-ai --version 2>&1 | head -1)"
echo ">>> graphify available: $(command -v graphify)"
echo ">>> gum version: $(gum --version)"

# Verify graphify is a working CLI (no Claude session required).
graphify --help >/dev/null

# Verify flox-ai discovered the bundled /graphify skill.
# Strip ANSI colors so grep matches regardless of terminal style.
doctor_out="$(flox-ai doctor 2>&1 \
  | sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g')"
if ! echo "$doctor_out" | grep -qE '✓[[:space:]]+graphify'; then
  echo "Error: flox-ai did not discover the graphify skill."
  echo "$doctor_out" | tail -20
  exit 1
fi
echo ">>> flox-ai discovered the /graphify skill"

echo ">>> graphify-demo environment is working"
