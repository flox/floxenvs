# remotion-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fremotion-demo%2Fdevcontainer.json)

Demo variant of [remotion](../remotion) — adds `gum` for a
styled welcome banner with quick-start commands.

## Quick start

```bash
flox activate -r flox/remotion-demo
```

The banner prints the canonical bootstrap commands for a new
Remotion project. From here:

```bash
# Scaffold a fresh blank project (npm)
npx create-video@latest --yes --blank --no-tailwind my-video
cd my-video

# Open the visual editor
npx remotion studio

# Render to MP4
npx remotion render

# Open Claude Code — the remotion-best-practices skill is
# already registered. Whenever you ask Claude to touch
# Remotion code, the skill auto-loads with the topic rules
# (animations, audio, captions, 3D, transitions, etc.).
claude
```

## What's added on top of `flox/remotion`

- `gum` — styled banner during `on-activate`

Everything else (Node.js 22, ffmpeg, Claude Code, and the
`claude-code-plugin-remotion` plugin) comes from the
included [remotion](../remotion) environment.

## See also

- [remotion](../remotion) — minimal env meant for
  `[include]` in your own projects
- Upstream skill source:
  <https://github.com/remotion-dev/skills>
- Remotion docs: <https://remotion.dev>
