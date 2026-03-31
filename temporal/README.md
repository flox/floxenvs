# temporal

Temporal dev server with SQLite storage and built-in
Web UI. Uses `temporal-cli` which bundles the server,
UI, and CLI in a single package. No external
dependencies required.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/temporal"]
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

## See Also

- [temporal-demo](../temporal-demo) -- demo environment
  with a sample workflow and worker
