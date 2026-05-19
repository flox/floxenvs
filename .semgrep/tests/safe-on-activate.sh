#!/usr/bin/env bash
# Fixture for the negative case — no rule should fire.
set -euo pipefail
mkdir -p "${FLOX_ENV_CACHE}/postgres"
exec "${POSTGRES_BIN}" -D "${FLOX_ENV_CACHE}/postgres"
