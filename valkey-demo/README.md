# valkey-demo

Full Valkey demo environment that walks you through
connection, basic operations, and service management
with Flox.

For a minimal environment to include in your own
project, see [valkey](../valkey/) or use `flox/valkey`
on FloxHub.

## Quick start

```bash
flox activate -r flox/valkey-demo --start-services
```

Then connect:

```bash
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT"
```

## What this demo includes

- Valkey server and CLI (latest stable)
- `gum` for styled terminal output
- Service definition for background valkey-server
- Connection info display on activation

## SET/GET walkthrough

After starting the service, try basic operations:

```bash
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT"
```

```
127.0.0.1:16380> SET greeting "hello"
OK
127.0.0.1:16380> GET greeting
"hello"
127.0.0.1:16380> DEL greeting
(integer) 1
127.0.0.1:16380> QUIT
```

Or run commands directly from the shell:

```bash
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" \
  SET mykey "myvalue"
valkey-cli -h "$VALKEY_HOST" -p "$VALKEY_PORT" \
  GET mykey
```

## Redis compatibility

Valkey is a drop-in replacement for Redis. Any client
library that supports the Redis protocol will work
with Valkey without changes. You can even use
`redis-cli` to connect if you have it installed.

## Customizing

Override these vars in your own manifest:

```toml
[vars]
VALKEY_HOST = "0.0.0.0"   # listen on all interfaces
VALKEY_PORT = "6379"       # use standard port
```

## Data directory

Valkey data is stored in `$FLOX_ENV_CACHE/valkey`.
This persists across activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/valkey"
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/valkey"]
```

This gives you Valkey with sane defaults. Override
vars in your own manifest as needed.

## Service management

```bash
flox services start         # start valkey
flox services stop          # stop valkey
flox services status        # check status
flox services logs valkey   # view logs
```
