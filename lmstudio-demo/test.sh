#!/usr/bin/env bash

set -eo pipefail
export LMS_SKIP_GPU_CHECK=1

if ! command -v lms >/dev/null 2>&1; then
  echo "Error: 'lms' command not found."
  exit 1
fi
echo ">>> lms ... OK"

if ! command -v gum >/dev/null 2>&1; then
  echo "Error: 'gum' command not found."
  exit 1
fi
echo ">>> gum ... OK"

echo ">>> lmstudio-demo environment is working"
