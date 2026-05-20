#!/usr/bin/env bash
# Shared default quality checks for envs and packages.
#
# Source from a metrics.sh:
#   . "$REPO_ROOT/scripts/lib/metrics-defaults.sh"
#   default_env_checks "$name" "$dir"
#   default_pkg_checks "$name" "$dir"
#
# Output: a JSON quality section to stdout (the same
# shape used by metrics.sh — { score, checks: [...] }).

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$LIB_DIR/sh-helpers.sh"

# Current schema version we accept as "current".
EXPECTED_SCHEMA_VERSION="1.10.0"

# ── env defaults ─────────────────────────────────────────
#
# Args: <name> <dir>
default_env_checks() {
  local _name="$1" dir="$2"
  local manifest="$dir/.flox/env/manifest.toml"
  local meta="$dir/meta.yaml"

  {
    sh_check_json "has-readme" \
      "$([ -f "$dir/README.md" ] && echo true || echo false)" 5

    sh_check_json "has-test-sh" \
      "$([ -f "$dir/test.sh" ] && echo true || echo false)" 10

    local sv=false
    if [ -f "$manifest" ] && grep -q \
         "^schema-version = \"${EXPECTED_SCHEMA_VERSION}\"$" \
         "$manifest"; then
      sv=true
    fi
    sh_check_json "schema-version-current" "$sv" 5

    local has_inc=false
    if [ -f "$manifest" ] && grep -qF '[include]' "$manifest"; then
      has_inc=true
    fi
    sh_check_json "has-include-comment" "$has_inc" 5

    # silent hook = on-activate body has no echo/print.
    local silent=true note=""
    if [ -f "$manifest" ]; then
      if awk '
        /^on-activate = '"'"''"'"''"'"'/,/^'"'"''"'"''"'"'/ {
          if (/echo|printf/) { found=1 }
        }
        END { exit found ? 0 : 1 }
      ' "$manifest"; then
        silent=false
        note="echo or printf found in on-activate"
      fi
    fi
    sh_check_json "silent-hook" "$silent" 10 "$note"

    local fec=true
    if [ -f "$manifest" ] \
       && grep -q '^on-activate' "$manifest" \
       && ! grep -q 'FLOX_ENV_CACHE' "$manifest"; then
      fec=false
    fi
    sh_check_json "uses-flox-env-cache" "$fec" 10

    local pgn=true
    if [ -f "$manifest" ]; then
      if grep -qE '\.pkg-path = ' "$manifest" \
         && ! grep -qE '\.pkg-group = ' "$manifest"; then
        pgn=false
      fi
    fi
    sh_check_json "pkg-group-named" "$pgn" 5

    sh_check_json "has-demo-variant" \
      "$([ -d "$dir-demo" ] && echo true || echo false)" 5

    sh_check_json "meta-yaml-complete" \
      "$([ -f "$meta" ] && echo true || echo false)" 15
  } | sh_aggregate_quality
}

# ── pkg defaults ─────────────────────────────────────────
#
# Args: <name> <dir>
default_pkg_checks() {
  local _name="$1" dir="$2"
  local pubj="$dir/publish.json"
  local hashes="$dir/hashes.json"
  local upgrade="$dir/upgrade.sh"

  {
    sh_check_json "has-default-nix" \
      "$([ -f "$dir/default.nix" ] && echo true || echo false)" \
      10

    sh_check_json "has-publish-json" \
      "$([ -f "$pubj" ] && echo true || echo false)" 10

    local pv=false
    if [ -f "$pubj" ] && jq -e \
         '.org and (.systems | type == "array")' \
         "$pubj" >/dev/null 2>&1; then
      pv=true
    fi
    sh_check_json "publish-json-valid" "$pv" 5

    local dnp=false
    if [ -f "$dir/default.nix" ] \
       && nix-instantiate --parse "$dir/default.nix" \
            >/dev/null 2>&1; then
      dnp=true
    fi
    sh_check_json "default-nix-parses" "$dnp" 10

    sh_check_json "meta-yaml-complete" \
      "$([ -f "$dir/meta.yaml" ] && echo true || echo false)" 15

    if [ -f "$upgrade" ]; then
      sh_check_json "has-upgrade-sh" true 5
      local sc=true
      if command -v shellcheck >/dev/null 2>&1 \
         && ! shellcheck -S warning "$upgrade" >/dev/null 2>&1; then
        sc=false
      fi
      sh_check_json "upgrade-sh-shellchecked" "$sc" 5
    fi

    if [ -f "$hashes" ]; then
      sh_check_json "has-hashes-json" true 5
      local hf=true note=""
      if ! jq -e '.version' "$hashes" >/dev/null 2>&1; then
        hf=false
        note="hashes.json missing .version"
      fi
      sh_check_json "hashes-json-fresh" "$hf" 5 "$note"
    fi

    if [ -f "$dir/README.md" ]; then
      sh_check_json "has-readme" true 5
    fi
  } | sh_aggregate_quality
}
