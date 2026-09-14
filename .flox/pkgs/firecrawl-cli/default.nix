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
