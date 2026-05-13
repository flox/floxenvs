{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON
    (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    rev = data.rev;
    hash = data.srcHash;
  };

  skillSubdir = "skills/playwright-cli";
in
stdenvNoCC.mkDerivation {
  pname = "skills-playwright-cli";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    for dest in \
      "$out/share/claude-code/skills/playwright-cli" \
      "$out/share/opencode/skills/playwright-cli"; do
      mkdir -p "$dest"
      cp -r "$src/${skillSubdir}"/. "$dest/"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Playwright CLI skill bundle for Claude Code "
      + "and OpenCode — drives playwright-cli from "
      + "an agent via a token-efficient command set.";
    homepage =
      "https://github.com/microsoft/playwright-cli/tree/main/skills/playwright-cli";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
