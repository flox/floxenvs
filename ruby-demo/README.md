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

## Native extension packages

The base `ruby` layer ships only the interpreter.
If your gems need native extensions, add build
tools in your manifest. Common packages:

```toml
[install]
# C compiler for native extensions
gcc-unwrapped.pkg-path = "gcc-unwrapped"
gnumake.pkg-path = "gnumake"
binutils.pkg-path = "binutils"
pkg-config.pkg-path = "pkg-config"

# XML parsing (nokogiri)
libxml2.pkg-path = "libxml2"
libxslt.pkg-path = "libxslt"

# Crypto (net-ssh, jwt, etc.)
openssl.pkg-path = "openssl"

# YAML parsing
libyaml.pkg-path = "libyaml"

# Database clients
postgresql.pkg-path = "postgresql"    # pg gem
libmysqlclient.pkg-path = "libmysqlclient"  # mysql2

# Image processing (mini_magick, rmagick)
imagemagick.pkg-path = "imagemagick"

# Linux only
glibc.pkg-path = "glibc"
glibc.systems = ["x86_64-linux", "aarch64-linux"]
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
