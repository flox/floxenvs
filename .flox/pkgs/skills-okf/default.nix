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

    # The scripts live ONCE at $out/libexec, outside $out/share, so
    # flox_agent_layout never copies them: all four per-agent trees
    # reference the same absolute path. Keeping them under skills/<s>/
    # would produce four duplicates and force SKILL.md to name one
    # arbitrary copy.
    for skill in okf validate visualize; do
      src_dir="$PLUGIN_DIR/skills/$skill/scripts"
      [ -d "$src_dir" ] || { echo "missing $src_dir" >&2; exit 1; }
      mkdir -p "$out/libexec/okf/$skill"
      mv "$src_dir"/*.py "$out/libexec/okf/$skill/"
      rmdir "$src_dir"
    done

    # Repoint the #!/usr/bin/env python3 shebangs at the bundled
    # interpreter and mark the scripts executable, so direct invocation
    # works without python3 on the caller's PATH.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!${pythonEnv}/bin/python3"
      chmod +x "$f"
    done < <(find "$out/libexec/okf" -type f -name '*.py')

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
