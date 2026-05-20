{
  lib,
  stdenv,
  fetchzip,
  nodejs,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation {
  pname = "claude-code-router";
  inherit version;

  src = fetchzip {
    url =
      "https://registry.npmjs.org/@musistudio/claude-code-router/"
      + "-/claude-code-router-${version}.tgz";
    inherit hash;
  };

  nativeBuildInputs = [ nodejs ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src/dist/cli.js $out/bin/ccr
    chmod +x $out/bin/ccr

    substituteInPlace $out/bin/ccr \
      --replace-quiet "#!/usr/bin/env node" "#!${nodejs}/bin/node"

    # Bundle the tiktoken WASM next to the CLI so it can locate it via
    # relative resolution at runtime.
    cp $src/dist/tiktoken_bg.wasm $out/bin/

    runHook postInstall
  '';

  meta = {
    description = "Run Claude Code against any LLM provider via a routing proxy";
    homepage = "https://github.com/musistudio/claude-code-router";
    changelog = "https://github.com/musistudio/claude-code-router/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = "ccr";
  };
}
