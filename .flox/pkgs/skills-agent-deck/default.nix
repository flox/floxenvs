{
  lib,
  stdenvNoCC,
  agent-deck,
}:
stdenvNoCC.mkDerivation {
  pname = "skills-agent-deck";
  inherit (agent-deck) version;
  inherit (agent-deck) src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$dest"
      cp -r "$src/skills/." "$dest/"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Skills bundled with agent-deck (agent-deck, session-share) "
      + "for Claude Code and OpenCode.";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    inherit (agent-deck.meta) license;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
