{
  lib,
  stdenvNoCC,
  agent-deck,
  python3,
}:
stdenvNoCC.mkDerivation {
  pname = "skills-agent-deck";
  inherit (agent-deck) version;
  inherit (agent-deck) src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ python3 ];

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills"; do
      mkdir -p "$dest"
      cp -r "$src/skills/." "$dest/"
    done

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "agent-deck" "$out/share"
    patchShebangs "$out/share/flox"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
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
