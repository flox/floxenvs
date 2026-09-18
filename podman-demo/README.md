# Podman Demo

Interactive demo environment built on the minimal
[podman/](../podman/) base layer.

## Usage

```sh
cd podman-demo
flox activate
```

## What's included

Everything from the base `podman` environment, plus:

- **gum** -- interactive prompts and styled output
- **undocker** -- extract container images to a directory
- **podman-tui** -- terminal UI for managing containers

## Behaviour

### Activation output

The environment description lists available commands.
On activation a styled box shows the Podman version;
that hook output is suppressed when `FLOX_ENVS_TESTING=1`.

### macOS VM stop on exit

When running on macOS, exiting the shell triggers a
confirmation prompt asking whether to stop the Podman
virtual machine. This is also suppressed during testing.

## Minimal environment

For a lighter setup without the demo tools, use the
[podman/](../podman/) environment directly.
