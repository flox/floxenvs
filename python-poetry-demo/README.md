# python-poetry-demo

Demo project showing Python + Poetry with automatic virtual
environment management, powered by the
[python-poetry](../python-poetry) base environment.

## Quick start

```bash
flox activate -d python-poetry-demo
```

On first activation the environment will:

1. Create a Poetry virtual environment
2. Install packages from `poetry.lock`
3. Display a styled welcome banner via gum

## What is included

| Component | Source |
| --------- | ------ |
| Python 3 | python-poetry (included) |
| Poetry | python-poetry (included) |
| gum | demo manifest |
| pyjokes | pyproject.toml / poetry.lock |

## Version customization

Override the Python version in the demo manifest:

```toml
[install]
python3.pkg-path = "python312"
```

Or pin an exact version:

```toml
[install]
python3.pkg-path = "python3"
python3.version = "3.12.2"
```

## Poetry usage

Common commands inside the environment:

```bash
poetry add <package>
poetry install
poetry show
poetry run <script>
```

Packages are installed into a Poetry-managed venv cached
under `$FLOX_ENV_CACHE/python-poetry`, not globally.

## Automatic dependency installation

The `PYTHON_AUTO_INSTALL` variable (default `"true"`)
controls whether `poetry.lock` is installed on activation.
The hook hashes the lockfile and skips installation when
dependencies have not changed.

To disable:

```toml
[vars]
PYTHON_AUTO_INSTALL = "false"
```

## Base environment

This demo includes [python-poetry](../python-poetry) via
the `[include]` directive. The base layer provides the venv
lifecycle, dependency caching, and profile activation. See
its README for full details.
