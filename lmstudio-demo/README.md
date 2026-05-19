# lmstudio-demo

Interactive variant of [lmstudio](../lmstudio/) with a
gum-styled onboarding banner. Shows the activation
flow, model download, and how to point an agentic CLI
at the local API.

**Requires the same GPU as
[lmstudio](../lmstudio/).** Platforms:
aarch64-darwin (Apple Silicon),
aarch64-linux, x86_64-linux.

## Quick start

```bash
flox activate -r flox/lmstudio-demo
```

You should see a styled banner with the next steps:

1. `flox services start` — bring up the API server.
2. `lms get qwen2.5-7b-instruct` — download a model.
3. `lms load qwen2.5-7b-instruct` — load it.
4. `lms-launch claude --model qwen2.5-7b-instruct` —
   launch Claude Code against the local model
   (requires the `claude` CLI on `$PATH`).

## What's different from lmstudio

- Adds [gum](https://github.com/charmbracelet/gum) for
  the welcome banner.
- Same `lms`, `lm-studio`, `lms-service`,
  `lmstudio-health`, `lms-launch`, `lmstudio-info`
  binaries.
- Same configuration variables (see
  [lmstudio README](../lmstudio/README.md#configuration-variables)).

## See also

- [lmstudio](../lmstudio/) — minimal `[include]` layer.
- LM Studio upstream: <https://lmstudio.ai/>
