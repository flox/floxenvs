# python-pip

Minimal Python + pip environment with automatic virtual environment
management. Designed for use as an `[include]` base layer.

## What it provides

- Python 3 interpreter
- pip package manager
- Automatic venv creation and activation
- Smart dependency installation from `requirements.txt`

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = [
  { dir = "../python-pip" }
]
```

Or from FloxHub:

```toml
[include]
environments = ["flox/python-pip"]
```

## Python version

There are three ways to control the Python version in your
manifest:

1. **Latest available** (default):

   ```toml
   [install]
   python3.pkg-path = "python3"
   ```

2. **Specific major.minor**:

   ```toml
   [install]
   python3.pkg-path = "python312"
   ```

3. **Exact version pin**:

   ```toml
   [install]
   python3.pkg-path = "python3"
   python3.version = "3.12.2"
   ```

## Automatic dependency installation

When `PYTHON_AUTO_INSTALL` is `"true"` (the default) and a
`requirements.txt` file exists in the project directory, the
hook runs `pip install -r requirements.txt` automatically on
activation.

To skip automatic installation, set the variable in your
manifest:

```toml
[vars]
PYTHON_AUTO_INSTALL = "false"
```

## Dependency caching

The hook computes an MD5 hash of `requirements.txt` and stores
it inside the venv. On subsequent activations, packages are
only reinstalled when the hash changes. This keeps activation
fast when dependencies have not changed.

The hash calculation uses `md5sum` on Linux and `md5` on macOS,
so both platforms are supported.

## Venv interpreter tracking

If the Python interpreter path changes (e.g. after a Nix
update), the venv is automatically recreated to stay in sync.

## See also

- [python-pip-demo](../python-pip-demo) -- demo project that
  includes this environment and adds sample dependencies
