# omlx

Minimal oMLX environment. oMLX is an LLM inference
server with continuous batching and tiered KV caching,
optimized for Apple Silicon.

**Requires aarch64-darwin (Apple M1+) and macOS 15+.**

## Quick start

Activate directly:

```bash
flox activate -r flox/omlx --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/omlx"]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `omlx` | oMLX server with `[mcp,grammar,audio]` extras |

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `OMLX_HOST` | `127.0.0.1` | Server bind address |
| `OMLX_PORT` | `18000` | Server port (ADR-003 prefix) |
| `OMLX_MODEL_DIR` | `$FLOX_ENV_CACHE/omlx/models` | MLX model directory |
| `OMLX_DATA_DIR` | `$FLOX_ENV_CACHE/omlx` | State directory |

Override any in your own manifest before
`[include]`-ing this environment.

## Services

oMLX runs as a background service on `OMLX_PORT`:

```bash
flox services start        # start omlx
flox services stop         # stop
flox services status       # status
flox services logs omlx    # view logs
```

The server exposes an OpenAI-compatible API at
`http://${OMLX_HOST}:${OMLX_PORT}/v1` and an admin UI
at `http://${OMLX_HOST}:${OMLX_PORT}/admin`.

## Models

Drop MLX-format models into `$OMLX_MODEL_DIR/`, or
download via the admin UI's model downloader. Example:

```bash
huggingface-cli download \
  mlx-community/Qwen3-1.7B-MLX-4bit \
  --local-dir "$OMLX_MODEL_DIR/Qwen3-1.7B-MLX-4bit"
```

## See also

For a walkthrough with styled terminal output, see
[omlx-demo](../omlx-demo/).

oMLX upstream: <https://github.com/jundot/omlx>
