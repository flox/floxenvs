# langchain

Minimal LangChain environment with Ollama. Include it
in your own manifest to get LangGraph, LangChain-Ollama,
LangChain-Community, and an Ollama service.

## Quick start

Activate directly:

```bash
flox activate -r flox/langchain --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/langchain"]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `langgraph` | LangGraph orchestration framework |
| `langchain-ollama` | Ollama integration for LangChain |
| `langchain-community` | Community integrations |
| `ollama` | Local LLM runtime |

## Services

Ollama runs as a background service:

```bash
flox services start          # start ollama
flox services stop           # stop ollama
flox services status         # check status
flox services logs ollama    # view logs
```

## See also

For a full walkthrough with styled terminal output, see
[langchain-demo](../langchain-demo/).
