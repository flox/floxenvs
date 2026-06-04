# Example Flox Environments

A collection of ready-to-use [Flox](https://flox.dev)
environments.

## Quick start

Include any environment in your manifest:

```toml
[include]
environments = [{ remote = "flox/<name>" }]
```

Or run as a Docker container:

```bash
docker run -it ghcr.io/flox/floxenvs:<name>-latest
```

## Open in Codespaces

Every environment is available as a one-click GitHub
Codespace. Two variants:

- **`<name>-demo`** — the full demo with sample data,
  services started, and a gum welcome.
- **`<name>`** — the minimal base environment, for
  hacking on the manifest itself.

First Codespace boot is slower (downloads packages into
a persistent `/nix` volume); subsequent boots reuse the
cache.

**Note:** Codespaces in enterprise GitHub orgs that
restrict `seccomp=unconfined` will fail to start the
container.

## Dual-layer pattern

Most environments follow a dual-layer pattern:

- **`<name>/`** — minimal base layer for `[include]`
- **`<name>-demo/`** — demo with gum UI and sample
  project files

## Languages

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| go | Go | [floxhub](https://hub.flox.dev/flox/go) · [docs](go/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgo%2Fdevcontainer.json) |
| _└ go-demo_ | | [floxhub](https://hub.flox.dev/flox/go-demo) · [docs](go-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/go-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgo-demo%2Fdevcontainer.json) |
| python-pip | Python + pip | [floxhub](https://hub.flox.dev/flox/python-pip) · [docs](python-pip/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-pip%2Fdevcontainer.json) |
| _└ python-pip-demo_ | | [floxhub](https://hub.flox.dev/flox/python-pip-demo) · [docs](python-pip-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-pip-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-pip-demo%2Fdevcontainer.json) |
| python-poetry | Python + Poetry | [floxhub](https://hub.flox.dev/flox/python-poetry) · [docs](python-poetry/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-poetry%2Fdevcontainer.json) |
| _└ python-poetry-demo_ | | [floxhub](https://hub.flox.dev/flox/python-poetry-demo) · [docs](python-poetry-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-poetry-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-poetry-demo%2Fdevcontainer.json) |
| python-uv | Python + uv | [floxhub](https://hub.flox.dev/flox/python-uv) · [docs](python-uv/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-uv%2Fdevcontainer.json) |
| _└ python-uv-demo_ | | [floxhub](https://hub.flox.dev/flox/python-uv-demo) · [docs](python-uv-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/python-uv-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpython-uv-demo%2Fdevcontainer.json) |
| javascript-node | Node.js + npm | [floxhub](https://hub.flox.dev/flox/javascript-node) · [docs](javascript-node/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-node-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-node%2Fdevcontainer.json) |
| _└ javascript-node-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-node-demo) · [docs](javascript-node-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-node-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-node-demo%2Fdevcontainer.json) |
| javascript-bun | Bun | [floxhub](https://hub.flox.dev/flox/javascript-bun) · [docs](javascript-bun/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-bun-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-bun%2Fdevcontainer.json) |
| _└ javascript-bun-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-bun-demo) · [docs](javascript-bun-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-bun-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-bun-demo%2Fdevcontainer.json) |
| javascript-deno | Deno | [floxhub](https://hub.flox.dev/flox/javascript-deno) · [docs](javascript-deno/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-deno-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-deno%2Fdevcontainer.json) |
| _└ javascript-deno-demo_ | | [floxhub](https://hub.flox.dev/flox/javascript-deno-demo) · [docs](javascript-deno-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/javascript-deno-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fjavascript-deno-demo%2Fdevcontainer.json) |
| ruby | Ruby + Bundler | [floxhub](https://hub.flox.dev/flox/ruby) · [docs](ruby/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/ruby-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fruby%2Fdevcontainer.json) |
| _└ ruby-demo_ | | [floxhub](https://hub.flox.dev/flox/ruby-demo) · [docs](ruby-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/ruby-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fruby-demo%2Fdevcontainer.json) |
| rust | Rust + Cargo | [floxhub](https://hub.flox.dev/flox/rust) · [docs](rust/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Frust%2Fdevcontainer.json) |
| _└ rust-demo_ | | [floxhub](https://hub.flox.dev/flox/rust-demo) · [docs](rust-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/rust-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Frust-demo%2Fdevcontainer.json) |

## Databases & Services

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| postgresql | PostgreSQL | [floxhub](https://hub.flox.dev/flox/postgresql) · [docs](postgresql/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpostgresql%2Fdevcontainer.json) |
| _└ postgresql-demo_ | | [floxhub](https://hub.flox.dev/flox/postgresql-demo) · [docs](postgresql-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/postgresql-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fpostgresql-demo%2Fdevcontainer.json) |
| mysql | MySQL | [floxhub](https://hub.flox.dev/flox/mysql) · [docs](mysql/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmysql%2Fdevcontainer.json) |
| _└ mysql-demo_ | | [floxhub](https://hub.flox.dev/flox/mysql-demo) · [docs](mysql-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mysql-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmysql-demo%2Fdevcontainer.json) |
| mariadb | MariaDB | [floxhub](https://hub.flox.dev/flox/mariadb) · [docs](mariadb/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmariadb%2Fdevcontainer.json) |
| _└ mariadb-demo_ | | [floxhub](https://hub.flox.dev/flox/mariadb-demo) · [docs](mariadb-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mariadb-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmariadb-demo%2Fdevcontainer.json) |
| mongodb | MongoDB | [floxhub](https://hub.flox.dev/flox/mongodb) · [docs](mongodb/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmongodb%2Fdevcontainer.json) |
| _└ mongodb-demo_ | | [floxhub](https://hub.flox.dev/flox/mongodb-demo) · [docs](mongodb-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mongodb-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmongodb-demo%2Fdevcontainer.json) |
| redis | Redis | [floxhub](https://hub.flox.dev/flox/redis) · [docs](redis/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fredis%2Fdevcontainer.json) |
| _└ redis-demo_ | | [floxhub](https://hub.flox.dev/flox/redis-demo) · [docs](redis-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/redis-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fredis-demo%2Fdevcontainer.json) |
| valkey | Valkey | [floxhub](https://hub.flox.dev/flox/valkey) · [docs](valkey/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fvalkey%2Fdevcontainer.json) |
| _└ valkey-demo_ | | [floxhub](https://hub.flox.dev/flox/valkey-demo) · [docs](valkey-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/valkey-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fvalkey-demo%2Fdevcontainer.json) |
| cassandra | Apache Cassandra | [floxhub](https://hub.flox.dev/flox/cassandra) · [docs](cassandra/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fcassandra%2Fdevcontainer.json) |
| _└ cassandra-demo_ | | [floxhub](https://hub.flox.dev/flox/cassandra-demo) · [docs](cassandra-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/cassandra-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fcassandra-demo%2Fdevcontainer.json) |
| temporal | Temporal | [floxhub](https://hub.flox.dev/flox/temporal) · [docs](temporal/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ftemporal%2Fdevcontainer.json) |
| _└ temporal-demo_ | | [floxhub](https://hub.flox.dev/flox/temporal-demo) · [docs](temporal-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/temporal-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ftemporal-demo%2Fdevcontainer.json) |

## Tools & Applications

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| bazel | Bazel build system | [floxhub](https://hub.flox.dev/flox/bazel) · [docs](bazel/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/bazel-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fbazel%2Fdevcontainer.json) |
| _└ bazel-demo_ | | [floxhub](https://hub.flox.dev/flox/bazel-demo) · [docs](bazel-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/bazel-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fbazel-demo%2Fdevcontainer.json) |
| colima | Docker via Colima | [floxhub](https://hub.flox.dev/flox/colima) · [docs](colima/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-latest) |
| _└ colima-demo_ | | [floxhub](https://hub.flox.dev/flox/colima-demo) · [docs](colima-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/colima-demo-latest) |
| nginx | Nginx | [floxhub](https://hub.flox.dev/flox/nginx) · [docs](nginx/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fnginx%2Fdevcontainer.json) |
| _└ nginx-demo_ | | [floxhub](https://hub.flox.dev/flox/nginx-demo) · [docs](nginx-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/nginx-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fnginx-demo%2Fdevcontainer.json) |
| podman | Podman | [floxhub](https://hub.flox.dev/flox/podman) · [docs](podman/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/podman-latest) |
| _└ podman-demo_ | | [floxhub](https://hub.flox.dev/flox/podman-demo) · [docs](podman-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/podman-demo-latest) |
| localstack | Local AWS | [floxhub](https://hub.flox.dev/flox/localstack) · [docs](localstack/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/localstack-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flocalstack%2Fdevcontainer.json) |
| _└ localstack-demo_ | | [floxhub](https://hub.flox.dev/flox/localstack-demo) · [docs](localstack-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/localstack-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flocalstack-demo%2Fdevcontainer.json) |
| 1password | 1Password CLI | [floxhub](https://hub.flox.dev/flox/1password) · [docs](1password/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/1password-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2F1password%2Fdevcontainer.json) |
| _└ 1password-demo_ | | [floxhub](https://hub.flox.dev/flox/1password-demo) · [docs](1password-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/1password-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2F1password-demo%2Fdevcontainer.json) |
| dotenv | Load `.env` vars | [floxhub](https://hub.flox.dev/flox/dotenv) · [docs](dotenv/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/dotenv-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fdotenv%2Fdevcontainer.json) |
| _└ dotenv-demo_ | | [floxhub](https://hub.flox.dev/flox/dotenv-demo) · [docs](dotenv-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/dotenv-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fdotenv-demo%2Fdevcontainer.json) |
| fnox | Secrets manager (age / KMS / Vault / 1Password / ...) | [floxhub](https://hub.flox.dev/flox/fnox) · [docs](fnox/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/fnox-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ffnox%2Fdevcontainer.json) |
| _└ fnox-demo_ | | [floxhub](https://hub.flox.dev/flox/fnox-demo) · [docs](fnox-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/fnox-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ffnox-demo%2Fdevcontainer.json) |
| sfw | Supply-chain firewall for npm / pip / cargo | [floxhub](https://hub.flox.dev/flox/sfw) · [docs](sfw/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/sfw-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsfw%2Fdevcontainer.json) |
| _└ sfw-demo_ | | [floxhub](https://hub.flox.dev/flox/sfw-demo) · [docs](sfw-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/sfw-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsfw-demo%2Fdevcontainer.json) |
| mkcert | Local TLS certs | [floxhub](https://hub.flox.dev/flox/mkcert) · [docs](mkcert/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mkcert-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmkcert%2Fdevcontainer.json) |
| _└ mkcert-demo_ | | [floxhub](https://hub.flox.dev/flox/mkcert-demo) · [docs](mkcert-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/mkcert-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmkcert-demo%2Fdevcontainer.json) |
| playwright | Browser automation + MCP | [floxhub](https://hub.flox.dev/flox/playwright) · [docs](playwright/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/playwright-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fplaywright%2Fdevcontainer.json) |
| _└ playwright-demo_ | | [floxhub](https://hub.flox.dev/flox/playwright-demo) · [docs](playwright-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/playwright-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fplaywright-demo%2Fdevcontainer.json) |
| worktrunk | Git worktree manager for AI agents | [floxhub](https://hub.flox.dev/flox/worktrunk) · [docs](worktrunk/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/worktrunk-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fworktrunk%2Fdevcontainer.json) |
| _└ worktrunk-demo_ | | [floxhub](https://hub.flox.dev/flox/worktrunk-demo) · [docs](worktrunk-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/worktrunk-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fworktrunk-demo%2Fdevcontainer.json) |

## AI & ML

| Environment | Description | Links |
| ----------- | ----------- | ----- |
| basic-memory | Local-first knowledge graph + MCP server | [floxhub](https://hub.flox.dev/flox/basic-memory) · [docs](basic-memory/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/basic-memory-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fbasic-memory%2Fdevcontainer.json) |
| _└ basic-memory-demo_ | | [floxhub](https://hub.flox.dev/flox/basic-memory-demo) · [docs](basic-memory-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/basic-memory-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fbasic-memory-demo%2Fdevcontainer.json) |
| huggingface | Hugging Face Hub CLI | [floxhub](https://hub.flox.dev/flox/huggingface) · [docs](huggingface/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/huggingface-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhuggingface%2Fdevcontainer.json) |
| _└ huggingface-demo_ | | [floxhub](https://hub.flox.dev/flox/huggingface-demo) · [docs](huggingface-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/huggingface-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhuggingface-demo%2Fdevcontainer.json) |
| graphify | Knowledge-graph skill for Claude Code | [floxhub](https://hub.flox.dev/flox/graphify) · [docs](graphify/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/graphify-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgraphify%2Fdevcontainer.json) |
| _└ graphify-demo_ | | [floxhub](https://hub.flox.dev/flox/graphify-demo) · [docs](graphify-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/graphify-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgraphify-demo%2Fdevcontainer.json) |
| understand-anything | Codebase knowledge graph plugin for Claude Code | [floxhub](https://hub.flox.dev/flox/understand-anything) · [docs](understand-anything/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/understand-anything-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Funderstand-anything%2Fdevcontainer.json) |
| _└ understand-anything-demo_ | | [floxhub](https://hub.flox.dev/flox/understand-anything-demo) · [docs](understand-anything-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/understand-anything-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Funderstand-anything-demo%2Fdevcontainer.json) |
| agentmemory | Persistent memory plugin for Claude Code | [floxhub](https://hub.flox.dev/flox/agentmemory) · [docs](agentmemory/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/agentmemory-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fagentmemory%2Fdevcontainer.json) |
| _└ agentmemory-demo_ | | [floxhub](https://hub.flox.dev/flox/agentmemory-demo) · [docs](agentmemory-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/agentmemory-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fagentmemory-demo%2Fdevcontainer.json) |
| honcho | Self-hostable memory server + SDK for stateful agents | [floxhub](https://hub.flox.dev/flox/honcho) · [docs](honcho/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/honcho-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhoncho%2Fdevcontainer.json) |
| _└ honcho-demo_ | | [floxhub](https://hub.flox.dev/flox/honcho-demo) · [docs](honcho-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/honcho-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhoncho-demo%2Fdevcontainer.json) |
| gstack | Garry Tan's Claude Code stack | [floxhub](https://hub.flox.dev/flox/gstack) · [docs](gstack/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/gstack-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgstack%2Fdevcontainer.json) |
| _└ gstack-demo_ | | [floxhub](https://hub.flox.dev/flox/gstack-demo) · [docs](gstack-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/gstack-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgstack-demo%2Fdevcontainer.json) |
| remotion | Remotion video skill for Claude Code | [floxhub](https://hub.flox.dev/flox/remotion) · [docs](remotion/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/remotion-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fremotion%2Fdevcontainer.json) |
| _└ remotion-demo_ | | [floxhub](https://hub.flox.dev/flox/remotion-demo) · [docs](remotion-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/remotion-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fremotion-demo%2Fdevcontainer.json) |
| langchain | LangChain + Ollama | [floxhub](https://hub.flox.dev/flox/langchain) · [docs](langchain/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/langchain-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flangchain%2Fdevcontainer.json) |
| _└ langchain-demo_ | | [floxhub](https://hub.flox.dev/flox/langchain-demo) · [docs](langchain-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/langchain-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flangchain-demo%2Fdevcontainer.json) |
| verba | Verba RAG app | [floxhub](https://hub.flox.dev/flox/verba) · [docs](verba/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/verba-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fverba%2Fdevcontainer.json) |
| _└ verba-demo_ | | [floxhub](https://hub.flox.dev/flox/verba-demo) · [docs](verba-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/verba-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fverba-demo%2Fdevcontainer.json) |
| symphony | OpenAI Symphony orchestrator | [floxhub](https://hub.flox.dev/flox/symphony) · [docs](symphony/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/symphony-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsymphony%2Fdevcontainer.json) |
| _└ symphony-demo_ | | [floxhub](https://hub.flox.dev/flox/symphony-demo) · [docs](symphony-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/symphony-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsymphony-demo%2Fdevcontainer.json) |
| omlx | oMLX LLM server (Apple Silicon) | [floxhub](https://hub.flox.dev/flox/omlx) · [docs](omlx/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/omlx-latest) |
| _└ omlx-demo_ | | [floxhub](https://hub.flox.dev/flox/omlx-demo) · [docs](omlx-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/omlx-demo-latest) |
| sana | NVIDIA SANA text-to-image inference | [floxhub](https://hub.flox.dev/flox/sana) · [docs](sana/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/sana-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsana%2Fdevcontainer.json) |
| _└ sana-demo_ | | [floxhub](https://hub.flox.dev/flox/sana-demo) · [docs](sana-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/sana-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fsana-demo%2Fdevcontainer.json) |
| lmstudio | LM Studio local LLM + OpenAI API | [floxhub](https://hub.flox.dev/flox/lmstudio) · [docs](lmstudio/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/lmstudio-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flmstudio%2Fdevcontainer.json) |
| _└ lmstudio-demo_ | | [floxhub](https://hub.flox.dev/flox/lmstudio-demo) · [docs](lmstudio-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/lmstudio-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flmstudio-demo%2Fdevcontainer.json) |
| vibe-kanban | Kanban for coding agents | [floxhub](https://hub.flox.dev/flox/vibe-kanban) · [docs](vibe-kanban/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/vibe-kanban-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fvibe-kanban%2Fdevcontainer.json) |
| _└ vibe-kanban-demo_ | | [floxhub](https://hub.flox.dev/flox/vibe-kanban-demo) · [docs](vibe-kanban-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/vibe-kanban-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fvibe-kanban-demo%2Fdevcontainer.json) |
| serena | MCP toolkit for coding agents | [floxhub](https://hub.flox.dev/flox/serena) · [docs](serena/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/serena-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fserena%2Fdevcontainer.json) |
| _└ serena-demo_ | | [floxhub](https://hub.flox.dev/flox/serena-demo) · [docs](serena-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/serena-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fserena-demo%2Fdevcontainer.json) |
| hermes | Self-improving AI agent (Nous Research) | [floxhub](https://hub.flox.dev/flox/hermes) · [docs](hermes/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/hermes-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhermes%2Fdevcontainer.json) |
| _└ hermes-demo_ | | [floxhub](https://hub.flox.dev/flox/hermes-demo) · [docs](hermes-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/hermes-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhermes-demo%2Fdevcontainer.json) |
| codeburn | AI coding token observability TUI | [floxhub](https://hub.flox.dev/flox/codeburn) · [docs](codeburn/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/codeburn-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fcodeburn%2Fdevcontainer.json) |
| _└ codeburn-demo_ | | [floxhub](https://hub.flox.dev/flox/codeburn-demo) · [docs](codeburn-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/codeburn-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fcodeburn-demo%2Fdevcontainer.json) |
| iloom | AI-assisted dev in isolated worktrees | [floxhub](https://hub.flox.dev/flox/iloom) · [docs](iloom/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/iloom-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Filoom%2Fdevcontainer.json) |
| _└ iloom-demo_ | | [floxhub](https://hub.flox.dev/flox/iloom-demo) · [docs](iloom-demo/README.md) · [docker](https://github.com/flox/floxenvs/pkgs/container/floxenvs/iloom-demo-latest) · [codespace](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Filoom-demo%2Fdevcontainer.json) |

## Docker images

All environments are published to GHCR. Browse at
[ghcr.io/flox/floxenvs](https://github.com/flox/floxenvs/pkgs/container/floxenvs).
