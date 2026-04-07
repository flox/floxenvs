#!/usr/bin/env bash
#
# Discover flox environments and produce CI matrix JSON.
#
# Parses manifest.lock (JSON) instead of manifest.toml to
# avoid brittle TOML parsing. Only needs coreutils, git, jq
# (all present on ubuntu-latest).
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

# ── Lock file helpers ─────────────────────────────────────

# Check if environment has services defined in lock file.
has_services() {
  local lock="$1"
  jq -e '.manifest.services // {} | length > 0' "$lock" \
    >/dev/null 2>&1
}

# Extract systems list from lock file (one per line).
# If manifest.options.systems is empty or absent, all
# default systems are assumed (per ADR-004).
# We are skipping x86_64-darwin intentionally since
# we don't have good enough CI for it.
ALL_SYSTEMS="aarch64-darwin
aarch64-linux
x86_64-linux"

get_systems() {
  local lock="$1"
  local systems
  systems="$(jq -r '.manifest.options.systems // [] | map(select(. != "x86_64-darwin")) | .[]' "$lock")"
  if [ -z "$systems" ]; then
    systems="$ALL_SYSTEMS"
  fi
  echo "$systems"
}

# ── Environment discovery ──────────────────────────────────

find_locks() {
  find "$REPO_ROOT" -maxdepth 4 -path '*/.flox/env/manifest.lock' \
    -not -path "$REPO_ROOT/_worktrees/*" \
    -not -path '*/remote/*' \
    -not -path '*/.git/*' \
    | sort
}

is_demo() {
  local name="$1"
  [[ "$name" == *-demo ]]
}

# Resolve lock path to the env directory (two levels up
# from .flox/env/manifest.lock).
lock_to_env() {
  local lock="$1"
  dirname "$(dirname "$(dirname "$lock")")"
}

# ── Modes ──────────────────────────────────────────────────

mode_validate() {
  local warnings=0
  while IFS= read -r lock; do
    local env_path
    env_path="$(lock_to_env "$lock")"
    local name
    name="$(basename "$env_path")"

    if ! jq empty "$lock" 2>/dev/null; then
      echo "FAIL: $name - invalid JSON in manifest.lock"
      warnings=$((warnings + 1))
      continue
    fi

    local systems
    systems="$(get_systems "$lock")"
    if [ -z "$systems" ]; then
      echo "WARN: $name - no systems found (skipped in CI)"
      continue
    fi

    local svc="false"
    if has_services "$lock"; then
      svc="true"
    fi

    echo "OK:   $name  systems=$(echo "$systems" | tr '\n' ',' | sed 's/,$//')  services=$svc"
  done < <(find_locks)

  if [ "$warnings" -gt 0 ]; then
    echo ""
    echo "$warnings lock file(s) have issues"
    exit 1
  fi
  echo ""
  echo "All lock files valid."
}

mode_list() {
  printf "%-25s %-8s %-40s\n" "ENVIRONMENT" "SERVICES" "SYSTEMS"
  printf "%-25s %-8s %-40s\n" "-----------" "--------" "-------"
  while IFS= read -r lock; do
    local env_path
    env_path="$(lock_to_env "$lock")"
    local name
    name="$(basename "$env_path")"

    local svc="no"
    if has_services "$lock"; then
      svc="yes"
    fi

    local systems
    systems="$(get_systems "$lock" | tr '\n' ',' | sed 's/,$//')"

    printf "%-25s %-8s %-40s\n" "$name" "$svc" "$systems"
  done < <(find_locks)
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
  local envs_deploy=()

  while IFS= read -r lock; do
    local env_path
    env_path="$(lock_to_env "$lock")"
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
      if has_services "$lock"; then
        start_services="true"
      fi

      local systems
      systems="$(get_systems "$lock")"

      while IFS= read -r sys; do
        [ -z "$sys" ] && continue
        envs_per_system+=("{\"example\":\"$name\",\"system\":\"$sys\",\"start_services\":$start_services}")
      done <<< "$systems"

      envs_only+=("\"$name\"")

      # Deploy list excludes demo environments
      if ! is_demo "$name"; then
        envs_deploy+=("\"$name\"")
      fi
    fi
  done < <(find_locks)

  # Build JSON arrays
  local per_system_json
  per_system_json="[$(IFS=,; echo "${envs_per_system[*]:-}")]"
  local only_json
  only_json="[$(IFS=,; echo "${envs_only[*]:-}")]"
  local deploy_json
  deploy_json="[$(IFS=,; echo "${envs_deploy[*]:-}")]"

  echo "-- envs_per_system ---------" >&2
  echo "$per_system_json" | jq . >&2
  echo "----------------------------" >&2

  echo "-- envs_only ---------------" >&2
  echo "$only_json" | jq . >&2
  echo "----------------------------" >&2

  echo "-- envs_deploy -------------" >&2
  echo "$deploy_json" | jq . >&2
  echo "----------------------------" >&2

  # Output for CI or stdout
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "envs_per_system=$per_system_json" >> "$GITHUB_OUTPUT"
    echo "envs_only=$only_json" >> "$GITHUB_OUTPUT"
    echo "envs_deploy=$deploy_json" >> "$GITHUB_OUTPUT"
  else
    echo "envs_per_system=$per_system_json"
    echo "envs_only=$only_json"
    echo "envs_deploy=$deploy_json"
  fi
}

mode_update() {
  # Output JSON array of minimal (non-demo) envs with
  # a has_demo flag. Used by update.yml to upgrade env
  # and its demo together.
  local envs=()

  while IFS= read -r lock; do
    local env_path
    env_path="$(lock_to_env "$lock")"
    local name
    name="$(basename "$env_path")"

    # Skip demos — handled with their parent
    if is_demo "$name"; then
      continue
    fi

    local has_demo="false"
    local demo_dir="$REPO_ROOT/${name}-demo"
    if [ -d "$demo_dir/.flox/env" ]; then
      has_demo="true"
    fi

    envs+=("{\"name\":\"$name\",\"has_demo\":$has_demo}")
  done < <(find_locks)

  local json
  json="[$(IFS=,; echo "${envs[*]:-}")]"

  echo "-- update envs -------------" >&2
  echo "$json" | jq . >&2
  echo "----------------------------" >&2

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "envs=$json" >> "$GITHUB_OUTPUT"
  else
    echo "envs=$json"
  fi
}

# ── Main ───────────────────────────────────────────────────

case "${1:-}" in
  --validate) mode_validate ;;
  --list)     mode_list ;;
  --update)   mode_update ;;
  *)          mode_discover ;;
esac
