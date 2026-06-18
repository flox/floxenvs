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
  pname = "skills-official-learning-output-style";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ flox-agent-layout ];

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/learning-output-style"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/learning-output-style/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  postInstall = ''
    flox-agent-layout --plugin learning-output-style --share "$out/share"
  '';

  meta = {
    description = "Interactive learning mode that requests meaningful code contributions at decision points (mimics the unshipped Learning output style)";
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
