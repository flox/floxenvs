#!/usr/bin/env bash
#
# Per-env metrics for `claude`. Inherits the env defaults
# and adds Claude-specific quality checks.
#
# Usage: metrics.sh <kind> <name>  (kind = env, name = claude)

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/sh-helpers.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/metrics-defaults.sh"

# shellcheck disable=SC2034
KIND="${1:-env}"
NAME="${2:-claude}"
dir="$REPO_ROOT/$NAME"
manifest="$dir/.flox/env/manifest.toml"

# Start with the env defaults, then re-aggregate including
# claude-specific extra checks.
defaults=$(default_env_checks "$NAME" "$dir")

# Stream all checks (defaults + extras) through
# sh_aggregate_quality so the output shape stays uniform.
{
  # Replay the default checks (one per line).
  echo "$defaults" | jq -c '.checks[]'

  # Claude-specific checks.
  # claude-managed pinned to semver
  pinned=true note=""
  if grep -q '^claude-managed.version' "$manifest"; then
    v=$(grep '^claude-managed.version' "$manifest" \
          | head -1 | awk -F'"' '{print $2}')
    if [[ ! "$v" =~ ^\^?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
      pinned=false
      note="claude-managed.version=$v is not semver"
    fi
  else
    pinned=false
    note="claude-managed.version missing"
  fi
  sh_check_json "claude-managed-pinned" "$pinned" 10 "$note"

  # MCP fragment example present in README
  mcp_doc=false
  if [ -f "$dir/README.md" ] \
     && grep -qi 'mcp' "$dir/README.md"; then
    mcp_doc=true
  fi
  sh_check_json "documents-mcp" "$mcp_doc" 5

  # Demo should not start services for the CLI env.
  svc=true
  if [ -f "$dir-demo/.flox/env/manifest.toml" ] \
     && grep -q '^\[services\]' \
          "$dir-demo/.flox/env/manifest.toml"; then
    svc=false
  fi
  sh_check_json "no-services-in-demo" "$svc" 5
} | sh_aggregate_quality
