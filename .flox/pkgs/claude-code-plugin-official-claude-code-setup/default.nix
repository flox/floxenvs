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
  pname = "claude-code-plugin-official-claude-code-setup";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/claude-code-setup"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/claude-code-setup/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  meta = {
    description = "Analyze codebases and recommend tailored Claude Code automations such as hooks, skills, MCP servers, and subagents.";
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
