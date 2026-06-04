#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# Inherited from the minimal env via [include].
command_exists honcho-server
command_exists honcho-deriver
command_exists honcho-migrate
command_exists psql
command_exists redis-cli
command_exists python
command_exists gum

# quickstart.py must parse and import its top-level deps cleanly.
python -c "import ast; ast.parse(open('quickstart.py').read())"
echo ">>> quickstart.py parses"

python -c "from honcho import Honcho"
echo ">>> honcho-ai SDK importable"

# If the demo env is started with services (start_services: true
# in meta.yaml), exercise the live storage path. Otherwise just
# confirm the SDK can be constructed against a fake URL.
if pg_isready -h "$PGHOSTADDR" -p "$PGPORT" -q 2>/dev/null \
   && curl -fsS "$HONCHO_URL/health" >/dev/null 2>&1; then
  echo ">>> postgres + honcho-api are up — running quickstart storage path"
  python quickstart.py
else
  echo ">>> services not running — skipping live quickstart, doing SDK ctor check"
  python -c "
from honcho import Honcho
h = Honcho(workspace_id='ci-check', base_url='$HONCHO_URL', api_key='local-dev')
print('>>> Honcho client constructed against', h.base_url)
"
fi

echo ">>> honcho-demo environment is working"
