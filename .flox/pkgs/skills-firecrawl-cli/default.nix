{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON
    (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "firecrawl";
    repo = "cli";
    rev = data.rev;
    hash = data.srcHash;
  };

  # The repo ships a bundle of skills under skills/ — the entry
  # `firecrawl-cli` skill plus per-capability skills (scrape, crawl,
  # search, map, interact, parse, download, monitor, agent). Install
  # the whole bundle so the agent gets the full command set.
  skillsSubdir = "skills";
in
stdenvNoCC.mkDerivation {
  pname = "skills-firecrawl-cli";
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
      "Firecrawl CLI skill bundle for Claude Code and "
      + "OpenCode — search, scrape, crawl, and interact "
      + "with the web by driving firecrawl-cli from an "
      + "agent.";
    homepage =
      "https://github.com/firecrawl/cli/tree/main/skills";
    license = lib.licenses.isc;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
