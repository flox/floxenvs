{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
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
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-claude-blog";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-blog";
    tag = "v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for python3 so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell script wrapper are unreliable
  # under stripped environments.
  nativeBuildInputs = [ makeBinaryWrapper ];

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

    # Wrap python3 so subprocess.run() inside plugin scripts finds
    # gh/curl/jq/git without depending on the caller's PATH. The
    # blog-flow sync script shells to `gh auth token`; the Google
    # skills shell to `curl` for OAuth and `gh` for token fallback.
    runtimeBins=${lib.makeBinPath [ curl gh git jq ]}
    mkdir -p "$out/bin"
    makeBinaryWrapper "${pythonEnv}/bin/python3" "$out/bin/python3" \
      --prefix PATH : "$runtimeBins"

    # Repoint every #!/usr/bin/env python3 shebang at the wrapped
    # python3. Marks files executable so the kernel honors the
    # shebang when Claude Code invokes the script.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!$out/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -name '*.py' -type f)

    # Rewrite upstream-install path references in markdown files to
    # the ''${CLAUDE_PLUGIN_ROOT}/... form that Claude Code uses for
    # plugins. Same helper as claude-code-plugin-claude-seo (same
    # author, same `~/.claude/skills/<name>/...` reference style).
    "$out/bin/python3" ${./fix_md_paths.py} "$PLUGIN_DIR"

    runHook postInstall
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
