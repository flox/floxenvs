#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists sfw
command_exists gum
command_exists node
command_exists npm
command_exists pip
command_exists cargo

# The included flox/sfw env wires its shims; npm/pip/cargo must resolve
# to the shim dir so installs route through sfw transparently.
shim_dir="$FLOX_ENV/libexec/sfw-shims"
for cmd in npm pip cargo; do
  resolved="$(command -v "$cmd")"
  case "$resolved" in
    "$shim_dir/"*)
      echo ">>> '$cmd' routed through sfw shim"
      ;;
    *)
      echo "Error: '$cmd' not routed through sfw shim: $resolved"
      exit 1
      ;;
  esac
done

# Per-env install targets are set so installs land in the cache without
# sudo or polluting $HOME.
for var in NPM_CONFIG_PREFIX CARGO_HOME PIP_TARGET; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var not set by hook."
    exit 1
  fi
  echo ">>> $var=${!var}"
done

echo ">>> sfw-demo environment is working"
