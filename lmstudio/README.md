# lmstudio

Minimal LM Studio environment. LM Studio is a desktop +
CLI tool for running local LLMs and exposing them via
an OpenAI-compatible API.

**Requires a Metal-capable GPU (macOS) or a CUDA / Vulkan-
capable discrete GPU (Linux).** LM Studio's `lms` binary
hard-exits at startup on systems without one. Set
`LMS_SKIP_GPU_CHECK=1` to bypass the check (useful for
CI / install-only flows; the API server itself still
needs a GPU to serve models).

**Platforms:** aarch64-darwin (Apple Silicon),
aarch64-linux, x86_64-linux. LM Studio does not ship
an Intel-Mac build.

## Quick start

Activate directly:

```bash
flox activate -r flox/lmstudio --start-services
```

The headless API server comes up on
`http://127.0.0.1:11234/v1`.

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/lmstudio"]
```

## What is included

| Command | Description |
| ------- | ----------- |
| `lms` | LM Studio CLI (load / serve / get / chat). |
| `lm-studio` | LM Studio GUI launcher. |
| `lms-service` | Headless API-server launcher. |
| `lmstudio-health` | Probe `/v1/models`; report loaded models. |
| `lms-launch` | Run claude / codex / opencode against local API. |
| `lmstudio-info` | Print current configuration. |

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `LMS_HOST` | `127.0.0.1` | API bind address. |
| `LMS_PORT` | `11234` | API listen port. |
| `LMS_CONTEXT_LENGTH` | `131072` | Context window for `lms load`. |
| `LMS_LOG_DIR` | `$FLOX_ENV_CACHE/lmstudio/logs` | Log directory. |
| `LMS_CORS` | unset | `1` enables `--cors` for browser clients. |
| `LMS_SKIP_GPU_CHECK` | unset | Bypass GPU-presence check. |

Override any of these in your own manifest before
`[include]`-ing this environment.

## Services

LM Studio runs as a background service on `LMS_PORT`:

```bash
flox services start         # start lmstudio
flox services stop          # stop
flox services status        # status
flox services logs lmstudio # view logs
```

The server exposes an OpenAI-compatible API at
`http://${LMS_HOST}:${LMS_PORT}/v1`.

Test the API:

```bash
lmstudio-health
curl http://${LMS_HOST}:${LMS_PORT}/v1/models
```

## Models

Download and load with `lms`:

```bash
lms get qwen2.5-7b-instruct
lms load qwen2.5-7b-instruct --context-length 65536
lms ls
```

## Composing with agentic CLIs

`lms-launch` runs claude / codex / opencode against the
local model. The agent CLI itself isn't bundled here —
compose with another env:

```toml
[include]
environments = [
  "flox/lmstudio",
  "flox/claude-code"
]
```

Then:

```bash
flox activate --start-services
lms-launch claude --model qwen2.5-7b-instruct
```

## See also

For a styled terminal walkthrough, see
[lmstudio-demo](../lmstudio-demo/).

LM Studio upstream: <https://lmstudio.ai/>
