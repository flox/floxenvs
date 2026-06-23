{ stdenv, lib, fetchFromGitHub, jq, typescript-language-server }:

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
  pname = "skills-anthropic-typescript-lsp";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/typescript-lsp"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp "$src/plugins/typescript-lsp/LICENSE" \
       "$src/plugins/typescript-lsp/README.md" \
       "$PLUGIN_DIR/"

    entry=$(jq '.plugins[] | select(.name == "typescript-lsp")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, version, author}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"
    echo "$entry" \
      | jq '.lspServers' \
      > "$PLUGIN_DIR/.lsp.json"

    cmd_tmp=$(mktemp)
    jq --arg c "${typescript-language-server}/bin/typescript-language-server" \
      '.typescript.command = $c' "$PLUGIN_DIR/.lsp.json" > "$cmd_tmp"
    mv "$cmd_tmp" "$PLUGIN_DIR/.lsp.json"

    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "typescript-lsp" "$out/share"

    runHook postInstall

    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description = "TypeScript/JavaScript language server for enhanced code intelligence";
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
