{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "shipshitdev";
    repo = "skills";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-shipshit";
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
      "Ship Shit Dev skills bundle for Claude Code and OpenCode "
      + "— 150+ specialized agent skills for indie developers.";
    homepage = "https://github.com/shipshitdev/skills";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
