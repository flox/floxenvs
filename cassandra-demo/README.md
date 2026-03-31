# Cassandra Demo

Demo environment for Apache Cassandra 4.x. Includes the
minimal [cassandra](../cassandra) environment and adds
styled terminal output with `gum`.

## Quick start

```bash
flox activate -d cassandra-demo -- bash
flox services start
```

Or start services automatically:

```bash
flox activate -d cassandra-demo --start-services
```

## Connecting with cqlsh

```bash
cqlsh $CASSANDRA_HOST $CASSANDRA_PORT
```

Run a single query:

```bash
cqlsh $CASSANDRA_HOST $CASSANDRA_PORT \
  -e "SELECT now() FROM system.local;"
```

## CQL walkthrough

Create a keyspace:

```sql
CREATE KEYSPACE IF NOT EXISTS my_app
  WITH replication = {
    'class': 'SimpleStrategy',
    'replication_factor': 1
  };
```

Create a table and insert data:

```sql
USE my_app;

CREATE TABLE IF NOT EXISTS items (
  id UUID PRIMARY KEY,
  name text,
  value int
);

INSERT INTO items (id, name, value)
  VALUES (uuid(), 'example', 42);

SELECT * FROM items;
```

Clean up:

```sql
DROP KEYSPACE my_app;
```

## Customization

Override variables in your own manifest or shell:

```toml
[vars]
CASSANDRA_PORT = "9042"
CASSANDRA_CLUSTER_NAME = "Production"
CASSANDRA_SEED_ADDRS = "10.0.0.1,10.0.0.2"
```

## See also

- [cassandra](../cassandra) -- minimal base environment
  for use with `[include]`
