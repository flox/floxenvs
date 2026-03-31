# mariadb

Minimal MariaDB server environment designed for composition
via `[include]`.

For MySQL, see the `mysql/` environment instead.

## Quick start

Include in your own Flox manifest:

```toml
[include]
environments = ["flox/mariadb"]
```

Activate and start the service:

```bash
flox activate
flox services start
```

## Variables

Override any of these in your manifest's `[vars]` section:

| Variable | Default |
| ---------------- | ----------- |
| MARIADB_HOST | 127.0.0.1 |
| MARIADB_PORT | 13307 |
| MARIADB_DATABASE | mydb |
| MARIADB_USER | (your user) |
| MARIADB_PWD | mypass |

When `MARIADB_USER` is left empty it defaults to `$USER`.

## Connecting

Via Unix socket (fastest, local only):

```bash
mariadb --socket="$MARIADB_SOCKET" \
  -u "$MARIADB_USER" -p"$MARIADB_PWD" "$MARIADB_DATABASE"
```

Via TCP:

```bash
mariadb -h "$MARIADB_HOST" -P "$MARIADB_PORT" \
  -u "$MARIADB_USER" -p"$MARIADB_PWD" "$MARIADB_DATABASE"
```

## Data location

All data is stored under `$FLOX_ENV_CACHE/mariadb/`.
Delete that directory to reinitialize from scratch.

## See also

- [mariadb-demo](https://github.com/flox/mariadb-demo)
