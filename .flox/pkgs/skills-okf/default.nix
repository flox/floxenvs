{
  stdenv,
  lib,
  fetchFromGitHub,
  python3,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version rev srcHash;

  # The three shipped scripts are PEP-723 single-file scripts whose only
  # third-party dependency is pyyaml. They import no subprocess module and
  # shell out to nothing, so a plain interpreter (no makeBinaryWrapper, no
  # PATH prefix) is enough — script shebangs and the SKILL.md invocations
  # point at this store path.
  pythonEnv = python3.withPackages (ps: [ ps.pyyaml ]);
in
stdenv.mkDerivation {
  pname = "skills-okf";
  inherit version;

  src = fetchFromGitHub {
    owner = "scaccogatto";
    repo = "okf-skills";
    inherit rev;
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/okf"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin at the repo root:
    # `.claude-plugin/plugin.json` names the plugin `okf` and
    # `.claude-plugin/marketplace.json` points its source at `./`. Copy the
    # whole tree, then strip everything that is not plugin content.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    rm -rf "$PLUGIN_DIR/.okf" \
           "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/benchmark" \
           "$PLUGIN_DIR/docs" \
           "$PLUGIN_DIR/examples" \
           "$PLUGIN_DIR/templates" \
           "$PLUGIN_DIR/tests" \
           "$PLUGIN_DIR/Makefile" \
           "$PLUGIN_DIR/action.yml" \
           "$PLUGIN_DIR/CHANGELOG.md" \
           "$PLUGIN_DIR/README.md"

    runHook postInstall
  '';

  # Emit the per-agent launch layout (share/flox/<agent>/okf) from the
  # share/claude-code staging, then hard-gate packaging hygiene. Both
  # helpers are sourced inline (no build-input derivation) so postInstall
  # runs on the native builder and cross-system publish works.
  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "okf" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description =
      "Open Knowledge Format (OKF) skills for Claude Code — author, "
      + "maintain, validate, and visualize portable markdown knowledge "
      + "bundles, with Python and pyyaml bundled for the skill scripts.";
    homepage = "https://github.com/scaccogatto/okf-skills";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
