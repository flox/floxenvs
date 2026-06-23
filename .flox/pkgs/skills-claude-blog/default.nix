{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  runCommandLocal,
  python3,
  curl,
  gh,
  git,
  jq,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # Python interpreter pre-loaded with the core deps that
  # `scripts/analyze_blog.py` and the skill scripts import unconditionally.
  # The plugin uses try/except for textstat + beautifulsoup4 (graceful
  # degradation) but the analyzer's scoring is meaningfully worse without
  # them, so we ship them by default.
  #
  # Heavier opt-in deps (spacy, sentence-transformers, scikit-learn,
  # language-tool-python, patchright, google-api-python-client, etc.)
  # are NOT bundled here: each skill that needs them ships its own
  # `setup_environment.py` that builds a per-skill venv on demand. That
  # venv calls `venv.create()` against this wrapped python3 and then
  # pip-installs from the skill's requirements.lock at runtime — so the
  # heavy deps land in user space, not in this derivation's closure.
  pythonEnv = python3.withPackages (ps: with ps; [
    beautifulsoup4
    jsonschema
    lxml
    requests
    textstat
  ]);

  # Runtime tools the wrapped python3 must find on PATH so the
  # blog-flow sync script (gh auth token) and the Google skills
  # (curl OAuth, gh token fallback) keep working regardless of the
  # caller's PATH.
  runtimeBinPath = lib.makeBinPath [ curl gh git jq ];

  # The wrapped interpreter lives at its OWN store path (not in the
  # shared $out/bin) so multiple skill packages can be installed
  # together without colliding on bin/python3, and so the plugin tree
  # never pollutes the consumer's PATH. Script shebangs point here.
  pythonWrapped = runCommandLocal "python3-skills-claude-blog"
    { nativeBuildInputs = [ makeBinaryWrapper ]; } ''
      makeBinaryWrapper ${pythonEnv}/bin/python3 $out/bin/python3 \
        --prefix PATH : ${runtimeBinPath}
    '';
in
stdenv.mkDerivation {
  pname = "skills-claude-blog";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-blog";
    tag = "v${version}";
    hash = srcHash;
  };

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/claude-blog"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin source at the repo root —
    # `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
    # both live there. Copy the whole tree, then strip the install
    # scripts (Claude Code plugins don't use them — the plugin dir IS
    # the install) and repo-only metadata that would otherwise leak
    # into the user-facing tree.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitattributes" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/install.sh" \
           "$PLUGIN_DIR/install.ps1" \
           "$PLUGIN_DIR/uninstall.sh" \
           "$PLUGIN_DIR/uninstall.ps1" \
           "$PLUGIN_DIR/tests"

    # Repoint every #!/usr/bin/env python3 shebang at the wrapped
    # python3 (its own store path, ${pythonWrapped}). Marks files
    # executable so the kernel honors the shebang when Claude Code
    # invokes the script.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!${pythonWrapped}/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -name '*.py' -type f)

    # Rewrite upstream-install path references in markdown files to
    # the ''${CLAUDE_PLUGIN_ROOT}/... form that Claude Code uses for
    # plugins. Same helper as skills-claude-seo (same
    # author, same `~/.claude/skills/<name>/...` reference style).
    ${pythonWrapped}/bin/python3 ${./fix_md_paths.py} "$PLUGIN_DIR"

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "claude-blog" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description =
      "AI blog creation plugin for Claude Code (28 skills, 5 agents) with Python + core analysis deps bundled";
    homepage = "https://github.com/AgriciDaniel/claude-blog";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
