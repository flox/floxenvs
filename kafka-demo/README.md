# Kafka Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fkafka-demo%2Fdevcontainer.json)

Demo environment for Apache Kafka (KRaft mode). Includes the
minimal [kafka](../kafka) environment and adds styled terminal
output with `gum`.

## Quick start

```bash
flox activate -d kafka-demo -- bash
flox services start
```

Or start services automatically:

```bash
flox activate -d kafka-demo --start-services
```

## Working with topics

List topics:

```bash
kafka-topics.sh --bootstrap-server $KAFKA_BROKERS --list
```

Create a topic:

```bash
kafka-topics.sh --bootstrap-server $KAFKA_BROKERS \
  --create --topic my-topic --partitions 1 \
  --replication-factor 1
```

## Produce and consume messages

Produce messages:

```bash
kafka-console-producer.sh \
  --bootstrap-server $KAFKA_BROKERS \
  --topic my-topic
```

Consume messages:

```bash
kafka-console-consumer.sh \
  --bootstrap-server $KAFKA_BROKERS \
  --topic my-topic \
  --from-beginning
```

## Customization

Override variables in your own manifest or shell:

```toml
[vars]
KAFKA_PORT = "19092"
KAFKA_HOST = "0.0.0.0"
```

`KAFKA_BROKERS` follows `KAFKA_HOST:KAFKA_PORT` automatically.

## See also

- [kafka](../kafka) -- minimal base environment for use with
  `[include]`
