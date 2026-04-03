# verba

Minimal Verba RAG environment. Include it in your
own manifest to get Weaviate, Ollama, and the Verba
application with sane defaults.

## Quick start

Activate directly:

```bash
flox activate -r flox/verba --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/verba"]
```

Then customize vars in your own manifest to override
defaults.

## What is included

- Python 3.11 with Verba installed in a venv
- Weaviate vector database
- Ollama LLM backend
- Build tools (gcc, pkg-config)

## Services

| Service | Description |
| ------- | ----------- |
| weaviate | Vector database on port 8080 |
| ollama | LLM backend on port 11434 |
| verba | RAG web UI on port 8000 |
| models | Pulls configured Ollama models |

Start all services:

```bash
flox services start
```

## Ollama models

By default the environment pulls two models:

| Variable | Default |
| -------- | ------- |
| `OLLAMA_MODEL` | llama3 |
| `OLLAMA_EMBED_MODEL` | mxbai-embed-large |

Override in your own manifest:

```toml
[vars]
OLLAMA_MODEL = "mistral"
OLLAMA_EMBED_MODEL = "nomic-embed-text"
```

## Environment variables

| Variable | Description |
| -------- | ----------- |
| `WEAVIATE_URL_VERBA` | Weaviate hostname |
| `WEAVIATE_URL_VERBA_full` | Full Weaviate URL |
| `PERSISTENCE_DATA_PATH` | Weaviate data dir |
| `OLLAMA_URL` | Ollama API endpoint |
| `OLLAMA_MODEL` | Chat model name |
| `OLLAMA_EMBED_MODEL` | Embedding model name |

## Data directory

Verba data is stored in `./verba-data` by default.
The Python venv lives in `$FLOX_ENV_CACHE/python`.

To start fresh:

```bash
rm -rf ./verba-data "$FLOX_ENV_CACHE/python"
```

## See also

For a full demo with styled terminal output, see
[verba-demo](../verba-demo/).
