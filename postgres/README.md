# postgres

Minimal PostgreSQL environment. Include it in your own manifest
to get a working PostgreSQL setup with sane defaults.

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

Then customize in your own manifest as needed — override vars,
add extensions, or change the port.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | PostgreSQL 16 |
| Port | 15432 |
| User | pguser |
| Database | pgdb |
| Data dir | `$FLOX_ENV_CACHE/postgres/data` |

## See also

For a full walkthrough with version selection, extensions, and
configuration examples, see
[postgres-demo](../postgres-demo/).
