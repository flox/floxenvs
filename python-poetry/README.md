# python-poetry

Minimal Python + Poetry environment with automatic virtual
environment management. Designed for use as an `[include]`
base layer.

## What it provides

- Python 3 interpreter
- Poetry package manager
- Automatic venv creation via `poetry env use`
- Smart dependency installation from `poetry.lock`

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../python-poetry" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/python-poetry"]
```

## Python version

There are three ways to control the Python version in your
manifest:

1. **Latest available** (default):

   ```toml
   [install]
   python.pkg-path = "python3"
   ```

2. **Specific major.minor**:

   ```toml
   [install]
   python.pkg-path = "python312"
   ```

3. **Exact version pin**:

   ```toml
   [install]
   python.pkg-path = "python3"
   python.version = "3.12.2"
   ```

## Automatic dependency installation

When `PYTHON_AUTO_INSTALL` is `"true"` (the default) and a
`poetry.lock` file exists in the project directory, the hook
runs `poetry install --no-interaction` automatically on
activation.

To skip automatic installation, set the variable in your
manifest:

```toml
[vars]
PYTHON_AUTO_INSTALL = "false"
```

## Dependency caching

The hook computes an MD5 hash of `poetry.lock` and stores it
in the Poetry cache directory. On subsequent activations,
packages are only reinstalled when the hash changes. This
keeps activation fast when dependencies have not changed.

The hash calculation uses `md5sum` on Linux and `md5` on
macOS, so both platforms are supported.

## How the venv works

Poetry manages its own virtual environments. The on-activate
hook calls `poetry env use python3` to create a venv (if one
does not exist), then activates it with the standard
`bin/activate` script. The profile section re-activates the
venv in each shell so the prompt and PATH stay correct.

A `pyproject.toml` must exist in the project directory for
any of this to take effect. When used standalone (without a
project), the hook safely skips venv creation.

## See also

- [python-poetry-demo](../python-poetry-demo) -- demo
  project that includes this environment and adds sample
  dependencies
