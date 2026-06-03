{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "skill-temporal-developer";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-temporal-developer";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Upstream ships a single skill: SKILL.md at the repo root
    # plus a references/ tree it links into (references/core/*.md
    # and per-language go/, python/, java/, dotnet/, typescript/,
    # ruby/). SKILL.md's links are relative, so the references/
    # tree must travel with it or every reference breaks. Install
    # the whole thing under skills/temporal-developer/ for both
    # Claude Code and OpenCode, where claude-managed (pulled in via
    # flox/claude) auto-discovers it on activate.
    if [ ! -f "$src/SKILL.md" ]; then
      echo "error: SKILL.md not found in skill-temporal-developer" >&2
      exit 1
    fi

    for dest in \
      "$out/share/claude-code/skills/temporal-developer" \
      "$out/share/opencode/skills/temporal-developer"; do
      mkdir -p "$dest"
      cp "$src/SKILL.md" "$dest/SKILL.md"
      if [ -d "$src/references" ]; then
        cp -r "$src/references" "$dest/references"
      fi
    done

    runHook postInstall
  '';

  meta = {
    description =
      "Temporal Developer skill for Claude Code and OpenCode "
      + "— build, debug, and manage Temporal workflows, "
      + "activities, and workers across Python, TypeScript, Go, "
      + "Java, .NET, and Ruby.";
    homepage = "https://github.com/temporalio/skill-temporal-developer";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
