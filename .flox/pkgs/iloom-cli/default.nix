{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
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
  srcWithLock = runCommand "iloom-cli-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@iloom/cli/-/cli-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json

    # The committed package-lock.json describes runtime dependencies
    # only (see upgrade.sh): `npm install --package-lock-only` records
    # devDependencies no matter what --omit=dev says, and Dependabot
    # then alerts on test runners and bundlers that dontNpmBuild means
    # we never run. `npm ci` refuses to run when package.json and
    # package-lock.json disagree, so the same field is deleted here.
    # nixpkgs' npmInstallHook prunes dev dependencies from the output
    # regardless, so nothing that used to ship stops shipping.
    jq 'del(.devDependencies)' $out/package.json > package.json.pruned
    rm -f $out/package.json
    mv package.json.pruned $out/package.json
  '';
in
buildNpmPackage {
  pname = "iloom-cli";
  inherit version npmDepsHash;

  src = srcWithLock;

  # The npm tarball already ships prebuilt JS in dist/.
  dontNpmBuild = true;

  # npmInstallHook enumerates the files to install with `npm pack
  # --dry-run`, which runs the `prepare` lifecycle script. Upstream
  # packages commonly set `"prepare": "husky"` — a devDependency the
  # pruned lockfile no longer installs, and one this build has no use
  # for, since dontNpmBuild means nothing is built from source here.
  # Skipping pack's scripts keeps that from breaking the install phase.
  npmPackFlags = [ "--ignore-scripts" ];
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
