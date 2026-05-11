# huggingface

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
environments = ["flox/huggingface"]
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
