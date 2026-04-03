# langchain-demo

Full LangChain demo environment that walks you through
using LangGraph, LangChain-Ollama, and LangChain-Community
with a local Ollama service managed by Flox.

For a minimal environment to include in your own
project, see [langchain](../langchain/) or use
`flox/langchain` on FloxHub.

## Quick start

```bash
flox activate -r flox/langchain-demo --start-services
```

## What this demo includes

- LangGraph orchestration framework
- LangChain-Ollama and LangChain-Community integrations
- Ollama local LLM runtime as a background service
- `gum` for styled terminal output
- Connection info display on activation

## Using Ollama

After starting services:

```bash
ollama list                   # list available models
ollama pull llama3            # download a model
ollama run llama3 "Hello!"    # run a prompt
```

## Using with Python

```python
from langchain_ollama.llms import OllamaLLM

model = OllamaLLM(model="llama3")
print(model.invoke("What is LangChain?"))
```

## Service management

```bash
flox services start          # start ollama
flox services stop           # stop ollama
flox services status         # check status
flox services logs ollama    # view logs
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/langchain"]
```

This gives you LangChain with Ollama and sane
defaults. Override vars in your own manifest as needed.
