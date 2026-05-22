{
  stdenv,
  lib,
  fetchFromGitHub,
  ffmpeg-headless,
  perl,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version commit srcHash;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-hyperframes";
  inherit version;

  src = fetchFromGitHub {
    owner = "heygen-com";
    repo = "hyperframes";
    rev = commit;
    hash = srcHash;
  };

  nativeBuildInputs = [ perl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/hyperframes"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships 15 skill folders under skills/ and a complete
    # .claude-plugin/{plugin.json,marketplace.json} pair. Copy both
    # verbatim — no manifest synthesis needed (unlike
    # claude-code-plugin-remotion). Claude Code reads
    # .claude-plugin/plugin.json to discover the plugin and recurses
    # into skills/ to advertise each as a slash command.
    cp -r "$src/skills" "$PLUGIN_DIR/skills"
    cp -r "$src/.claude-plugin" "$PLUGIN_DIR/.claude-plugin"
    chmod -R u+w "$PLUGIN_DIR"

    # Nix-lock command-context references to ffmpeg / ffprobe so the
    # skill content points the agent at the exact ffmpeg-headless build
    # pulled into this derivation's closure, not whichever `ffmpeg`
    # happens to be on PATH. The lookahead `(?=[\s",)])` restricts
    # the substitution to executable positions (followed by space,
    # closing quote, comma, or close-paren) — so we don't mangle
    # filename uses like `$OUTDIR/ffmpeg.stderr`, the `ffmpeg/ffprobe`
    # error-message slug, or possessives like `ffmpeg's filter`.
    find "$PLUGIN_DIR" -type f \
        \( -name '*.md' -o -name '*.sh' -o -name '*.py' \) -print0 \
      | xargs -0 perl -i -pe '
          s{\bffmpeg(?=[\s",)])}{${ffmpeg-headless}/bin/ffmpeg}g;
          s{\bffprobe(?=[\s",)])}{${ffmpeg-headless}/bin/ffprobe}g;
        '

    runHook postInstall
  '';

  meta = {
    description =
      "HyperFrames skill bundle for Claude Code — 15 skills covering "
      + "HTML compositions, GSAP/Anime.js/CSS/Lottie/Three.js/WAAPI "
      + "animation adapters, Tailwind, captions, TTS, transcription, "
      + "website-to-video, and Remotion-to-HyperFrames translation.";
    homepage = "https://github.com/heygen-com/hyperframes";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
