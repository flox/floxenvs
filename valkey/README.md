# valkey

Minimal Valkey environment. Include it in your own
manifest to get a working Valkey server and CLI with
sane defaults.

Valkey is a Redis-compatible key/value store, forked
after the Redis license change. It speaks the same
protocol and supports the same commands.

## Quick start

Activate directly:

```bash
flox activate -r flox/valkey --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/valkey"]
```

Then customize vars in your own manifest to override
defaults.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | Latest stable (tracks `valkey`) |
| Host | 127.0.0.1 |
| Port | 16380 |
| Data dir | `$FLOX_ENV_CACHE/valkey` |

## Customizing

Override these vars in your own manifest:

```toml
[vars]
VALKEY_HOST = "0.0.0.0"   # listen on all interfaces
VALKEY_PORT = "6379"       # use standard port
```

## Environment variables

After activation, these are available in your shell:

| Variable | Description |
| -------- | ----------- |
| `VALKEY_HOST` | Bind address for the server |
| `VALKEY_PORT` | Port the server listens on |
| `VALKEY_DATA` | Path to the data directory |

## Connection string

Most Redis-compatible clients accept a URL in this form:

```
redis://$VALKEY_HOST:$VALKEY_PORT
```

Or connect with the CLI:

```bash
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT"
```

## Redis compatibility

Valkey is a drop-in replacement for Redis. Any client
library that supports the Redis protocol will work with
Valkey without changes.

## See also

For a full walkthrough with SET/GET examples and
styled terminal output, see
[valkey-demo](../valkey-demo/).
