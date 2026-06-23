{ stdenvNoCC, lib, fetchFromGitHub }:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-anthropic-cwc-makers";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/cwc-makers"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/cwc-makers/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "cwc-makers" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description = "Onboard a Code-with-Claude Makers Cardputer with one /maker-setup command — clones the build-with-claude repo, flashes UIFlow firmware, and installs the Claude Buddy app bundle.";
    homepage =
      "https://github.com/anthropics/claude-plugins-official";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
