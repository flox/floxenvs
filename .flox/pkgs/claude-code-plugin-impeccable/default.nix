{ stdenv, lib, fetchFromGitHub }:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-impeccable";
  inherit version;

  src = fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    tag = "skill-v${version}";
    hash = srcHash;
  };

  installPhase = ''
    PLUGIN_DIR="$out/share/claude-code/plugins/impeccable"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships per-harness mirrors at top-level (.claude/, .cursor/,
    # .gemini/, etc.). The Claude Code plugin source is the `plugin/`
    # subdirectory — that's what marketplace.json points at.
    cp -r "$src/plugin/." "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"
  '';

  meta = {
    description =
      "Impeccable design fluency plugin for Claude Code (1 skill, 23 commands)";
    homepage = "https://github.com/pbakaus/impeccable";
    license = lib.licenses.asl20;
  };
}
