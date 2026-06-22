{ stdenv, lib, fetchFromGitHub, jq, sourcekit-lsp }:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenv.mkDerivation {
  pname = "skills-anthropic-swift-lsp";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/swift-lsp"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp "$src/plugins/swift-lsp/LICENSE" \
       "$src/plugins/swift-lsp/README.md" \
       "$PLUGIN_DIR/"

    entry=$(jq '.plugins[] | select(.name == "swift-lsp")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, version, author}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"
    echo "$entry" \
      | jq '.lspServers' \
      > "$PLUGIN_DIR/.lsp.json"

    cmd_tmp=$(mktemp)
    jq --arg c "${sourcekit-lsp}/bin/sourcekit-lsp" \
      '."sourcekit-lsp".command = $c' "$PLUGIN_DIR/.lsp.json" > "$cmd_tmp"
    mv "$cmd_tmp" "$PLUGIN_DIR/.lsp.json"

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "swift-lsp" "$out/share"
  '';

  meta = {
    description = "Swift language server (SourceKit-LSP) for code intelligence";
    homepage =
      "https://github.com/anthropics/claude-plugins-official";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
