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

for skill in firecrawl-cli firecrawl-scrape firecrawl-search; do
  if [ ! -f \
    "$FLOX_ENV/share/flox/claude/firecrawl-cli/skills/$skill/SKILL.md" ]; then
    echo "Error: $skill SKILL.md not installed under" \
      "\$FLOX_ENV/share/flox/claude/firecrawl-cli/skills/$skill/"
    exit 1
  fi
  echo ">>> skill $skill installed"
done

if ! flox-ai search firecrawl 2>&1 | grep -q "skills-firecrawl-cli"; then
  echo "Error: flox-ai search did not surface the firecrawl-cli skill"
  exit 1
fi
echo ">>> flox-ai search firecrawl ... OK"

echo ">>> firecrawl environment is working"
