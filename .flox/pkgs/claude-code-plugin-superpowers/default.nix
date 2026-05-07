{
  stdenv,
  lib,
  fetchFromGitHub,
  nodejs,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash commitSha;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-superpowers";
  inherit version;

  src = fetchFromGitHub {
    owner = "obra";
    repo = "superpowers";
    tag = "v${version}";
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/superpowers"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin source at the repo root —
    # `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
    # both reference `./` as the plugin source. Copy the whole tree, then
    # strip per-harness mirrors and repo-only metadata that Claude Code
    # would otherwise attempt to load or surface as plugin content.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    rm -rf "$PLUGIN_DIR/.codex-plugin" \
           "$PLUGIN_DIR/.cursor-plugin" \
           "$PLUGIN_DIR/.opencode" \
           "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/.gitattributes" \
           "$PLUGIN_DIR/.version-bump.json" \
           "$PLUGIN_DIR/AGENTS.md" \
           "$PLUGIN_DIR/CLAUDE.md" \
           "$PLUGIN_DIR/GEMINI.md" \
           "$PLUGIN_DIR/gemini-extension.json" \
           "$PLUGIN_DIR/package.json" \
           "$PLUGIN_DIR/scripts" \
           "$PLUGIN_DIR/tests"

    # Bundle node so the brainstorming visual companion (server.cjs) and
    # render-graphs.js resolve a runtime without requiring the consumer's
    # flox env to install nodejs. Plain symlink — no makeBinaryWrapper,
    # no PATH prefix — because superpowers' Node code is stdlib-only:
    # server.cjs uses crypto/http/fs and never shells out; render-graphs.js
    # shells to `dot` (graphviz), which we deliberately leave to the
    # consumer.
    mkdir -p "$PLUGIN_DIR/bin"
    ln -s "${nodejs}/bin/node" "$PLUGIN_DIR/bin/node"

    # Repoint every #!/usr/bin/env node shebang at the bundled node.
    # Marks files executable so the kernel honors the shebang when
    # Claude Code invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env node' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env node' "#!$PLUGIN_DIR/bin/node"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f \
              \( -name '*.cjs' -o -name '*.js' -o -name '*.mjs' \))

    # The brainstorm server is started from start-server.sh via two
    # `node server.cjs` invocations (foreground + nohup background).
    # Rewrite both to use the bundled node by absolute path. The script
    # defines SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)" at the top, so
    # $SCRIPT_DIR/../../../bin/node resolves to $PLUGIN_DIR/bin/node.
    # --replace-fail makes upstream renames trip the build instead of
    # silently shipping a broken script.
    substituteInPlace \
      "$PLUGIN_DIR/skills/brainstorming/scripts/start-server.sh" \
      --replace-fail \
      'node server.cjs' \
      '"$SCRIPT_DIR/../../../bin/node" server.cjs'

    # Make hook entry points executable. session-start has a bash
    # shebang (auto-patched by fixupPhase). run-hook.cmd is a
    # shebang-less polyglot — Claude Code invokes it via /bin/sh, which
    # falls back to interpreting it as a shell script when exec hits
    # ENOEXEC.
    chmod +x "$PLUGIN_DIR/hooks/session-start" \
             "$PLUGIN_DIR/hooks/run-hook.cmd"

    # Drop installed_plugins.json so claude-managed registers the plugin
    # in $CLAUDE_CONFIG_DIR/plugins/installed_plugins.json at activation.
    # installPath is patched to the real symlink target by
    # `claude-managed plugins add`. v2 is the schema claude-managed
    # >=0.2.8 reads.
    cat > "$PLUGIN_DIR/installed_plugins.json" <<JSON
    {
      "plugins": {
        "superpowers@flox": [
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
      "Superpowers plugin for Claude Code (14 skills + SessionStart "
      + "hook) with Node.js bundled for the brainstorming visual "
      + "companion.";
    homepage = "https://github.com/obra/superpowers";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
