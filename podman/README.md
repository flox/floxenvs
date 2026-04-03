# Podman

Minimal Podman environment providing rootless containers.

## Usage

Include this environment in your own manifest:

```toml
[include]
environments = ["flox/podman"]
```

## What's included

- **podman** -- rootless container engine
- **podman-compose** -- docker-compose compatible tool
- **qemu** -- virtual machine support (macOS only)

## Notes

### macOS

Podman on macOS needs a Linux virtual machine. After
activating the environment, run:

```sh
podman machine init
podman machine start
```

### Linux

A containers `policy.json` is created automatically in
`~/.config/containers/` on first activation if one does
not already exist.

### docker-compose compatibility

Use `podman-compose` as a drop-in replacement for
`docker-compose`. It reads the same `compose.yaml` files.

## Demo

See [podman-demo/](../podman-demo/) for an interactive
demo environment with additional tools.
