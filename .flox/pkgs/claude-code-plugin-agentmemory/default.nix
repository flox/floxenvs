{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  nodejs,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # Escape so the indented-string interpolation below produces the
  # literal token `${CLAUDE_PLUGIN_ROOT}` in the resulting bash, with
  # no further Nix or bash expansion.
  pluginRootRef = "\${CLAUDE_PLUGIN_ROOT}";
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-agentmemory";
  inherit version;

  src = fetchFromGitHub {
    owner = "rohitg00";
    repo = "agentmemory";
    tag = "v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for node so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell-script wrapper are unreliable
  # under stripped environments.
  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/agentmemory"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships per-harness mirrors at top-level (.codex-plugin,
    # integrations, etc.). The Claude Code plugin source is the
    # `plugin/` subdirectory — its `.claude-plugin/plugin.json` is the
    # plugin manifest Claude Code reads.
    cp -r "$src/plugin/." "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Strip Codex-specific siblings so Claude Code doesn't try to load
    # them as part of the plugin tree.
    rm -rf "$PLUGIN_DIR/.codex-plugin" \
           "$PLUGIN_DIR/hooks/hooks.codex.json"

    # Bundle node + npx so the consumer's flox env doesn't need
    # nodejs installed just to run the plugin's hook scripts and the
    # MCP shim. Plugin hooks invoke node via plain `node ...` in
    # hooks.json; .mcp.json invokes `npx -y @agentmemory/mcp`.
    runtimeBins=${lib.makeBinPath [ nodejs ]}
    mkdir -p "$PLUGIN_DIR/bin"
    makeBinaryWrapper "${nodejs}/bin/node" "$PLUGIN_DIR/bin/node" \
      --prefix PATH : "$runtimeBins"
    # npx is a JS script with `#!/usr/bin/env node`. Wrap it so PATH
    # is amended before the kernel re-reads the shebang and dispatches
    # `env node`, otherwise the `env` lookup runs against the caller's
    # PATH — which (for an MCP server spawned by Claude Code) may not
    # include nodejs.
    makeBinaryWrapper "${nodejs}/bin/npx" "$PLUGIN_DIR/bin/npx" \
      --prefix PATH : "$runtimeBins"

    # Repoint every #!/usr/bin/env node shebang at the bundled node.
    # Marks files executable so the kernel honors the shebang when
    # Claude Code invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env node' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env node' "#!$PLUGIN_DIR/bin/node"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f \
              \( -name '*.mjs' -o -name '*.cjs' -o -name '*.js' \))

    # Repoint `node ''${CLAUDE_PLUGIN_ROOT}/scripts/<X>.mjs` hook
    # commands at the bundled node, so they don't depend on the
    # consumer env having nodejs on PATH.
    substituteInPlace "$PLUGIN_DIR/hooks/hooks.json" \
      --replace-fail \
      'node ${pluginRootRef}/' \
      '${pluginRootRef}/bin/node ${pluginRootRef}/'

    # Repoint the MCP server invocation at the bundled npx for the
    # same reason. `command` is the literal string `npx` in upstream;
    # we replace it with the ''${CLAUDE_PLUGIN_ROOT}-anchored path
    # (the same form hooks.json uses), which Claude Code expands at
    # plugin load.
    substituteInPlace "$PLUGIN_DIR/.mcp.json" \
      --replace-fail \
      '"command": "npx"' \
      '"command": "${pluginRootRef}/bin/npx"'

    runHook postInstall
  '';

  meta = {
    description =
      "agentmemory plugin for Claude Code (13 hooks + 8 skills) "
      + "with Node.js bundled for the hook scripts and MCP shim.";
    homepage = "https://github.com/rohitg00/agentmemory";
    license = lib.licenses.asl20;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
