# remotion

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fremotion%2Fdevcontainer.json)

Minimal [Remotion](https://remotion.dev) environment. Include
it in your own manifest to get Claude Code, the `flox-agent`
launcher and the Remotion skills plugin, plus Node.js 22 so
`npx create-video`, `npx remotion studio`, and
`npx remotion render` work out of the box. Launch Claude Code
with `flox-agent launch claude` to get the skills loaded.

`ffmpeg`/`ffprobe` are intentionally not installed — Remotion
ships its own via `npx remotion ffmpeg`, which is what the
skill tells Claude to use.

Remotion lets you build videos programmatically with React —
animations, audio, captions, 3D, transitions, charts, and
more.

## Quick start

Activate directly:

```bash
flox activate -r flox/remotion
```

Scaffold a new project and open the studio:

```bash
npx create-video@latest --yes --blank --no-tailwind my-video
cd my-video
npx remotion studio
```

Run `flox-agent launch claude` to start Claude Code with the
`remotion-best-practices` skill injected —
Claude will automatically load it whenever you work with
Remotion code.

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/remotion"]
```

## What is included

- `flox/claude-code` — Claude Code
- `flox/flox-agent` — launcher that loads the bundled skills
  into Claude Code via `flox-agent launch claude`
- `agent-stacks/agent-plugin-remotion-dev-skills` — the
  Remotion skills (best practices, captions, render, studio,
  and more) installed under
  `share/agent-plugins/remotion-dev-skills/`
- `nodejs_22` — for `npx remotion …` and
  `npx create-video@latest`

## What the skill covers

| Topic | Rule files |
| ----- | ---------- |
| Animations & timing | `timing.md`, `text-animations.md`, `transitions.md` |
| Audio & captions | `audio.md`, `voiceover.md`, `display-captions.md`, |
| | `subtitles.md`, `import-srt-captions.md`, |
| | `transcribe-captions.md`, `silence-detection.md` |
| Video sources | `videos.md`, `gifs.md`, `transparent-videos.md`, |
| | `trimming.md` |
| Images & fonts | `images.md`, `google-fonts.md`, `local-fonts.md` |
| 3D & effects | `3d.md`, `lottie.md`, `light-leaks.md`, |
| | `html-in-canvas.md` |
| Maps & charts | `maplibre.md`, `audio-visualization.md` |
| Composition API | `compositions.md`, `sequencing.md`, `parameters.md`, |
| | `calculate-metadata.md` |
| ffmpeg & measurement | `ffmpeg.md`, `measuring-dom-nodes.md`, |
| | `measuring-text.md`, `get-audio-duration.md`, |
| | `get-video-duration.md`, `get-video-dimensions.md` |
| Styling | `tailwind.md` |
| Misc | `sfx.md` |

## See also

For a styled demo with a sample blank project, see
[remotion-demo](../remotion-demo/).

Upstream skill source:
<https://github.com/remotion-dev/skills>

Remotion docs: <https://remotion.dev>
