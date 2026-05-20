# huggingface

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhuggingface%2Fdevcontainer.json)

Minimal [Hugging Face Hub](https://huggingface.co/) CLI
environment for downloading models, datasets, and Spaces
artifacts.

## Quick start

Activate directly:

```bash
flox activate -r flox/huggingface
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/huggingface" }]
```

## What is included

| Command | Description |
| ------- | ----------- |
| `hf` | Main Hugging Face Hub CLI |
| `huggingface-cli` | Legacy alias kept for compatibility |
| `tiny-agents` | Minimal agent runtime built on `hf` |

## Cache layout

The environment sets `HF_HOME` to
`$FLOX_ENV_CACHE/huggingface` so models and datasets
persist across activations without polluting
`~/.cache/huggingface`. Override `HF_HOME` in your own
manifest to point elsewhere.

## High-performance transfers (opt-in)

The bundled `hf-xet` binary already accelerates every
download via chunk-based deduplication — no flag needed.
For multi-GB models you can additionally saturate
bandwidth and use all CPU cores by setting
`HF_XET_HIGH_PERFORMANCE=1`:

```toml
[vars]
HF_XET_HIGH_PERFORMANCE = "1"
```

Note: the legacy `HF_HUB_ENABLE_HF_TRANSFER=1` is
deprecated in `huggingface_hub` v1.x — `hf-xet` replaced
`hf_transfer` entirely.

## Common commands

```bash
hf auth login                           # store a token
hf download <repo_id> [<filename>]      # fetch files
hf upload   <repo_id> <local_path>      # push files
hf cache scan                           # inspect cache
```

## See also

For an interactive walkthrough, see
[huggingface-demo](../huggingface-demo/).
