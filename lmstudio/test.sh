#!/usr/bin/env bash

set -eo pipefail

# LM Studio's lms wrapper hard-exits on GPU-less hosts.
export LMS_SKIP_GPU_CHECK=1

for cmd in lms lm-studio lms-service \
           lmstudio-health lms-launch lmstudio-info; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

# On Linux, the lms Bun binary segfaults at startup without a
# supported GPU even when LMS_SKIP_GPU_CHECK=1 bypasses the
# wrapper's pre-flight check. CI builders are GPU-less, so we can
# only invoke the binary on macOS. Linux verifies binary presence
# (above) and lmstudio-info (below); the real `lms` functionality
# is exercised at user activation.
if [[ "$(uname)" == "Darwin" ]]; then
  if ! lms --version >/dev/null 2>&1; then
    echo "Error: 'lms --version' failed."
    exit 1
  fi
  echo ">>> lms --version OK"
else
  echo ">>> lms --version skipped on $(uname) (binary needs a GPU)"
fi

if ! lmstudio-info >/dev/null 2>&1; then
  echo "Error: 'lmstudio-info' failed."
  exit 1
fi
echo ">>> lmstudio-info OK"

echo ">>> lmstudio environment is working"
