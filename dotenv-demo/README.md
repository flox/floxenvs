# dotenv-demo

A demonstration environment showing how the
[dotenv](../dotenv/) base layer automatically loads
variables from a `.env` file.

## What it does

On activation this environment:

1. Includes the minimal `dotenv` layer which sources `.env`.
2. Displays a welcome banner (using `gum`) showing how many
   variables were loaded.

## Quick start

```bash
flox activate -d dotenv-demo
```

The sample `.env` ships with the demo so variables are
available immediately.

## Customizing the file path

Override `DOTENV_FILE` in your own manifest to load a
different file:

```toml
[vars]
DOTENV_FILE = ".env.local"
```

## See also

- [dotenv](../dotenv/) -- the minimal base layer.
