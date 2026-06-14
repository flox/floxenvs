{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "conorbronsdon";
    repo = "avoid-ai-writing";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-avoid-ai-writing";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # The skill is a single self-contained SKILL.md. Upstream keeps the
    # canonical copy at the repo root (the same bytes it syncs into its
    # Claude Code plugin at plugins/avoid-ai-writing/skills/avoid-ai-writing/).
    # The repo root is NOT a bare skill folder — it also carries the JS
    # detector, a Cursor port, docs, and build scripts — so copy only
    # SKILL.md rather than the whole tree. The skill needs no supporting
    # files: it references the detector's thresholds in prose but never
    # invokes it, so SKILL.md alone is the complete agent capability.
    for dest in \
      "$out/share/claude-code/skills/avoid-ai-writing" \
      "$out/share/opencode/skills/avoid-ai-writing"; do
      mkdir -p "$dest"
      cp "$src/SKILL.md" "$dest/SKILL.md"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Avoid AI Writing skill for Claude Code and OpenCode — audits and "
      + "rewrites content to remove AI writing patterns (\"AI-isms\"), with "
      + "detect-only and edit-in-place modes, voice profiles, and "
      + "iterate-to-convergence.";
    homepage = "https://github.com/conorbronsdon/avoid-ai-writing";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
