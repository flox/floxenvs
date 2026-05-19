{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  makeWrapper,
  git,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish; upstream also uses pnpm, not npm). Inject a pinned
  # lockfile regenerated from the tarball's package.json so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "iloom-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@iloom/cli/-/cli-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "iloom-cli";
  inherit version npmDepsHash;

  src = srcWithLock;

  # The npm tarball already ships prebuilt JS in dist/.
  dontNpmBuild = true;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  # iloom shells out to `git` (for worktrees) and `gh` (for issue tracker
  # operations) at runtime. `gh` is intentionally NOT bundled here — users
  # authenticate it from their own host install (see README).
  postInstall = ''
    for prog in iloom il; do
      wrapProgram $out/bin/$prog \
        --prefix PATH : ${lib.makeBinPath [ git ]}
    done
  '';

  # versionCheckHook is skipped: even `iloom --version` initializes
  # posthog telemetry which opens a network connection. The Nix
  # darwin/linux sandbox has no network, and posthog-node retries
  # silently with no log output until the build is killed. The env's
  # test.sh validates the binary runs end-to-end with the network
  # available, which is the right place for this check.

  meta = {
    description = "Control plane for AI-assisted development with Claude Code, isolated environments, and visible context";
    homepage = "https://github.com/iloom-ai/iloom-cli";
    changelog = "https://github.com/iloom-ai/iloom-cli/releases";
    license = lib.licenses.bsl11;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "il";
    platforms = lib.platforms.unix;
  };
}
