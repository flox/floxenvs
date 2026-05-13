{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # Use fetchurl (byte-level hash of the .tar.gz) instead of
  # fetchFromGitHub (which hashes the unpacked tree and can
  # produce platform-divergent hashes for the same source).
  # mkDerivation auto-unpacks the tarball in unpackPhase.
  src = fetchurl {
    url = "https://github.com/safishamsi/graphify/archive/${data.rev}.tar.gz";
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
    #
    # Upstream's frontmatter has a top-level `trigger:` key, which
    # isn't in the agentskills.io spec — claude-managed warns on
    # every activate. Nest it under `metadata:` as the spec (and
    # the warning text) recommends. The slash command itself is
    # derived from the skill directory name, so this is purely a
    # frontmatter-compliance fix.
    for dest in \
      "$out/share/claude-code/skills/graphify" \
      "$out/share/opencode/skills/graphify"; do
      mkdir -p "$dest"
      awk '
        /^trigger:[[:space:]]/ && !done {
          sub(/^trigger:[[:space:]]+/, "")
          print "metadata:"
          print "  trigger: " $0
          done = 1
          next
        }
        { print }
      ' graphify/skill.md > "$dest/SKILL.md"
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
