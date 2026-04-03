# dotenv

Automatically load environment variables from a `.env` file
on Flox activation.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/dotenv"]
```

By default it loads `.env` in the current directory. Override
the file path with:

```toml
[vars]
DOTENV_FILE = ".env.local"
```

## How it works

The `on-activate` hook uses `set -o allexport` and `source`
to export every variable defined in the file. If the file
does not exist the hook is silently skipped.

## Caveats

- The target file must exist at activation time; it is not
  an error if it is missing (the hook simply does nothing).
- Multiline values are not reliably supported with bare
  `source`. Use single-line values or a dedicated parser.
- Comments and inline comments follow standard shell rules.

## See also

- [dotenv-demo](../dotenv-demo/) shows a full working example
  with a welcome banner and sample variables.
