{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) rev hash;
in
stdenvNoCC.mkDerivation {
  pname = "uv2nix";
  version = builtins.substring 0 7 rev;

  src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "uv2nix";
    inherit rev hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/uv2nix
    cp -R . $out/uv2nix/
    runHook postInstall
  '';

  meta = {
    description = "Build Nix packages from uv lock files";
    homepage = "https://github.com/pyproject-nix/uv2nix";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
