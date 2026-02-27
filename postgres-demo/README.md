# postgres-demo

Full PostgreSQL demo environment that walks you through
configuration options, version selection, and service
management with Flox.

For a minimal environment to include in your own project,
see [postgres](../postgres/) or use `flox/postgres` on
FloxHub.

## Quick start

```bash
flox activate -r flox/postgres-demo --start-services
```

Then connect:

```bash
psql
```

## Inline documentation

After activation, use the `helpf` command to view this
README in your terminal:

```bash
helpf              # show README
helpf --force      # refresh cached copy
```

## What this demo includes

- PostgreSQL 16 (with commented alternatives for 13-15)
- `gum` for interactive UI during setup
- `bat` and `helpf` for inline documentation
- Automatic database initialization on first activation
- Service definition for background postgres
- Connection info display on activation

## Choosing a PostgreSQL version

Edit the manifest to uncomment your preferred version:

```toml
[install]
# postgresql.pkg-path = "postgresql_16"   # default
postgresql.pkg-path = "postgresql_15"     # activate this
```

Version trade-offs:

| Version | Key features |
| ------- | ------------ |
| 16 | Latest stable, SCRAM auth, logical replication |
| 15 | MERGE command, JSON logging |
| 14 | Multirange types, connection pooling |
| 13 | Legacy support |

After changing versions, delete the data directory to
reinitialize:

```bash
rm -rf "$FLOX_ENV_PROJECT/.flox/data/postgres"
```

## Adding extensions

Search for available extensions:

```bash
flox search postgresqlPackages
```

Add to your manifest:

```toml
[install]
postgis.pkg-path = "postgresqlPackages.postgis"
pgvector.pkg-path = "postgresqlPackages.pgvector"
```

## Customizing connection settings

Override any of these vars in your own manifest:

```toml
[vars]
PGPORT = "25432"        # different port
PGUSER = "myapp"        # different user
PGDATABASE = "myappdb"  # different database
```

## Data directory

PostgreSQL data is stored in `.flox/data/postgres/data`.
This persists across activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_PROJECT/.flox/data/postgres"
```

## Using the minimal version

If you don't need the demo experience, include the minimal
environment in your own manifest:

```toml
[include]
environments = ["flox/postgres"]
```

This gives you PostgreSQL 16 with sane defaults. Override
vars and add packages in your own manifest as needed.

## Service management

```bash
flox services start          # start postgres
flox services stop           # stop postgres
flox services status         # check status
flox services logs postgres  # view logs
```
