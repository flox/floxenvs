#!/usr/bin/env bash

set -eo pipefail

if ! command -v bazel >/dev/null 2>&1; then
  echo "Error: 'bazel' command not found."
  exit 1
fi

echo ">>> bazel version"
bazel --version

echo ">>> flox build hello"
flox build hello

if [ ! -x "./result-hello/bin/hello" ]; then
  echo "Error: ./result-hello/bin/hello not found or not executable"
  exit 1
fi

echo ">>> Running built binary"
OUT=$(./result-hello/bin/hello)
echo "$OUT"

EXPECTED="Hello from Bazel + Go + Flox!"
if [ "$OUT" != "$EXPECTED" ]; then
  echo "Error: expected '$EXPECTED', got '$OUT'"
  exit 1
fi

echo ">>> flox build ... OK"

# Clean up build symlinks; bazel-* and result-* are
# created next to the source tree and would otherwise
# leak into the committed repo.
rm -rf result-hello bazel-bin bazel-out bazel-testlogs \
       bazel-bazel-demo bazel-"$(basename "$PWD")"
