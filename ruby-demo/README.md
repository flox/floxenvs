# Ruby Demo

Full Ruby development environment with a sample app
and bundled gems. Builds on the minimal
[ruby](../ruby/) environment via `[include]`.

## Quick start

```bash
flox activate
ruby test.rb
```

## Included tools

| Tool | Description |
| ---- | ------------------------------------ |
| `ruby` | Interpreter and standard library |
| `bundle` | Gem dependency manager |
| `gum` | Terminal UI for scripts |

## Sample application

The included `test.rb` uses the `colorize` gem to
print a greeting:

```bash
bundle exec ruby test.rb
```

## Automatic gem installation

The base layer sets `RUBY_AUTO_INSTALL=true` by
default. When both `Gemfile` and `Gemfile.lock` are
present, gems are installed automatically on activate.
A hash-based cache ensures subsequent activations are
fast.

To disable:

```toml
[vars]
RUBY_AUTO_INSTALL = "false"
```

## Customization

Fork this environment and edit
`.flox/env/manifest.toml` to add or remove packages.
The `[include]` directive pulls in the base Ruby
interpreter from `../ruby`.

## Minimal environment

If you only need the Ruby interpreter without demo
tooling, use [ruby](../ruby/) directly or include it
in your own manifest:

```toml
[include]
environments = ["flox/ruby"]
```
