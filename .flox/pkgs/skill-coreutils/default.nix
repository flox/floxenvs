{ stdenv }:

stdenv.mkDerivation {
  pname = "skill-coreutils";
  version = "0.1.0";

  src = ./.;

  installPhase = ''
    mkdir -p "$out/share/claude-code/skills/coreutils"
    cp -r "$src"/* "$out/share/claude-code/skills/coreutils/"
    rm -f "$out/share/claude-code/skills/coreutils/default.nix"
    substituteInPlace "$out/share/claude-code/skills/coreutils/SKILL.md" \
      --replace-fail '@SKILL_DIR@' "$out/share/claude-code/skills/coreutils"
  '';
}
