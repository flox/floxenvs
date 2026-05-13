#!/usr/bin/env bash

set -eo pipefail

for cmd in playwright playwright-cli playwright-mcp; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

# Wiring check — don't launch a browser in the CI sandbox.
playwright --version >/dev/null
echo ">>> playwright --version ... OK"

playwright test --version >/dev/null
echo ">>> playwright test --version ... OK"

playwright-cli --help >/dev/null
echo ">>> playwright-cli --help ... OK"

playwright-mcp --version >/dev/null
echo ">>> playwright-mcp --version ... OK"

if [ ! -f "$FLOX_ENV/share/claude-code/skills/playwright-cli/SKILL.md" ]; then
  echo "Error: SKILL.md not installed under \$FLOX_ENV/share/claude-code/skills/playwright-cli/"
  exit 1
fi
echo ">>> skill SKILL.md installed"

echo ">>> playwright environment is working"
