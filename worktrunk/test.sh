#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists wt
command_exists git-wt
command_exists git

echo ">>> wt version: $(wt --version)"
echo ">>> git-wt version: $(git-wt --version)"

if [ -z "${WORKTRUNK_CACHE:-}" ] || [ ! -d "$WORKTRUNK_CACHE" ]; then
  echo "Error: WORKTRUNK_CACHE missing: ${WORKTRUNK_CACHE:-<unset>}"
  exit 1
fi
echo ">>> WORKTRUNK_CACHE=$WORKTRUNK_CACHE"

# Smoke test: create a throwaway repo and run `wt list` against it.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
(
  cd "$tmp"
  git init -q -b main
  git -c user.email=test@flox.dev -c user.name=test \
    commit --allow-empty -q -m "init"
  wt list >/dev/null
)
echo ">>> wt list succeeds against a fresh repo"

echo ">>> worktrunk environment is working"
