{
  lib,
  writeShellApplication,
  runCommand,
  jq,
  yq-go,
}:

let
  # Stage the helper libs into their own store dir so the runner can source
  # them via $SKILLS_REVIEW_LIB. Keeping them out of the writeShellApplication
  # text means shellcheck only ever lints bin/skills-review (already clean).
  libDir = runCommand "skills-review-lib" { } ''
    mkdir -p "$out"
    cp -r ${./lib}/* "$out"/
  '';
in
writeShellApplication {
  name = "skills-review";

  # Only nixpkgs deps the runner itself needs. The six scoring tools
  # (skill-validator, claudelint, cclint, skill-tools, agnix, skillcheck)
  # are NOT bundled here: the skills-review Flox env installs this runner
  # alongside those tool packages so they share a PATH at runtime. The
  # runner calls them by bare name and fails closed if any is missing.
  runtimeInputs = [
    jq
    yq-go
  ];

  text = ''
    export SKILLS_REVIEW_LIB="${libDir}"
    exec ${./bin/skills-review} "$@"
  '';

  meta = {
    description = "Unified 0-100 quality score for Claude skills & agents (tool-ensemble)";
    homepage = "https://github.com/flox/floxenvs";
    license = lib.licenses.mit;
    mainProgram = "skills-review";
    platforms = lib.platforms.unix;
  };
}
