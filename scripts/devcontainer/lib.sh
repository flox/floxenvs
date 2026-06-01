# shellcheck shell=bash
# Helpers used by generate.sh. Source, do not execute.

# Read the pinned flox version from flake.nix. Accepts either
# a tag ref (`refs/tags/vX.Y.Z`) or a release branch ref
# (`release-X.Y.Z`) — release PRs may land before the tag is
# published. Always emits `vX.Y.Z`.
flox_pinned_version() {
  local flake="${1:-flake.nix}"
  grep -oE '(refs/tags/v|release-)[0-9]+\.[0-9]+\.[0-9]+' "$flake" \
    | head -1 \
    | sed -E 's|^(refs/tags/v\|release-)|v|'
}

# Convert a TOML file to JSON on stdout via yj. yj is
# expected on PATH (provided by the nix flake app).
toml_to_json() {
  local toml="$1"
  if [ ! -f "$toml" ]; then
    echo '{}'
    return 0
  fi
  yj -tj < "$toml"
}

# Extract a string field from an overlay JSON, falling
# back to a default. Usage: overlay_str <json> <path> <default>
overlay_str() {
  local json="$1" path="$2" default="$3"
  printf '%s' "$json" | jq -r --arg d "$default" \
    "$path // \$d"
}

# Extract an integer field with default.
overlay_int() {
  local json="$1" path="$2" default="$3"
  printf '%s' "$json" | jq -r --argjson d "$default" \
    "$path // \$d"
}

# Extract a JSON array fragment with default.
overlay_array() {
  local json="$1" path="$2" default="$3"
  printf '%s' "$json" | jq -c --argjson d "$default" \
    "$path // \$d"
}

# Should this env be skipped? Combines the explicit
# `skip = true` overlay with auto-detection of envs that
# have no Linux system support.
should_skip() {
  local overlay_json="$1" lock="$2"
  local explicit
  explicit="$(printf '%s' "$overlay_json" \
    | jq -r '.skip // false')"
  if [ "$explicit" = "true" ]; then
    echo "explicit"
    return 0
  fi
  # Auto-skip if no Linux system in the lockfile.
  local linux
  linux="$(jq -r '
    .manifest.options.systems // []
    | if length == 0 then "true"
      else (any(. == "x86_64-linux" or . == "aarch64-linux"))
           | tostring
      end
  ' "$lock")"
  if [ "$linux" != "true" ]; then
    echo "no-linux"
    return 0
  fi
  echo ""
}

# Render an extensions JSON array. Always includes
# "flox.flox"; merges in extras from the overlay.
render_extensions() {
  local overlay_json="$1"
  printf '%s' "$overlay_json" | jq -c '
    ["flox.flox"]
    + ((.vscode.extensions // []) | unique)
    | unique
  '
}

# Render forwardPorts as a JSON array of ints.
render_forward_ports() {
  local overlay_json="$1"
  printf '%s' "$overlay_json" | jq -c '
    [(.ports // [])[].port]
  '
}

# Render portsAttributes as a JSON object keyed by port.
render_ports_attributes() {
  local overlay_json="$1"
  printf '%s' "$overlay_json" | jq -c '
    (.ports // []) | map({
      key: (.port | tostring),
      value: {
        label: (.label // ""),
        visibility: (.visibility // "private")
      }
    }) | from_entries
  '
}
