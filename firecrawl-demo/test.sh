#!/usr/bin/env bash

set -eo pipefail

# Wiring-only test — skip the interactive key prompt and
# the styled banner inside the CI sandbox.
export FLOX_ENVS_TESTING=1

for cmd in firecrawl gum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

firecrawl --version >/dev/null
echo ">>> firecrawl --version ... OK"

if [ ! -f \
  "$FLOX_ENV/share/agent-plugins/firecrawl/skills/firecrawl/SKILL.md" ]; then
  echo "Error: firecrawl SKILL.md not installed"
  exit 1
fi
echo ">>> firecrawl skill installed"

if ! flox-agent list 2>&1 | grep -q "agent-plugin-firecrawl"; then
  echo "Error: flox-agent list did not show the firecrawl plugin"
  exit 1
fi
echo ">>> flox-agent list shows firecrawl ... OK"

echo ">>> firecrawl-demo environment is working"
