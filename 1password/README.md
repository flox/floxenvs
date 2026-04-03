# 1Password

Minimal 1Password CLI environment with automatic session
caching. Designed to be included as a base layer in other
Flox environments.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/1password"]

[hook]
on-activate = '''
export MY_API_KEY=$(op item get "MyService" \
  --field "credential")
'''
```

## Session Caching

On activation the hook checks whether you already have a
valid 1Password session. If not, it attempts to sign in and
caches the session token under `$FLOX_ENV_CACHE/1password`.

The cached token is reused across activations so you are
not prompted repeatedly. Caching is best-effort: if
authentication fails, the environment still activates
without setting `OP_SESSION_TOKEN`.

## Environment Variables

| Variable | Description |
| -------- | ----------- |
| `OP_SESSION_TOKEN` | Set when a cached or fresh session is available |
| `OP_CACHE` | Directory where the session file is stored |

## Packages

- `op` (`_1password`) -- 1Password CLI
