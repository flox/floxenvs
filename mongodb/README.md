# mongodb

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fmongodb%2Fdevcontainer.json)

Minimal MongoDB environment for use with `[include]`.
Provides a MongoDB server with sane defaults, designed
for composition into your own project environment.

## Quick start

Activate directly:

```bash
flox activate -r flox/mongodb --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/mongodb" }]
```

Then customize vars in your own manifest as needed.

## Defaults

| Setting | Value |
| ------- | ----- |
| Version | Latest stable (tracks `mongodb-ce`) |
| Host | `127.0.0.1` |
| Port | `27017` |
| Data dir | `$FLOX_ENV_CACHE/mongodb` |

## Customizing

Override these vars in your own manifest:

```toml
[vars]
MONGO_HOST = "0.0.0.0"
MONGO_PORT = "37017"
```

## Connection string

```text
mongodb://$MONGO_HOST:$MONGO_PORT
```

With defaults:

```text
mongodb://127.0.0.1:27017
```

## Environment variables

| Variable | Description |
| -------- | ----------- |
| `MONGO_HOST` | Bind address for the server |
| `MONGO_PORT` | Port the server listens on |
| `MONGO_DATA` | Path to the data directory |

## See also

For an interactive setup with `mongosh` and usage
examples, see [mongodb-demo](../mongodb-demo/).
