# Example Flox Environments

A collection of ready-to-use [Flox](https://flox.dev)
environments.

## Quick start

Include any environment in your manifest:

```toml
[include]
environments = ["flox/<name>"]
```

Or run as a Docker container:

```bash
docker run -it ghcr.io/flox/floxenvs:<name>-latest
```

## Dual-layer pattern

Most environments follow a dual-layer pattern:

- **`<name>/`** — minimal base layer for `[include]`
- **`<name>-demo/`** — demo with gum UI and sample
  project files

## Languages

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| go | Go | [floxhub](https://hub.flox.dev/flox/go) [docs](go/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-latest) |
| python-pip | Python + pip | [floxhub](https://hub.flox.dev/flox/python-pip) [docs](python-pip/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-latest) |
| python-poetry | Python + Poetry | [floxhub](https://hub.flox.dev/flox/python-poetry) [docs](python-poetry/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-latest) |
| python-uv | Python + uv | [floxhub](https://hub.flox.dev/flox/python-uv) [docs](python-uv/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-latest) |
| javascript-bun | JavaScript + Bun | [floxhub](https://hub.flox.dev/flox/javascript-bun) [docs](javascript-bun/README.md) |
| javascript-deno | JavaScript + Deno | [floxhub](https://hub.flox.dev/flox/javascript-deno) |
| javascript-node | JavaScript + Node | [floxhub](https://hub.flox.dev/flox/javascript-node) |
| ruby | Ruby | [floxhub](https://hub.flox.dev/flox/ruby) [docs](ruby/README.md) |
| rust | Rust | [floxhub](https://hub.flox.dev/flox/rust) [docs](rust/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-latest) |

## Databases & Services

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| postgresql | PostgreSQL | [floxhub](https://hub.flox.dev/flox/postgresql) [docs](postgresql/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-latest) |
| mysql | MySQL | [floxhub](https://hub.flox.dev/flox/mysql) [docs](mysql/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-latest) |
| mariadb | MariaDB | [floxhub](https://hub.flox.dev/flox/mariadb) [docs](mariadb/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-latest) |
| mongodb | MongoDB | [floxhub](https://hub.flox.dev/flox/mongodb) [docs](mongodb/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-latest) |
| redis | Redis | [floxhub](https://hub.flox.dev/flox/redis) [docs](redis/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-latest) |
| valkey | Valkey | [floxhub](https://hub.flox.dev/flox/valkey) [docs](valkey/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-latest) |
| cassandra | Apache Cassandra | [floxhub](https://hub.flox.dev/flox/cassandra) [docs](cassandra/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-latest) |
| temporal | Temporal | [floxhub](https://hub.flox.dev/flox/temporal) [docs](temporal/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-latest) |

## Tools & Applications

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| colima | Docker via Colima | [floxhub](https://hub.flox.dev/flox/colima) [docs](colima/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-latest) |
| nginx | Nginx | [floxhub](https://hub.flox.dev/flox/nginx) [docs](nginx/README.md) [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-latest) |
| 1password | 1Password CLI | [floxhub](https://hub.flox.dev/flox/1password) |
| dotenv | Load `.env` vars | [floxhub](https://hub.flox.dev/flox/dotenv) |
| langchain | LangChain AI | [floxhub](https://hub.flox.dev/flox/langchain) |
| localstack | Local AWS | [floxhub](https://hub.flox.dev/flox/localstack) |
| mkcert | Local TLS certs | [floxhub](https://hub.flox.dev/flox/mkcert) |
| podman | Podman | [floxhub](https://hub.flox.dev/flox/podman) |
| ComfyUI | Stable Diffusion | [floxhub](https://hub.flox.dev/flox/ComfyUI) |
| verba | Verba RAG | [floxhub](https://hub.flox.dev/flox/verba) |

## Docker images

All dual-layer environments are published to GHCR.
Browse at
[ghcr.io/flox/floxenvs](https://github.com/flox/floxenvs/pkgs/container/floxenvs).
