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

plugin_dir="$FLOX_ENV/share/flox/claude/playwright-cli"

if [ ! -f "$plugin_dir/.claude-plugin/plugin.json" ]; then
  echo "Error: plugin.json not installed under \$FLOX_ENV/share/flox/claude/playwright-cli/.claude-plugin/"
  exit 1
fi
echo ">>> plugin.json installed"

if [ ! -f "$plugin_dir/skills/playwright-cli/SKILL.md" ]; then
  echo "Error: SKILL.md not installed under \$FLOX_ENV/share/flox/claude/playwright-cli/skills/playwright-cli/"
  exit 1
fi
echo ">>> skill SKILL.md installed"

if ! flox-ai search playwright | grep -q skills-playwright-cli; then
  echo "Error: 'flox-ai search playwright' did not surface skills-playwright-cli"
  exit 1
fi
echo ">>> flox-ai search playwright ... OK"

echo ">>> playwright environment is working"
