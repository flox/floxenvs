# huggingface-demo

Interactive demo for the
[Hugging Face Hub](https://huggingface.co/) CLI. Adds
[`gum`](https://github.com/charmbracelet/gum) on top of
the minimal [huggingface](../huggingface/) environment so
the activation hook prints a styled cheat sheet.

## Quick start

```bash
flox activate -r flox/huggingface-demo
```

## Walkthrough

### 1. Authenticate (optional, only needed for private
repos or higher rate limits)

```bash
hf auth login
```

You will be prompted for a token from
<https://huggingface.co/settings/tokens>.

### 2. Download a public file

```bash
hf download hf-internal-testing/tiny-random-gpt2 \
  config.json
```

Files land under `$HF_HOME` (defaults to
`$FLOX_ENV_CACHE/huggingface` inside this environment),
keyed by repo and revision.

### 3. Inspect the cache

```bash
hf cache scan
```

### 4. Upload a file (requires authentication)

```bash
hf upload <your-username>/<repo> ./path/to/file
```

## What is included

| Package | Description |
| ------- | ----------- |
| `hf` | Main Hugging Face Hub CLI |
| `huggingface-cli` | Legacy alias kept for compatibility |
| `tiny-agents` | Minimal agent runtime |
| `gum` | Styled terminal UI (demo only) |

## See also

- [huggingface](../huggingface/) — minimal layer for
  `[include]` composition
- [Hub docs](https://huggingface.co/docs/huggingface_hub)
