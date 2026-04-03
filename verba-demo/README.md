# verba-demo

Full Verba RAG demo environment that shows service
URLs, Ollama model configuration, and styled terminal
output with Flox.

For a minimal environment to include in your own
project, see [verba](../verba/) or use `flox/verba`
on FloxHub.

## Quick start

```bash
flox activate -r flox/verba-demo --start-services
```

Then open Verba in your browser:

```
http://localhost:8000
```

## What this demo includes

- Everything from the `verba` base environment
- `gum` for styled terminal output
- Banner showing service URLs and model config

## Services

| Service | URL |
| ------- | --- |
| Weaviate | <http://localhost:8080> |
| Ollama | <http://localhost:11434> |
| Verba | <http://localhost:8000> |

## Service management

```bash
flox services start        # start all services
flox services stop         # stop all services
flox services status       # check status
flox services logs verba   # view verba logs
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/verba"]
```

This gives you Verba with sane defaults. Override
vars in your own manifest as needed.
