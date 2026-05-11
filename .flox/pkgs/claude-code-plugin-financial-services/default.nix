{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
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
