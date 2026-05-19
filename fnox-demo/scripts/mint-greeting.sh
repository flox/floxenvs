#!/usr/bin/env bash
# Demo "credential minting" script for fnox's command lease.
#
# fnox passes us FNOX_LEASE_DURATION (seconds) and FNOX_LEASE_LABEL.
# We must print a JSON document on stdout with a `credentials`
# map; everything in that map becomes an env var when the lease
# is activated via `fnox lease create`.
#
# Replace this script with anything that produces a credential:
#   - `op item get` to pull from 1Password
#   - `gh auth token` to mint a GitHub token
#   - `curl` against your internal API
#   - signing a JWT with a CA key
#   - reading from macOS Keychain via `security find-generic-password`

set -euo pipefail

duration="${FNOX_LEASE_DURATION:-300}"
label="${FNOX_LEASE_LABEL:-fnox-lease}"

# Build a fake token + expiry to show the shape of a real lease.
token="demo-token-$(date +%s)-${RANDOM}"
expires_at=$(date -u -v+"${duration}"S +"%Y-%m-%dT%H:%M:%SZ" \
  2>/dev/null \
  || date -u -d "@$(($(date +%s) + duration))" \
       +"%Y-%m-%dT%H:%M:%SZ")

cat <<EOF
{
  "credentials": {
    "DEMO_GREETING_TOKEN": "$token",
    "DEMO_GREETING_LABEL": "$label"
  },
  "expires_at": "$expires_at",
  "lease_id": "greeting-$(date +%s%N)"
}
EOF
