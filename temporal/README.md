# temporal

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ftemporal%2Fdevcontainer.json)

Temporal dev server with SQLite storage and built-in
Web UI. Bundles two Flox-packaged binaries:

- `temporal-cli` (cmd `temporal`) — workflow/namespace
  management plus an embedded dev server with Web UI.
  Drives the `[services]` block below.
- `temporal` server (cmd `temporal-server`, plus
  `temporal-sql-tool`, `temporal-cassandra-tool`,
  `tdbg`) — production binaries for running against
  PostgreSQL/MySQL/Cassandra clusters.

No external dependencies required for dev use.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [{ remote = "flox/temporal" }]
```

Then start the service:

```bash
flox activate
flox services start
```

## Configuration

Override these variables in your manifest as needed:

| Variable | Default | Description |
| -------- | ------- | ----------- |
| TEMPORAL_HOST | 127.0.0.1 | Bind address |
| TEMPORAL_PORT | 7233 | gRPC frontend port |
| TEMPORAL_UI_PORT | 8233 | Web UI port |

## Endpoints

- Web UI: <http://127.0.0.1:8233>
- gRPC (for SDKs): `127.0.0.1:7233`

Connect your Temporal SDK client to the gRPC endpoint:

```python
client = await Client.connect("127.0.0.1:7233")
```

```go
c, err := client.Dial(client.Options{
    HostPort: "127.0.0.1:7233",
})
```

## Production server

For non-dev use, `temporal-server` is available as
well. It speaks the same protocol but needs an
external database. Point it at a config file:

```bash
temporal-server start \
  --config /path/to/config \
  --service frontend,history,matching,worker
```

`temporal-sql-tool` and `temporal-cassandra-tool`
handle schema setup; `tdbg` is the debugger.

## See Also

- [temporal-demo](../temporal-demo) -- demo environment
  with a sample workflow and worker
