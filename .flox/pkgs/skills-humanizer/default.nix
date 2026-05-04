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

  meta = {
    description =
      "Humanizer skill for Claude Code and OpenCode "
      + "— removes signs of AI-generated writing.";
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
