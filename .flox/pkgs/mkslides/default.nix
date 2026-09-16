{
  lib,
  python3,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    srcHash
    revealjsRev
    revealjsHash
    highlightjsRev
    highlightjsHash
    ;

  # reveal.js and the highlight.js cdn-release are git submodules of
  # mkslides (.gitmodules), and both are load-bearing: constants.py reads
  # `reveal.js/package.json` and `highlight.js/build/package.json` at
  # import time, and enumerates the shipped themes from their
  # directories. A release tarball leaves the two submodule directories
  # empty, so fetch each pinned revision separately and copy it into
  # place in postPatch.
  #
  # `fetchSubmodules = true` on the mkslides fetch would also work, but
  # its hash can only be computed with nix-prefetch-git, which the
  # upgrade env does not ship — so upgrade.sh could not keep it current.
  revealjsSrc = fetchFromGitHub {
    owner = "hakimel";
    repo = "reveal.js";
    rev = revealjsRev;
    hash = revealjsHash;
  };

  highlightjsSrc = fetchFromGitHub {
    owner = "highlightjs";
    repo = "cdn-release";
    rev = highlightjsRev;
    hash = highlightjsHash;
  };
in
python3.pkgs.buildPythonApplication {
  pname = "mkslides";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "MartenBE";
    repo = "mkslides";
    tag = version;
    hash = srcHash;
  };

  build-system = with python3.pkgs; [ uv-build ];

  postPatch = ''
    cp -r ${revealjsSrc}/. src/mkslides/assets/reveal.js/
    cp -r ${highlightjsSrc}/. src/mkslides/assets/highlight.js/
    chmod -R u+w src/mkslides/assets

    # mkslides copies its bundled assets into the output directory with
    # shutil.copytree, which preserves the source modes. Installed
    # assets come from the Nix store, so they arrive read-only
    # (0444/0555) and the next run's shutil.rmtree of the output
    # directory dies with "PermissionError: [Errno 13] Permission
    # denied: <output>/mkslides-assets/reveal-js". Restore user write on
    # what was just copied so rebuilding into an existing directory
    # works.
    substituteInPlace src/mkslides/markupgenerator.py \
      --replace-fail \
        $'            shutil.copytree(source_path, destination_path, dirs_exist_ok=True)\n' \
        $'            shutil.copytree(source_path, destination_path, dirs_exist_ok=True)\n            for entry in [destination_path, *destination_path.rglob("*")]:\n                entry.chmod(entry.stat().st_mode | 0o200)\n'

    # Upstream caps the build backend at `uv_build<0.9.0` while nixpkgs
    # ships 0.11, so pypa/build's dependency check rejects it. The cap
    # constrains the backend, not the built package, and 0.11 builds
    # this release unchanged — drop the upper bound.
    substituteInPlace pyproject.toml \
      --replace-fail 'requires = ["uv_build>=0.8.23,<0.9.0"]' \
                     'requires = ["uv_build>=0.8.23"]'
  '';

  dependencies = with python3.pkgs; [
    beautifulsoup4
    click
    emoji
    jinja2
    jsonschema
    livereload
    markdown
    natsort
    omegaconf
    python-frontmatter
    pyyaml
    rich
    treelib
  ];

  # types-beautifulsoup4 and types-markdown are type stubs that upstream
  # lists as runtime dependencies. Only mypy consults them — nothing
  # imports them at runtime — so keep them out of the closure.
  pythonRemoveDeps = [
    "types-beautifulsoup4"
    "types-markdown"
  ];

  pythonImportsCheck = [ "mkslides" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Slides with Markdown using the power of Reveal.js";
    homepage = "https://martenbe.github.io/mkslides";
    changelog = "https://github.com/MartenBE/mkslides/releases/tag/${version}";
    license = lib.licenses.mit;
    mainProgram = "mkslides";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
}
