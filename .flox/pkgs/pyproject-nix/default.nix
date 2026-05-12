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
  pname = "pyproject-nix";
  version = builtins.substring 0 7 rev;

  src = fetchFromGitHub {
    owner = "pyproject-nix";
    repo = "pyproject.nix";
    inherit rev hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/pyproject-nix
    cp -R . $out/pyproject-nix/
    runHook postInstall
  '';

  meta = {
    description = "Nix tools for working with Python's pyproject.toml";
    homepage = "https://github.com/pyproject-nix/pyproject.nix";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
