#!/usr/bin/env bash
#
# One-shot helper that walks README.md and inserts a
# [codespace] link at the end of each table row whose env
# has a generated devcontainer.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
README="$REPO_ROOT/README.md"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# Build the set of envs that have devcontainers.
declare -A HAS_DC
for dc in "$REPO_ROOT"/.devcontainer/*/devcontainer.json; do
  [ -e "$dc" ] || continue
  env="$(basename "$(dirname "$dc")")"
  HAS_DC["$env"]=1
done

# Walk README. For each row that mentions an [floxhub]
# link, extract the env name from the [docs](X/README.md)
# form and append a [codespace] link if appropriate.
# Skip rows already containing "[codespace]".
while IFS= read -r line; do
  if [[ "$line" =~ ^\| ]] \
     && [[ "$line" == *"floxhub"* ]] \
     && [[ "$line" != *"[codespace]"* ]]; then
    env="$(printf '%s' "$line" \
      | grep -oE '\[docs\]\([a-zA-Z0-9_-]+/README' \
      | head -1 \
      | sed 's|\[docs\](||; s|/README||')"
    if [ -n "$env" ] && [ -n "${HAS_DC[$env]:-}" ]; then
      url="https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2F$env%2Fdevcontainer.json"
      prefix="${line%|*}"
      prefix="${prefix%" "}"
      line="$prefix · [codespace]($url) |"
    fi
  fi
  printf '%s\n' "$line"
done < "$README" > "$TMP"

mv "$TMP" "$README"
echo "README updated."
