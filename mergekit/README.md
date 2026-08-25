# Mergekit

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmergekit%2Fdevcontainer.json)

Ready-to-use [Mergekit](https://github.com/arcee-ai/mergekit)
environment — Arcee's toolkit for merging pre-trained large
language models. Merges run lazily on CPU, so no GPU is needed.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/mergekit"]
```

## What it provides

- `mergekit-yaml` — run a merge from a YAML config
- `mergekit-moe` — build Mixture-of-Experts models
- `mergekit-extract-lora` — extract a LoRA from a fine-tune
- `mergekit-tokensurgeon`, `mergekit-evolve`, `bakllama`, and
  the other upstream entry points

## Usage

Write a merge config and run it:

```yaml
# merge.yml
models:
  - model: Qwen/Qwen2.5-0.5B
  - model: Qwen/Qwen2.5-0.5B-Instruct
merge_method: linear
dtype: float16
```

```console
$ mergekit-yaml merge.yml ./merged-model
```

Models are pulled from the Hugging Face Hub into `HF_HOME`
(default: `~/.cache/huggingface`).

## Systems

`aarch64-darwin`, `aarch64-linux`, `x86_64-linux`. torch ships
no `x86_64-darwin` wheels since 2.3, so that platform is
excluded. Linux builds use CPU-only torch wheels to keep the
closure small.
