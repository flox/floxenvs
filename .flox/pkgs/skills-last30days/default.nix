{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
  nodejs_22,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);

  # The engine is pure-stdlib Python — pyproject declares no runtime
  # dependencies, and every import across scripts/ resolves to the
  # standard library — so it only needs a 3.12+ interpreter. The
  # X/Twitter source (scripts/lib/bird_x.py) shells out to the vendored
  # scripts/lib/vendor/bird-search/bird-search.mjs, which needs Node 22+
  # (and has no npm dependencies of its own). Both runtimes are bundled
  # so the skill runs with no host Python/Node and no surrounding flox
  # environment.
  py = "${python3}/bin/python3";
  rtPath = lib.makeBinPath [
    python3
    nodejs_22
  ];

  src = fetchFromGitHub {
    owner = "mvanhorn";
    repo = "last30days-skill";
    rev = data.rev;
    hash = data.srcHash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "skills-last30days";
  version = data.version;
  inherit src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # last30days is a directory skill: SKILL.md drives the engine by a
    # path relative to its own location (`"$SKILL_DIR/scripts/last30days.py"`),
    # so the whole skills/last30days tree must ship together with SKILL.md
    # at the root. Ship into every agent skills dir we support.
    for share in \
      "$out/share/claude-code/skills" \
      "$out/share/opencode/skills"; do
      mkdir -p "$share"
      cp -r "$src/skills/last30days" "$share/last30days"
      chmod -R u+w "$share/last30days"
    done

    runHook postInstall
  '';

  # Wire the engine to the bundled runtimes so it runs with no host
  # Python/Node and no surrounding flox env:
  #
  #   1. Each entry-point helper's shebang -> the bundled interpreter.
  #   2. A startup shim (injected right after the script's first import
  #      anchor) prepends the bundled python3 + node bins to PATH, so the
  #      `shutil.which("node")` gate and the `["node", bird-search.mjs,
  #      ...]` subprocess in lib/bird_x.py resolve the bundled Node, and
  #      re-execs the script under the bundled interpreter if it was
  #      launched some other way.
  #   3. SKILL.md's "Runtime Preflight" probes PATH for a python3.12+ and
  #      keeps it in LAST30DAYS_PYTHON; pin that probe to the bundled
  #      interpreter directly so the engine Bash call uses it with nothing
  #      installed.
  postInstall = ''
    for skill in "$out"/share/*/skills/last30days; do
      scripts="$skill/scripts"

      # Only the top-level entry scripts are executed directly; the
      # lib/ modules are imported into the same process, so the PATH the
      # entry script sets up covers them too.
      for f in "$scripts"/*.py; do
        anchor='from __future__ import'
        if ! grep -q "^$anchor" "$f"; then
          # No __future__ import: anchor the shim right after the shebang.
          anchor='__SHEBANG_ONLY__'
        fi
        # NB: awk var is BINS, not RT — RT is a gawk built-in (record
        # terminator) and gawk clobbers any -v RT= with the matched
        # newline on the first record read.
        awk -v PY="${py}" -v BINS="${rtPath}" -v ANCHOR="$anchor" '
          function emit() {
            print "import os as _os, sys as _sys"
            print "_os.environ[\"PATH\"] = \"" BINS "\" + _os.pathsep + _os.environ.get(\"PATH\", \"\")"
            print "_PY = \"" PY "\""
            print "if _os.path.realpath(_sys.executable) != _os.path.realpath(_PY) and _os.path.exists(_PY):"
            print "    _os.execv(_PY, [_PY] + _sys.argv)"
          }
          NR == 1 {
            print "#!" PY
            if (ANCHOR == "__SHEBANG_ONLY__") { emit(); shim = 1 }
            next
          }
          { print }
          $0 ~ ("^" ANCHOR) && !shim { emit(); shim = 1 }
        ' "$f" > "$f.wired"
        mv "$f.wired" "$f"
        chmod +x "$f"
      done

      # Pin the agent-facing interpreter probe to the bundled python so
      # the engine runs with no python3 installed on the host. The loop's
      # own `command -v` + version check still validate the path.
      substituteInPlace "$skill/SKILL.md" \
        --replace-fail \
          'for py in python3.14 python3.13 python3.12 python3; do' \
          'for py in "${py}"; do'
    done
  '';

  meta = {
    description =
      "last30days skill for Claude Code and OpenCode — research "
      + "what people actually said about any topic in the last 30 "
      + "days across Reddit, X, YouTube, TikTok, Hacker News, "
      + "Polymarket, GitHub, and the web, then synthesize a grounded, "
      + "cited summary. The pure-stdlib Python engine ships wired to a "
      + "bundled interpreter and the vendored bird-search X client runs "
      + "on a bundled Node 22 — no host runtime required.";
    homepage = "https://github.com/mvanhorn/last30days-skill";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
