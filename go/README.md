# Go

Minimal Go environment providing the Go compiler and
standard toolchain.

## What is included

- `go` -- compiler, build tool, and standard library

## Usage

Activate directly:

```bash
flox activate -r flox/go
```

Or include it in your own manifest:

```toml
[include]
environments = ["flox/go"]
```

## Environment variables

| Variable | Description                          |
| -------- | ------------------------------------ |
| `GOENV`  | Set to `$FLOX_ENV_CACHE/go` on activate |

## Editor tooling and sample app

For a full development setup with `gopls`, `gotools`,
`go-task`, and a sample "Hello World" app, see
[go-demo](../go-demo/).
