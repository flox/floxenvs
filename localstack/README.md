# localstack

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Flocalstack%2Fdevcontainer.json)

Minimal LocalStack environment for use with Flox
`[include]`.

## Usage

Include this environment in your project manifest:

```toml
[include]
environments = [{ remote = "flox/localstack" }]
```

Activate and start the service:

```bash
flox activate -- flox services start
```

## What's included

- LocalStack
- Python 3 with a managed venv
- AWS CLI v2 + `awscli-local` (pip)
- kubectl

## Data directory

All data is stored under
`$FLOX_ENV_CACHE/localstack/`. Delete that directory
to reinitialize from scratch.

## See also

- [localstack-demo](../localstack-demo) -- demo
  project that includes this environment
