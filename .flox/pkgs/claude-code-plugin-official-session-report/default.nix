{ stdenvNoCC, lib, fetchFromGitHub, jq }:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "claude-plugins-official";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "claude-code-plugin-official-session-report";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/session-report"
    mkdir -p "$PLUGIN_DIR/.claude-plugin"

    cp -r "$src/plugins/session-report/." "$PLUGIN_DIR/"

    # Upstream plugins/session-report/ ships LICENSE + skills/ but no
    # .claude-plugin/plugin.json — the metadata lives in the repo-level
    # marketplace.json. Synthesize plugin.json so Claude Code registers
    # the plugin.
    entry=$(jq '.plugins[] | select(.name == "session-report")' \
      "$src/.claude-plugin/marketplace.json")
    echo "$entry" \
      | jq '{name, description, author, homepage}' \
      > "$PLUGIN_DIR/.claude-plugin/plugin.json"

    runHook postInstall
  '';

  meta = {
    description = "Generate an explorable HTML report of Claude Code session usage — tokens, cache efficiency, subagents, skills, and the most expensive prompts — from local ~/.claude/projects transcripts.";
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
