{
  stdenv,
  lib,
  fetchFromGitHub,
  nodejs,
  python3,
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
  pname = "skills-caveman";
  inherit version;

  src = fetchFromGitHub {
    owner = "JuliusBrussee";
    repo = "caveman";
    tag = "v${version}";
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  # Emit the per-agent launch layout (share/flox/<agent>/caveman) from the
  # share/claude-code content. The helper is sourced inline (no build-input
  # derivation) so postInstall runs on the native builder — cross-system
  # publish works. Runs via runHook postInstall.
  postInstall = ''
    ${builtins.readFile ../../nix/flox-agent-layout.sh}
    flox_agent_layout "caveman" "$out/share"
    ${builtins.readFile ../../nix/flox-skill-check.sh}
    flox_skill_check "$out"
  '';

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/caveman"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin source at the repo root —
    # `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
    # both reference `./` as the plugin source. Copy the whole tree, then
    # strip per-harness mirrors, dev-only metadata, and the installer
    # entry points so Claude Code doesn't try to load or surface them
    # as plugin content.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    rm -rf "$PLUGIN_DIR/.codex" \
           "$PLUGIN_DIR/.junie" \
           "$PLUGIN_DIR/.kiro" \
           "$PLUGIN_DIR/.roo" \
           "$PLUGIN_DIR/.agents" \
           "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/.gitattributes" \
           "$PLUGIN_DIR/AGENTS.md" \
           "$PLUGIN_DIR/GEMINI.md" \
           "$PLUGIN_DIR/CLAUDE.md" \
           "$PLUGIN_DIR/CONTRIBUTING.md" \
           "$PLUGIN_DIR/INSTALL.md" \
           "$PLUGIN_DIR/gemini-extension.json" \
           "$PLUGIN_DIR/install.sh" \
           "$PLUGIN_DIR/install.ps1" \
           "$PLUGIN_DIR/package.json" \
           "$PLUGIN_DIR/skills-lock.json" \
           "$PLUGIN_DIR/bin" \
           "$PLUGIN_DIR/dist" \
           "$PLUGIN_DIR/docs" \
           "$PLUGIN_DIR/evals" \
           "$PLUGIN_DIR/benchmarks" \
           "$PLUGIN_DIR/tests" \
           "$PLUGIN_DIR/plugins" \
           "$PLUGIN_DIR/src/plugins" \
           "$PLUGIN_DIR/src/rules" \
           "$PLUGIN_DIR/src/tools"

    # v2.0.0 turned upstream into a monorepo: CLI, browser extension,
    # cache engine, SDKs, MCP servers, release tooling. None of it is
    # plugin content Claude Code loads — the plugin needs only
    # .claude-plugin/, skills/, agents/ and src/hooks/. Drop the rest
    # (scripts/ ships the dev installer whose /usr/bin/env shebang
    # fails flox_skill_check).
    rm -rf "$PLUGIN_DIR/browse" \
           "$PLUGIN_DIR/cacheengine" \
           "$PLUGIN_DIR/cli" \
           "$PLUGIN_DIR/engine" \
           "$PLUGIN_DIR/explorer" \
           "$PLUGIN_DIR/extension" \
           "$PLUGIN_DIR/integrations" \
           "$PLUGIN_DIR/mcp" \
           "$PLUGIN_DIR/mem" \
           "$PLUGIN_DIR/packages" \
           "$PLUGIN_DIR/proxy" \
           "$PLUGIN_DIR/rewriter" \
           "$PLUGIN_DIR/scripts" \
           "$PLUGIN_DIR/shared" \
           "$PLUGIN_DIR/shrink" \
           "$PLUGIN_DIR/ui" \
           "$PLUGIN_DIR/src/mcp-servers" \
           "$PLUGIN_DIR/src/hooks/install.sh" \
           "$PLUGIN_DIR/src/hooks/install.ps1" \
           "$PLUGIN_DIR/src/hooks/uninstall.sh" \
           "$PLUGIN_DIR/src/hooks/uninstall.ps1" \
           "$PLUGIN_DIR/go.mod" \
           "$PLUGIN_DIR/go.sum" \
           "$PLUGIN_DIR/pnpm-lock.yaml" \
           "$PLUGIN_DIR/pnpm-workspace.yaml" \
           "$PLUGIN_DIR/tsconfig.base.json" \
           "$PLUGIN_DIR/skills-lock.json" \
           "$PLUGIN_DIR/ANNOUNCEMENT.md" \
           "$PLUGIN_DIR/CODE_OF_CONDUCT.md" \
           "$PLUGIN_DIR/LICENSING.md" \
           "$PLUGIN_DIR/LICENSE.BSL" \
           "$PLUGIN_DIR/SECURITY.md" \
           "$PLUGIN_DIR/TRADEMARKS.md" \
           "$PLUGIN_DIR/.editorconfig" \
           "$PLUGIN_DIR/.npmignore"

    # The commands/ directory ships *only* Codex-flavored `.toml` files
    # at the upstream root. Claude Code's plugin loader picks up `.md`
    # files from `commands/` and would otherwise warn on the `.toml`s.
    # Drop them — Claude Code users drive caveman through the
    # UserPromptSubmit hook (which matches `/caveman …` in raw input),
    # so removing the TOMLs doesn't lose functionality on this harness.
    rm -rf "$PLUGIN_DIR/commands"

    # Bundle node + python so the runtime dependencies of the hooks
    # (Node) and the caveman-compress skill scripts (Python) resolve
    # without requiring the consumer's flox env to install either one.
    # Plain symlinks — no makeBinaryWrapper, no PATH prefix — because
    # caveman's Node hooks use only stdlib (fs, path, os, child_process
    # calling itself via process.execPath), and the Python scripts use
    # only stdlib (subprocess + the `claude` CLI which the consumer env
    # is expected to provide via flox/claude-code).
    mkdir -p "$PLUGIN_DIR/bin"
    ln -s "${nodejs}/bin/node" "$PLUGIN_DIR/bin/node"
    ln -s "${python3}/bin/python3" "$PLUGIN_DIR/bin/python3"

    # Repoint every #!/usr/bin/env node shebang at the bundled node.
    # Marks files executable so the kernel honors the shebang when
    # Claude Code (or the SessionStart / UserPromptSubmit hook command)
    # invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env node' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env node' "#!$PLUGIN_DIR/bin/node"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f \
              \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \))

    # Repoint every #!/usr/bin/env python3 shebang at the bundled
    # python3 for the same reason. caveman-compress invokes scripts as
    # a module (`python3 -m scripts …`), but the individual files also
    # carry shebangs and may be invoked directly during development.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!$PLUGIN_DIR/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f -name '*.py')

    # Rewrite the bare `node "${pluginRootRef}/..."` invocations in
    # plugin.json (SessionStart + UserPromptSubmit hooks) to use the
    # bundled node by absolute path. Upstream assumes `node` is on the
    # caller's PATH, which it isn't under flox unless the consumer env
    # also installs nodejs — and we don't want to force that, since the
    # whole point of bundling node here is to avoid it. The file ships
    # the path as a JSON string with escaped quotes, so the literal
    # bytes to match are `node \"${pluginRootRef}/`.
    substituteInPlace "$PLUGIN_DIR/.claude-plugin/plugin.json" \
      --replace-fail \
      'node \"${pluginRootRef}/' \
      '\"${pluginRootRef}/bin/node\" \"${pluginRootRef}/'

    # Rewrite the caveman-compress invocation in SKILL.md so it uses
    # the bundled python3 rather than the consumer's PATH. Upstream
    # tells Claude to "cd to the SKILL.md directory, then run
    # `python3 -m scripts <filepath>`" — that fails on consumer envs
    # that don't ship python3. The bundled `bin/python3` is at the
    # plugin root, two levels up from `skills/caveman-compress/`.
    compress_skill="$PLUGIN_DIR/skills/caveman-compress/SKILL.md"
    if [ -f "$compress_skill" ]; then
      substituteInPlace "$compress_skill" --replace-fail \
        'python3 -m scripts' \
        '${pluginRootRef}/bin/python3 -m scripts'
    fi

    # Defense in depth for flox_skill_check: any surviving executable
    # .sh/.py whose shebang still points at /usr/bin/env (e.g.
    # src/hooks/caveman-statusline.sh — user-invoked via `bash <path>`
    # from a statusline command, so the executable bit is not needed)
    # loses the executable bit instead of failing the build.
    while IFS= read -r f; do
      if head -1 "$f" | grep -qE '^#!/usr/bin/env |^#![a-zA-Z]'; then
        chmod -x "$f"
      fi
    done < <(find "$PLUGIN_DIR" -type f -perm -u+x \
              \( -name '*.sh' -o -name '*.py' \))

    runHook postInstall
  '';

  meta = {
    description =
      "Caveman plugin for Claude Code — ultra-compressed communication "
      + "mode (7 skills + SessionStart/UserPromptSubmit hooks) with "
      + "Node.js and Python bundled for the hooks and compress scripts.";
    homepage = "https://github.com/JuliusBrussee/caveman";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
