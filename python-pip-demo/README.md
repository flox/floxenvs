# python-pip-demo

Demo project showing Python + pip with automatic virtual
environment management, powered by the
[python-pip](../python-pip) base environment.

## Quick start

```bash
flox activate -d python-pip-demo
```

On first activation the environment will:

1. Create a virtual environment
2. Install packages from `requirements.txt`
3. Display a styled welcome banner via gum

## What is included

| Component | Source |
| --------- | ------ |
| Python 3 | python-pip (included) |
| pip + venv | python-pip (included) |
| gum | demo manifest |
| pyjokes | requirements.txt |

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

## pip usage

Common commands inside the environment:

```bash
pip install <package>
pip install -r requirements.txt
pip list
pip freeze > requirements.txt
```

Packages are installed into the managed venv at
`$FLOX_ENV_CACHE/python-pip/venv`, not globally.

## Automatic dependency installation

The `PYTHON_AUTO_INSTALL` variable (default `"true"`) controls
whether `requirements.txt` is installed on activation. The
hook hashes the file and skips installation when dependencies
have not changed.

To disable:

```toml
[vars]
PYTHON_AUTO_INSTALL = "false"
```

## Base environment

This demo includes [python-pip](../python-pip) via the
`[include]` directive. The base layer provides the venv
lifecycle, dependency caching, and profile activation. See
its README for full details.
