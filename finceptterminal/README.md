# finceptterminal

Minimal Fincept Terminal environment. Fincept Terminal is a
native Qt 6 / C++20 desktop application for financial analytics,
investment research, and economic data — built from upstream
source with a fully Nix-derived Python 3.11 runtime.

**Requires a graphical session** — X11 or Wayland on Linux,
native on macOS. The headless API server / "service" pattern the
rest of floxenvs uses does **not** apply to this env.

**Platforms:** `aarch64-darwin`, `x86_64-linux`. No
`x86_64-darwin` build — upstream ships no Intel-Mac binary. No
`aarch64-linux` build — the upstream Python dep `pyqlib==0.9.7`
has no arm64 wheel and we don't currently maintain an sdist
build path for it.

## Quick start

Activate directly:

```bash
flox activate -r flox/finceptterminal
finceptterminal
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/finceptterminal"]
```

## What is included

| Command | Description |
| ------- | ----------- |
| `finceptterminal` | Launch the Qt desktop app. |

The wrapper sets `FINCEPT_INSTALL_DIR` and `QT_PLUGIN_PATH` so
the binary picks up the pre-built Python venv and Qt plugins
from the Nix store.

## Configuration variables

<!-- markdownlint-disable MD013 -->
| Variable | Default | Description |
| -------- | ------- | ----------- |
| `FINCEPT_DATA_DIR` | `$FLOX_ENV_CACHE/finceptterminal` | Per-user profile, logs, downloaded model files. Maps to `XDG_DATA_HOME`. |
| `FINCEPT_INSTALL_DIR` | `<store>/share/finceptterminal/install-dir` | Where the app reads its UV / Python bootstrap state. Override only when you know what you're doing. |
<!-- markdownlint-enable MD013 -->

Override any of these in your own manifest before
`[include]`-ing this environment.

## How the Python runtime works

Fincept Terminal v4 normally downloads UV and `uv pip install`s
~70 Python packages on first launch (5-10 minutes). This env
**pre-builds** that environment via Nix and points the running
binary at it through two small upstream patches:

- `AppPaths::root()` honors `FINCEPT_INSTALL_DIR` when set.
- `PythonSetupManager::check_status()` short-circuits the UV
  bootstrap when a `.fincept-nix-managed` sentinel exists.

The result: first launch goes straight to the main window.

## License

Fincept Terminal is dual-licensed under **AGPL-3.0** and a
**commercial license**. The AGPL terms apply to source +
derivative work; **commercial use requires a paid license** from
Fincept Corporation. See
<https://github.com/Fincept-Corporation/FinceptTerminal/blob/main/docs/COMMERCIAL_LICENSE.md>.

This flox env packages the AGPL-3.0 source build. We make no
representations about commercial fitness.

## See also

For an interactive walkthrough, see
[finceptterminal-demo](../finceptterminal-demo/).

Upstream: <https://github.com/Fincept-Corporation/FinceptTerminal>
