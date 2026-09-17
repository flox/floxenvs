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
    # seven highs being proxy-handling flaws; upstream issue
    # firecrawl/cli#172 also reports the CLI failing behind an HTTP
    # proxy on this axios, which is motivating context rather than a
    # diagnosis anyone has confirmed.
    #
    # 1.18.0 because it clears all 18 and is where firecrawl itself
    # lands from 4.26.0 onward. It is not an upstream-tested pairing:
    # upstream tested 1.18.0 against firecrawl 4.26.0, and no upstream
    # release combines firecrawl 4.24.0 with it. What makes that safe
    # to run is narrow rather than assumed — 4.24.0's axios calls set
    # only `headers` and `timeout`, and never `proxy`, `httpAgent`,
    # `httpsAgent`, `maxRedirects` or `paramsSerializer`, so none of
    # the proxy and redirect semantics 1.18.0 changed touch anything
    # this SDK configures. (Every `proxy` in the SDK is Firecrawl's own
    # API-level scrape option, not axios request config.)
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
    #
    # Merged with `+=`, not assigned. firecrawl-cli 1.23.3 ships no
    # `overrides` field, and jq's `null + object` yields the object, so
    # merging is a drop-in today. It is what keeps the field safe to
    # touch later: an upstream `overrides` block would be carrying its
    # own security floors (mcporter's upstream uses `pnpm.overrides`
    # for exactly that), and assigning over it would delete them
    # silently — upgrade.sh applies the same transform, so package.json
    # and the lockfile would still agree and `npm ci` would not object.
    # Our key still wins on collision, which is the intent.
    jq '.overrides += { "firecrawl@4.24.0": { "axios": "1.18.0" } }' \
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

  # Gate the build on the override having actually applied.
  #
  # Everything that can silently undo it ends the same way — a green
  # build shipping axios 1.15.2 again — and nothing else would catch
  # that. The version-scoped key stops matching once upstream bumps its
  # firecrawl pin, and firecrawl 4.25.0 still pins axios 1.15.2, so the
  # next bump is not necessarily a fix; npm's override matching has
  # churned recently; and a refactor could drop the field from this file
  # and upgrade.sh together, which stays self-consistent and so passes
  # `npm ci`. In each case package.json and the lockfile agree and the
  # build is green.
  #
  # That matters more here than it would elsewhere: upgrade.sh runs
  # unattended every six hours, and ci.yml auto-merges the PR it opens
  # once this build goes green. Failing here is what stops a regression
  # reaching main. The env's test.sh is not a substitute: it checks
  # that `firecrawl` is on PATH, that `firecrawl --version` exits 0,
  # and that the skill bundle's SKILL.md files are installed — nothing
  # axios-related, so it passes unchanged on 1.15.2. It also resolves
  # firecrawl-cli from FloxHub, so it exercises the published package
  # rather than this build.
  #
  # A floor rather than an equality: upstream moving past 1.18.0 is the
  # outcome this override exists to reach, and must not fail the build.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck

    axios_pkg=$(find $out -path '*/node_modules/axios/package.json' -print -quit)
    if [ -z "$axios_pkg" ]; then
      echo "axios is not in the installed closure, so the override" >&2
      echo "cannot be verified. If the layout changed, update this check" >&2
      echo "rather than dropping it." >&2
      exit 1
    fi

    axios_version=$(jq -r .version "$axios_pkg")
    axios_floor=1.18.0
    if [ "$(printf '%s\n%s\n' "$axios_floor" "$axios_version" \
            | sort -V | head -n1)" != "$axios_floor" ]; then
      echo "axios override did not apply: got $axios_version," >&2
      echo "need >= $axios_floor. See the override in srcWithLock." >&2
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
