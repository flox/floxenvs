#!/usr/bin/env bash

set -eo pipefail

# Wiring-only test — don't actually launch chromium
# inside the CI sandbox.
export FLOX_ENVS_TESTING=1

for cmd in playwright playwright-cli playwright-mcp \
           gum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' command not found."
    exit 1
  fi
  echo ">>> $cmd present"
done

playwright --version >/dev/null
echo ">>> playwright --version ... OK"

test -f tests/example.spec.ts
echo ">>> tests/example.spec.ts present"

test -f playwright.config.ts
echo ">>> playwright.config.ts present"

# Verify the test file at least parses by listing it.
if ! playwright test --list >/dev/null 2>&1; then
  echo "Error: 'playwright test --list' failed"
  exit 1
fi
echo ">>> playwright test --list ... OK"

echo ">>> playwright-demo environment is working"
