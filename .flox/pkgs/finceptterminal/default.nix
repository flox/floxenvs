{
  stdenv,
  callPackage,
  ...
}@args:

if stdenv.hostPlatform.isLinux then
  callPackage ./linux.nix { }
else if stdenv.hostPlatform.isDarwin then
  (
    if builtins.pathExists ./darwin.nix then
      callPackage ./darwin.nix { }
    else
      throw "finceptterminal: darwin build pending Task 9.1"
  )
else
  throw "finceptterminal: unsupported system ${stdenv.hostPlatform.system}"
