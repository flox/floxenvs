# fnox Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ffnox-demo%2Fdevcontainer.json)

Interactive demo of the [fnox](../fnox/) environment showing
several ways to pull secrets into your shell.

## What's in the box

```text
fnox-demo/
├── fnox.toml                 # config: providers + secrets + leases
├── fnox-demo-key.txt         # demo age private key (NOT a real secret)
└── scripts/
    └── mint-greeting.sh      # command-lease script
```

## Quick start

```bash
flox activate -r flox/fnox-demo
```

The hook loads the demo age key, then prints a list of things
to try. The four headline patterns:

```bash
# 1. Just decrypt and print one secret.
fnox get DEMO_DATABASE_URL

# 2. View everything fnox knows about (encrypted and plain).
fnox list

# 3. Run a command with every secret in its env.
fnox exec -- env | grep ^DEMO_

# 4. Mint a fresh short-lived credential from a custom script.
fnox lease create greeting
```

## Patterns the demo shows

### Encrypted-in-git via age

`DEMO_DATABASE_URL` is age-encrypted ciphertext stored inline
in `fnox.toml`. The recipient is a public key; the matching
private key (`FNOX_AGE_KEY`) lives in `fnox-demo-key.txt`.

For real use cases generate your own keypair:

```bash
age-keygen -o ~/.config/fnox/age.txt
grep 'public key:' ~/.config/fnox/age.txt   # paste into fnox.toml
export FNOX_AGE_KEY=$(grep '^AGE-SECRET-KEY-' ~/.config/fnox/age.txt)
fnox set DATABASE_URL "<real value>" --provider age
```

### Plain defaults

`DEMO_APP_PORT` and `DEMO_NODE_ENV` use `default = "..."` —
non-secret config that lives next to the encrypted secrets so
they get loaded together. Override at any layer (env var,
profile, parent `fnox.toml`).

### Custom command leases

`fnox lease create greeting` runs `scripts/mint-greeting.sh`,
parses the JSON it prints, and exposes the result as env vars
for the configured duration. Replace the script with anything:

| Want… | Put this in the script |
| ----- | ----- |
| A short-lived 1Password token | `op item get …` |
| A GitHub App installation token | `gh auth token` or a signed JWT |
| An AWS session from STS | `aws sts assume-role` |
| A credential from your internal CA | `curl https://ca.internal/sign …` |
| A value from macOS Keychain | `security find-generic-password …` |

The credential expires automatically and `fnox lease revoke`
calls the (optional) revoke command.

## Wiring up real providers

The `fnox.toml` has commented-out blocks for 1Password, Vault,
keychain, password-store, AWS STS leases, GitHub App leases,
and Vault dynamic-DB leases. Uncomment one, configure it, then
use `fnox set <KEY> "<reference>" --provider <name>`.

Full provider docs: <https://fnox.jdx.dev/providers/overview.html>

## What it provides

Everything from [fnox](../fnox/) plus:

- `age` — encryption tool (so you can rotate the demo key)
- `gum` — styled terminal UI for the welcome banner

## See also

- [fnox](../fnox/) — minimal environment for `[include]`
- [Upstream site](https://fnox.jdx.dev/) and
  [repo](https://github.com/jdx/fnox)
