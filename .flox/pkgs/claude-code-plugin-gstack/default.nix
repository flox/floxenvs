{
  stdenv,
  lib,
  fetchFromGitHub,
  bun,
  nodejs,
  git,
  jq,
  curl,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version rev srcHash;

  # Escape so the indented-string interpolation below produces the
  # literal token `${CLAUDE_PLUGIN_ROOT}` in the resulting bash, with
  # no further Nix or bash expansion.
  pluginRootRef = "\${CLAUDE_PLUGIN_ROOT}";

  # Synthesized plugin manifest. gstack upstream targets the legacy
  # ~/.claude/skills/gstack/ install path and ships no
  # .claude-plugin/plugin.json of its own.
  pluginManifest = builtins.toJSON {
    name = "gstack";
    inherit version;
    description =
      "Garry Tan's Claude Code stack — 45 skills for planning, "
      + "design, QA, code review, security, and shipping. "
      + "Originally designed for the legacy ~/.claude/skills/gstack/ "
      + "install path; this is the Claude Code plugin port.";
    homepage = "https://github.com/garrytan/gstack";
    repository = "https://github.com/garrytan/gstack";
    license = "MIT";
  };
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-gstack";
  inherit version;

  src = fetchFromGitHub {
    owner = "garrytan";
    repo = "gstack";
    inherit rev;
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  # ─── Substitution tokens ──────────────────────────────────────────
  # Available as @TOKEN@ in installPhase via stdenv's substitute helpers,
  # but we use plain bash variables here for clarity.

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/gstack"
    mkdir -p "$PLUGIN_DIR"

    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # ─── Strip repo-only metadata + tests ─────────────────────────
    # These directories add ~megabytes and never run from the
    # installed plugin tree. Leave the top-level *.md (CHANGELOG,
    # README, CONTRIBUTING, etc.) in place — they help users orient.
    rm -rf "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/.gitattributes" \
           "$PLUGIN_DIR/.gitlab-ci.yml" \
           "$PLUGIN_DIR/.env.example" \
           "$PLUGIN_DIR/test" \
           "$PLUGIN_DIR/conductor.json" \
           "$PLUGIN_DIR/slop-scan.config.json"

    # Remove the dangling symlink (points at gstack/open-gstack-browser
    # which lives elsewhere in the upstream tree). Claude Code's plugin
    # loader walks the tree and chokes on broken symlinks.
    rm -f "$PLUGIN_DIR/connect-chrome"

    # ─── Expose skill dirs under skills/ for the plugin loader ────
    # Upstream keeps each skill at the top level of the gstack tree
    # (legacy ~/.claude/skills/gstack/<name>/SKILL.md layout). Skills
    # cross-reference each other (and back at bin/, lib/, design/)
    # using top-level paths — moving them under skills/ breaks every
    # such reference inside the skill prose. Claude Code's plugin
    # loader scans $PLUGIN_ROOT/skills/<name>/SKILL.md, so expose the
    # dirs there via symlinks instead.
    mkdir -p "$PLUGIN_DIR/skills"
    while IFS= read -r skill_md; do
      dir="$(dirname "$skill_md")"
      base="$(basename "$dir")"
      # Skip the plugin root itself (its SKILL.md is the unused
      # root-skill template, removed below).
      [ "$dir" = "$PLUGIN_DIR" ] && continue
      # Skip anything already under skills/ (defensive — upstream
      # currently has nothing nested, but a future rename shouldn't
      # break the build).
      case "$dir" in *"/skills/"*) continue;; esac
      ln -s "../$base" "$PLUGIN_DIR/skills/$base"
    done < <(find "$PLUGIN_DIR" -maxdepth 2 -name 'SKILL.md' -type f)

    # Remove the root SKILL.md / SKILL.md.tmpl — they describe the
    # standalone "/gstack" command that gstack's setup script
    # generates on direct install. The plugin loader doesn't use it,
    # and leaving SKILL.md at the plugin root would register a bare
    # `/gstack` command that collides with the package name.
    rm -f "$PLUGIN_DIR/SKILL.md" "$PLUGIN_DIR/SKILL.md.tmpl"

    # ─── Bundle runtime tools ─────────────────────────────────────
    # gstack bin scripts shell out to bun, node, git, jq, curl. Bundle
    # symlinks inside the plugin so they resolve without depending on
    # the consumer's flox env having every one installed.
    mkdir -p "$PLUGIN_DIR/tools/bin"
    ln -s ${bun}/bin/bun        "$PLUGIN_DIR/tools/bin/bun"
    ln -s ${nodejs}/bin/node    "$PLUGIN_DIR/tools/bin/node"
    ln -s ${nodejs}/bin/npm     "$PLUGIN_DIR/tools/bin/npm"
    ln -s ${nodejs}/bin/npx     "$PLUGIN_DIR/tools/bin/npx"
    ln -s ${git}/bin/git        "$PLUGIN_DIR/tools/bin/git"
    ln -s ${jq}/bin/jq          "$PLUGIN_DIR/tools/bin/jq"
    ln -s ${curl}/bin/curl      "$PLUGIN_DIR/tools/bin/curl"

    # ─── Synthesize plugin.json ───────────────────────────────────
    mkdir -p "$PLUGIN_DIR/.claude-plugin"
    cat > "$PLUGIN_DIR/.claude-plugin/plugin.json" <<'PLUGIN_JSON_EOF'
    ${pluginManifest}
    PLUGIN_JSON_EOF

    # ─── Rewrite hardcoded skill-root paths ───────────────────────
    # Upstream SKILL.md preambles hardcode
    #   ~/.claude/skills/gstack/bin/...
    #   .claude/skills/gstack/bin/...
    # which only resolve under a standalone gstack install. In plugin
    # mode, Claude Code exports CLAUDE_PLUGIN_ROOT for every Bash tool
    # invocation — substitute that token so the preambles resolve to
    # the bundled bin/, browse/, design/, make-pdf/ trees.
    #
    # The grep guards keep substituteInPlace from failing the build on
    # files that don't contain the source token (--replace-fail
    # semantics in nixpkgs).
    rewritten=0
    while IFS= read -r f; do
      changed=0
      if grep -q '~/\.claude/skills/gstack/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '~/.claude/skills/gstack/' \
          '${pluginRootRef}/'
        changed=1
      fi
      if grep -q '"\$HOME"/\.claude/skills/gstack/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '"$HOME"/.claude/skills/gstack/' \
          '${pluginRootRef}/'
        changed=1
      fi
      if grep -q '\$HOME/\.claude/skills/gstack/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '$HOME/.claude/skills/gstack/' \
          '${pluginRootRef}/'
        changed=1
      fi
      if grep -q '\.claude/skills/gstack/' "$f"; then
        substituteInPlace "$f" --replace-quiet \
          '.claude/skills/gstack/' \
          '${pluginRootRef}/'
        changed=1
      fi
      [ $changed -eq 1 ] && rewritten=$((rewritten + 1))
    done < <(find "$PLUGIN_DIR" -type f -name '*.md')
    echo "rewrote skill-root path refs in $rewritten markdown file(s)"

    # ─── Executable bits ──────────────────────────────────────────
    # nix-store copies preserve mode for files originating as +x, but
    # the gstack bin/ scripts ship without committed +x in some forks
    # (Windows checkouts). Force +x on every bin entry.
    find "$PLUGIN_DIR/bin" -type f -exec chmod +x {} +
    # gstack's own setup script (not used in plugin mode, but harmless
    # to keep executable for users inspecting the tree).
    [ -f "$PLUGIN_DIR/setup" ] && chmod +x "$PLUGIN_DIR/setup" || true

    runHook postInstall
  '';

  meta = {
    description =
      "Garry Tan's Claude Code stack (gstack) — 45 skills covering "
      + "planning, design, QA, review, security, and release "
      + "management. Packaged as a Claude Code plugin.";
    homepage = "https://github.com/garrytan/gstack";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
