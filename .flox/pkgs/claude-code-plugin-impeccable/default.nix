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
  inherit (versionData) version srcHash;

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
    runtimeBins=${lib.makeBinPath [ git nodejs ]}
    mkdir -p "$out/bin"
    makeBinaryWrapper "${nodejs}/bin/node" "$out/bin/node" \
      --prefix PATH : "$runtimeBins"

    # Repoint every #!/usr/bin/env node shebang at the wrapped node.
    # Marks files executable so the kernel honors the shebang when
    # Claude Code invokes them.
    while IFS= read -r f; do
      head -1 "$f" | grep -q '/usr/bin/env node' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/usr/bin/env node' "#!$out/bin/node"
      chmod +x "$f"
    done < <(find "$PLUGIN_DIR" -type f \( -name '*.mjs' -o -name '*.js' \))

    # Rewrite hardcoded `.claude/skills/impeccable/scripts/<X>` references
    # in markdown to `''${CLAUDE_PLUGIN_ROOT}/skills/impeccable/scripts/<X>`,
    # the form Claude Code uses for plugins. Upstream's markdown is shared
    # across harnesses so it embeds the user-install layout, which is wrong
    # under a plugin install where the plugin root is `plugin/`.
    rewritten=0
    while IFS= read -r f; do
      if grep -q '\.claude/skills/impeccable/scripts/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '.claude/skills/impeccable/scripts/' \
          '${pluginRootRef}/skills/impeccable/scripts/'
        rewritten=$((rewritten + 1))
      fi
    done < <(find "$PLUGIN_DIR" -type f -name '*.md')
    echo "fix_md_paths: rewrote refs in $rewritten markdown file(s)"

    runHook postInstall
  '';

  meta = {
    description =
      "Impeccable design fluency plugin for Claude Code (1 skill, 23 commands) with Node.js bundled";
    homepage = "https://github.com/pbakaus/impeccable";
    license = lib.licenses.asl20;
  };
}
