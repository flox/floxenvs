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
  "$FLOX_ENV/share/flox/claude/firecrawl-cli/skills/firecrawl-cli/SKILL.md" ]; then
  echo "Error: firecrawl-cli SKILL.md not installed"
  exit 1
fi
echo ">>> firecrawl-cli skill installed"

if ! flox-ai search firecrawl 2>&1 | grep -q "skills-firecrawl-cli"; then
  echo "Error: flox-ai search did not surface the firecrawl-cli skill"
  exit 1
fi
echo ">>> flox-ai search firecrawl ... OK"

echo ">>> firecrawl-demo environment is working"
