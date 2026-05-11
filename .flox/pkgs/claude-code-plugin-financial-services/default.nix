{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "financial-services";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "claude-code-plugin-financial-services";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    OUT_BASE="$out/share/claude-code"
    mkdir -p "$OUT_BASE"
    cp -r "$src"/. "$OUT_BASE/financial-services-raw/"

    runHook postInstall
  '';

  meta = {
    description =
      "Claude for Financial Services — 19 Claude Code plugins "
      + "(agents + verticals + partner-built) with Python "
      + "runtime bundled.";
    homepage = "https://github.com/anthropics/financial-services";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
