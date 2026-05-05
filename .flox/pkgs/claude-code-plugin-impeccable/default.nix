{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  nodejs,
  git,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash commitSha;

  # Escape so the indented-string interpolation below produces the
  # literal token `${CLAUDE_PLUGIN_ROOT}` in the resulting bash, with
  # no further Nix or bash expansion.
  pluginRootRef = "\${CLAUDE_PLUGIN_ROOT}";
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-impeccable";
  inherit version;

  src = fetchFromGitHub {
    owner = "pbakaus";
    repo = "impeccable";
    tag = "skill-v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for node so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell-script wrapper are unreliable
  # under stripped environments.
  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/impeccable"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships per-harness mirrors at top-level (.claude/, .cursor/,
    # .gemini/, etc.). The Claude Code plugin source is the `plugin/`
    # subdirectory — that's what marketplace.json points at.
    cp -r "$src/plugin/." "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Wrap node so the one git invocation in scripts/is-generated.mjs
    # (`git check-ignore`) and the npx-based external impeccable CLI
    # referenced from markdown resolve from Nix without depending on
    # the caller's PATH.
    #
    # Place node *inside* the plugin tree so users can call it via
    # ''${CLAUDE_PLUGIN_ROOT}/bin/node — the consumer's flox env doesn't
    # ship nodejs (and shouldn't have to, just because they want this
    # plugin), so Claude's `Bash(node ...)` invocations would otherwise
    # fail with `command not found: node`.
    runtimeBins=${lib.makeBinPath [ git nodejs ]}
    mkdir -p "$PLUGIN_DIR/bin"
    makeBinaryWrapper "${nodejs}/bin/node" "$PLUGIN_DIR/bin/node" \
      --prefix PATH : "$runtimeBins"
    # npx is a JS script; it'll find the wrapped node via the wrapper
    # itself prepending nodejs onto PATH at exec time.
    ln -s "${nodejs}/bin/npx" "$PLUGIN_DIR/bin/npx"

    # Repoint every #!/usr/bin/env node shebang at the wrapped node.
    # Marks files executable so the kernel honors the shebang when
    # Claude Code invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env node' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env node' "#!$PLUGIN_DIR/bin/node"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f \( -name '*.mjs' -o -name '*.js' \))

    # Rewrite hardcoded `.claude/skills/impeccable/scripts/<X>` references
    # in markdown to `''${CLAUDE_PLUGIN_ROOT}/skills/impeccable/scripts/<X>`,
    # the form Claude Code uses for plugins. Upstream's markdown is shared
    # across harnesses so it embeds the user-install layout, which is wrong
    # under a plugin install where the plugin root is `plugin/`.
    #
    # Then prefix bare `node ''${CLAUDE_PLUGIN_ROOT}/...` and
    # `npx impeccable ...` invocations with our bundled binaries, so
    # they don't depend on the consumer env having nodejs installed.
    rewritten=0
    while IFS= read -r f; do
      changed=0
      if grep -q '\.claude/skills/impeccable/scripts/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '.claude/skills/impeccable/scripts/' \
          '${pluginRootRef}/skills/impeccable/scripts/'
        changed=1
      fi
      if grep -qF 'node ${pluginRootRef}/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          'node ${pluginRootRef}/' \
          '${pluginRootRef}/bin/node ${pluginRootRef}/'
        changed=1
      fi
      if grep -q 'npx impeccable' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          'npx impeccable' \
          '${pluginRootRef}/bin/npx impeccable'
        changed=1
      fi
      [ $changed -eq 1 ] && rewritten=$((rewritten + 1))
    done < <(find "$PLUGIN_DIR" -type f -name '*.md')
    echo "fix_md_paths: rewrote refs in $rewritten markdown file(s)"

    # Drop an installed_plugins.json next to the plugin so claude-managed
    # registers it in $CLAUDE_CONFIG_DIR/plugins/installed_plugins.json
    # — without that file Claude Code lists the plugin but won't trust it.
    # Schema follows the v2 (`plugins` wrapper) format claude-managed uses;
    # installPath is patched to the real symlink target by `plugins add`.
    cat > "$PLUGIN_DIR/installed_plugins.json" <<JSON
    {
      "plugins": {
        "impeccable@flox": [
          {
            "installPath": "",
            "scope": "project",
            "version": "${version}",
            "gitCommitSha": "${commitSha}"
          }
        ]
      },
      "version": 2
    }
    JSON

    runHook postInstall
  '';

  meta = {
    description =
      "Impeccable design fluency plugin for Claude Code (1 skill, 23 commands) with Node.js bundled";
    homepage = "https://github.com/pbakaus/impeccable";
    license = lib.licenses.asl20;
  };
}
