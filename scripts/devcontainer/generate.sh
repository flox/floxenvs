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

  local display_name cpus memory storage
  display_name="$(overlay_str "$overlay_json" \
    '."display-name"' "$env_dir")"
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

  # Build the devcontainer.json with jq. Using jq -n with
  # --arg/--argjson handles JSON encoding for all values
  # safely (no sed escaping concerns). The shape mirrors
  # .devcontainer/scripts/template.json — keep them in sync.
  jq -n \
    --arg display_name "$display_name" \
    --arg flox_version "$FLOX_VERSION" \
    --arg env_dir "$env_dir" \
    --argjson cpus "$cpus" \
    --arg memory "$memory" \
    --arg storage "$storage" \
    --argjson forward_ports "$forward_ports" \
    --argjson ports_attributes "$ports_attributes" \
    --argjson extensions "$extensions" \
    '{
      name: $display_name,
      image: ("ghcr.io/flox/flox:" + $flox_version),
      workspaceFolder: ("/workspaces/floxenvs/" + $env_dir),
      runArgs: ["--security-opt", "seccomp=unconfined"],
      hostRequirements: {
        cpus: $cpus,
        memory: $memory,
        storage: $storage
      },
      mounts: ["source=floxenvs-nix-store,target=/nix,type=volume"],
      forwardPorts: $forward_ports,
      portsAttributes: $ports_attributes,
      containerEnv: { FLOX_DISABLE_METRICS: "true" },
      customizations: { vscode: { extensions: $extensions } },
      postCreateCommand: ("bash /workspaces/floxenvs/.devcontainer/scripts/post-create.sh " + $env_dir),
      postStartCommand: ("bash /workspaces/floxenvs/.devcontainer/scripts/post-start.sh " + $env_dir),
      remoteUser: "root"
    }' > "$out"

  echo "  wrote $out"
}

# For now, render a single hardcoded env. Iteration comes
# in a later task.
render_one "postgresql-demo"

echo "Done."
