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
  pname = "skills-anthropic-pr-review-toolkit";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ flox-agent-layout ];

  installPhase = ''
    runHook preInstall
    PLUGIN_DIR="$out/share/claude-code/plugins/pr-review-toolkit"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src/plugins/pr-review-toolkit/." "$PLUGIN_DIR/"
    runHook postInstall
  '';

  postInstall = ''
    flox-agent-layout --plugin pr-review-toolkit --share "$out/share"
  '';

  meta = {
    description = "Comprehensive PR review agents specializing in comments, tests, error handling, type design, code quality, and code simplification";
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
