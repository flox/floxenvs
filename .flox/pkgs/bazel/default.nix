{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  bash,
  coreutils,
  diffutils,
  file,
  findutils,
  gawk,
  gnugrep,
  gnupatch,
  gnused,
  gnutar,
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

  # Runtime tools Bazel shells out to during user builds. Mirrors
  # `defaultShellUtils` from the nixpkgs bazel_9 source build:
  # https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/ba/bazel_9/package.nix
  runtimeDeps = [
    bash
    coreutils
    diffutils
    file
    findutils
    gawk
    gnugrep
    gnupatch
    gnused
    gnutar
    gzip
    python3
    unzip
    which
    zip
  ];
in
# The upstream release binary is an ELF/Mach-O launcher with a zip of
# Bazel's install tree (server jar + embedded JDK) appended. On first
# run Bazel extracts that zip to $output_user_root/install/<hash>/.
# The extracted JDK is pinned to /lib64/ld-linux-*, which is absent on
# NixOS, so we unzip the install tree at build time and let
# autoPatchelfHook rewrite every ELF interpreter. --install_base then
# points Bazel at our patched tree so it skips the runtime extraction.
# `strip` and `patchShebangs` both corrupt the zip trailer on the
# launcher, so both are disabled.
stdenv.mkDerivation {
  pname = "bazel";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchShebangs = true;

  nativeBuildInputs =
    [ makeWrapper unzip ]
    ++ lib.optional stdenv.isLinux autoPatchelfHook;

  buildInputs = lib.optionals stdenv.isLinux [
    zlib
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/bazel/bazel-launcher"

    install_base="$out/share/bazel/install"
    mkdir -p "$install_base"
    unzip -q -o "$src" -d "$install_base"
    chmod -R u+w "$install_base"

    # See ./bazel-wrapper.sh for rationale. We clone the patched
    # install tree into a per-user cache on first run because Bazel
    # wants to create a lock file inside --install_base and $out is
    # read-only.
    install -Dm755 ${./bazel-wrapper.sh} "$out/bin/bazel"
    substituteInPlace "$out/bin/bazel" \
      --subst-var-by bash "${bash}/bin/bash" \
      --subst-var-by out "$out" \
      --subst-var-by runtimeDeps "${lib.makeBinPath runtimeDeps}"

    runHook postInstall
  '';

  meta = {
    description = "Prebuilt Bazel ${version} from bazel.build";
    homepage = "https://bazel.build";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      binaryBytecode
    ];
    mainProgram = "bazel";
    platforms = lib.attrNames platformMap;
  };
}
