{ stdenv, lib, fetchFromGitHub, jq, clang-tools }:

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
  pname = "skills-anthropic-clangd-lsp";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/clangd-lsp"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp "$src/plugins/clangd-lsp/LICENSE" \
       "$src/plugins/clangd-lsp/README.md" \
       "$PLUGIN_DIR/"

    entry=$(jq '.plugins[] | select(.name == "clangd-lsp")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, version, author}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"
    echo "$entry" \
      | jq '.lspServers' \
      > "$PLUGIN_DIR/.lsp.json"

    cmd_tmp=$(mktemp)
    jq --arg c "${clang-tools}/bin/clangd" \
      '.clangd.command = $c' "$PLUGIN_DIR/.lsp.json" > "$cmd_tmp"
    mv "$cmd_tmp" "$PLUGIN_DIR/.lsp.json"

    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "clangd-lsp" "$out/share"

    runHook postInstall
  '';

  meta = {
    description = "C/C++ language server (clangd) for code intelligence";
    homepage =
      "https://github.com/anthropics/claude-plugins-official";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
