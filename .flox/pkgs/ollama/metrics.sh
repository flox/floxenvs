#!/usr/bin/env bash
#
# Per-pkg metrics for `ollama`. Inherits the pkg defaults
# and adds pkg-specific quality checks.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/sh-helpers.sh"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/metrics-defaults.sh"

_KIND="${1:-pkg}"
NAME="${2:-ollama}"
dir="$REPO_ROOT/.flox/pkgs/$NAME"

defaults=$(default_pkg_checks "$NAME" "$dir")

{
  # Replay the default checks.
  echo "$defaults" | jq -c '.checks[]'

  # vendorHash present and not the placeholder zero hash
  vh_ok=true note=""
  if [ -f "$dir/hashes.json" ]; then
    vh=$(jq -r '.vendorHash // ""' "$dir/hashes.json")
    if [ -z "$vh" ] \
       || [ "$vh" = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" ]; then
      vh_ok=false
      note="vendorHash missing or placeholder"
    fi
  fi
  sh_check_json "vendor-hash-real" "$vh_ok" 10 "$note"

  # upgrade.sh sets -euo pipefail
  pf=true
  if [ -f "$dir/upgrade.sh" ] \
     && ! head -5 "$dir/upgrade.sh" \
          | grep -q 'set -euo pipefail'; then
    pf=false
  fi
  sh_check_json "upgrade-sh-pipefail" "$pf" 5
} | sh_aggregate_quality
