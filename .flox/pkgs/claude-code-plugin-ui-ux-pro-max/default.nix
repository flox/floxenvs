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

  # Escape so the indented-string interpolation below produces the
  # literal token `${CLAUDE_PLUGIN_ROOT}` in the resulting bash, with
  # no further Nix or bash expansion.
  pluginRootRef = "\${CLAUDE_PLUGIN_ROOT}";
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-ui-ux-pro-max";
  inherit version;

  src = fetchFromGitHub {
    owner = "nextlevelbuilder";
    repo = "ui-ux-pro-max-skill";
    tag = "v${version}";
    hash = srcHash;
  };

  # makeBinaryWrapper produces a compiled C wrapper for python3 so it
  # is exec'd directly by the kernel via shebang on Darwin, where
  # shebang chains through a shell-script wrapper are unreliable
  # under stripped environments.
  nativeBuildInputs = [ makeBinaryWrapper ];

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/ui-ux-pro-max"
    mkdir -p "$PLUGIN_DIR"

    # `cp -a` preserves the two symlinks
    # `.claude/skills/ui-ux-pro-max/{data,scripts}` →
    # `../../../src/ui-ux-pro-max/{data,scripts}` that wire the active
    # skill to its CSV data and BM25 search scripts.
    cp -a "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Drop dirs that aren't part of the runtime plugin: GitHub config,
    # the standalone npm install CLI for non-Claude editors, docs site,
    # marketing previews/screenshots, and the demo `cat-feeding-app`
    # HTML page upstream ships as a sample artifact.
    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/cat-feeding-app" \
           "$PLUGIN_DIR/cli" \
           "$PLUGIN_DIR/docs" \
           "$PLUGIN_DIR/preview" \
           "$PLUGIN_DIR/screenshots"

    # Wrap python3 so the BM25 search scripts always find a working
    # interpreter even when the consumer's flox env doesn't ship one.
    # The active skill imports only stdlib (csv/json/re/argparse/...),
    # so no extra packages needed.
    mkdir -p "$PLUGIN_DIR/bin"
    makeBinaryWrapper "${python3}/bin/python3" "$PLUGIN_DIR/bin/python3"

    # Normalize CRLF → LF on `.py` files first. Upstream ships
    # `src/ui-ux-pro-max/scripts/search.py` with Windows line endings,
    # which leaves a `\r` at the end of the shebang line and makes the
    # kernel try to exec `<wrapped-python>\r` (ENOENT). Other CSV/MD
    # files we leave alone — the `\r` only matters where it ends up on
    # the shebang line, and Python's `csv` module handles both.
    find "$PLUGIN_DIR" -type f -name '*.py' \
      -exec sed -i 's/\r$//' {} +

    # Repoint every `#!/usr/bin/env python3` shebang at the wrapped
    # python so Claude Code can invoke scripts via their path without
    # depending on the caller's PATH. Marks them executable so the
    # kernel honors the shebang.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env python3' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env python3' "#!$PLUGIN_DIR/bin/python3"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f -name '*.py')

    # Rewrite the SKILL.md's `python3 skills/ui-ux-pro-max/scripts/<X>`
    # invocations to absolute references that work under a plugin
    # install. Upstream's markdown embeds the user-install layout (where
    # `skills/` is the install dir), which doesn't resolve from a plugin
    # whose root is wherever Claude Code unpacks it. Also routes them
    # through our bundled python so the consumer's env doesn't have to
    # ship one.
    rewritten=0
    while IFS= read -r f; do
      grep -q 'python3 skills/ui-ux-pro-max/scripts/' "$f" || continue
      substituteInPlace "$f" --replace-quiet \
        'python3 skills/ui-ux-pro-max/scripts/' \
        '${pluginRootRef}/bin/python3 ${pluginRootRef}/.claude/skills/ui-ux-pro-max/scripts/'
      rewritten=$((rewritten + 1))
    done < <(find "$PLUGIN_DIR" -type f -name '*.md')
    echo "rewrote python invocations in $rewritten markdown file(s)"

    # Drop an installed_plugins.json next to the plugin so flox-ai
    # registers it in $CLAUDE_CONFIG_DIR/plugins/installed_plugins.json
    # — without that file Claude Code lists the plugin but won't trust it.
    # Schema follows the v2 (`plugins` wrapper) format flox-ai uses;
    # installPath is patched to the real symlink target by `plugins add`.
    cat > "$PLUGIN_DIR/installed_plugins.json" <<JSON
    {
      "plugins": {
        "ui-ux-pro-max@flox": [
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
      "UI/UX Pro Max design intelligence plugin for Claude Code "
      + "— styles, palettes, typography, charts, and UX guidance "
      + "across 15+ stacks (Python search engine bundled).";
    homepage = "https://github.com/nextlevelbuilder/ui-ux-pro-max-skill";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
