{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
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
in
# The upstream release binary is an ELF/Mach-O launcher with a zip
# of Bazel's install tree (server jar + embedded JDK) appended.
# autoPatchelfHook rewires the launcher's interpreter for Linux;
# the JDK Bazel extracts on first run keeps its distro-pinned
# /lib64/ld-linux-*.so.2 path, which is present on every non-NixOS
# Linux and via the nix-ld shim on NixOS. `strip` and `patchShebangs`
# both corrupt the zip trailer, so both are disabled.
stdenv.mkDerivation {
  pname = "bazel";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
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
    description = "Prebuilt Bazel ${version} from bazel.build";
    homepage = "https://bazel.build";
    license = lib.licenses.asl20;
    mainProgram = "bazel";
    platforms = lib.attrNames platformMap;
  };
}
