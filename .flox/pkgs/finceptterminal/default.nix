{
  stdenv,
  callPackage,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  ...
}@args:

let
  pythonEnv =
    if builtins.pathExists ./python-env.nix then
      callPackage ./python-env.nix {
        inherit pyproject-nix uv2nix pyproject-build-systems;
      }
    else
      throw "finceptterminal: python-env.nix pending Task 6.3";
in

if stdenv.hostPlatform.isLinux then
  callPackage ./linux.nix { inherit pythonEnv; }
else if stdenv.hostPlatform.isDarwin then
  (
    if builtins.pathExists ./darwin.nix then
      callPackage ./darwin.nix { inherit pythonEnv; }
    else
      throw "finceptterminal: darwin build pending Task 9.1"
  )
else
  throw "finceptterminal: unsupported system ${stdenv.hostPlatform.system}"
