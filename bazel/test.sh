#!/usr/bin/env bash

set -eo pipefail

if ! command -v bazel >/dev/null 2>&1; then
  echo "Error: 'bazel' command not found."
  exit 1
fi

echo ">>> bazel version"
bazel --version

if [ -z "${BAZEL_CACHE_DIR:-}" ]; then
  echo "Error: BAZEL_CACHE_DIR is not exported."
  exit 1
fi

if [ ! -d "$BAZEL_CACHE_DIR" ]; then
  echo "Error: BAZEL_CACHE_DIR '$BAZEL_CACHE_DIR' does not exist."
  exit 1
fi

echo ">>> BAZEL_CACHE_DIR: $BAZEL_CACHE_DIR"
echo ">>> Bazel environment is working"
