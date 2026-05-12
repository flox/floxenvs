{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "safishamsi";
    repo = "graphify";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skill-graphify";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Upstream bundles the skill at graphify/skill.md inside the
    # Python package. Install it as a discoverable Claude Code /
    # OpenCode skill under share/<host>/skills/graphify/SKILL.md.
    for dest in \
      "$out/share/claude-code/skills/graphify" \
      "$out/share/opencode/skills/graphify"; do
      mkdir -p "$dest"
      cp "$src/graphify/skill.md" "$dest/SKILL.md"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "graphify skill for Claude Code and OpenCode "
      + "— turn any folder of files into a knowledge graph.";
    homepage = "https://github.com/safishamsi/graphify";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
