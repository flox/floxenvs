# omlx-demo

Full oMLX demo environment that walks you through
running a local LLM inference server on Apple Silicon.

For a minimal environment to include in your own
project, see [omlx](../omlx/) or use `flox/omlx` on
FloxHub.

**Requires aarch64-darwin (Apple M1+) and macOS 15+.**

## Quick start

```bash
flox activate -r flox/omlx-demo --start-services
```

The activation banner prints connection info and
example commands.

## What this demo includes

- oMLX server with `[mcp,grammar,audio]` extras
- `gum` for styled terminal output
- A startup banner with download and curl examples

## Walkthrough

### 1. Start the server

```bash
flox services start
flox services logs omlx     # follow startup logs
```

The server listens on `http://127.0.0.1:18000` by
default. Override with `OMLX_HOST` and `OMLX_PORT`.

### 2. Download a model

Either via the admin UI at
<http://127.0.0.1:18000/admin>, or via CLI:

```bash
huggingface-cli download \
  mlx-community/Qwen3-1.7B-MLX-4bit \
  --local-dir "$OMLX_MODEL_DIR/Qwen3-1.7B-MLX-4bit"
```

### 3. Test inference

```bash
curl http://127.0.0.1:18000/v1/models

curl http://127.0.0.1:18000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwen3-1.7B-MLX-4bit",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

## Connecting other tools

oMLX exposes an OpenAI-compatible API, so any client
that accepts a custom `OPENAI_BASE_URL` works. For
example:

```bash
export OPENAI_BASE_URL=http://127.0.0.1:18000/v1
export OPENAI_API_KEY=anything
```

Works with the `openai` Python SDK, Claude Code,
`opencode`, `codex`, and other OpenAI-compatible
clients.

## Service management

```bash
flox services start      # start omlx
flox services stop       # stop
flox services status     # status
flox services logs omlx  # logs
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/omlx"]
```

oMLX upstream: <https://github.com/jundot/omlx>
