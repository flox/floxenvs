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
    # transcriptapi.com, so we drop a `curl` on PATH (see below) to make
    # the package self-contained — no host curl assumption.
    for share in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$share"
      cp -r "$src/skills/." "$share/"
      chmod -R u+w "$share"
    done

    # The only runtime dependency the skills reach for is `curl`. Bundle
    # it on PATH so the bare `curl ...` invocations in every SKILL.md
    # resolve once this package is installed into the consumer's flox
    # env, with nix recording curl in the closure automatically.
    mkdir -p "$out/bin"
    ln -s "${curl}/bin/curl" "$out/bin/curl"

    runHook postInstall
  '';

  meta = {
    description =
      "youtube-skills for Claude Code and OpenCode — 12 skills for "
      + "YouTube transcripts, captions, search, channels, and playlists "
      + "via the TranscriptAPI.com backend. The SKILL.md curl calls run "
      + "against a bundled curl on PATH; set TRANSCRIPT_API_KEY to use.";
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
