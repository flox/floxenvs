{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  makeWrapper,
  python3,
  curl,
  gh,
  git,
  jq,
  nodejs,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # Python interpreter pre-loaded with every third-party module the
  # plugin's own scripts/ + hooks/ + extensions/ tree imports.
  pythonEnv = python3.withPackages (ps: with ps; [
    beautifulsoup4
    google-api-python-client
    google-auth
    google-auth-httplib2
    google-auth-oauthlib
    lxml
    matplotlib
    numpy
    openpyxl
    pillow
    playwright
    pypdf
    requests
    urllib3
    validators
    weasyprint
  ]);
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-claude-seo";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-seo";
    tag = "v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for python3 so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell script wrapper are unreliable
  # under stripped environments. makeWrapper is still needed for the
  # bash extension scripts (wrapProgram).
  nativeBuildInputs = [ makeBinaryWrapper makeWrapper ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/claude-seo"
    mkdir -p "$PLUGIN_DIR"
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.devcontainer" \
           "$PLUGIN_DIR/install.sh" \
           "$PLUGIN_DIR/install.ps1" \
           "$PLUGIN_DIR/uninstall.sh" \
           "$PLUGIN_DIR/uninstall.ps1"

    # Wrap python3 so subprocess.run() inside plugin scripts finds
    # gh/curl/jq/git/node/npx without depending on the caller's PATH.
    runtimeBins=${lib.makeBinPath [ curl gh git jq nodejs ]}
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

    # hooks.json invokes 'python3 path/to/script' which would resolve
    # python3 from the caller's PATH. Drop the explicit interpreter
    # so the patched shebang on validate-schema.py is honored.
    substituteInPlace "$PLUGIN_DIR/hooks/hooks.json" --replace-fail \
      'python3 \"''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py\"' \
      '\"''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py\"'

    # Wrap each extension install/uninstall script so 'node', 'npx',
    # 'python3', 'jq', etc. resolve from Nix when a user runs them.
    # Note: 'claude' is intentionally not bundled — it is provided by
    # the consumer's flox/claude-code package.
    for f in "$PLUGIN_DIR"/extensions/*/install.sh \
             "$PLUGIN_DIR"/extensions/*/uninstall.sh; do
      [ -f "$f" ] || continue
      chmod +x "$f"
      wrapProgram "$f" --prefix PATH : "$runtimeBins:$out/bin"
    done

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
      "Universal SEO plugin for Claude Code (skills, agents, hooks, extensions) with Python + binaries bundled";
    homepage = "https://github.com/AgriciDaniel/claude-seo";
    license = lib.licenses.mit;
  };
}
