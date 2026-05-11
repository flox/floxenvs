{
  stdenv,
  lib,
  fetchFromGitHub,
  makeBinaryWrapper,
  makeWrapper,
  python3,
  curl,
  gh,
  git,
  jq,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "anthropics";
    repo = "financial-services";
    rev = data.rev;
    hash = data.srcHash;
  };

  # Skill scripts + bundled marketplace scripts call into these.
  # See spec section "Why these Python deps" for which dep maps
  # to which consumer.
  pythonEnv = python3.withPackages (ps: with ps; [
    anthropic
    jsonschema
    openpyxl
    python-pptx
    pyyaml
    requests
  ]);
in
stdenv.mkDerivation {
  pname = "claude-code-plugin-financial-services";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ makeBinaryWrapper makeWrapper jq ];

  installPhase = ''
    runHook preInstall

    PLUGINS_OUT="$out/share/claude-code/plugins"
    EXTRA_OUT="$out/share/claude-code/financial-services"
    mkdir -p "$PLUGINS_OUT" "$EXTRA_OUT"

    # Lay out the 19 plugin dirs flat under plugins/.
    # Upstream tree:
    #   plugins/agent-plugins/<slug>/
    #   plugins/vertical-plugins/<slug>/
    #   plugins/partner-built/<slug>/
    for src_subdir in \
        "$src/plugins/agent-plugins" \
        "$src/plugins/vertical-plugins" \
        "$src/plugins/partner-built"; do
      [ -d "$src_subdir" ] || continue
      for plugin_dir in "$src_subdir"/*/; do
        name="$(basename "$plugin_dir")"
        cp -r "$plugin_dir" "$PLUGINS_OUT/$name"
      done
    done

    # Co-ship marketplace metadata, scripts, and managed-agent
    # cookbooks under share/claude-code/financial-services/.
    cp -r "$src/scripts" "$EXTRA_OUT/scripts"
    cp -r "$src/managed-agent-cookbooks" \
          "$EXTRA_OUT/managed-agent-cookbooks"
    mkdir -p "$EXTRA_OUT/.claude-plugin"
    cp "$src/.claude-plugin/marketplace.json" \
       "$EXTRA_OUT/.claude-plugin/marketplace.json"

    chmod -R u+w "$out"

    # Nothing to strip from per-plugin dirs — upstream packs
    # them clean. We only sanity-check that no stray repo
    # metadata leaked into the copies via cp -r.
    for d in "$PLUGINS_OUT"/*/; do
      rm -rf "$d/.github" "$d/.gitignore" 2>/dev/null || true
    done

    # Generate installed_plugins.json per plugin dir so
    # claude-managed registers and Claude Code trusts each one.
    UPSTREAM_REV="${data.rev}"
    for plugin_dir in "$PLUGINS_OUT"/*/; do
      name="$(basename "$plugin_dir")"
      plugin_json="$plugin_dir/.claude-plugin/plugin.json"
      if [ -f "$plugin_json" ]; then
        plugin_version=$(jq -r '.version // "0.0.0"' \
          "$plugin_json")
      else
        plugin_version="0.0.0"
      fi
      jq -n \
        --arg name "$name@flox" \
        --arg version "$plugin_version" \
        --arg sha "$UPSTREAM_REV" \
        '{
          plugins: {
            ($name): [{
              installPath: "",
              scope: "project",
              version: $version,
              gitCommitSha: $sha
            }]
          },
          version: 2
        }' > "$plugin_dir/installed_plugins.json"
    done

    # Wrap python3 so plugin scripts find curl/gh/git/jq on PATH
    # without depending on the consumer flox env. Same pattern as
    # claude-code-plugin-claude-seo.
    runtimeBins=${lib.makeBinPath [ curl gh git jq ]}
    mkdir -p "$out/bin"
    makeBinaryWrapper "${pythonEnv}/bin/python3" "$out/bin/python3" \
      --prefix PATH : "$runtimeBins"

    # Repoint every #!/usr/bin/env python3 shebang on line 1 at the
    # wrapped python3 and mark executable so the kernel honors the
    # shebang when Claude Code invokes the script. Only line 1 is
    # rewritten — upstream skill-creator's init_skill.py embeds a
    # second `#!/usr/bin/env python3` inside an EXAMPLE_SCRIPT
    # template that gets written to user disk, which must remain
    # portable (#!/usr/bin/env python3, not a /nix/store/... path).
    while IFS= read -r f; do
      head -1 "$f" | grep -q '^#!/usr/bin/env python3$' || continue
      sed -i '1s|^#!/usr/bin/env python3$|#!'"$out"'/bin/python3|' "$f"
      chmod +x "$f"
    done < <(find "$out/share/claude-code" -name '*.py' -type f)

    runHook postInstall
  '';

  meta = {
    description =
      "Claude for Financial Services — 19 Claude Code plugins "
      + "(agents + verticals + partner-built) with Python "
      + "runtime bundled.";
    homepage = "https://github.com/anthropics/financial-services";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
