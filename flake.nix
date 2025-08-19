{
  description = "Flox example environments";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flox.url = "github:flox/flox/refs/tags/v1.7.1";

  outputs =
    {
      self,
      flake-utils,
      nixpkgs,
      flox,
    } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};

        mkFloxEnvPkg = name: {
          path ? "${inputs.self}/${name}",
          packages ? with pkgs; [
            coreutils
            flox.packages."${system}".default
          ],
        }: pkgs.writeShellScriptBin "test-${name}" ''
          set -exo pipefail

          export FLOX_DISABLE_METRICS=true
          export FLOX_ENVS_TESTING=1
          export PATH="${lib.makeBinPath packages}:$PATH"
          export LANG=
          export LC_COLLATE="C"
          export LC_CTYPE="C"
          export LC_MESSAGES="C"
          export LC_MONETARY="C"
          export LC_NUMERIC="C"
          export LC_TIME="C"
          export LC_ALL=

          mkdir -p /tmp/floxenvs
          # copy self/nb into temp dir
          # fallback to non-subdirectory to work around /tmp/floxenv resets on x86_64-darwin
          export TESTDIR="$(mktemp --directory --tmpdir=/tmp/floxenvs --suffix floxenvs-${name}-example || mktemp --directory --tmpdir=/tmp --suffix floxenvs-${name}-example )"
          ret=$?
          if [ $ret -ne 0 ] || [ "$TESTDIR" = ""] ; then
            echo "Error: unable to create temp directory"
            exit $ret
          fi

          chmod g=rwx "$TESTDIR"
          cp -R ${path}/* $TESTDIR
          cp -R ${path}/.flox* $TESTDIR
          if [ -f ${path}/.env ]; then
            cp -R ${path}/.env $TESTDIR
          fi
          chown -R $(whoami) $TESTDIR/.flox*
          chmod -R a+w,g+rw $TESTDIR/.flox*

          # switch to root for the test
          cd $TESTDIR
          echo "👉 Running tests in $TESTDIR"

          start_services=""
          if [ "$1" == "true" ]; then
            start_services=" --start-services"
          fi

          # run tests
          if [ ! -f test.sh ]; then
            echo "Error: No test.sh script found"
            exit 1
          fi

          echo "👉 Running ${name} test..."
          flox activate$start_services -- ${pkgs.bashInteractive}/bin/bash test.sh

          ret=$?
          if [ $ret -ne 0 ]; then
            echo "Error: Tests failed"
            exit $ret
          fi
        '';
        mkFloxEnvApp = path: let 
          name = builtins.baseNameOf path;
          script = mkFloxEnvPkg name {};
        in {
          name = "test-${name}";
          value = {
            type = "app";
            program = "${script}/bin/test-${name}";
          };
        };
        manifestPath = ".flox/env/manifest.toml";
        allEnvironments =
          builtins.map
            (x:
              let
                xs = builtins.toString x;
                len = (builtins.stringLength xs) - (builtins.stringLength manifestPath);
              in
                builtins.substring 0 len xs
            ) 
            (
              builtins.filter
                (x: lib.hasSuffix manifestPath (builtins.toString x))
                (lib.filesystem.listFilesRecursive ./.)
            );
        environmentsWithTest = 
          builtins.filter
            (x: builtins.pathExists "${x}/test.sh")
            allEnvironments;
      in
      {
        packages = builtins.listToAttrs (
          builtins.map
            (path: rec {
              name = builtins.baseNameOf path;
              value = mkFloxEnvPkg name {};
            })
            environmentsWithTest
        );
        apps = builtins.listToAttrs (
          builtins.map mkFloxEnvApp environmentsWithTest
        );
        devShells.default = pkgs.mkShell {
          packages = [];
        };
      }
    );
}
