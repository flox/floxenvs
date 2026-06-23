{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  makeWrapper,
  runCommandLocal,
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
  pythonEnv = python3.withPackages (
    ps:
    let
      # weasyprint's checkPhase is a pixel/font-rendering pytest suite that
      # is darwin-environment sensitive (fontconfig) and fails when built
      # from source on the CI darwin runners. Skip the check on darwin only;
      # linux keeps it. The let-binding shadows `ps.weasyprint` below (a let
      # binding takes precedence over `with`).
      weasyprint =
        if stdenv.hostPlatform.isDarwin then
          ps.weasyprint.overridePythonAttrs (_: { doCheck = false; })
        else
          ps.weasyprint;
    in
    with ps;
    [
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
    ]
  );

  # Runtime tools the wrapped python3 must find on PATH so
  # subprocess.run("curl"/"gh"/"git"/"jq"/"node"/"npx") inside plugin
  # scripts works without depending on the caller's PATH.
  runtimeBinPath = lib.makeBinPath [ curl gh git jq nodejs ];

  # The wrapped interpreter lives at its OWN store path (not in the
  # shared $out/bin) so multiple skill packages can be installed
  # together without colliding on bin/python3, and so the plugin tree
  # never pollutes the consumer's PATH. Script shebangs point here.
  pythonWrapped = runCommandLocal "python3-skills-claude-seo"
    { nativeBuildInputs = [ makeBinaryWrapper ]; } ''
      makeBinaryWrapper ${pythonEnv}/bin/python3 $out/bin/python3 \
        --prefix PATH : ${runtimeBinPath}
    '';
in
stdenv.mkDerivation {
  pname = "skills-claude-seo";
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

    # Repoint every #!/usr/bin/env python3 shebang at the wrapped
    # python3 (its own store path, ${pythonWrapped}). Marks files
    # executable so the kernel honors the shebang when Claude Code
    # invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!${pythonWrapped}/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -name '*.py' -type f)

    # Hook launchers have changed across upstream versions:
    #
    # - v1.9.8 used: python "''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py"
    #   That would resolve python from the caller's PATH. Drop the
    #   explicit interpreter so the patched shebang on validate-schema.py
    #   is honored.
    #
    # - v2.2.0 uses: node run-python-hook.js validate-schema.py ...
    #   That JS helper probes python from the caller's PATH. Force it to
    #   try our wrapped python first, and make the hook invoke Nix's node.
    if grep -Fq 'python \"''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py\"' \
        "$PLUGIN_DIR/hooks/hooks.json"; then
      substituteInPlace "$PLUGIN_DIR/hooks/hooks.json" --replace-fail \
        'python \"''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py\"' \
        '\"''${CLAUDE_PLUGIN_ROOT}/hooks/validate-schema.py\"'
    fi

    if grep -q '"command": "node"' "$PLUGIN_DIR/hooks/hooks.json"; then
      substituteInPlace "$PLUGIN_DIR/hooks/hooks.json" --replace-fail \
        '"command": "node"' \
        '"command": "${nodejs}/bin/node"'
    fi

    if [ -f "$PLUGIN_DIR/hooks/run-python-hook.js" ]; then
      substituteInPlace "$PLUGIN_DIR/hooks/run-python-hook.js" --replace-fail \
        'const candidates = [];' \
        'const candidates = [{ label: "bundled python3", exe: "${pythonWrapped}/bin/python3", args: [] }];'
    fi

    # Wrap each extension install/uninstall script so 'node', 'npx',
    # 'python3', 'jq', etc. resolve from Nix when a user runs them.
    # Note: 'claude' is intentionally not bundled — it is provided by
    # the consumer's flox/claude-code package.
    for f in "$PLUGIN_DIR"/extensions/*/install.sh \
             "$PLUGIN_DIR"/extensions/*/uninstall.sh; do
      [ -f "$f" ] || continue
      chmod +x "$f"
      wrapProgram "$f" --prefix PATH : "${runtimeBinPath}:${pythonWrapped}/bin"
    done

    # Rewrite upstream-install path references in markdown files to
    # the ''${CLAUDE_PLUGIN_ROOT}/... form that Claude Code uses for
    # plugins. Driven by a basename index of the plugin tree, so new
    # upstream files added in future versions are picked up without
    # changing this derivation.
    ${pythonWrapped}/bin/python3 ${./fix_md_paths.py} "$PLUGIN_DIR"

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "claude-seo" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  meta = {
    description =
      "Universal SEO plugin for Claude Code (skills, agents, hooks, extensions) with Python + binaries bundled";
    homepage = "https://github.com/AgriciDaniel/claude-seo";
    license = lib.licenses.mit;
  };
}
