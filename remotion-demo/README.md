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

# Launch Claude with this env's skills and rules injected.
# First install Claude Code (e.g. `flox install
# flox/claude-code`) or use your own install, then run the
# launcher below. The remotion-best-practices skill is
# registered, so whenever you ask Claude to touch Remotion
# code it auto-loads with the topic rules (animations, audio,
# captions, 3D, transitions, etc.).
flox-ai launch claude
```

## What's added on top of `flox/remotion`

- `gum` — styled banner during `on-activate`

Everything else (Node.js 22, ffmpeg, the `flox-ai` launcher,
and the `skills-remotion` plugin) comes from the
included [remotion](../remotion) environment. Claude Code is
not bundled — install it yourself, then start it with
`flox-ai launch claude`.

## See also

- [remotion](../remotion) — minimal env meant for
  `[include]` in your own projects
- Upstream skill source:
  <https://github.com/remotion-dev/skills>
- Remotion docs: <https://remotion.dev>
