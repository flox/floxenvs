{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  python3,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash commitSha;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-claude-obsidian";
  inherit version;

  src = fetchFromGitHub {
    owner = "AgriciDaniel";
    repo = "claude-obsidian";
    tag = "v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for python3 so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell-script wrapper are unreliable
  # under stripped environments.
  nativeBuildInputs = [ makeBinaryWrapper ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/claude-obsidian"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin source at the repo root —
    # `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`
    # both live at the top level. Copy the whole tree, then strip per-
    # harness mirrors, repo-only metadata, upstream test runners, and
    # upstream's own dogfood vault content.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Per-harness mirrors and repo/CI metadata that aren't part of the
    # runtime plugin.
    rm -rf "$PLUGIN_DIR/.cursor" \
           "$PLUGIN_DIR/.windsurf" \
           "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/AGENTS.md" \
           "$PLUGIN_DIR/CLAUDE.md" \
           "$PLUGIN_DIR/GEMINI.md" \
           "$PLUGIN_DIR/Makefile" \
           "$PLUGIN_DIR/tests"

    # Upstream's own dogfood vault: example pages, raw clips, and vault
    # metadata. Users start with an empty vault — these would otherwise
    # leak upstream-specific content into every install.
    rm -rf "$PLUGIN_DIR/wiki" \
           "$PLUGIN_DIR/.raw" \
           "$PLUGIN_DIR/.vault-meta"

    # Wrap python3 so the DragonScale scripts (boundary-score.py,
    # tiling-check.py) resolve a working interpreter even when the
    # consumer's flox env doesn't ship one. Both scripts use only the
    # Python stdlib (urllib for ollama, fcntl for locking, hashlib,
    # math, re, etc.) so no extra packages are needed.
    mkdir -p "$PLUGIN_DIR/bin-runtime"
    makeBinaryWrapper "${python3}/bin/python3" \
      "$PLUGIN_DIR/bin-runtime/python3"

    # Repoint every `#!/usr/bin/env python3` shebang at the wrapped
    # python and mark executable so the kernel honors the shebang when
    # Claude Code (or the user) invokes the script directly.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!$PLUGIN_DIR/bin-runtime/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f -name '*.py')

    # Bash scripts compute the vault root from BASH_SOURCE
    # (`$(dirname "''${BASH_SOURCE[0]}")/..`), so they only function
    # correctly when copied/symlinked into the user's vault — wrapping
    # them with nix-store paths would point VAULT_ROOT at the plugin
    # install and break the design. Just make them executable for the
    # case where the user does copy them into their vault.
    find "$PLUGIN_DIR/bin" "$PLUGIN_DIR/scripts" \
      -type f -name '*.sh' -exec chmod +x {} +

    # Drop an installed_plugins.json next to the plugin so claude-managed
    # registers it in $CLAUDE_CONFIG_DIR/plugins/installed_plugins.json
    # — without that file Claude Code lists the plugin but won't trust
    # it. Schema follows the v2 (`plugins` wrapper) format claude-managed
    # uses; installPath is patched to the real symlink target by
    # `claude-managed plugins add`.
    cat > "$PLUGIN_DIR/installed_plugins.json" <<JSON
    {
      "plugins": {
        "claude-obsidian@flox": [
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
      "Claude + Obsidian knowledge companion plugin for Claude Code "
      + "— persistent compounding wiki vault (Karpathy LLM Wiki "
      + "pattern) with /wiki, /save, /autoresearch, /canvas commands, "
      + "agents, hooks, and the DragonScale Memory extension "
      + "(Python runtime bundled).";
    homepage = "https://github.com/AgriciDaniel/claude-obsidian";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
