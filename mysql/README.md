# mysql

Minimal MySQL 8.4 server environment for use with Flox
`[include]`.

## Usage

Include this environment in your project manifest:

```toml
[include]
environments = ["flox/mysql"]
```

Activate and start the service:

```bash
flox activate -- flox services start
```

## Variables

Override these in your own manifest under `[vars]`:

| Variable       | Default     | Description              |
| -------------- | ----------- | ------------------------ |
| MYSQL_HOST     | 127.0.0.1   | Bind address             |
| MYSQL_PORT     | 13306       | TCP port                 |
| MYSQL_DATABASE | mydb        | Database created on init |
| MYSQL_USER     | (your user) | DB user (defaults to $USER if empty) |
| MYSQL_PWD      | mypass      | DB user password         |

## Connection examples

Using the mysql client (available in the environment):

```bash
mysql -e "SHOW DATABASES;"
```

The environment sets `MYSQL_TCP_PORT`, `MYSQL_HOST`,
`MYSQL_PWD`, and `MYSQL_USER` so the client connects
automatically.

From application code, use the connection string:

```
mysql://$MYSQL_USER:$MYSQL_PWD@$MYSQL_HOST:$MYSQL_PORT/$MYSQL_DATABASE
```

## Data directory

All data is stored under `$FLOX_ENV_CACHE/mysql/`.
Delete that directory to reinitialize the database
from scratch.

## See also

- [mysql-demo](../mysql-demo) -- demo project that
  includes this environment
- [mariadb](../mariadb) -- for MariaDB, use the
  separate mariadb/ environment instead
