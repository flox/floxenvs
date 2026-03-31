# colima

Minimal Colima environment. Include it in your own manifest
to get a working container runtime with Docker CLI.

## Quick start

Activate directly:

```bash
flox activate -r flox/colima --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/colima"]
```

## Defaults

| Setting | Value |
| ------- | ----- |
| Runtime | Colima (Lima-based containers) |
| CLI | Docker client |
| VM backend | Default (QEMU or Virtualization.framework) |

## Usage

Once the service is running:

```bash
docker run hello-world
docker ps
docker images
```

## Customizing

Override settings in your own manifest as needed. For
example, to add docker-compose:

```toml
[install]
docker-compose.pkg-path = "docker-compose"
```

## See also

For a full setup with container management TUIs
(lazydocker, oxker, ctop, dive), see
[colima-demo](../colima-demo/).
