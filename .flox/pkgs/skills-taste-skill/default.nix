{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "Leonxlnx";
    repo = "taste-skill";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-taste-skill";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # The upstream repo bundles a collection of skills under
    # `skills/<name>/SKILL.md`. Install each one as its own
    # discoverable skill for both Claude Code and OpenCode.
    for base in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$base"
      for sub in "$src"/skills/*/; do
        name="$(basename "$sub")"
        if [ -f "$sub/SKILL.md" ]; then
          mkdir -p "$base/$name"
          cp -r "$sub"/. "$base/$name/"
        fi
      done
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Taste-Skill bundle for Claude Code and OpenCode "
      + "— gives AI good taste and stops generic-slop output.";
    homepage = "https://github.com/Leonxlnx/taste-skill";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
