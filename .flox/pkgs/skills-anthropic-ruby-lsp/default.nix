{ stdenv, lib, fetchFromGitHub, jq, rubyPackages }:

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
  pname = "skills-anthropic-ruby-lsp";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/ruby-lsp"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp "$src/plugins/ruby-lsp/LICENSE" \
       "$src/plugins/ruby-lsp/README.md" \
       "$PLUGIN_DIR/"

    entry=$(jq '.plugins[] | select(.name == "ruby-lsp")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, version, author}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"
    echo "$entry" \
      | jq '.lspServers' \
      > "$PLUGIN_DIR/.lsp.json"

    cmd_tmp=$(mktemp)
    jq --arg c "${rubyPackages.ruby-lsp}/bin/ruby-lsp" \
      '."ruby-lsp".command = $c' "$PLUGIN_DIR/.lsp.json" > "$cmd_tmp"
    mv "$cmd_tmp" "$PLUGIN_DIR/.lsp.json"

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "ruby-lsp" "$out/share"
  '';

  meta = {
    description = "Ruby language server for code intelligence and analysis";
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
