{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "blader";
    repo = "humanizer";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-humanizer";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills/humanizer" \
      "$out/share/opencode/skills/humanizer"; do
      mkdir -p "$dest"
      cp -r "$src"/. "$dest/"
    done

    runHook postInstall
  '';

  # Upstream SKILL.md puts `version:` at the top level of the YAML
  # frontmatter, which agentskills.io flags as an unknown key. Nest it
  # under `metadata:` so the loader stops warning on every session start.
  postInstall = ''
    for skill_md in \
      "$out/share/claude-code/skills/humanizer/SKILL.md" \
      "$out/share/opencode/skills/humanizer/SKILL.md"; do
      awk '
        BEGIN { fm = 0 }
        /^---[[:space:]]*$/ { fm++; print; next }
        fm == 1 && /^version:[[:space:]]/ {
          print "metadata:"
          print "  " $0
          next
        }
        { print }
      ' "$skill_md" > "$skill_md.new"
      mv "$skill_md.new" "$skill_md"
    done
  '';

  meta = {
    description =
      "Humanizer skill for Claude Code and OpenCode " + "— removes signs of AI-generated writing.";
    homepage = "https://github.com/blader/humanizer";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
