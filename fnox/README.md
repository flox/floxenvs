# fnox

Minimal [fnox](https://fnox.jdx.dev/) environment. fnox
("Fort Knox") manages secrets via encryption (age, AWS/Azure/
GCP KMS) or cloud providers (1Password, Bitwarden, HashiCorp
Vault, AWS Secrets Manager, GCP Secret Manager, Doppler,
Infisical, password-store, OS keychain, and more). Designed
to be included as a base layer in other Flox environments.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/fnox"]
```

Then add a `fnox.toml` in your project, and either load
secrets into the environment at activation:

```toml
[hook]
on-activate = '''
eval "$(fnox export --shell bash)"
'''
```

or wrap individual commands:

```bash
fnox exec -- npm start
```

## Quick start

```bash
# Initialise fnox in the current directory
fnox init

# Add an age provider (encrypted secrets in git)
fnox provider add age

# Set and read a secret
fnox set DATABASE_URL "postgresql://localhost/mydb"
fnox get DATABASE_URL

# Run a command with all secrets loaded as env vars
fnox exec -- env | grep DATABASE_URL
```

`fnox.toml` is safe to commit — encrypted values stay
ciphertext, and remote references store only the lookup key.

## Providers

fnox supports a wide range of secret backends. See
<https://fnox.jdx.dev/providers/overview.html> for the
full list. Common ones:

| Provider | Use case |
| -------- | -------- |
| `age` | Encrypted secrets in git (works with SSH keys) |
| `aws-kms`, `azure-kms`, `gcp-kms` | KMS-encrypted secrets in git |
| `1password` | Pull from 1Password vaults |
| `bitwarden` | Pull from Bitwarden / Vaultwarden |
| `vault` | HashiCorp Vault (KV, dynamic creds) |
| `aws-sm`, `aws-ps` | AWS Secrets Manager / Parameter Store |
| `gcp-sm`, `azure-sm` | GCP / Azure secrets |
| `keychain` | OS keychain (macOS/Windows/Linux) |
| `password-store` | GPG-encrypted Unix `pass` |

## Environment Variables

| Variable | Description |
| -------- | ----------- |
| `FNOX_DATA_DIR` | Lease/token cache (default: `$FLOX_ENV_CACHE/fnox`) |
| `FNOX_LOG` | Log level (`trace` … `error`); defaults to `warn` |

## Packages

- `fnox` — the fnox CLI (custom Flox package, prebuilt
  upstream binaries)

## See also

- [`fnox-demo`](../fnox-demo) — interactive demo showing
  several providers and patterns side-by-side
- Project site: <https://fnox.jdx.dev/>
- Source: <https://github.com/jdx/fnox>
