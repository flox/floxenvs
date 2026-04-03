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
| go | Go | [floxhub](https://hub.flox.dev/flox/go) · [docs](go/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-latest) |
| _└ go-demo_ | | [floxhub](https://hub.flox.dev/flox/go-demo) · [docs](go-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-demo-latest) |
| python-pip | Python + pip | [floxhub](https://hub.flox.dev/flox/python-pip) · [docs](python-pip/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-latest) |
| _└ python-pip-demo_ | | [floxhub](https://hub.flox.dev/flox/python-pip-demo) · [docs](python-pip-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-demo-latest) |
| python-poetry | Python + Poetry | [floxhub](https://hub.flox.dev/flox/python-poetry) · [docs](python-poetry/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-latest) |
| _└ python-poetry-demo_ | | [floxhub](https://hub.flox.dev/flox/python-poetry-demo) · [docs](python-poetry-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-demo-latest) |
| python-uv | Python + uv | [floxhub](https://hub.flox.dev/flox/python-uv) · [docs](python-uv/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-latest) |
| _└ python-uv-demo_ | | [floxhub](https://hub.flox.dev/flox/python-uv-demo) · [docs](python-uv-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-demo-latest) |
| javascript-node | Node.js + npm | [floxhub](https://hub.flox.dev/flox/javascript-node) · [docs](javascript-node/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-node-latest) |
| _└ javascript-node-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-node-demo) · [docs](javascript-node-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-node-demo-latest) |
| javascript-bun | Bun | [floxhub](https://hub.flox.dev/flox/javascript-bun) · [docs](javascript-bun/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-bun-latest) |
| _└ javascript-bun-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-bun-demo) · [docs](javascript-bun-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-bun-demo-latest) |
| javascript-deno | Deno | [floxhub](https://hub.flox.dev/flox/javascript-deno) · [docs](javascript-deno/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-deno-latest) |
| _└ javascript-deno-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-deno-demo) · [docs](javascript-deno-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-deno-demo-latest) |
| ruby | Ruby + Bundler | [floxhub](https://hub.flox.dev/flox/ruby) · [docs](ruby/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/ruby-latest) |
| _└ ruby-demo_ | | [floxhub](https://hub.flox.dev/flox/ruby-demo) · [docs](ruby-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/ruby-demo-latest) |
| rust | Rust + Cargo | [floxhub](https://hub.flox.dev/flox/rust) · [docs](rust/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-latest) |
| _└ rust-demo_ | | [floxhub](https://hub.flox.dev/flox/rust-demo) · [docs](rust-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-demo-latest) |

## Databases & Services

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| postgresql | PostgreSQL | [floxhub](https://hub.flox.dev/flox/postgresql) · [docs](postgresql/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-latest) |
| _└ postgresql-demo_ | | [floxhub](https://hub.flox.dev/flox/postgresql-demo) · [docs](postgresql-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-demo-latest) |
| mysql | MySQL | [floxhub](https://hub.flox.dev/flox/mysql) · [docs](mysql/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-latest) |
| _└ mysql-demo_ | | [floxhub](https://hub.flox.dev/flox/mysql-demo) · [docs](mysql-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-demo-latest) |
| mariadb | MariaDB | [floxhub](https://hub.flox.dev/flox/mariadb) · [docs](mariadb/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-latest) |
| _└ mariadb-demo_ | | [floxhub](https://hub.flox.dev/flox/mariadb-demo) · [docs](mariadb-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-demo-latest) |
| mongodb | MongoDB | [floxhub](https://hub.flox.dev/flox/mongodb) · [docs](mongodb/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-latest) |
| _└ mongodb-demo_ | | [floxhub](https://hub.flox.dev/flox/mongodb-demo) · [docs](mongodb-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-demo-latest) |
| redis | Redis | [floxhub](https://hub.flox.dev/flox/redis) · [docs](redis/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-latest) |
| _└ redis-demo_ | | [floxhub](https://hub.flox.dev/flox/redis-demo) · [docs](redis-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-demo-latest) |
| valkey | Valkey | [floxhub](https://hub.flox.dev/flox/valkey) · [docs](valkey/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-latest) |
| _└ valkey-demo_ | | [floxhub](https://hub.flox.dev/flox/valkey-demo) · [docs](valkey-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-demo-latest) |
| cassandra | Apache Cassandra | [floxhub](https://hub.flox.dev/flox/cassandra) · [docs](cassandra/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-latest) |
| _└ cassandra-demo_ | | [floxhub](https://hub.flox.dev/flox/cassandra-demo) · [docs](cassandra-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-demo-latest) |
| temporal | Temporal | [floxhub](https://hub.flox.dev/flox/temporal) · [docs](temporal/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-latest) |
| _└ temporal-demo_ | | [floxhub](https://hub.flox.dev/flox/temporal-demo) · [docs](temporal-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-demo-latest) |

## Tools & Applications

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| colima | Docker via Colima | [floxhub](https://hub.flox.dev/flox/colima) · [docs](colima/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-latest) |
| _└ colima-demo_ | | [floxhub](https://hub.flox.dev/flox/colima-demo) · [docs](colima-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-demo-latest) |
| nginx | Nginx | [floxhub](https://hub.flox.dev/flox/nginx) · [docs](nginx/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-latest) |
| _└ nginx-demo_ | | [floxhub](https://hub.flox.dev/flox/nginx-demo) · [docs](nginx-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-demo-latest) |
| podman | Podman | [floxhub](https://hub.flox.dev/flox/podman) · [docs](podman/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/podman-latest) |
| _└ podman-demo_ | | [floxhub](https://hub.flox.dev/flox/podman-demo) · [docs](podman-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/podman-demo-latest) |
| localstack | Local AWS | [floxhub](https://hub.flox.dev/flox/localstack) · [docs](localstack/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/localstack-latest) |
| _└ localstack-demo_ | | [floxhub](https://hub.flox.dev/flox/localstack-demo) · [docs](localstack-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/localstack-demo-latest) |
| 1password | 1Password CLI | [floxhub](https://hub.flox.dev/flox/1password) · [docs](1password/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/1password-latest) |
| _└ 1password-demo_ | | [floxhub](https://hub.flox.dev/flox/1password-demo) · [docs](1password-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/1password-demo-latest) |
| dotenv | Load `.env` vars | [floxhub](https://hub.flox.dev/flox/dotenv) · [docs](dotenv/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/dotenv-latest) |
| _└ dotenv-demo_ | | [floxhub](https://hub.flox.dev/flox/dotenv-demo) · [docs](dotenv-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/dotenv-demo-latest) |
| mkcert | Local TLS certs | [floxhub](https://hub.flox.dev/flox/mkcert) · [docs](mkcert/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mkcert-latest) |
| _└ mkcert-demo_ | | [floxhub](https://hub.flox.dev/flox/mkcert-demo) · [docs](mkcert-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mkcert-demo-latest) |

## AI & ML

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| langchain | LangChain + Ollama | [floxhub](https://hub.flox.dev/flox/langchain) · [docs](langchain/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/langchain-latest) |
| _└ langchain-demo_ | | [floxhub](https://hub.flox.dev/flox/langchain-demo) · [docs](langchain-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/langchain-demo-latest) |
| verba | Verba RAG app | [floxhub](https://hub.flox.dev/flox/verba) · [docs](verba/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/verba-latest) |
| _└ verba-demo_ | | [floxhub](https://hub.flox.dev/flox/verba-demo) · [docs](verba-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/verba-demo-latest) |

## Docker images

All environments are published to GHCR. Browse at
[ghcr.io/flox/floxenvs](https://github.com/flox/floxenvs/pkgs/container/floxenvs).
