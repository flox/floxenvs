# nginx

Minimal Nginx environment. Include it in your own manifest
to get a working web server with sane defaults.

## Quick start

Activate directly:

```bash
flox activate -r flox/nginx --start-services
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/nginx"]
```

Then customize in your own manifest as needed -- override
vars, change the document root, or add upstream proxying.

## Defaults

| Setting | Value |
| ------- | ----- |
| Port | 18181 |
| Document root | `$FLOX_ENV_CACHE/www` |
| Worker processes | 1 |
| Worker connections | 1024 |
| Config | `$FLOX_ENV_CACHE/nginx/nginx.conf` |

## Customizing

Override these vars in your own manifest:

```toml
[vars]
NGINX_PORT = "18080"
NGINX_WWW_DIR = "./public"
NGINX_WORKER_PROCESSES = "4"
NGINX_WORKER_CONNECTIONS = "2048"
```

Set `NGINX_WWW_DIR` to point at your own document root.
When left empty, it defaults to `$FLOX_ENV_CACHE/www`
with a sample `index.html`.

## See also

For an interactive setup with curl and gum, see
[nginx-demo](../nginx-demo/).
