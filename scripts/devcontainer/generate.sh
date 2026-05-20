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

# Escape characters that have meaning on the replacement side of `sed s|||`:
# backslash, ampersand, and the delimiter `|` itself.
sed_escape() {
  printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}

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

  # Escape sed metacharacters in all substitution values.
  local display_name_esc cpus_esc memory_esc storage_esc env_dir_esc
  local flox_version_esc forward_ports_esc ports_attributes_esc
  local extensions_esc
  display_name_esc="$(sed_escape "$display_name")"
  cpus_esc="$(sed_escape "$cpus")"
  memory_esc="$(sed_escape "$memory")"
  storage_esc="$(sed_escape "$storage")"
  env_dir_esc="$(sed_escape "$env_dir")"
  flox_version_esc="$(sed_escape "$FLOX_VERSION")"
  forward_ports_esc="$(sed_escape "$forward_ports")"
  ports_attributes_esc="$(sed_escape "$ports_attributes")"
  extensions_esc="$(sed_escape "$extensions")"

  local out="$OUT_DIR/$env_dir/devcontainer.json"
  mkdir -p "$(dirname "$out")"

  # Note: sed delimiters use | because paths contain /.
  # All values are escaped to prevent metacharacters from breaking substitution.
  sed \
    -e "s|__DISPLAY_NAME__|$display_name_esc|g" \
    -e "s|__FLOX_VERSION__|$flox_version_esc|g" \
    -e "s|__ENV_DIR__|$env_dir_esc|g" \
    -e "s|__CPUS__|$cpus_esc|g" \
    -e "s|__MEMORY__|$memory_esc|g" \
    -e "s|__STORAGE__|$storage_esc|g" \
    -e "s|__FORWARD_PORTS__|$forward_ports_esc|g" \
    -e "s|__PORTS_ATTRIBUTES__|$ports_attributes_esc|g" \
    -e "s|__EXTENSIONS__|$extensions_esc|g" \
    "$TEMPLATE" \
    | jq . > "$out"

  echo "  wrote $out"
}

# For now, render a single hardcoded env. Iteration comes
# in a later task.
render_one "postgresql-demo"

echo "Done."
