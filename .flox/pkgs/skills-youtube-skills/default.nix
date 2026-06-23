{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  curl,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "ZeroPointRepo";
    repo = "youtube-skills";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-youtube-skills";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # youtube-skills ships 12 directory skills under skills/ (the
    # clawhub/ tree is an OpenClaw-specific variant we don't use here).
    # Each skill is SKILL.md + references/ and must ship as a unit.
    # The skill bodies invoke `curl` by bare name to call
    # transcriptapi.com; postInstall rewrites those invocations to an
    # absolute store-path curl so the package is self-contained without
    # polluting PATH (no $out/bin).
    for share in \
      "$out/share/claude-code/skills"; do
      mkdir -p "$share"
      cp -r "$src/skills/." "$share/"
      chmod -R u+w "$share"
    done

    runHook postInstall
  '';

  postInstall = ''
    # The only runtime dependency the skills reach for is `curl`. Every
    # `curl` mention in the SKILL.md bodies is a `curl -s "https://..."`
    # command invocation (no prose mentions), so rewrite the bare command
    # to an absolute store path. nix records curl in the closure
    # automatically and the agent needs no curl on PATH. Runs pre-layout on
    # the single staging tree so every agent copy inherits the rewrite when
    # flox_agent_layout fans it out.
    while IFS= read -r f; do
      substituteInPlace "$f" --replace-quiet 'curl ' '${curl}/bin/curl '
    done < <(find "$out/share/claude-code" -name 'SKILL.md')

    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "youtube-skills" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description =
      "youtube-skills for Claude Code and OpenCode — 12 skills for "
      + "YouTube transcripts, captions, search, channels, and playlists "
      + "via the TranscriptAPI.com backend. The SKILL.md curl calls are "
      + "rewritten to a bundled curl by absolute store path; set "
      + "TRANSCRIPT_API_KEY to use.";
    homepage = "https://github.com/ZeroPointRepo/youtube-skills";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
