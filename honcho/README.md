# Honcho

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhoncho%2Fdevcontainer.json)

Self-hostable [Honcho](https://github.com/plastic-labs/honcho)
environment — memory infrastructure for stateful agents. Ships the
FastAPI server, the background `deriver` worker, the
`honcho-ai` Python SDK, and local PostgreSQL (with pgvector) +
Redis wired up as flox services.

## Quick start

Include in your manifest:

```toml
[include]
environments = [{ remote = "flox/honcho" }]
```

Then activate and start the services:

```bash
flox activate --start-services
```

The Honcho API listens on `http://127.0.0.1:18000` and `/health`
returns 200 once it's ready. The Python SDK is importable
straight away:

```python
from honcho import Honcho
honcho = Honcho(
    workspace_id="my-app",
    base_url="http://127.0.0.1:18000",
    api_key="local-dev",
)
```

## What it provides

| Binary           | What it does                                   |
| ---------------- | ---------------------------------------------- |
| `honcho-server`  | Runs the FastAPI app via uvicorn               |
| `honcho-deriver` | Runs the background reasoning worker           |
| `honcho-migrate` | Runs `alembic upgrade head` against the DB     |
| `psql`           | PostgreSQL CLI                                 |
| `redis-cli`      | Redis CLI                                      |

Plus the `honcho-ai` Python SDK in the bundled venv —
`from honcho import Honcho` works without `pip install`.

## Services

| Service          | What it does                                   |
| ---------------- | ---------------------------------------------- |
| `postgres`       | Local PostgreSQL with pgvector extension       |
| `redis`          | Local Redis cache                              |
| `honcho-api`     | The FastAPI server on `$HONCHO_PORT`           |
| `honcho-deriver` | Background worker that builds peer reps        |

Start all four with `flox activate --start-services` or
selectively via `flox services start <name>`.

## Configuration

| Variable                | Default                            | Purpose                                |
| ----------------------- | ---------------------------------- | -------------------------------------- |
| `HONCHO_HOST`           | `127.0.0.1`                        | API bind host                          |
| `HONCHO_PORT`           | `18000`                            | API port (ADR-003 `1`-prefixed)        |
| `HONCHO_URL`            | `http://127.0.0.1:18000`           | Convenience for SDK clients            |
| `PGPORT`                | `15432`                            | PostgreSQL TCP port                    |
| `PGUSER` / `PGPASS`     | `honcho` / `honcho`                | DB credentials (trust auth, localhost) |
| `PGDATABASE`            | `honcho`                           | Database name                          |
| `REDIS_PORT`            | `16379`                            | Redis port                             |
| `AUTH_USE_AUTH`         | `false`                            | Disable JWT auth (local dev)           |
| `DB_CONNECTION_URI`     | derived                            | `postgresql+psycopg://...`             |
| `CACHE_URL`             | derived                            | `redis://...`                          |

Honcho's reasoning endpoints (chat, representations) need at
least one LLM provider key. Set whichever you have:

```bash
export LLM_OPENAI_API_KEY=sk-...
# or LLM_ANTHROPIC_API_KEY, LLM_GEMINI_API_KEY
```

Storage endpoints (workspaces, peers, sessions, messages,
`/health`) work without an LLM key.

See [Honcho's configuration reference][cfg] for the full set
of env vars and TOML sections.

[cfg]: https://github.com/plastic-labs/honcho#configuration

## How data is stored

All state lives under `$FLOX_ENV_CACHE/honcho/`:

- `pgdata/` — PostgreSQL cluster (initialized + migrated on
  first activate)
- `redis/` — Redis dump
- `logs/init.log` — only present if first-time init failed

`flox delete` wipes the cache.

## See also

- [honcho-demo](../honcho-demo/) — interactive demo with a
  sample `quickstart.py` that exercises the Store →
  Reason → Query → Inject loop
- [Honcho upstream](https://github.com/plastic-labs/honcho)
- [Honcho docs](https://honcho.dev/docs/)
