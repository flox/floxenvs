#!/usr/bin/env bash
#
# Discover flox environments and produce CI matrix JSON.
#
# No dependencies beyond coreutils, git, jq (all present on
# ubuntu-latest). Replaces yq-based TOML parsing that broke
# on manifests containing comments.
#
# Environment variables (inputs):
#   BASE_SHA    - git diff base (default: HEAD~1)
#   UPDATE_ALL  - set to "true" to include all envs
#   GITHUB_OUTPUT - if set, write CI outputs there
#
# Usage:
#   bash scripts/discover-envs.sh            # JSON matrices
#   bash scripts/discover-envs.sh --list     # table view
#   bash scripts/discover-envs.sh --validate # check manifests
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ── TOML helpers ────────────────────────────────────────────

# Check if manifest has real (uncommented) service commands.
has_services() {
  local manifest="$1"
  # Match lines like: name.command = "..." that are NOT comments
  grep -qE '^[^#]*\.command[[:space:]]*=' "$manifest"
}

# Extract systems list from [options] section.
# Handles both single-line and multi-line arrays.
# Returns empty string if no systems found.
get_systems() {
  local manifest="$1"
  local raw
  raw="$(sed -n '/^\[options\]/,/^\[/p' "$manifest")" || true
  if [ -z "$raw" ]; then
    return 0
  fi
  echo "$raw" \
    | sed -n '/^systems[[:space:]]*=/,/\]/p' \
    | { grep -oE '"[^"]+"' || true; } \
    | tr -d '"'
}

# ── Environment discovery ──────────────────────────────────

find_manifests() {
  find "$REPO_ROOT" -maxdepth 4 -path '*/.flox/env/manifest.toml' \
    -not -path '*/_worktrees/*' \
    -not -path '*/remote/*' \
    -not -path '*/.git/*' \
    | sort
}

# Resolve manifest path to the env directory (two levels up
# from .flox/env/manifest.toml).
manifest_to_env() {
  local manifest="$1"
  dirname "$(dirname "$(dirname "$manifest")")"
}

# ── Modes ──────────────────────────────────────────────────

mode_validate() {
  local errors=0
  while IFS= read -r manifest; do
    local env_path
    env_path="$(manifest_to_env "$manifest")"
    local name
    name="$(basename "$env_path")"

    local systems
    systems="$(get_systems "$manifest")"
    if [ -z "$systems" ]; then
      echo "WARN: $name - no systems found (skipped in CI)"
      continue
    fi

    local svc="false"
    if has_services "$manifest"; then
      svc="true"
    fi

    echo "OK:   $name  systems=$(echo "$systems" | tr '\n' ',' | sed 's/,$//')  services=$svc"
  done < <(find_manifests)

  if [ "$errors" -gt 0 ]; then
    echo ""
    echo "$errors manifest(s) failed validation"
    exit 1
  fi
  echo ""
  echo "All manifests valid."
}

mode_list() {
  printf "%-25s %-8s %-40s\n" "ENVIRONMENT" "SERVICES" "SYSTEMS"
  printf "%-25s %-8s %-40s\n" "-----------" "--------" "-------"
  while IFS= read -r manifest; do
    local env_path
    env_path="$(manifest_to_env "$manifest")"
    local name
    name="$(basename "$env_path")"

    local svc="no"
    if has_services "$manifest"; then
      svc="yes"
    fi

    local systems
    systems="$(get_systems "$manifest" | tr '\n' ',' | sed 's/,$//')"

    printf "%-25s %-8s %-40s\n" "$name" "$svc" "$systems"
  done < <(find_manifests)
}

mode_discover() {
  local base_sha="${BASE_SHA:-HEAD~1}"
  local update_all="${UPDATE_ALL:-}"

  # Check for major changes that force full rebuild
  if [ -z "$update_all" ]; then
    if git -C "$REPO_ROOT" diff --name-only "$base_sha" HEAD -- \
        | grep -qE 'flake\.nix|flake\.lock|\.github'; then
      echo "detected major change" >&2
      update_all=true
    fi
  fi

  local envs_per_system=()
  local envs_only=()

  while IFS= read -r manifest; do
    local env_path
    env_path="$(manifest_to_env "$manifest")"
    local name
    name="$(basename "$env_path")"
    local rel_env_path
    rel_env_path="${env_path#"$REPO_ROOT"/}"

    echo "env_path=$env_path" >&2
    echo "rel_env_path=$rel_env_path" >&2

    # Include env if: (has test.sh AND update_all) OR git changed
    local include=false
    if [ -f "$env_path/test.sh" ] && [ "$update_all" = "true" ]; then
      include=true
    elif git -C "$REPO_ROOT" diff --name-only "$base_sha" HEAD \
        | grep -q "$rel_env_path/"; then
      include=true
    fi

    if [ "$include" = "true" ]; then
      local start_services="false"
      if has_services "$manifest"; then
        start_services="true"
      fi

      local systems
      systems="$(get_systems "$manifest")"

      while IFS= read -r sys; do
        [ -z "$sys" ] && continue
        envs_per_system+=("{\"example\":\"$name\",\"system\":\"$sys\",\"start_services\":$start_services}")
      done <<< "$systems"

      envs_only+=("\"$name\"")
    fi
  done < <(find_manifests)

  # Build JSON arrays
  local per_system_json
  per_system_json="[$(IFS=,; echo "${envs_per_system[*]:-}")]"
  local only_json
  only_json="[$(IFS=,; echo "${envs_only[*]:-}")]"

  echo "-- envs_per_system ---------" >&2
  echo "$per_system_json" | jq . >&2
  echo "----------------------------" >&2

  echo "-- envs_only ---------------" >&2
  echo "$only_json" | jq . >&2
  echo "----------------------------" >&2

  # Output for CI or stdout
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "envs_per_system=$per_system_json" >> "$GITHUB_OUTPUT"
    echo "envs_only=$only_json" >> "$GITHUB_OUTPUT"
  else
    echo "envs_per_system=$per_system_json"
    echo "envs_only=$only_json"
  fi
}

# ── Main ───────────────────────────────────────────────────

case "${1:-}" in
  --validate) mode_validate ;;
  --list)     mode_list ;;
  *)          mode_discover ;;
esac
