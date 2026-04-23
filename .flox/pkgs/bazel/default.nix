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

    # Shell wrapper instead of makeWrapper's --add-flags: bazel's
    # top-level `--version` / `--help` / `-h` pseudo-commands reject
    # startup options, so --install_base must only be injected for
    # real commands.
    mkdir -p "$out/bin"
    cat > "$out/bin/bazel" <<EOF
    #!${bash}/bin/bash
    set -e
    export PATH="${lib.makeBinPath runtimeDeps}:\$PATH"
    case "\''${1:-}" in
      --version|--help|-h)
        exec "$out/libexec/bazel/bazel-launcher" "\$@"
        ;;
    esac
    exec "$out/libexec/bazel/bazel-launcher" "--install_base=$install_base" "\$@"
    EOF
    # Strip the leading four-space indent the here-doc preserves.
    sed -i 's/^    //' "$out/bin/bazel"
    chmod +x "$out/bin/bazel"

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
