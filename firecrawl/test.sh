#!/usr/bin/env bash

set -eo pipefail

if ! command -v firecrawl >/dev/null 2>&1; then
  echo "Error: 'firecrawl' command not found."
  exit 1
fi
echo ">>> firecrawl present"

# Self-contained, offline command — no API key needed.
firecrawl --version >/dev/null
echo ">>> firecrawl --version ... OK"

# Upstream renamed the entry skill firecrawl-cli -> firecrawl.
for skill in firecrawl firecrawl-scrape firecrawl-search; do
  if [ ! -f \
    "$FLOX_ENV/share/agent-plugins/firecrawl/skills/$skill/SKILL.md" ]; then
    echo "Error: $skill SKILL.md not installed under" \
      "\$FLOX_ENV/share/agent-plugins/firecrawl/skills/$skill/"
    exit 1
  fi
  echo ">>> skill $skill installed"
done

if ! flox-agent list 2>&1 | grep -q "agent-plugin-firecrawl"; then
  echo "Error: flox-agent list did not show the firecrawl plugin"
  exit 1
fi
echo ">>> flox-agent list shows firecrawl ... OK"

echo ">>> firecrawl environment is working"
