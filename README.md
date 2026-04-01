# Example Flox Environments

A collection of ready-to-use
[Flox](https://flox.dev) environments.

## Dual-layer pattern

Most environments follow a dual-layer pattern:

- `<name>/` -- minimal base layer for `[include]`
  composition
- `<name>-demo/` -- demo with gum UI and sample
  project files

Include a minimal layer in your own manifest:

```toml
[include]
environments = ["flox/<name>"]
```

## Docker images

Each environment is also published as a Docker image
to the GitHub Container Registry:

```bash
docker pull ghcr.io/flox/floxenvs:<name>-latest
docker run -it ghcr.io/flox/floxenvs:<name>-latest
```

Browse all images at
[ghcr.io/flox/floxenvs](https://github.com/flox/floxenvs/pkgs/container/floxenvs).

## Environments

### Languages

| Environment | Demo | Description |
| ----------- | ---- | ----------- |
| [go](https://hub.flox.dev/flox/go) | [go-demo](https://hub.flox.dev/flox/go-demo) | Go ([docs](go/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-latest)) |
| [python-pip](https://hub.flox.dev/flox/python-pip) | [python-pip-demo](https://hub.flox.dev/flox/python-pip-demo) | Python + pip ([docs](python-pip/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-latest)) |
| [python-poetry](https://hub.flox.dev/flox/python-poetry) | [python-poetry-demo](https://hub.flox.dev/flox/python-poetry-demo) | Python + Poetry ([docs](python-poetry/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-latest)) |
| [python-uv](https://hub.flox.dev/flox/python-uv) | [python-uv-demo](https://hub.flox.dev/flox/python-uv-demo) | Python + uv ([docs](python-uv/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-latest)) |
| [javascript-bun](https://hub.flox.dev/flox/javascript-bun) | | JavaScript with Bun ([docs](javascript-bun/README.md)) |
| [javascript-deno](https://hub.flox.dev/flox/javascript-deno) | | JavaScript with Deno |
| [javascript-node](https://hub.flox.dev/flox/javascript-node) | | JavaScript with Node/NPM |
| [ruby](https://hub.flox.dev/flox/ruby) | | Ruby ([docs](ruby/README.md)) |
| [rust](https://hub.flox.dev/flox/rust) | [rust-demo](https://hub.flox.dev/flox/rust-demo) | Rust ([docs](rust/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-latest)) |

### Databases & Services

| Environment | Demo | Description |
| ----------- | ---- | ----------- |
| [postgresql](https://hub.flox.dev/flox/postgresql) | [postgresql-demo](https://hub.flox.dev/flox/postgresql-demo) | PostgreSQL ([docs](postgresql/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-latest)) |
| [mysql](https://hub.flox.dev/flox/mysql) | [mysql-demo](https://hub.flox.dev/flox/mysql-demo) | MySQL ([docs](mysql/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-latest)) |
| [mariadb](https://hub.flox.dev/flox/mariadb) | [mariadb-demo](https://hub.flox.dev/flox/mariadb-demo) | MariaDB ([docs](mariadb/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-latest)) |
| [mongodb](https://hub.flox.dev/flox/mongodb) | [mongodb-demo](https://hub.flox.dev/flox/mongodb-demo) | MongoDB ([docs](mongodb/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-latest)) |
| [redis](https://hub.flox.dev/flox/redis) | [redis-demo](https://hub.flox.dev/flox/redis-demo) | Redis ([docs](redis/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-latest)) |
| [valkey](https://hub.flox.dev/flox/valkey) | [valkey-demo](https://hub.flox.dev/flox/valkey-demo) | Valkey ([docs](valkey/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-latest)) |
| [cassandra](https://hub.flox.dev/flox/cassandra) | [cassandra-demo](https://hub.flox.dev/flox/cassandra-demo) | Apache Cassandra ([docs](cassandra/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-latest)) |
| [temporal](https://hub.flox.dev/flox/temporal) | [temporal-demo](https://hub.flox.dev/flox/temporal-demo) | Temporal ([docs](temporal/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-latest)) |

### Tools & Applications

| Environment | Demo | Description |
| ----------- | ---- | ----------- |
| [1password](https://hub.flox.dev/flox/1password) | | 1Password CLI helper |
| [colima](https://hub.flox.dev/flox/colima) | [colima-demo](https://hub.flox.dev/flox/colima-demo) | Docker via Colima ([docs](colima/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-latest)) |
| [dotenv](https://hub.flox.dev/flox/dotenv) | | Load `.env` variables |
| [langchain](https://hub.flox.dev/flox/langchain) | | LangChain AI framework |
| [localstack](https://hub.flox.dev/flox/localstack) | | Local AWS services |
| [mkcert](https://hub.flox.dev/flox/mkcert) | | Local TLS certificates |
| [nginx](https://hub.flox.dev/flox/nginx) | [nginx-demo](https://hub.flox.dev/flox/nginx-demo) | Nginx ([docs](nginx/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-latest)) |
| [podman](https://hub.flox.dev/flox/podman) | | Podman containers |
| [ComfyUI](https://hub.flox.dev/flox/ComfyUI) | | ComfyUI for Stable Diffusion |
| [verba](https://hub.flox.dev/flox/verba) | | Verba RAG application |
