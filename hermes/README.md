# hermes

Minimal Hermes Agent environment. Provides the
[`hermes`](https://github.com/NousResearch/hermes-agent) CLI
from Nous Research — a self-improving AI agent with skill
creation, persistent memory, and messaging gateway support
(Telegram, Discord, Slack, ...).

## Quick start

Activate directly:

```bash
flox activate -r flox/hermes
hermes setup     # interactive wizard
hermes           # start chatting
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/hermes"]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `flox/hermes-agent` | The `hermes` CLI (Python 3.13 venv) |
| `ripgrep` | Required by hermes' shell tools |
| `ffmpeg` | Required for voice-memo transcription |
| `git` | Required by hermes' git-aware tools |
| `nodejs_22` | Required by some MCP servers |

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `HERMES_HOME` | `$FLOX_ENV_CACHE/hermes` | Config / skills / memory root |

Override `HERMES_HOME` in your own manifest before
`[include]`-ing this environment if you want a shared
location across envs.

## Lazy installs are disabled

Upstream's
[`tools/lazy_deps.py`](https://github.com/NousResearch/hermes-agent/blob/main/tools/lazy_deps.py)
runs `pip install` on first use of opt-in backends
(`anthropic`, `exa`, `firecrawl`, `faster-whisper`,
`matrix`, ...). The Nix-built venv is read-only, so the
activation hook seeds `$HERMES_HOME/config.yaml` with:

```yaml
security:
  allow_lazy_installs: false
```

Picking a lazy-only provider will fail with a
`FeatureUnavailable` error and a remediation hint. If you
need one of those backends, fall back to the
[upstream installer](https://github.com/NousResearch/hermes-agent#quick-install),
or open an issue asking us to bundle the extra in
`hermes-agent[all]`.

## Migrating from OpenClaw

Hermes is the successor to OpenClaw. To migrate settings,
memories, and skills:

```bash
hermes claw migrate --dry-run   # preview
hermes claw migrate             # apply
```

See
[`hermes claw migrate --help`](https://hermes-agent.nousresearch.com/docs/)
for all options.

## See also

- [hermes-demo](../hermes-demo/) — interactive demo
  environment with a welcome banner
- [Upstream docs](https://hermes-agent.nousresearch.com/docs/)
- [Upstream repo](https://github.com/NousResearch/hermes-agent)
