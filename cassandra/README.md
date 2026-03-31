# Cassandra

Minimal Flox environment providing Apache Cassandra 4.x.
Designed for use with `[include]` so other environments can
build on top of it.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../cassandra" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/cassandra"]
```

## Default variables

| Variable | Default |
| ----------------------- | ------------- |
| `CASSANDRA_HOST` | `127.0.0.1` |
| `CASSANDRA_PORT` | `19042` |
| `CASSANDRA_STORAGE_PORT`| `7070` |
| `CASSANDRA_CLUSTER_NAME`| `My Cluster` |
| `CASSANDRA_SEED_ADDRS` | `127.0.0.1` |
| `CASSANDRA_ALLOW_CLIENTS`| `true` |

Override any variable in your own manifest:

```toml
[vars]
CASSANDRA_PORT = "9042"
CASSANDRA_CLUSTER_NAME = "Production"
```

## Starting the service

```bash
flox activate --start-services
# or
flox services start
```

## Connecting with cqlsh

```bash
cqlsh $CASSANDRA_HOST $CASSANDRA_PORT
```

```bash
cqlsh $CASSANDRA_HOST $CASSANDRA_PORT \
  -e "SELECT now() FROM system.local;"
```

## See also

- [cassandra-demo](../cassandra-demo) -- full demo with
  styled output and CQL walkthrough
