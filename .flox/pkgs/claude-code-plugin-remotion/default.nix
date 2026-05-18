{
  stdenv,
  lib,
  fetchFromGitHub,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version commit srcHash;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-remotion";
  inherit version;

  src = fetchFromGitHub {
    owner = "remotion-dev";
    repo = "skills";
    rev = commit;
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/remotion"
    mkdir -p "$PLUGIN_DIR/skills"

    # Upstream layout is `skills/remotion/` with SKILL.md + rules/
    # and a handful of .tsx asset examples. Copy the whole skill
    # tree verbatim — Claude Code reads SKILL.md frontmatter
    # to advertise it as `remotion-best-practices`.
    cp -r "$src/skills/remotion" "$PLUGIN_DIR/skills/remotion"
    chmod -R u+w "$PLUGIN_DIR"

    # Upstream ships no .claude-plugin/plugin.json — the canonical
    # consumer is `npx remotion skills add`, which drops skill folders
    # straight into the user's project at `.claude/skills/`. We're
    # shipping the same content as a Claude Code plugin, so synthesize
    # the manifest Claude Code expects. Fields mirror upstream's Codex
    # plugin manifest (packages/codex-plugin/.codex-plugin/plugin.json)
    # in the remotion-dev/remotion monorepo.
    mkdir -p "$PLUGIN_DIR/.claude-plugin"
    cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<JSON
    {
      "name": "remotion",
      "version": "${version}",
      "description": "Remotion video creation skills — best practices, animations, audio, captions, 3D, and more for building programmatic videos with React.",
      "homepage": "https://remotion.dev",
      "repository": "https://github.com/remotion-dev/skills",
      "license": "MIT",
      "keywords": [
        "remotion",
        "video",
        "react",
        "animation",
        "composition",
        "rendering",
        "ffmpeg",
        "captions",
        "audio"
      ]
    }
    JSON

    runHook postInstall
  '';

  meta = {
    description =
      "Remotion best-practices plugin for Claude Code — 1 skill, "
      + "30+ topic rules covering animations, audio, captions, 3D, "
      + "transitions, and more for programmatic video creation in React.";
    homepage = "https://github.com/remotion-dev/skills";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
