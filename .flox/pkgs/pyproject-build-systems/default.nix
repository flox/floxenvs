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
  pname = "pyproject-build-systems";
  version = builtins.substring 0 7 rev;

  src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "build-system-pkgs";
    inherit rev hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/pyproject-build-systems
    cp -R . $out/pyproject-build-systems/
    runHook postInstall
  '';

  meta = {
    description = "Build-system overlays for pyproject-nix / uv2nix";
    homepage = "https://github.com/pyproject-nix/build-system-pkgs";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
