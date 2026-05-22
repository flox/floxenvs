# sana-demo

Interactive demo for the [`sana`](../sana/README.md)
environment with a Gradio web UI.

## What's included

- Everything in [`flox/sana`](../sana/README.md):
  `sana-generate`, `sana-pull`, full diffusers stack
- `gum` for the activation banner
- `sana-gradio` service running a web UI on
  `http://127.0.0.1:17860`
- `sample_prompt.txt` to get you started

## Walkthrough

```bash
# 1. Activate
flox activate -r flox/sana-demo

# 2. Pull a model (first run only — about 3 GB)
sana-pull

# 3a. Generate from the CLI
sana-generate "$(cat sample_prompt.txt)" --output sample.png

# 3b. Or start the web UI
flox services start sana-gradio
open http://127.0.0.1:17860
```

## Configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `SANA_GRADIO_HOST` | `127.0.0.1` | bind host |
| `SANA_GRADIO_PORT` | `17860` | bind port |
| `SANA_DEFAULT_MODEL` | see below | model loaded on first request |
| `SANA_SKIP_LOAD` | unset | `=1` starts UI without weights (CI) |

`SANA_DEFAULT_MODEL` full default:
`Efficient-Large-Model/SANA1.5_1.6B_1024px_diffusers`

Variables inherited from
[`flox/sana`](../sana/README.md) (`HF_HOME`,
`SANA_DATA_DIR`) apply here too.

## Performance notes

| System              | Backend           | First request  | Subsequent       |
| ------------------- | ----------------- | -------------- | ---------------- |
| Linux + NVIDIA      | CUDA              | 10-20s (load)  | sub-second/image |
| Linux (no GPU)      | CPU               | minutes (load) | minutes/image    |
| macOS Apple Silicon | CPU (MPS broken)  | minutes (load) | minutes/image    |

The first generation pays a model-load cost. The web
UI loads the model lazily on the first click of
"Generate".

On Mac, MPS currently crashes — set `SANA_FORCE_CPU=1`
before activating to skip the broken MPS path:

```sh
SANA_FORCE_CPU=1 flox activate -r flox/sana-demo
flox services start sana-gradio
```

See [`sana/README.md` known issues](../sana/README.md#known-issues)
for details.

## See also

- Minimal env: [`sana`](../sana/README.md)
- Upstream: <https://github.com/NVlabs/Sana>
