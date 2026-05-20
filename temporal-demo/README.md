# temporal-demo

Full Temporal demo environment with styled terminal
output. Includes the Temporal dev server (via the
minimal [temporal](../temporal/) layer) and `gum` for
formatted usage hints on activation.

For a minimal environment to include in your own
project, see [temporal](../temporal/) or use
`flox/temporal` on FloxHub.

## Quick start

```bash
flox activate -r flox/temporal-demo --start-services
go run ./start World
```

You should see `Workflow result: Hello World` printed
by the starter. The Temporal Web UI is at
<http://127.0.0.1:8233>.

## What this demo includes

- Temporal dev server with built-in Web UI (inherited
  from the [temporal](../temporal/) minimal env)
- A Go worker (`worker/main.go`) running as a flox
  service on `my-task-queue`
- A starter binary (`start/main.go`) that triggers a
  `SayHelloWorkflow`
- A trivial `greeting` Go package showing the
  workflow/activity split
- `gum` for the activation banner
- `jq` for the test harness's worker-readiness probe

## Web UI

After starting services, open the Temporal Web UI:

```text
http://localhost:8233
```

The Web UI lets you browse workflows, view execution
history, and inspect namespace configuration.

## CLI examples

List registered namespaces:

```bash
temporal operator namespace list
```

List workflows in the default namespace:

```bash
temporal workflow list
```

Describe a specific workflow execution:

```bash
temporal workflow describe --workflow-id <id>
```

## Default settings

| Setting | Value |
| ------- | ----- |
| Host | 127.0.0.1 |
| gRPC port | 7233 |
| Web UI port | 8233 |

## Customizing connection settings

Override vars in your own manifest:

```toml
[vars]
TEMPORAL_PORT = "17233"
TEMPORAL_UI_PORT = "18233"
TEMPORAL_HOST = "0.0.0.0"
```

## Data directory

Temporal data is stored in
`$FLOX_ENV_CACHE/temporal`. This persists across
activations. To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/temporal"
```

## Using the minimal version

If you do not need the demo experience, include
the minimal environment in your own manifest:

```toml
[include]
environments = [{ remote = "flox/temporal" }]
```

This gives you the Temporal dev server with sane
defaults. Override vars and add packages in your
own manifest as needed.

## Service management

```bash
flox services start            # start temporal
flox services stop             # stop temporal
flox services status           # check status
flox services logs temporal    # view logs
```
