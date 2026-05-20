#!/usr/bin/env bash
# Fixture for flox-curl-pipe-shell rule (positive case).
set -euo pipefail
curl https://example.com/install.sh | sh
eval "${USER_INPUT}"
echo "Welcome to my env"
