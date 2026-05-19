#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists fnox
command_exists age
command_exists gum

if [ -z "${FNOX_AGE_KEY:-}" ]; then
  echo "Error: FNOX_AGE_KEY not set by hook."
  exit 1
fi
echo ">>> FNOX_AGE_KEY is set"

# 1. Encrypted secret round-trips through age.
url=$(fnox get DEMO_DATABASE_URL)
if [ "$url" != "postgresql://demo:password@localhost:5432/mydb" ]; then
  echo "Error: DEMO_DATABASE_URL decrypted to unexpected value: '$url'"
  exit 1
fi
echo ">>> DEMO_DATABASE_URL decrypted: $url"

# 2. Plain defaults resolve.
port=$(fnox get DEMO_APP_PORT)
if [ "$port" != "3000" ]; then
  echo "Error: DEMO_APP_PORT was '$port', expected '3000'"
  exit 1
fi
echo ">>> DEMO_APP_PORT default: $port"

# 3. fnox exec injects everything into the env.
# shellcheck disable=SC2016
out=$(fnox exec -- sh -c \
  'echo "$DEMO_DATABASE_URL|$DEMO_APP_PORT|$DEMO_NODE_ENV"')
if [ "$out" != "postgresql://demo:password@localhost:5432/mydb|3000|development" ]; then
  echo "Error: fnox exec output unexpected: '$out'"
  exit 1
fi
echo ">>> fnox exec injected all secrets"

# 4. Command lease mints fresh credentials each call.
lease=$(fnox lease create greeting --format env 2>/dev/null)
if ! echo "$lease" | grep -q "DEMO_GREETING_TOKEN=demo-token-"; then
  echo "Error: command lease did not mint a token:"
  echo "$lease"
  exit 1
fi
echo ">>> command lease minted a token"

echo ">>> fnox-demo environment is working"
