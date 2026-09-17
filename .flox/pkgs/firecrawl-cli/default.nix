{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish; upstream also uses pnpm, not npm). Inject a pinned
  # lockfile regenerated from the tarball's package.json so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "firecrawl-cli-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/firecrawl-cli/-/firecrawl-cli-${version}.tgz";
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

    # Force axios off 1.15.2. Two exact pins in a row leave npm no
    # resolution freedom — firecrawl-cli pins firecrawl 4.24.0 exactly,
    # and firecrawl 4.24.0 pins axios 1.15.2 exactly — so the lockfile
    # cannot move axios on its own and `upgrade.sh` has nothing to
    # bump: firecrawl-cli has published no stable release since
    # 2026-08-27. 1.15.2 carries 18 open advisories here, five of the
    # seven highs being proxy-handling flaws, and upstream issue
    # firecrawl/cli#172 reports the CLI failing outright behind an HTTP
    # proxy for the same reason. 1.18.0 is what firecrawl itself ships
    # from 4.26.0 onward, so this matches upstream's tested pairing
    # rather than getting ahead of it.
    #
    # The key is version-scoped deliberately. It applies only while
    # firecrawl-cli is pinned to firecrawl 4.24.0, so it self-expires
    # the moment upstream bumps that pin — npm silently ignores an
    # override whose key matches nothing — instead of quietly holding
    # axios at 1.18.0 long after upstream has moved past it. Delete it
    # once the pin moves; `upgrade.sh` prints a reminder when it does.
    #
    # `npm ci` rebuilds the expected tree from package.json and rejects
    # a lockfile that disagrees with it, so the override has to be
    # injected into the source as well as applied to the lockfile —
    # editing package-lock.json alone is not enough. Without this,
    # `npm ci` computes axios@1.15.2 from firecrawl's pin, does not
    # find it in the lockfile, and reports `code EUSAGE / Missing:
    # axios@1.15.2 from lock file`; inside the sealed build sandbox the
    # same disagreement surfaces as `code ENOTCACHED`, because npm
    # falls back to re-resolving axios against a registry it cannot
    # reach. upgrade.sh injects the same field before re-locking.
    jq '.overrides = { "firecrawl@4.24.0": { "axios": "1.18.0" } }' \
      $out/package.json > package.json.overridden
    rm -f $out/package.json
    mv package.json.overridden $out/package.json
  '';
in
buildNpmPackage {
  pname = "firecrawl-cli";
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

  # `firecrawl --version` is a self-contained, offline command, so the
  # default versionCheckHook would be safe — but buildNpmPackage doesn't
  # wire it in by default and the env's test.sh exercises the binary
  # end-to-end, which is the right place for a runtime smoke test.

  meta = {
    description =
      "Official Firecrawl CLI — scrape, crawl, search, "
      + "and extract data from any website directly from "
      + "the terminal.";
    homepage = "https://github.com/firecrawl/cli";
    changelog = "https://github.com/firecrawl/cli/releases";
    license = lib.licenses.isc;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "firecrawl";
    platforms = lib.platforms.unix;
  };
}
