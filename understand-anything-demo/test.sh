#!/usr/bin/env bash

set -eo pipefail

# Inherited from the understand-anything base env.
for cmd in claude flox-ai node pnpm python3 git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
done
echo ">>> base commands present"

# Demo-only addition.
if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' command not found."
  exit 1
fi
echo ">>> gum present"

# UA_PREBUILD must be set so the activation hook builds
# packages/core upfront. Without it the demo banner's
# promise of an instant /understand is misleading.
if [ "${UA_PREBUILD:-0}" != "1" ]; then
  echo "Error: UA_PREBUILD=$UA_PREBUILD (expected '1')"
  exit 1
fi
echo ">>> UA_PREBUILD=1"

# Pre-build should have produced packages/core/dist/.
dist="$FLOX_ENV_CACHE/understand-anything/repo/understand-anything-plugin/packages/core/dist/index.js"
if [ ! -f "$dist" ]; then
  echo "Error: packages/core/dist/index.js missing — pre-build failed"
  exit 1
fi
echo ">>> packages/core/dist/index.js built"

echo ">>> understand-anything-demo environment is working"
