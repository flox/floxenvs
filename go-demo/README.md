# Go Demo

Full Go development environment with editor tooling,
a task runner, and a sample "Hello World" application.

Builds on the minimal [go](../go/) environment via
`[include]`.

## Quick start

```bash
flox activate
go build && ./hello
```

## Included tools

| Tool           | Description                          |
| -------------- | ------------------------------------ |
| `go`           | Compiler and standard toolchain      |
| `gopls`        | Official Go language server          |
| `gotools`      | Standard tools (`goimports`, etc.)   |
| `gomodifytags` | Struct tag modifier                  |
| `gotests`      | Test generator                       |
| `gore`         | Go REPL                             |
| `go-task`      | Task runner (Taskfile.yml)           |
| `gum`          | Terminal UI for scripts              |

## Sample application

The included `main.go` prints a localized greeting
using `rsc.io/quote`:

```bash
go build -o hello
./hello
```

## Customization

Fork this environment and edit
`.flox/env/manifest.toml` to add or remove tools.
The `[include]` directive pulls in the base Go
compiler from `../go`.

## Minimal environment

If you only need the Go compiler without editor
tooling, use [go](../go/) directly or include it
in your own manifest:

```toml
[include]
environments = ["flox/go"]
```
