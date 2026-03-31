# redis

Minimal Redis environment. Include it in your own
manifest to get a working Redis server and CLI with
sane defaults.

## Quick start

Activate directly:

```bash
flox activate -r flox/redis --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/redis"]
```

Then customize vars in your own manifest to override
defaults.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | Latest stable (tracks `redis`) |
| Host | 127.0.0.1 |
| Port | 16379 |
| Data dir | `$FLOX_ENV_CACHE/redis` |

## Customizing

Override these vars in your own manifest:

```toml
[vars]
REDIS_HOST = "0.0.0.0"   # listen on all interfaces
REDIS_PORT = "6379"       # use standard port
```

## Environment variables

After activation, these are available in your shell:

| Variable | Description |
| -------- | ----------- |
| `REDIS_HOST` | Bind address for the server |
| `REDIS_PORT` | Port the server listens on |
| `REDIS_DATA` | Path to the data directory |

## Connection string

Most Redis clients accept a URL in this form:

```
redis://$REDIS_HOST:$REDIS_PORT
```

Or connect with the CLI:

```bash
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT"
```

## See also

For a full walkthrough with SET/GET examples and
styled terminal output, see
[redis-demo](../redis-demo/).
