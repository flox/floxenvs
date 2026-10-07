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

  # Gate the build on axios actually being clear of the advisories.
  #
  # firecrawl-cli used to need an `overrides` entry here to force axios
  # off 1.15.2, which carried 18 advisories: firecrawl-cli pinned
  # firecrawl 4.24.0 exactly and 4.24.0 pinned axios 1.15.2 exactly, so
  # the lockfile had no freedom to move. firecrawl 4.26.0 moved to axios
  # 1.18.0 and firecrawl-cli now pins 4.44.0, which resolves axios
  # 1.20.0 on its own, so the override is gone.
  #
  # The check stays. It is what notices if a future bump walks axios
  # back below the floor — upstream's pin is now the only thing holding
  # it there, and nothing else here would catch a regression: a green
  # build shipping a vulnerable axios looks identical to a good one.
  # That matters because upgrade.sh runs unattended every six hours and
  # ci.yml auto-merges the PR it opens once this build is green. The
  # env's test.sh is no substitute — it checks that `firecrawl` is on
  # PATH, that `firecrawl --version` exits 0, and that the skill
  # bundle's SKILL.md files are installed, nothing axios-related, and it
  # resolves firecrawl-cli from FloxHub rather than this build.
  #
  # A floor rather than an equality: everything at or above 1.18.0 is
  # clear of all 18, so upstream moving further ahead must not fail the
  # build.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck

    axios_pkg=$(find $out -path '*/node_modules/axios/package.json' -print -quit)
    if [ -z "$axios_pkg" ]; then
      echo "axios is not in the installed closure, so its version" >&2
      echo "cannot be verified. If the layout changed, update this check" >&2
      echo "rather than dropping it." >&2
      exit 1
    fi

    axios_version=$(jq -r .version "$axios_pkg")
    axios_floor=1.18.0
    if [ "$(printf '%s\n%s\n' "$axios_floor" "$axios_version" \
            | sort -V | head -n1)" != "$axios_floor" ]; then
      echo "axios regressed below the advisory floor: got" >&2
      echo "$axios_version, need >= $axios_floor." >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

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
