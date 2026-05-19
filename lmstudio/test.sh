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

if ! lms --version >/dev/null 2>&1; then
  echo "Error: 'lms --version' failed."
  exit 1
fi
echo ">>> lms --version OK"

if ! lmstudio-info >/dev/null 2>&1; then
  echo "Error: 'lmstudio-info' failed."
  exit 1
fi
echo ">>> lmstudio-info OK"

echo ">>> lmstudio environment is working"
