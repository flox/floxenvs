{
  stdenv,
  lib,
  fetchFromGitHub,
  jq,
  curl,
  coreutils,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-agent-skills";
  inherit version;

  src = fetchFromGitHub {
    owner = "addyosmani";
    repo = "agent-skills";
    # Upstream tags releases as bare `X.Y.Z` (no `v` prefix).
    tag = version;
    hash = srcHash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    PLUGIN_DIR="$out/share/claude-code/plugins/agent-skills"
    mkdir -p "$PLUGIN_DIR"

    # Upstream ships the Claude Code plugin source at the repo root —
    # `.claude-plugin/plugin.json` points commands at `./.claude/commands`,
    # skills at `./skills`, and agents at `./agents/*.md`. Copy the whole
    # tree, then strip per-harness mirrors, dev-only metadata, tests, and
    # the duplicate root manifest so Claude Code only sees plugin content.
    cp -r "$src"/. "$PLUGIN_DIR/"
    chmod -R u+w "$PLUGIN_DIR"

    # Per-harness mirrors and repo dev metadata. `.claude/` stays — the
    # manifest's `commands` field points into `.claude/commands`.
    rm -rf "$PLUGIN_DIR/.gemini" \
           "$PLUGIN_DIR/.opencode" \
           "$PLUGIN_DIR/.github" \
           "$PLUGIN_DIR/.gitignore" \
           "$PLUGIN_DIR/.gitattributes" \
           "$PLUGIN_DIR/AGENTS.md" \
           "$PLUGIN_DIR/CLAUDE.md" \
           "$PLUGIN_DIR/CONTRIBUTING.md"

    # The top-level `commands/` directory holds Codex-flavored `.toml`
    # files — duplicates of the Claude Code `.md` commands under
    # `.claude/commands/` that the manifest actually references. Drop the
    # toml mirror so Claude Code's loader doesn't warn on them.
    rm -rf "$PLUGIN_DIR/commands"

    # `docs/` is entirely other-harness setup guides (cursor, copilot,
    # gemini-cli, opencode, windsurf, antigravity…) — irrelevant to a
    # Claude Code plugin install.
    rm -rf "$PLUGIN_DIR/docs"

    # `scripts/validate-skills.js` is a CI/dev linter (Node), never run
    # from the installed tree. Removing it lets us avoid bundling Node.
    rm -rf "$PLUGIN_DIR/scripts"

    # `*-test.sh` files under hooks/ are dev self-tests (they shell out to
    # node). The runtime hooks (session-start, sdd-cache-*, simplify-ignore)
    # and their `.md` docs stay.
    rm -f "$PLUGIN_DIR"/hooks/*-test.sh

    # The repo root carries a stray `plugin.json` (name only, version
    # 1.0.0) alongside the real `.claude-plugin/plugin.json`. Claude Code
    # reads `.claude-plugin/plugin.json`; remove the root duplicate so the
    # version source stays unambiguous.
    rm -f "$PLUGIN_DIR/plugin.json"

    # ─── Bundle runtime dependencies ──────────────────────────────────
    # The only auto-wired hook (hooks/hooks.json → SessionStart →
    # session-start.sh) needs `jq`. The opt-in hooks documented in
    # hooks/*.md (sdd-cache-pre/post, simplify-ignore) additionally need
    # `curl` and a SHA tool. macOS ships `shasum` but not `sha256sum`;
    # those scripts auto-detect and fall back to `sha256sum`/`sha1sum`,
    # which coreutils provides. Bundle all three so the hooks resolve
    # without the consumer's flox env installing anything.
    mkdir -p "$PLUGIN_DIR/bin"
    ln -s "${jq}/bin/jq"               "$PLUGIN_DIR/bin/jq"
    ln -s "${curl}/bin/curl"           "$PLUGIN_DIR/bin/curl"
    ln -s "${coreutils}/bin/sha256sum" "$PLUGIN_DIR/bin/sha256sum"
    ln -s "${coreutils}/bin/sha1sum"   "$PLUGIN_DIR/bin/sha1sum"

    # The hooks invoke these tools by bare name (`jq …`, `curl …`,
    # `sha256sum …`) relying on PATH. Prepend the bundled bin/ to PATH at
    # the top of each shipped hook so they resolve to the bundled copies.
    # Claude Code exports CLAUDE_PLUGIN_ROOT for hook commands; fall back
    # to a `$0`-relative path for direct invocation. Insert right after
    # the `#!/bin/bash` shebang line.
    pathLine='_pbin="''${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/bin"; [ -d "$_pbin" ] && PATH="$_pbin:$PATH"'
    for f in "$PLUGIN_DIR"/hooks/*.sh; do
      [ -f "$f" ] || continue
      head -1 "$f" | grep -q '^#!/bin/bash' || continue
      substituteInPlace "$f" --replace-fail \
        '#!/bin/bash' "#!/bin/bash
$pathLine"
      chmod +x "$f"
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Addy Osmani's agent-skills for Claude Code — 24 production-grade "
      + "engineering skills, 8 commands, 4 agents, and a SessionStart "
      + "meta-skill hook, with jq/curl/coreutils bundled for the hooks.";
    homepage = "https://github.com/addyosmani/agent-skills";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
