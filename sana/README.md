# sana

Run NVIDIA SANA text-to-image on macOS and Linux —
no conda, no manual pip installs, no CUDA toolkit
required.

## What you get

- `sana-generate` — single-image text-to-image CLI
- `sana-pull` — download a SANA model into `HF_HOME`
- Python 3.12 with `diffusers`, `transformers`,
  `torch`, `accelerate`, `sentencepiece`, `pillow`
  pre-installed
- HuggingFace cache rooted at
  `$FLOX_ENV_CACHE/huggingface` (inherited from
  [`flox/huggingface`](../huggingface/README.md))

## Include in your own environment

```toml
[include]
environments = ["flox/sana"]
```

## Quick start

```bash
flox activate -r flox/sana

# First run only — downloads ~3 GB
sana-pull

# Generate
sana-generate "a cyberpunk cat with a neon sign that says Sana" \
  --output cat.png
```

## CLI reference

### `sana-generate`

```text
sana-generate PROMPT
  [--model MODEL_ID]
  [--output PATH]
  [--width N] [--height N]
  [--steps N] [--guidance F]
  [--seed N]
```

Defaults: 1024×1024, 20 steps, guidance 4.5, output
`sana-<unixtime>.png`. Device auto-selected: CUDA →
MPS → CPU.

### `sana-pull`

```text
sana-pull             # pull the default model
sana-pull MODEL_ID    # pull a specific model
sana-pull --list      # print curated model IDs
```

## Available models

`sana-pull --list` knows about these curated SANA
diffusers checkpoints:

| Model ID | Size | Resolution |
| -------- | ---- | ---------- |
| `Efficient-Large-Model/Sana_600M_1024px_diffusers` | ~1.2 GB | 1024 |
| `Efficient-Large-Model/SANA1.5_1.6B_1024px_diffusers` | ~3.2 GB | 1024 (default) |
| `Efficient-Large-Model/Sana_1600M_2Kpx_BF16_diffusers` | ~3.2 GB | 2048 |
| `Efficient-Large-Model/Sana_1600M_4Kpx_BF16_diffusers` | ~3.2 GB | 4096 |

Any HuggingFace `SanaPipeline`-compatible model ID
also works — pass it to `sana-pull MODEL_ID` or
`sana-generate --model MODEL_ID`.

## Configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `SANA_DEFAULT_MODEL` | see manifest | default model for `sana-generate` |
| `SANA_DATA_DIR` | `$FLOX_ENV_CACHE/sana` | per-env data + script staging |
| `HF_HOME` | `$FLOX_ENV_CACHE/huggingface` | model cache (inherited) |

## Backend support

| System | Backend | Speed for 1024px |
| ------ | ------- | ---------------- |
| `aarch64-darwin` (M-series, 16 GB+) | MPS (bfloat16) | seconds |
| `x86_64-linux` with NVIDIA + drivers | CUDA (bfloat16) | seconds |
| `x86_64-linux` or `aarch64-linux` CPU-only | CPU (float32) | minutes |

CPU inference works but is slow. For real-time use,
prefer Apple Silicon or NVIDIA hardware.

## What's not included

This env packages **inference only** via `diffusers`.
The following are out of scope and require the
upstream NVlabs/Sana conda environment:

- Training pipelines
- `flash-attn`, `xformers`, `triton` custom kernels
- 4-bit / 8-bit quantization (Nunchaku, bitsandbytes)
- SANA-Video, SANA-Sprint, SANA-WM pipelines
- ControlNet variants

## See also

- Demo with web UI: [sana-demo](../sana-demo/README.md)
- Upstream: <https://github.com/NVlabs/Sana>
- SANA on HuggingFace:
  <https://huggingface.co/collections/Efficient-Large-Model/sana>
