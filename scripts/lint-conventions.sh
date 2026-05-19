#!/usr/bin/env bash
# AGENTS.md rule checks for an env directory. Emits a
# JSON quality section on stdout.
#
# Usage: lint-conventions.sh <name>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

NAME="${1:?name required}"
dir="$ROOT/$NAME"
manifest="$dir/.flox/env/manifest.toml"

EXPECTED_SCHEMA="1.10.0"

{
  sv=false
  if [ -f "$manifest" ] && grep -q \
       "^schema-version = \"${EXPECTED_SCHEMA}\"$" \
       "$manifest"; then
    sv=true
  fi
  sh_check_json "schema-version-current" "$sv" 10

  silent=true; note=""
  if [ -f "$manifest" ]; then
    if awk '
      /^on-activate = '"'"''"'"''"'"'/,/^'"'"''"'"''"'"'/ {
        if (/echo|printf/) { found=1 }
      }
      END { exit found ? 0 : 1 }
    ' "$manifest"; then
      silent=false
      note="echo or printf in on-activate"
    fi
  fi
  sh_check_json "silent-hook" "$silent" 10 "$note"

  fec=true; note=""
  if [ -f "$manifest" ] \
     && grep -q '^on-activate' "$manifest" \
     && ! grep -q 'FLOX_ENV_CACHE' "$manifest"; then
    fec=false
    note="on-activate without FLOX_ENV_CACHE"
  fi
  sh_check_json "uses-flox-env-cache" "$fec" 10 "$note"

  pgn=true; note=""
  if [ -f "$manifest" ]; then
    if grep -qE '\.pkg-path = ' "$manifest" \
       && ! grep -qE '\.pkg-group = ' "$manifest"; then
      pgn=false
      note="pkg-path entries without pkg-group"
    fi
  fi
  sh_check_json "pkg-group-named" "$pgn" 10 "$note"

  hic=true; note=""
  if [ -f "$manifest" ] \
     && ! grep -qF '[include]' "$manifest"; then
    hic=false
    note="no [include] comment block in manifest.toml"
  fi
  sh_check_json "has-include-comment" "$hic" 5 "$note"

} | sh_aggregate_quality
