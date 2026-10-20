{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    aarch64-darwin = "darwin-arm64";
    aarch64-linux = "linux-arm64";
    x86_64-linux = "linux-amd64";
  };

  platform = stdenvNoCC.hostPlatform.system;
  suffix = platformMap.${platform}
    or (throw "Unsupported system: ${platform}");
in
stdenvNoCC.mkDerivation {
  pname = "go";
  inherit version;

  src = fetchurl {
    url = "https://go.dev/dl/go${version}.${suffix}.tar.gz";
    hash = hashes.${platform};
  };

  nativeBuildInputs =
    lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs =
    lib.optionals stdenvNoCC.hostPlatform.isLinux [ gcc-unwrapped.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/go"
    cp -r . "$out/share/go"

    mkdir -p "$out/bin"
    ln -s "$out/share/go/bin/go" "$out/bin/go"
    ln -s "$out/share/go/bin/gofmt" "$out/bin/gofmt"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    export GOCACHE="$TMPDIR/go-cache"
    export GOPATH="$TMPDIR/gopath"
    "$out/bin/go" version
    [[ "$("$out/bin/go" version)" == *"go${version}"* ]]
  '';

  meta = {
    description = "Go Programming language";
    homepage = "https://go.dev/";
    license = lib.licenses.bsd3;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "go";
  };
}
