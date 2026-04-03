# Ruby

Minimal Ruby environment providing the Ruby interpreter
and Bundler, designed for use as an `[include]` base in
other Flox environments.

## What is included

- `ruby` -- interpreter and standard library
- `bundle` -- gem dependency manager (ships with Ruby)

## Usage

Activate directly:

```bash
flox activate -r flox/ruby
```

Or include it in your own manifest:

```toml
[include]
environments = ["flox/ruby"]
```

## Package groups

Ruby belongs to the `ruby` pkg-group. When pinning a
version, set it on the same group:

```toml
[install]
ruby.pkg-path = "ruby"
ruby.pkg-group = "ruby"
ruby.version = "3.3.4"
```

## Environment variables

| Variable | Description |
| -------- | ------------------------------------ |
| `RUBY_CACHE` | Set to `$FLOX_ENV_CACHE/ruby` |
| `BUNDLE_PATH` | Gem install path inside cache |
| `RUBY_AUTO_INSTALL` | Auto-install gems on activate |

## Automatic gem installation

When `RUBY_AUTO_INSTALL` is `"true"` (the default) and
both `Gemfile` and `Gemfile.lock` are present, the
on-activate hook runs `bundle install` automatically.
A SHA-256 hash of the two files is cached so subsequent
activations skip the install when nothing has changed.

To disable automatic installation:

```toml
[vars]
RUBY_AUTO_INSTALL = "false"
```

## Native extension packages

This base layer intentionally ships only Ruby itself.
If your gems require native extensions (e.g. nokogiri,
pg, mysql2, mini_magick), add the necessary build tools
in your own manifest:

```toml
[install]
gcc-unwrapped.pkg-path = "gcc-unwrapped"
libxml2.pkg-path = "libxml2"
openssl.pkg-path = "openssl"
pkg-config.pkg-path = "pkg-config"
```

## See also

For a full development environment with a sample app
and bundled gems, see [ruby-demo](../ruby-demo/).
