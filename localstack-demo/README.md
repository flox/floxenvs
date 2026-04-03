# localstack-demo

Full LocalStack demo environment with styled terminal
output and service management.

For a minimal environment to include in your own project,
see [localstack](../localstack/) or use `flox/localstack`
on FloxHub.

## Quick start

```bash
flox activate -r flox/localstack-demo --start-services
```

## What this demo includes

- LocalStack
- AWS CLI v2 + `awscli-local`
- kubectl
- `gum` for styled terminal output
- Automatic venv setup on first activation
- Service definition for background LocalStack

## Check available services

```bash
localstack status services
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/localstack"]
```

This gives you LocalStack with sane defaults. Override
vars and add packages in your own manifest as needed.

## Service management

```bash
flox services start         # start localstack
flox services stop          # stop localstack
flox services status        # check status
flox services logs localstack  # view logs
```
