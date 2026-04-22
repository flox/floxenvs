{ stdenv, lib, typescript-language-server }:

stdenv.mkDerivation {
  pname = "claude-code-plugin-typescript-lsp";
  version = "0.2.4";

  src = builtins.path {
    path = ./.;
    filter = path: type: true;
  };

  installPhase = ''
    mkdir -p "$out/bin"
    ln -s "${typescript-language-server}/bin/typescript-language-server" \
      "$out/bin/typescript-language-server"

    PLUGINS_DIR="$out/share/claude-code/plugins/typescript-lsp"
    mkdir -p "$PLUGINS_DIR"
    cp -r "$src/typescript-lsp/." "$PLUGINS_DIR/"
  '';
}
