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
  pname = "claude-code-plugin-official-agent-sdk-dev";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/agent-sdk-dev"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/agent-sdk-dev/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  meta = {
    description = "Development kit for working with the Claude Agent SDK";
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
