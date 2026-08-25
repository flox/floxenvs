# Mergekit Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmergekit-demo%2Fdevcontainer.json)

Interactive demo of [Mergekit](https://github.com/arcee-ai/mergekit).
Activating this env writes an `example-merge.yml` that merges two
small Qwen models on CPU — a complete model merge on a laptop, no
GPU required.

## What you get

- All `mergekit-*` entry points from the [mergekit](../mergekit/)
  env
- A pre-written `example-merge.yml` (linear merge of
  `Qwen/Qwen2.5-0.5B` and its Instruct variant)

## Try it

```console
$ flox activate
$ mergekit-yaml example-merge.yml ./merged-model
```

The two source models (~1GB total) download from the Hugging Face
Hub on first run; the merged model lands in `./merged-model`.

## Next steps

Swap the models or the `merge_method` (`slerp`, `ties`,
`dare_ties`, ...) in `example-merge.yml` — see the
[merge configuration docs](https://github.com/arcee-ai/mergekit#merge-configuration)
for the full option set.
