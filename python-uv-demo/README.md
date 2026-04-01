# python-uv-demo

Demo project showing Python + uv with automatic virtual
environment management, powered by the
[python-uv](../python-uv) base environment.

## Quick start

```bash
flox activate -d python-uv-demo
```

On first activation the environment will:

1. Create a virtual environment
2. Install packages from `uv.lock`
3. Display a styled welcome banner via gum

## What is included

| Component | Source |
| --------- | ------ |
| Python 3 | python-uv (included) |
| uv | python-uv (included) |
| gum | demo manifest |
| pyjokes | pyproject.toml / uv.lock |

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

## uv usage

Common commands inside the environment:

```bash
uv add <package>
uv sync
uv run <script>
uv pip list
```

Packages are installed into the managed venv at
`$FLOX_ENV_CACHE/python-uv/venv`, not globally.

## Automatic dependency installation

The `PYTHON_AUTO_INSTALL` variable (default `"true"`)
controls whether `uv.lock` is synced on activation. The
hook hashes the lockfile and skips installation when
dependencies have not changed.

To disable:

```toml
[vars]
PYTHON_AUTO_INSTALL = "false"
```

## Base environment

This demo includes [python-uv](../python-uv) via the
`[include]` directive. The base layer provides the venv
lifecycle, dependency caching, and profile activation. See
its README for full details.
