# postgres

Minimal PostgreSQL environment. Include it in your own
manifest to get a working PostgreSQL setup with sane
defaults.

## Quick start

Activate directly:

```bash
flox activate -r flox/postgres --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/postgres"]
```

Then customize in your own manifest as needed -- override
vars, add extensions, or change the port.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | Latest stable (currently 16) |
| Port | 15432 |
| User | pguser |
| Password | pgpass |
| Database | pgdb |
| Data dir | `.flox/data/postgres/data` |

## Customizing

Override these vars in your own manifest to change the
defaults:

```toml
[vars]
PGPORT = "25432"        # different port
PGUSER = "myapp"        # different user
PGPASS = "secret"       # different password
PGDATABASE = "myappdb"  # different database
PGHOSTADDR = "0.0.0.0"  # listen on all interfaces
```

To pin a specific PostgreSQL major version instead of
tracking the latest:

```toml
[install]
postgresql.pkg-path = "postgresql_15"
```

Available versions: `postgresql_13`, `postgresql_14`,
`postgresql_15`, `postgresql_16`. Use
`flox search postgresql` to see all options.

## See also

For a full walkthrough with version selection, extensions,
and configuration examples, see
[postgres-demo](../postgres-demo/).
