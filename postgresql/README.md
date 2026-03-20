# postgresql

Minimal PostgreSQL environment. Include it in your own
manifest to get a working PostgreSQL setup with sane
defaults.

## Quick start

Activate directly:

```bash
flox activate -r flox/postgresql --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/postgresql"]
```

Then customize in your own manifest as needed -- override
vars, add extensions, or change the connection mode.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | Latest stable (tracks `postgresql`) |
| Connection | Unix socket (no TCP port) |
| Auth | trust (no password required) |
| User | pguser |
| Database | pgdb |
| Data dir | `$FLOX_ENV_CACHE/postgres/data` |

## Connection modes

### Socket mode (default)

By default, postgres listens only on a unix socket with
no TCP port bound. Clients connect via `PGHOST` which
points to the socket directory. This is the simplest
setup and allows multiple instances to coexist without
port conflicts.

### TCP mode

Set `PGPORT` in your manifest to switch to TCP mode:

```toml
[vars]
PGPORT = "15432"
```

In TCP mode, `PGHOST` is set to `PGHOSTADDR` (`127.0.0.1`
by default) and postgres listens on the specified port.

## Customizing

Override these vars in your own manifest:

```toml
[vars]
PGPORT = "15432"        # enable TCP mode on this port
PGUSER = "myapp"        # different user
PGPASS = "secret"       # different password
PGDATABASE = "myappdb"  # different database
PGHOSTADDR = "0.0.0.0"  # listen on all interfaces (TCP mode only)
```

To pin a specific PostgreSQL major version instead of
tracking the latest:

```toml
[install]
postgresql.pkg-path = "postgresql_15"
```

Available versions: `postgresql_13`, `postgresql_14`,
`postgresql_15`, `postgresql_16`, `postgresql_17`. Use
`flox search postgresql` to see all options.

## Environment variables

After activation, these are available in your shell:

| Variable | Description |
| --- | --- |
| `PGHOST` | Socket dir (socket mode) or host address (TCP mode) |
| `PGDATA` | Path to the data directory |
| `DATABASE_URL` | Connection string suitable for most frameworks |

## Authentication

The database is initialized with `--auth=trust`, meaning
any local connection is accepted without a password. This
is appropriate for local development.

`PGPASS` is available in `[vars]` as a convenience for
`DATABASE_URL` and frameworks that require a password
field in connection strings, but it is not enforced by
the server.

To configure password or other authentication methods
after initialization, edit `pg_hba.conf` in the data
directory (`$PGDATA/pg_hba.conf`) and reload:

```bash
pg_ctl -D "$PGDATA" reload
```

## See also

For a full walkthrough with version selection, extensions,
and configuration examples, see
[postgresql-demo](../postgresql-demo/).