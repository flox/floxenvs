# Apache Kafka

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fkafka%2Fdevcontainer.json)

Minimal Flox environment providing Apache Kafka in KRaft mode
(no ZooKeeper). Designed for use with `[include]` so other
environments can build on top of it.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../kafka" }
]
```

Or from FloxHub:

```toml
[include]
environments = [{ remote = "flox/kafka" }]
```

## Default variables

| Variable                 | Default                  |
| ------------------------ | ------------------------ |
| `KAFKA_HOST`             | `localhost`              |
| `KAFKA_PORT`             | `9092`                   |
| `KAFKA_CONTROLLER_PORT`  | `9093`                   |
| `KAFKA_BROKERS`          | `$KAFKA_HOST:$KAFKA_PORT` |

`KAFKA_BROKERS` is derived from `KAFKA_HOST` and `KAFKA_PORT` on
activation, so overriding either keeps it consistent. Set it explicitly
only to point clients at an external broker.

Override any variable in your own manifest:

```toml
[vars]
KAFKA_PORT = "19092"
KAFKA_HOST = "0.0.0.0"
```

## Starting the service

```bash
flox activate --start-services
# or
flox services start
```

## Connecting with kafka-topics.sh

```bash
kafka-topics.sh --bootstrap-server $KAFKA_BROKERS --list
```

```bash
kafka-topics.sh --bootstrap-server $KAFKA_BROKERS \
  --create --topic my-topic --partitions 1 \
  --replication-factor 1
```

## See also

- [kafka-demo](../kafka-demo) -- full demo with styled output
  and topic walkthrough
