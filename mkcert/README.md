# mkcert

Locally-trusted TLS development certificates powered by
[mkcert](https://github.com/FiloSottile/mkcert).

This is a minimal, include-ready base layer. For a
full demo with formatted output, see
[mkcert-demo](../mkcert-demo/).

## Usage

Include this environment in your own Flox manifest:

```toml
[include]
environments = ["flox/mkcert"]
```

Or for local development with a relative path:

```toml
[include]
environments = [
  { dir = "../mkcert" }
]
```

## Configuration

### MKCERT_DOMAINS

Space-separated list of domains for the certificate.
Override it in your manifest:

```toml
[vars]
MKCERT_DOMAINS = "myapp.local localhost 127.0.0.1 ::1"
```

Default value:

```
example.com localhost 127.0.0.1 ::1
```

## Environment variables

The hook exports two environment variables:

| Variable | Description |
| -------- | ----------- |
| `CAROOT` | Directory containing the CA and certificates |
| `NODE_EXTRA_CA_CERTS` | Path to `rootCA.pem` for Node.js HTTPS |

`NODE_EXTRA_CA_CERTS` allows Node.js applications to
trust the local CA without additional configuration.

## Certificate files

After activation, the following files are created inside
`$CAROOT`:

| File | Description |
| ---- | ----------- |
| `rootCA.pem` | Local root CA certificate |
| `rootCA-key.pem` | Local root CA private key |
| `domains.pem` | TLS certificate for configured domains |
| `domains-key.pem` | TLS private key for configured domains |
| `domains.p12` | PKCS#12 bundle (cert + key) |

## How it works

On activation the hook:

1. Creates a local Certificate Authority if one does not
   exist yet (`mkcert -install`).
2. Generates domain certificates whenever
   `MKCERT_DOMAINS` changes.

Certificates are cached in `$FLOX_ENV_CACHE/mkcert` so
they persist across shell sessions and are only
regenerated when the domain list changes.

## Packages

Both `mkcert` and `nssTools` are installed in the
`mkcert` package group to ensure version compatibility.
