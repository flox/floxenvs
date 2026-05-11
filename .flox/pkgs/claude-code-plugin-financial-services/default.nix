{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
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
in
stdenvNoCC.mkDerivation {
  pname = "claude-code-plugin-financial-services";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [ jq ];

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
