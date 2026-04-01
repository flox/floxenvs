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

Each dual-layer environment is published as a Docker
image to the GitHub Container Registry:

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
| [go](https://hub.flox.dev/flox/go) ([docs](go/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-latest)) | [go-demo](https://hub.flox.dev/flox/go-demo) ([docs](go-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-demo-latest)) | Go |
| [python-pip](https://hub.flox.dev/flox/python-pip) ([docs](python-pip/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-latest)) | [python-pip-demo](https://hub.flox.dev/flox/python-pip-demo) ([docs](python-pip-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-demo-latest)) | Python + pip |
| [python-poetry](https://hub.flox.dev/flox/python-poetry) ([docs](python-poetry/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-latest)) | [python-poetry-demo](https://hub.flox.dev/flox/python-poetry-demo) ([docs](python-poetry-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-demo-latest)) | Python + Poetry |
| [python-uv](https://hub.flox.dev/flox/python-uv) ([docs](python-uv/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-latest)) | [python-uv-demo](https://hub.flox.dev/flox/python-uv-demo) ([docs](python-uv-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-demo-latest)) | Python + uv |
| [javascript-bun](https://hub.flox.dev/flox/javascript-bun) ([docs](javascript-bun/README.md)) | | JavaScript with Bun |
| [javascript-deno](https://hub.flox.dev/flox/javascript-deno) | | JavaScript with Deno |
| [javascript-node](https://hub.flox.dev/flox/javascript-node) | | JavaScript with Node/NPM |
| [ruby](https://hub.flox.dev/flox/ruby) ([docs](ruby/README.md)) | | Ruby |
| [rust](https://hub.flox.dev/flox/rust) ([docs](rust/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-latest)) | [rust-demo](https://hub.flox.dev/flox/rust-demo) ([docs](rust-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-demo-latest)) | Rust |

### Databases & Services

| Environment | Demo | Description |
| ----------- | ---- | ----------- |
| [postgresql](https://hub.flox.dev/flox/postgresql) ([docs](postgresql/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-latest)) | [postgresql-demo](https://hub.flox.dev/flox/postgresql-demo) ([docs](postgresql-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-demo-latest)) | PostgreSQL |
| [mysql](https://hub.flox.dev/flox/mysql) ([docs](mysql/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-latest)) | [mysql-demo](https://hub.flox.dev/flox/mysql-demo) ([docs](mysql-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-demo-latest)) | MySQL |
| [mariadb](https://hub.flox.dev/flox/mariadb) ([docs](mariadb/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-latest)) | [mariadb-demo](https://hub.flox.dev/flox/mariadb-demo) ([docs](mariadb-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-demo-latest)) | MariaDB |
| [mongodb](https://hub.flox.dev/flox/mongodb) ([docs](mongodb/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-latest)) | [mongodb-demo](https://hub.flox.dev/flox/mongodb-demo) ([docs](mongodb-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-demo-latest)) | MongoDB |
| [redis](https://hub.flox.dev/flox/redis) ([docs](redis/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-latest)) | [redis-demo](https://hub.flox.dev/flox/redis-demo) ([docs](redis-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-demo-latest)) | Redis |
| [valkey](https://hub.flox.dev/flox/valkey) ([docs](valkey/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-latest)) | [valkey-demo](https://hub.flox.dev/flox/valkey-demo) ([docs](valkey-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-demo-latest)) | Valkey |
| [cassandra](https://hub.flox.dev/flox/cassandra) ([docs](cassandra/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-latest)) | [cassandra-demo](https://hub.flox.dev/flox/cassandra-demo) ([docs](cassandra-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-demo-latest)) | Apache Cassandra |
| [temporal](https://hub.flox.dev/flox/temporal) ([docs](temporal/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-latest)) | [temporal-demo](https://hub.flox.dev/flox/temporal-demo) ([docs](temporal-demo/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-demo-latest)) | Temporal |

### Tools & Applications

| Environment | Demo | Description |
| ----------- | ---- | ----------- |
| [1password](https://hub.flox.dev/flox/1password) | | 1Password CLI helper |
| [colima](https://hub.flox.dev/flox/colima) ([docs](colima/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-latest)) | [colima-demo](https://hub.flox.dev/flox/colima-demo) ([container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-demo-latest)) | Docker via Colima |
| [dotenv](https://hub.flox.dev/flox/dotenv) | | Load `.env` variables |
| [langchain](https://hub.flox.dev/flox/langchain) | | LangChain AI framework |
| [localstack](https://hub.flox.dev/flox/localstack) | | Local AWS services |
| [mkcert](https://hub.flox.dev/flox/mkcert) | | Local TLS certificates |
| [nginx](https://hub.flox.dev/flox/nginx) ([docs](nginx/README.md), [container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-latest)) | [nginx-demo](https://hub.flox.dev/flox/nginx-demo) ([container](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-demo-latest)) | Nginx |
| [podman](https://hub.flox.dev/flox/podman) | | Podman containers |
| [ComfyUI](https://hub.flox.dev/flox/ComfyUI) | | ComfyUI for Stable Diffusion |
| [verba](https://hub.flox.dev/flox/verba) | | Verba RAG application |
