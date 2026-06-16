{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON
    (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "DietrichGebert";
    repo = "ponytail";
    rev = data.rev;
    hash = data.srcHash;
  };

  # The repo ships a bundle of skills under skills/ — the entry
  # `ponytail` skill plus the per-mode skills (audit, debt, help,
  # review). Install the whole bundle so the agent gets the full
  # set of laziness modes and commands.
  skillsSubdir = "skills";
in
stdenvNoCC.mkDerivation {
  pname = "skills-ponytail";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for root in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$root"
      cp -r "$src/${skillsSubdir}"/. "$root/"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Ponytail skill bundle for Claude Code and OpenCode "
      + "— makes your agent think like the laziest senior "
      + "dev in the room: question whether the task needs "
      + "to exist, reach for stdlib before custom code, one "
      + "line before fifty.";
    homepage =
      "https://github.com/DietrichGebert/ponytail";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
