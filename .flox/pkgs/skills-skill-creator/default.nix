{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "skills";
    rev = data.rev;
    hash = data.srcHash;
  };

  skillSubdir = "skills/skill-creator";
in
stdenvNoCC.mkDerivation {
  pname = "skills-skill-creator";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills/skill-creator" \
      "$out/share/opencode/skills/skill-creator"; do
      mkdir -p "$dest"
      cp -r "$src/${skillSubdir}"/. "$dest/"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Skill-creator skill for Claude Code and OpenCode "
      + "— creates, edits, and evaluates Claude Code skills.";
    homepage =
      "https://github.com/anthropics/skills/tree/main/skills/skill-creator";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
