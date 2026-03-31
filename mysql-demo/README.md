# mysql-demo

Full MySQL demo environment with styled connection info,
service management, and CRUD examples.

For a minimal environment to include in your own project,
see [mysql](../mysql/) or use `flox/mysql` on FloxHub.

For MariaDB, see [mariadb-demo](../mariadb-demo/).

## Quick start

```bash
flox activate -r flox/mysql-demo --start-services
```

Then connect:

```bash
mysql -h $MYSQL_HOST -P $MYSQL_PORT -u $MYSQL_USER -p
```

## What this demo includes

- MySQL 8.4
- `gum` for styled terminal output
- Automatic database initialization on first activation
- Service definition for background mysqld
- Connection info display on activation

## Connecting

Use the `mysql` CLI with the environment variables:

```bash
mysql -h $MYSQL_HOST -P $MYSQL_PORT \
  -u $MYSQL_USER -p$MYSQL_PWD $MYSQL_DATABASE
```

Or use the socket directly:

```bash
mysql --socket=$MYSQL_SOCKET -u $MYSQL_USER -p
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
MYSQL_PORT = "3306"
MYSQL_HOST = "127.0.0.1"
MYSQL_DATABASE = "myappdb"
MYSQL_USER = "myapp"
MYSQL_PWD = "secret"
```

## Data directory

MySQL data is stored in `$FLOX_ENV_CACHE/mysql/data`.
This persists across activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/mysql"
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/mysql"]
```

This gives you MySQL with sane defaults. Override vars
and add packages in your own manifest as needed.

## Service management

```bash
flox services start         # start mysql
flox services stop          # stop mysql
flox services status        # check status
flox services logs mysql    # view logs
```
