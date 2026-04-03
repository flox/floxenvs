#!/usr/bin/env bash

set -eo pipefail

if ! command -v ruby >/dev/null 2>&1; then
  echo "Error: 'ruby' command not found."
  exit 1
fi
if ! command -v bundle >/dev/null 2>&1; then
  echo "Error: 'bundle' command not found."
  exit 1
fi

echo ">>> ruby version: $(ruby --version)"
echo ">>> bundler version: $(bundle --version)"

echo ">>> ruby environment is working"
