{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish; upstream also uses pnpm, not npm). Inject a pinned
  # lockfile regenerated from the tarball's package.json so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "firecrawl-cli-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/firecrawl-cli/-/firecrawl-cli-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "firecrawl-cli";
  inherit version npmDepsHash;

  src = srcWithLock;

  # The npm tarball already ships prebuilt JS in dist/.
  dontNpmBuild = true;
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
