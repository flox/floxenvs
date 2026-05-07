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

  skillSubdir = "skills/frontend-design";
in
stdenvNoCC.mkDerivation {
  pname = "skills-frontend-design";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills/frontend-design" \
      "$out/share/opencode/skills/frontend-design"; do
      mkdir -p "$dest"
      cp -r "$src/${skillSubdir}"/. "$dest/"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Frontend-design skill for Claude Code and OpenCode "
      + "— creates distinctive, production-grade frontend interfaces.";
    homepage =
      "https://github.com/anthropics/skills/tree/main/skills/frontend-design";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
