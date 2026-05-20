#!/usr/bin/env bash
#
# Generate per-env devcontainer.json files from a template
# and per-env .devcontainer.toml overlays.
#
# Requires: bash, jq, yj.
# Use `nix run .#generate-devcontainers` or
# `just generate-devcontainers` to get the right tools.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

# shellcheck source=scripts/devcontainer/lib.sh disable=SC1091
. "$REPO_ROOT/scripts/devcontainer/lib.sh"

TEMPLATE="$REPO_ROOT/.devcontainer/scripts/template.json"
OUT_DIR="$REPO_ROOT/.devcontainer"

FLOX_VERSION="$(flox_pinned_version flake.nix)"
if [ -z "$FLOX_VERSION" ]; then
  echo "ERROR: could not extract flox version from flake.nix" >&2
  exit 1
fi
echo "Using flox version: $FLOX_VERSION"

# Defaults applied when the overlay omits a field.
DEFAULT_CPUS=4
DEFAULT_MEMORY="8gb"
DEFAULT_STORAGE="32gb"

# Render one devcontainer.json. Arguments:
#   $1 env_dir  e.g. "postgresql-demo"
render_one() {
  local env_dir="$1"
  local overlay_toml="$env_dir/.devcontainer.toml"
  local overlay_json
  overlay_json="$(toml_to_json "$overlay_toml")"

  local display_name
  display_name="$(overlay_str "$overlay_json" \
    '."display-name"' "$env_dir")"

  local cpus memory storage
  cpus="$(overlay_int "$overlay_json" \
    '."host-requirements".cpus' "$DEFAULT_CPUS")"
  memory="$(overlay_str "$overlay_json" \
    '."host-requirements".memory' "$DEFAULT_MEMORY")"
  storage="$(overlay_str "$overlay_json" \
    '."host-requirements".storage' "$DEFAULT_STORAGE")"

  local forward_ports ports_attributes extensions
  forward_ports="$(render_forward_ports "$overlay_json")"
  ports_attributes="$(render_ports_attributes "$overlay_json")"
  extensions="$(render_extensions "$overlay_json")"

  local out="$OUT_DIR/$env_dir/devcontainer.json"
  mkdir -p "$(dirname "$out")"

  # Note: sed delimiters use | because paths contain /.
  sed \
    -e "s|__DISPLAY_NAME__|$display_name|g" \
    -e "s|__FLOX_VERSION__|$FLOX_VERSION|g" \
    -e "s|__ENV_DIR__|$env_dir|g" \
    -e "s|__CPUS__|$cpus|g" \
    -e "s|__MEMORY__|$memory|g" \
    -e "s|__STORAGE__|$storage|g" \
    -e "s|__FORWARD_PORTS__|$forward_ports|g" \
    -e "s|__PORTS_ATTRIBUTES__|$ports_attributes|g" \
    -e "s|__EXTENSIONS__|$extensions|g" \
    "$TEMPLATE" \
    | jq . > "$out"

  echo "  wrote $out"
}

# For now, render a single hardcoded env. Iteration comes
# in a later task.
render_one "postgresql-demo"

echo "Done."
