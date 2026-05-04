{ stdenv, lib, fetchFromGitHub }:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-claude-seo";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-seo";
    tag = "v${version}";
    hash = srcHash;
  };

  installPhase = ''
    PLUGIN_DIR="$out/share/claude-code/plugins/claude-seo"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"
    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.devcontainer" \
           "$PLUGIN_DIR/install.sh" \
           "$PLUGIN_DIR/install.ps1" \
           "$PLUGIN_DIR/uninstall.sh" \
           "$PLUGIN_DIR/uninstall.ps1"
  '';

  meta = {
    description =
      "Universal SEO plugin for Claude Code (skills, agents, hooks, extensions)";
    homepage = "https://github.com/AgriciDaniel/claude-seo";
    license = lib.licenses.mit;
  };
}
