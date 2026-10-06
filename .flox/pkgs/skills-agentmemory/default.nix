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
  pname = "skills-agentmemory";
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
  nativeBuildInputs = [
    makeBinaryWrapper
  ];

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

    # Bundle node so the consumer's flox env doesn't need nodejs
    # installed just to run the plugin's hook scripts and the MCP
    # server. Both invoke node via plain `node ...` — hooks.json in its
    # hook commands, .mcp.json for the plugin bridge.
    runtimeBins=${lib.makeBinPath [ nodejs ]}
    mkdir -p "$PLUGIN_DIR/bin"
    makeBinaryWrapper "${nodejs}/bin/node" "$PLUGIN_DIR/bin/node" \
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

    # Repoint `node "''${CLAUDE_PLUGIN_ROOT}/scripts/<X>.mjs"` hook
    # commands at the bundled node, so they don't depend on the
    # consumer env having nodejs on PATH. Upstream (v0.9.21+) wraps
    # the path in JSON-escaped quotes, so the literal bytes in the
    # file are `node \"''${CLAUDE_PLUGIN_ROOT}/...\"`.
    substituteInPlace "$PLUGIN_DIR/hooks/hooks.json" \
      --replace-fail \
      'node \"${pluginRootRef}/' \
      '\"${pluginRootRef}/bin/node\" \"${pluginRootRef}/'

    # Repoint the MCP server invocation at the bundled node for the
    # same reason. Up to 0.9.29 upstream shelled out to
    # `npx -y @agentmemory/mcp`; 0.9.30 runs the bridge script
    # directly, so `command` is now the literal string `node`. Replace
    # it with the ''${CLAUDE_PLUGIN_ROOT}-anchored path (the same form
    # hooks.json uses), which Claude Code expands at plugin load.
    substituteInPlace "$PLUGIN_DIR/.mcp.json" \
      --replace-fail \
      '"command": "node"' \
      '"command": "${pluginRootRef}/bin/node"'

    runHook postInstall
  '';

  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "agentmemory" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
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
      "x86_64-linux"
    ];
  };
}
