#!/usr/bin/env bash
#
# Insert a Codespaces badge into every <env>/README.md
# whose env has a generated devcontainer. Idempotent via
# the BADGE_MARKER comment.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BADGE_MARKER="<!-- codespaces-badge -->"

for dc in "$REPO_ROOT"/.devcontainer/*/devcontainer.json; do
  [ -e "$dc" ] || continue
  env="$(basename "$(dirname "$dc")")"
  readme="$REPO_ROOT/$env/README.md"
  [ -f "$readme" ] || continue

  url="https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2F$env%2Fdevcontainer.json"
  badge_md="[![Open in Codespaces](https://github.com/codespaces/badge.svg)]($url)"

  if grep -q "$BADGE_MARKER" "$readme"; then
    # Replace the line immediately after the marker (the badge line).
    awk -v marker="$BADGE_MARKER" -v badge="$badge_md" '
      prev_was_marker { print badge; prev_was_marker = 0; next }
      $0 == marker    { print; prev_was_marker = 1; next }
      { print }
    ' "$readme" > "$readme.new"
    mv "$readme.new" "$readme"
    echo "  updated $env/README.md"
  else
    # Insert marker + badge after the first H1 line,
    # consuming any blank line immediately after H1.
    awk -v marker="$BADGE_MARKER" -v badge="$badge_md" '
      BEGIN { inserted = 0; after_h1 = 0 }
      /^# / && !inserted {
        print
        after_h1 = 1
        inserted = 1
        next
      }
      after_h1 {
        # Skip a single blank line that may follow H1.
        after_h1 = 0
        print ""
        print marker
        print badge
        print ""
        if ($0 != "") print
        next
      }
      { print }
    ' "$readme" > "$readme.new"
    mv "$readme.new" "$readme"
    echo "  inserted into $env/README.md"
  fi
done

echo "Done."
