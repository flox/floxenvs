{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  python3,
  curl,
  git,
  jq,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # Python interpreter pre-loaded with every third-party module the
  # plugin's scripts/ tree imports. requirements.txt lists optional
  # AI image providers (google-genai, openai, stability-sdk, replicate)
  # but those are gated behind ADS_IMAGE_PROVIDER env var — skip them
  # at build time, the user can install via their own flox env if
  # they want to drive generate_image.py directly (banana-claude is
  # the default and lives outside this package).
  pythonEnv = python3.withPackages (
    ps: with ps; [
      matplotlib
      pillow
      playwright
      reportlab
      requests
      urllib3
    ]
  );
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-claude-ads";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-ads";
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

    PLUGIN_DIR="$out/share/claude-code/plugins/claude-ads"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Strip dev/CI and user-install bootstrap files — the plugin
    # consumer drives everything via Claude Code, not these.
    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/install.sh" \
           "$PLUGIN_DIR/install.ps1" \
           "$PLUGIN_DIR/uninstall.sh" \
           "$PLUGIN_DIR/uninstall.ps1" \
           "$PLUGIN_DIR/requirements.txt" \
           "$PLUGIN_DIR/requirements-dev.txt" \
           "$PLUGIN_DIR/tests" \
           "$PLUGIN_DIR/evals" \
           "$PLUGIN_DIR/research"

    # Wrap python3 so subprocess.run() inside plugin scripts finds
    # curl/git/jq without depending on the caller's PATH. The scripts
    # mostly call playwright (bundled with the pythonEnv) and optional
    # `mmdc` (mermaid-cli, looked up via shutil.which and skipped if
    # absent), but bundling these matches the claude-seo pattern so
    # any future subprocess call surface keeps working.
    runtimeBins=${
      lib.makeBinPath [
        curl
        git
        jq
      ]
    }
    mkdir -p "$out/bin"
    makeBinaryWrapper "${pythonEnv}/bin/python3" "$out/bin/python3" \
      --prefix PATH : "$runtimeBins"

    # Repoint every #!/usr/bin/env python3 shebang at the wrapped
    # python3. Marks files executable so the kernel honors the
    # shebang when Claude Code invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!$out/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -name '*.py' -type f)

    # Rewrite upstream-install path references in markdown files to
    # the ''${CLAUDE_PLUGIN_ROOT}/... form that Claude Code uses for
    # plugins. Driven by a basename index of the plugin tree, so new
    # upstream files added in future versions are picked up without
    # changing this derivation.
    "$out/bin/python3" ${./fix_md_paths.py} "$PLUGIN_DIR"

    runHook postInstall
  '';

  meta = {
    description =
      "Paid advertising audit & optimization plugin for Claude Code "
      + "(22 sub-skills, 10 agents) with Python + binaries bundled";
    homepage = "https://github.com/AgriciDaniel/claude-ads";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
