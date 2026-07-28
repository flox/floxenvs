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

  # The upstream unittest suite plus three smoke runs, all under the
  # bundled interpreter — this is what proves the shipped scripts execute
  # with the bundled pyyaml and nothing else.
  #
  # Skipped on x86_64-darwin: those builds run under Rosetta on the
  # aarch64 CI runners, where emulated check phases have hung past the
  # 1800s silence timeout in this repo. The other three systems cover it.
  doCheck = stdenv.hostPlatform.system != "x86_64-darwin";

  checkPhase = ''
    runHook preCheck

    ${pythonEnv}/bin/python3 tests/test_okf_validate.py

    # validate: the vendored sample bundle must pass --strict.
    ${pythonEnv}/bin/python3 skills/validate/scripts/okf_validate.py \
      examples/sample-bundle --strict

    # init + validate round trip: a freshly scaffolded bundle must be
    # strict-conformant, which is upstream's own stated invariant.
    scaffold="$TMPDIR/okf-scaffold"
    ${pythonEnv}/bin/python3 skills/okf/scripts/okf_init.py "$scaffold" \
      --title "check"
    ${pythonEnv}/bin/python3 skills/validate/scripts/okf_validate.py \
      "$scaffold" --strict

    # visualize: must emit a non-empty self-contained HTML file.
    # The flag is `-o/--out` (argparse, okf_visualize.py:409).
    ${pythonEnv}/bin/python3 skills/visualize/scripts/okf_visualize.py \
      examples/sample-bundle --out "$TMPDIR/viz.html"
    test -s "$TMPDIR/viz.html"

    runHook postCheck
  '';

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

    # Point every invocation at the bundled interpreter and the libexec
    # copy, by absolute store path. Upstream offers `uv run` with a
    # `pip install pyyaml` fallback; under flox neither uv nor a
    # system python3 is guaranteed, and a runtime pip install into an
    # immutable store is meaningless. --replace-fail so an upstream
    # rewording breaks the build instead of silently shipping a
    # uv-dependent skill.
    PY="${pythonEnv}/bin/python3"

    substituteInPlace "$PLUGIN_DIR/skills/okf/SKILL.md" \
      --replace-fail \
        'uv run "''${CLAUDE_SKILL_DIR}/scripts/okf_init.py"' \
        "$PY $out/libexec/okf/okf/okf_init.py" \
      --replace-fail \
        'uv run "''${CLAUDE_SKILL_DIR}/../validate/scripts/okf_validate.py"' \
        "$PY $out/libexec/okf/validate/okf_validate.py"

    # The upstream "If uv is unavailable, fall back to: <duplicate uv-free
    # command>" paragraph loses all meaning once the primary command above
    # is already rewritten to the bundled interpreter — there is no
    # fallback path left to describe, and leaving the sentence in place
    # would ship two byte-identical command blocks with a connective
    # sentence that no longer makes sense. Delete the sentence and its
    # code block outright rather than rewrite it into a second copy.
    substituteInPlace "$PLUGIN_DIR/skills/validate/SKILL.md" \
      --replace-fail \
        'uv run "''${CLAUDE_SKILL_DIR}/scripts/okf_validate.py"' \
        "$PY $out/libexec/okf/validate/okf_validate.py" \
      --replace-fail \
        'If `uv` is unavailable, fall back to:

```bash
python3 -m pip install --quiet pyyaml && \
python3 "''${CLAUDE_SKILL_DIR}/scripts/okf_validate.py" $ARGUMENTS
```

' \
        "" \
      --replace-fail \
        '`''${CLAUDE_SKILL_DIR}` resolves whether this skill runs as part of the `okf`
plugin or is installed standalone (e.g. via `npx skills add`), so the checker is
always found alongside the skill.' \
        'The path above is fixed by this flox package build, so the checker is
always found at that location regardless of how the skill is installed.'

    substituteInPlace "$PLUGIN_DIR/skills/visualize/SKILL.md" \
      --replace-fail \
        'uv run "''${CLAUDE_SKILL_DIR}/scripts/okf_visualize.py"' \
        "$PY $out/libexec/okf/visualize/okf_visualize.py" \
      --replace-fail \
        'If `uv` is unavailable:

```bash
python3 -m pip install --quiet pyyaml && \
python3 "''${CLAUDE_SKILL_DIR}/scripts/okf_visualize.py" $ARGUMENTS
```

' \
        "" \
      --replace-fail \
        'Open it in any browser; `''${CLAUDE_SKILL_DIR}` resolves whether this runs as part
of the `okf` plugin or as a standalone skills.sh skill.' \
        'Open it in any browser; the path above is fixed by this flox package build
regardless of how the skill is installed.'

    runHook postInstall
  '';

  # Emit the per-agent launch layout (share/flox/<agent>/okf) from the
  # share/claude-code staging, then hard-gate packaging hygiene. Both
  # helpers are sourced inline (no build-input derivation) so postInstall
  # runs on the native builder and cross-system publish works.
  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "okf" "$out/share"

    # Gate the FINAL per-agent trees: every SKILL.md that ships must be
    # free of PATH-dependent invocations.
    while IFS= read -r f; do
      if grep -nE 'uv run|pip install|CLAUDE_SKILL_DIR' "$f"; then
        echo "skills-okf: $f still has a PATH-dependent invocation" >&2
        exit 1
      fi
    done < <(find "$out/share/flox" -name 'SKILL.md' -type f)
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
