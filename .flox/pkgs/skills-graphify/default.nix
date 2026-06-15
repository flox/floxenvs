{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # Pull the sdist directly from PyPI — the same artifact
  # the `graphify` env's `pip install graphifyy` resolves
  # to. Versions are immutable and the hash is stable
  # across platforms, so this avoids both the GitHub
  # default-branch drift and the fetchFromGitHub
  # unpack-divergence we hit when sourcing from the repo.
  src = fetchurl {
    url = data.url;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-graphify";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # unpackPhase strips the single graphifyy-<version>/
    # wrapper dir, so we land inside it. The skill ships at
    # graphify/skill.md as setuptools package-data.
    skill_src="graphify/skill.md"
    if [ ! -f "$skill_src" ]; then
      echo "error: $skill_src not found in PyPI sdist" >&2
      exit 1
    fi

    # Upstream frontmatter has a top-level `trigger:` key
    # which isn't in the agentskills.io spec — flox-ai
    # warns on every activate. Nest it under `metadata:` as
    # the spec (and the warning text) recommends. The slash
    # command itself is derived from the skill directory
    # name, so this is purely a frontmatter-compliance fix.
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
      ' "$skill_src" > "$dest/SKILL.md"
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
