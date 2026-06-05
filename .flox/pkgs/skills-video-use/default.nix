{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  python3,
  ffmpeg,
  manim,
  texliveMedium,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # Everything the helpers import. timeline_view deliberately avoids
  # librosa (wave + ffmpeg fallback), so requests/numpy/pillow is the
  # complete set at this pin.
  pythonEnv = python3.withPackages (ps: [
    ps.requests
    ps.numpy
    ps.pillow
  ]);
  py = "${pythonEnv}/bin/python3";

  # The manim-video sub-skill drives the Manim CE engine. Bundle a TeX
  # distribution carrying the packages Manim's MathTex/Tex templates and
  # the dvisvgm step need, so equation rendering works headless. The
  # skill is consumed by installing this package into a flox env, so the
  # `manim` wrapper we drop in $out/bin lands on PATH — which is exactly
  # how the sub-skill invokes it (`manim -ql script.py Scene`).
  texEnv = texliveMedium.withPackages (ps: [
    ps.standalone
    ps.preview
    ps.doublestroke
    ps.dvisvgm
  ]);

  src = fetchFromGitHub {
    owner = "browser-use";
    repo = "video-use";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-video-use";
  version = data.version;
  inherit src;

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Bundle the Manim engine on PATH for the manim-video sub-skill:
    # the real manim plus a TeX distro and ffmpeg for MathTex + dvisvgm
    # + scene stitching. Lands in $out/bin, which is on PATH once the
    # package is installed into the consumer's flox env.
    mkdir -p "$out/bin"
    makeWrapper "${manim}/bin/manim" "$out/bin/manim" \
      --prefix PATH : "${lib.makeBinPath [ texEnv ffmpeg ]}"

    # video-use is a directory skill: SKILL.md references its helpers
    # by bare name (`transcribe.py <video>`), so the whole repo tree
    # must ship together with SKILL.md at the root. The optional Manim
    # engine lives at skills/manim-video; expose it as a first-class
    # sibling skill too. Ship into every agent skills dir we support.
    for share in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$share/video-use"
      cp -r "$src"/. "$share/video-use/"
      chmod -R u+w "$share/video-use"

      mkdir -p "$share/manim-video"
      cp -r "$src/skills/manim-video"/. "$share/manim-video/"
      chmod -R u+w "$share/manim-video"
    done

    runHook postInstall
  '';

  # Make the Python helpers self-contained so they run correctly no
  # matter how the agent launches them, with no host PATH assumptions:
  #
  #   1. Shebang -> the bundled interpreter (which carries requests,
  #      numpy, pillow). A shebang is a comment, so it is legal even
  #      ahead of the helpers' `from __future__` imports.
  #   2. A re-exec shim right after `from __future__` re-launches the
  #      script under the bundled interpreter when it was started as
  #      `python helpers/x.py` with some other Python — before any
  #      third-party import can fail.
  #   3. The bare "ffmpeg"/"ffprobe" subprocess literals are rewritten
  #      to absolute store paths, so they resolve without PATH and nix
  #      records ffmpeg in the package closure automatically.
  #
  # The SKILL.md / install.md prose is patched to drop the now-stale
  # "install ffmpeg / uv sync" steps and tell the agent the helpers are
  # executable and self-contained.
  postInstall = ''
    for skill in "$out"/share/*/skills/video-use; do
      helpers="$skill/helpers"

      for f in "$helpers"/*.py; do
        substituteInPlace "$f" \
          --replace-quiet '"ffmpeg"'  '"${ffmpeg}/bin/ffmpeg"' \
          --replace-quiet '"ffprobe"' '"${ffmpeg}/bin/ffprobe"'

        awk -v py="${py}" '
          NR == 1 { print "#!" py }
          { print }
          /^from __future__ import/ && !shim {
            print "import os as _os, sys as _sys"
            print "_PY = \"" py "\""
            print "if _os.path.realpath(_sys.executable) != _os.path.realpath(_PY) and _os.path.exists(_PY):"
            print "    _os.execv(_PY, [_PY] + _sys.argv)"
            shim = 1
          }
        ' "$f" > "$f.wired"
        mv "$f.wired" "$f"
        chmod +x "$f"
      done

      # Reflect the packaged reality in the prose the agent reads.
      substituteInPlace "$skill/SKILL.md" \
        --replace-quiet \
          '- `ffmpeg` + `ffprobe` on PATH.' \
          '- `ffmpeg` + `ffprobe` are bundled with this package (the helpers call them by absolute path) — nothing to install.' \
        --replace-quiet \
          '- Python deps installed (`uv sync` or `pip install -e .` inside the repo).' \
          '- Python deps (requests, numpy, pillow) are bundled — the helpers are executable and self-contained. Run them directly (e.g. `"$SKILL_DIR"/helpers/transcribe.py <video>`), not via `python`.'

      # install.md describes a manual clone/brew/pip flow that does not
      # apply to the flox package. Prepend a note so the agent skips it.
      note="$skill/.install-note.md"
      cat > "$note" <<'MD'
> **Packaged via flox (`flox/skills-video-use`).** The clone, `uv sync`,
> `pip install`, and `brew install ffmpeg` steps below are NOT needed:
> ffmpeg/ffprobe and the Python deps (requests, numpy, pillow) are bundled
> and the helpers are self-contained executables. You still need an
> `ELEVENLABS_API_KEY` for transcription. Optional, install on first use
> only: `yt-dlp` (URL downloads), Node.js + `npx` (HyperFrames / Remotion
> slots), Manim + LaTeX (manim-video slots). Subtitle burn-in uses libass;
> on a headless host install a font (e.g. DejaVu) or pass an available
> `FontName` if Helvetica is missing.

MD
      cat "$skill/install.md" >> "$note"
      mv "$note" "$skill/install.md"
    done

    # The Manim engine is bundled on PATH; reflect that in every copy of
    # the manim-video prereqs (it ships both as a top-level sibling skill
    # and nested under video-use/skills/manim-video).
    for md in "$out"/share/*/skills/manim-video/SKILL.md \
              "$out"/share/*/skills/video-use/skills/manim-video/SKILL.md; do
      substituteInPlace "$md" \
        --replace-quiet \
          'Run `scripts/setup.sh` to verify all dependencies. Requires: Python 3.10+, Manim Community Edition v0.20+ (`pip install manim`), LaTeX (`texlive-full` on Linux, `mactex` on macOS), and ffmpeg. Reference docs tested against Manim CE v0.20.1.' \
          'Manim CE v0.20.1, a bundled TeX distribution (for `MathTex`/`Tex` via dvisvgm), and ffmpeg are bundled with this package — the `manim` command is on PATH, nothing to install. `scripts/setup.sh` still works as a sanity check.'
    done
  '';

  meta = {
    description =
      "video-use skill for Claude Code — edit raw footage into a "
      + "finished cut by conversation: transcribe, cut on word "
      + "boundaries, color grade, fade, burn subtitles, and generate "
      + "overlay animations. Python helpers ship wired to a bundled "
      + "interpreter (requests/numpy/pillow) and ffmpeg. Includes the "
      + "manim-video engine sub-skill.";
    homepage = "https://github.com/browser-use/video-use";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
