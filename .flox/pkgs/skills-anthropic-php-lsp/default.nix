{ stdenv, lib, fetchFromGitHub, jq, intelephense }:

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
  pname = "skills-anthropic-php-lsp";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/php-lsp"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp "$src/plugins/php-lsp/LICENSE" \
       "$src/plugins/php-lsp/README.md" \
       "$PLUGIN_DIR/"

    entry=$(jq '.plugins[] | select(.name == "php-lsp")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, version, author}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"
    echo "$entry" \
      | jq '.lspServers' \
      > "$PLUGIN_DIR/.lsp.json"

    cmd_tmp=$(mktemp)
    jq --arg c "${intelephense}/bin/intelephense" \
      '.intelephense.command = $c' "$PLUGIN_DIR/.lsp.json" > "$cmd_tmp"
    mv "$cmd_tmp" "$PLUGIN_DIR/.lsp.json"

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "php-lsp" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description = "PHP language server (Intelephense) for code intelligence";
    homepage =
      "https://github.com/anthropics/claude-plugins-official";
    license = lib.licenses.unfree;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
