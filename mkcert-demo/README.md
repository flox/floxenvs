# mkcert-demo

Demo environment showcasing the
[mkcert](../mkcert/) base layer with formatted terminal
output using [gum](https://github.com/charmbracelet/gum).

## What it does

On activation this environment:

1. Includes the `mkcert` base layer which creates a
   local Certificate Authority and generates TLS
   certificates for the configured domains.
2. Displays a formatted summary box showing the
   generated certificate paths, configured domains,
   and the `NODE_EXTRA_CA_CERTS` value for Node.js.

The summary box is suppressed during CI testing when
`FLOX_ENVS_TESTING=1` is set.

## Usage

Activate the demo environment:

```bash
flox activate -d mkcert-demo
```

## Customizing domains

Override the default domains by setting `MKCERT_DOMAINS`
before activation or in a manifest that includes this
environment:

```toml
[vars]
MKCERT_DOMAINS = "myapp.local api.local localhost"
```

## Node.js integration

The base layer exports `NODE_EXTRA_CA_CERTS` pointing to
the local root CA. Node.js applications will
automatically trust certificates signed by the local CA
without any code changes.

```javascript
// No extra configuration needed - just use https
const https = require('https');
https.get('https://myapp.local', (res) => {
  // Works with locally-trusted certificate
});
```

## Certificate files

All certificates are stored in `$CAROOT`
(`$FLOX_ENV_CACHE/mkcert`):

| File | Description |
| ---- | ----------- |
| `rootCA.pem` | Local root CA certificate |
| `domains.pem` | TLS certificate for configured domains |
| `domains-key.pem` | TLS private key for configured domains |
| `domains.p12` | PKCS#12 bundle (cert + key) |

## See also

- [mkcert](../mkcert/) -- Minimal base layer for
  inclusion in other environments.
