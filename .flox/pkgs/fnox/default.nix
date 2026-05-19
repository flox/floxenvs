{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version binaries;

  # Linux: musl (static) — gnu builds error on NixOS because the
  # release binaries hard-code /lib64/ld-linux-x86-64.so.2 etc., which
  # is not present in the build sandbox or on most NixOS hosts.
  platformMap = {
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-darwin = "x86_64-apple-darwin";
    aarch64-darwin = "aarch64-apple-darwin";
  };

  platform = stdenv.hostPlatform.system;
  target = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/jdx/fnox/releases/download/v${version}/fnox-${target}.tar.gz";
    hash = binaries.${platform};
  };
in
stdenvNoCC.mkDerivation {
  pname = "fnox";
  inherit version src;

  sourceRoot = ".";

  # `fnox completion <shell>` in v1.25.1 requires a fnox.toml in cwd
  # and otherwise errors with `No such file or directory`. Skip shell
  # completion installation until upstream fixes it; users can still
  # get full integration via `eval "$(fnox activate <shell>)"`.
  installPhase = ''
    runHook preInstall

    install -Dm755 fnox $out/bin/fnox

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Fort Knox for your secrets — manage secrets with encryption or cloud providers";
    homepage = "https://fnox.jdx.dev/";
    changelog = "https://github.com/jdx/fnox/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "fnox";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
