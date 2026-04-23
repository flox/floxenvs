{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  buildFHSEnv,
  makeWrapper,
  bash,
  coreutils,
  findutils,
  gawk,
  gnugrep,
  gnused,
  gzip,
  python3,
  unzip,
  which,
  zip,
  zlib,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  system = stdenv.hostPlatform.system;

  platformMap = {
    "x86_64-linux"   = "linux-x86_64";
    "aarch64-linux"  = "linux-arm64";
    "x86_64-darwin"  = "darwin-x86_64";
    "aarch64-darwin" = "darwin-arm64";
  };

  platformSuffix =
    platformMap.${system} or (throw "bazel: unsupported system ${system}");

  srcHash =
    hashes.${system} or (throw "bazel: no hash for ${system}");

  src = fetchurl {
    url = "https://github.com/bazelbuild/bazel/releases/download/${version}/bazel-${version}-${platformSuffix}";
    hash = srcHash;
  };

  # Runtime tools Bazel shells out to while building user projects.
  runtimeDeps = [
    bash
    coreutils
    findutils
    gawk
    gnugrep
    gnused
    gzip
    python3
    unzip
    which
    zip
  ];

  # Raw binary with the ELF launcher patched (Linux) and a PATH
  # prefix that exposes the tools Bazel shells out to.
  bazelUnwrapped = stdenv.mkDerivation {
    pname = "bazel-unwrapped";
    inherit version;

    inherit src;
    dontUnpack = true;
    dontBuild = true;

    # Bazel's release binary has a zip trailer appended to an
    # ELF/Mach-O launcher. `strip` and `patchShebangs` both
    # corrupt that trailer.
    dontStrip = true;
    dontPatchShebangs = true;

    nativeBuildInputs =
      [ makeWrapper ]
      ++ lib.optional stdenv.isLinux autoPatchelfHook;

    buildInputs = lib.optionals stdenv.isLinux [
      zlib
      stdenv.cc.cc.lib
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/.bazel-raw"
      makeWrapper "$out/bin/.bazel-raw" "$out/bin/bazel" \
        --prefix PATH : ${lib.makeBinPath runtimeDeps}
      runHook postInstall
    '';

    meta = {
      description = "Prebuilt Bazel ${version} from bazel.build (unwrapped)";
      homepage = "https://bazel.build";
      license = lib.licenses.asl20;
      mainProgram = "bazel";
    };
  };
in
# Bazel's upstream Linux binary extracts an embedded JDK whose ELF
# interpreter is hard-coded to /lib64/ld-linux-*. That path does not
# exist on NixOS, so we launch Bazel inside a minimal FHS chroot where
# it does. macOS binaries are code-signed by Google and run directly.
if stdenv.isDarwin then
  bazelUnwrapped
else
  buildFHSEnv {
    pname = "bazel";
    inherit version;
    targetPkgs = pkgs: [ bazelUnwrapped ] ++ runtimeDeps;
    runScript = "bazel";
    meta = {
      description = "Prebuilt Bazel ${version} from bazel.build";
      homepage = "https://bazel.build";
      license = lib.licenses.asl20;
      mainProgram = "bazel";
      platforms = lib.attrNames platformMap;
    };
  }
