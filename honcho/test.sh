#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

command_exists honcho-server
command_exists honcho-deriver
command_exists honcho-migrate
command_exists psql
command_exists pg_isready
command_exists redis-cli
command_exists python

# Honcho-ai SDK must be importable from the bundled venv.
python -c "from honcho import Honcho; print('honcho-ai imported:', Honcho.__module__)"
echo ">>> honcho-ai SDK importable"

# Server module must import too — sanity-check that the
# bundled src/ package loaded all its transitive deps.
python -c "import src.main; print('src.main loaded')"
echo ">>> honcho server module loads"

# Config plumbing: honcho must parse our documented nested env-var
# names. The `__` delimiter spelling is the riskiest assumption in
# this env, so set overrides inline and read them back from the
# resolved settings object (a fresh python process picks up the env).
DERIVER_MODEL_CONFIG__MODEL="probe-deriver-model" \
EMBEDDING_MODEL_CONFIG__MODEL="probe-embed-model" \
LLM_OPENAI_BASE_URL="http://probe.invalid/v1" \
python - <<'PY'
from src.config import settings
assert settings.DERIVER.MODEL_CONFIG.model == "probe-deriver-model", \
    settings.DERIVER.MODEL_CONFIG.model
assert settings.EMBEDDING.MODEL_CONFIG.model == "probe-embed-model", \
    settings.EMBEDDING.MODEL_CONFIG.model
assert settings.LLM.OPENAI_BASE_URL == "http://probe.invalid/v1", \
    settings.LLM.OPENAI_BASE_URL
print("config plumbing ok")
PY
echo ">>> honcho parses nested config env vars"

# On first activate the hook ran initdb, createdb, the
# pgvector CREATE EXTENSION, and `honcho-migrate upgrade head`
# while postgres was up briefly. Bring it back up now to
# verify the schema looks right.
flox services start postgres redis

echo -n "Waiting for PostgreSQL .."
MAX=30
while [[ "$MAX" != "0" ]]; do
  if pg_isready -h "$PGHOSTADDR" -p "$PGPORT" -q 2>/dev/null; then
    echo ""
    break
  fi
  echo -n "."
  sleep 1
  MAX=$((MAX-1))
done
if [[ "$MAX" == "0" ]]; then
  echo ""
  echo "Error: PostgreSQL did not start in time."
  flox services logs postgres | tail -50
  exit 1
fi

echo -n "Waiting for Redis .."
MAX=30
while [[ "$MAX" != "0" ]]; do
  if redis-cli -h "$PGHOSTADDR" -p "$REDIS_PORT" ping 2>/dev/null | grep -q PONG; then
    echo ""
    break
  fi
  echo -n "."
  sleep 1
  MAX=$((MAX-1))
done
if [[ "$MAX" == "0" ]]; then
  echo ""
  echo "Error: Redis did not start in time."
  flox services logs redis | tail -50
  exit 1
fi

# pgvector must be installed.
ext=$(psql -h "$PGHOSTADDR" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc \
  "SELECT extname FROM pg_extension WHERE extname='vector'")
if [ "$ext" != "vector" ]; then
  echo "Error: pgvector extension not installed in $PGDATABASE."
  exit 1
fi
echo ">>> pgvector extension installed"

# Migrations must have created the workspaces table.
tables=$(psql -h "$PGHOSTADDR" -p "$PGPORT" -U "$PGUSER" -d "$PGDATABASE" -tAc \
  "SELECT tablename FROM pg_tables WHERE schemaname='public'" | sort | tr '\n' ',')
echo ">>> public tables: ${tables%,}"
echo "$tables" | grep -q "workspaces" || {
  echo "Error: workspaces table missing — migrations did not run."
  exit 1
}
echo ">>> alembic migrations applied"

# Bring up the API + deriver and confirm /health.
flox services start honcho-api honcho-deriver

echo -n "Waiting for Honcho /health .."
MAX=60
while [[ "$MAX" != "0" ]]; do
  if curl -fsS "$HONCHO_URL/health" >/dev/null 2>&1; then
    echo ""
    break
  fi
  echo -n "."
  sleep 1
  MAX=$((MAX-1))
done
if [[ "$MAX" == "0" ]]; then
  echo ""
  echo "Error: Honcho API did not become healthy."
  flox services logs honcho-api | tail -80
  exit 1
fi

echo ">>> $(curl -fsS "$HONCHO_URL/health")"

flox services status
flox services stop

echo ">>> honcho environment is working"
