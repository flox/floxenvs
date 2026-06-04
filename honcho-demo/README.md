# Honcho Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fhoncho-demo%2Fdevcontainer.json)

Interactive demo for the self-hosted
[Honcho](https://github.com/plastic-labs/honcho) memory server.
Composes the [honcho](../honcho/) minimal env (server + deriver
+ postgres + redis + SDK) and ships a `quickstart.py` that
exercises the full Store → Reason → Query → Inject loop.

## Try it

```bash
cd honcho-demo
flox activate --start-services
# Optional: enables the reasoning path
export LLM_OPENAI_API_KEY=sk-...
python quickstart.py
```

You should see four messages stored on `demo-session`, then
either a peer chat answer (if a key was set) or a clean skip.

## What you get

| Source env       | What it adds                                  |
| ---------------- | --------------------------------------------- |
| `../honcho`      | server, deriver, SDK, postgres+pgvector, redis |
| `demo-tools`     | `gum` for the banner                          |
| (this env)       | `quickstart.py` sample script                 |

## What quickstart.py does

```text
1. Connects to http://127.0.0.1:18000 (override with $HONCHO_URL)
2. Creates a workspace, two peers (alice + tutor), a session
3. Adds four messages (storage path, no LLM key needed)
4. Calls alice.representation() (storage path, no LLM key)
5. If an LLM key is set:
   - alice.chat("What is the user struggling with?")
   - session.context(summary=True, tokens=2000).to_openai(...)
```

The script's loop mirrors the [upstream README quickstart][upq]
exactly, just pointed at the local server instead of
`api.honcho.dev`.

[upq]: https://github.com/plastic-labs/honcho#quickstart

## Services

When you activate with `--start-services`, four flox services
come up:

| Service          | Port  | Notes                              |
| ---------------- | ----- | ---------------------------------- |
| `postgres`       | 15432 | TCP mode, trust auth, with pgvector |
| `redis`          | 16379 |                                    |
| `honcho-api`     | 18000 | FastAPI server                     |
| `honcho-deriver` | —     | Background reasoning worker        |

Tail logs with `flox services logs <name>`.

## Wiring it into your own code

The SDK and CLI are on PATH already:

```python
from honcho import Honcho

h = Honcho(
    workspace_id="my-app",
    base_url="http://127.0.0.1:18000",
    api_key="local-dev",   # AUTH_USE_AUTH=false in the minimal env
)
peer = h.peer("user-42")
session = h.session("convo-1")
session.add_messages([peer.message("hello")])
```

## See also

- [honcho](../honcho/) — minimal env you'd `[include]`
- [Honcho upstream](https://github.com/plastic-labs/honcho)
- [Honcho docs](https://honcho.dev/docs/)
