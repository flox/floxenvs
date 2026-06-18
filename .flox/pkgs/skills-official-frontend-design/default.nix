{ stdenvNoCC, lib, fetchFromGitHub, flox-agent-layout }:

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
  pname = "skills-official-frontend-design";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ flox-agent-layout ];

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/frontend-design"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/frontend-design/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  postInstall = ''
    flox-agent-layout --plugin frontend-design --share "$out/share"
  '';

  meta = {
    description = "Create distinctive, production-grade frontend interfaces with high design quality. Generates creative, polished code that avoids generic AI aesthetics.";
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
