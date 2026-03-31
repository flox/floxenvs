# redis-demo

Full Redis demo environment that walks you through
connection, basic operations, and service management
with Flox.

For a minimal environment to include in your own
project, see [redis](../redis/) or use `flox/redis`
on FloxHub.

## Quick start

```bash
flox activate -r flox/redis-demo --start-services
```

Then connect:

```bash
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT"
```

## What this demo includes

- Redis server and CLI (latest stable)
- `gum` for styled terminal output
- Service definition for background redis-server
- Connection info display on activation

## SET/GET walkthrough

After starting the service, try basic operations:

```bash
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT"
```

```
127.0.0.1:16379> SET greeting "hello"
OK
127.0.0.1:16379> GET greeting
"hello"
127.0.0.1:16379> DEL greeting
(integer) 1
127.0.0.1:16379> QUIT
```

Or run commands directly from the shell:

```bash
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
  SET mykey "myvalue"
redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" \
  GET mykey
```

## Customizing

Override these vars in your own manifest:

```toml
[vars]
REDIS_HOST = "0.0.0.0"   # listen on all interfaces
REDIS_PORT = "6379"       # use standard port
```

## Data directory

Redis data is stored in `$FLOX_ENV_CACHE/redis`.
This persists across activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/redis"
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/redis"]
```

This gives you Redis with sane defaults. Override
vars in your own manifest as needed.

## Service management

```bash
flox services start        # start redis
flox services stop         # stop redis
flox services status       # check status
flox services logs redis   # view logs
```
