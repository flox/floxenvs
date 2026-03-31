# mariadb-demo

Full MariaDB demo environment with styled connection info,
service management, and CRUD examples.

For a minimal environment to include in your own project,
see [mariadb](../mariadb/) or use `flox/mariadb` on FloxHub.

For MySQL, see [mysql-demo](../mysql-demo/).

## Quick start

```bash
flox activate -r flox/mariadb-demo --start-services
```

Then connect:

```bash
mariadb --socket=$MARIADB_SOCKET -u $MARIADB_USER -p
```

## What this demo includes

- MariaDB (latest stable)
- `gum` for styled terminal output
- Automatic database initialization on first activation
- Service definition for background mariadbd
- Connection info display on activation

## Connecting

Use the `mariadb` CLI with the socket:

```bash
mariadb --socket=$MARIADB_SOCKET \
  -u $MARIADB_USER -p$MARIADB_PWD $MARIADB_DATABASE
```

Or connect via TCP:

```bash
mariadb -h $MARIADB_HOST -P $MARIADB_PORT \
  -u $MARIADB_USER -p
```

## CRUD walkthrough

After starting services, try basic operations:

```sql
CREATE TABLE mydb.demo (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50)
);

INSERT INTO mydb.demo (name) VALUES ('hello');

SELECT * FROM mydb.demo;

UPDATE mydb.demo SET name = 'world' WHERE id = 1;

DELETE FROM mydb.demo WHERE id = 1;

DROP TABLE mydb.demo;
```

## Customizing connection settings

Override any of these vars in your own manifest:

```toml
[vars]
MARIADB_PORT = "3306"
MARIADB_HOST = "127.0.0.1"
MARIADB_DATABASE = "myappdb"
MARIADB_USER = "myapp"
MARIADB_PWD = "secret"
```

## Data directory

MariaDB data is stored in `$FLOX_ENV_CACHE/mariadb/data`.
This persists across activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/mariadb"
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/mariadb"]
```

This gives you MariaDB with sane defaults. Override vars
and add packages in your own manifest as needed.

## Service management

```bash
flox services start           # start mariadb
flox services stop            # stop mariadb
flox services status          # check status
flox services logs mariadb    # view logs
```
