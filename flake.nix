{
  description = "Flox example environments";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.flox.url = "github:flox/flox/refs/tags/v1.11.0";

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

        # Single entry point: nix run .#run-test -- <env-name>
        runTestScript = pkgs.writeShellScriptBin "run-test" ''
          set -euo pipefail

          if [ $# -eq 0 ]; then
            echo "Usage: nix run .#run-test -- <env-name>"
            echo ""
            echo "Available environments with test.sh:"
            for dir in ${inputs.self}/*/; do
              name="$(basename "$dir")"
              if [ -f "$dir/test.sh" ]; then
                echo "  $name"
              fi
            done
            exit 1
          fi

          name="$1"
          path="${inputs.self}/$name"

          if [ ! -d "$path/.flox" ]; then
            echo "Error: environment '$name' not found"
            exit 1
          fi
          if [ ! -f "$path/test.sh" ]; then
            echo "Error: no test.sh in '$name'"
            exit 1
          fi

          export FLOX_DISABLE_METRICS=true
          export FLOX_ENVS_TESTING=1
          export PATH="${lib.makeBinPath (with pkgs; [ coreutils flox.packages."${system}".default ] ++ lib.optionals stdenv.isLinux [ util-linux slirp4netns ])}:$PATH"
          export LANG=
          export LC_COLLATE="C"
          export LC_CTYPE="C"
          export LC_MESSAGES="C"
          export LC_MONETARY="C"
          export LC_NUMERIC="C"
          export LC_TIME="C"
          export LC_ALL=

          mkdir -p /tmp/floxenvs
          export TESTDIR="$(mktemp --directory --tmpdir=/tmp/floxenvs --suffix "-$name" || mktemp --directory --tmpdir=/tmp --suffix "-$name")"
          ret=$?
          if [ $ret -ne 0 ] || [ -z "$TESTDIR" ]; then
            echo "Error: unable to create temp directory"
            exit $ret
          fi

          cleanup() {
            cd /
            echo "👉 Stopping services..."
            flox services stop --dir "$envdir" 2>/dev/null || true

            # On Darwin there's no namespace isolation, so
            # processes spawned by flox activate can outlive the
            # test if `flox services stop` fails or hangs. Find
            # and kill any processes still referencing our temp
            # directory (process-compose, service daemons, etc).
            if [ "$(uname)" = "Darwin" ]; then
              echo "👉 Killing orphaned processes..."
              # Use pkill (built into macOS) — procps/pgrep is Linux-only
              pkill -f "$TESTDIR" 2>/dev/null || true
              sleep 1
              # SIGKILL stragglers
              pkill -9 -f "$TESTDIR" 2>/dev/null || true
            fi

            echo "👉 Cleaning up $TESTDIR..."
            for i in $(seq 1 10); do
              chmod -R u+w "$TESTDIR" 2>/dev/null
              rm -rf "$TESTDIR" 2>/dev/null && break
              echo "👉 Cleanup attempt $i/10 failed, retrying in 2s..."
              sleep 2
            done
            echo "👉 Cleanup done."
            true
          }
          trap cleanup EXIT

          # Use a parent dir so relative [include] paths work
          envdir="$TESTDIR/env"
          mkdir -p "$envdir"

          chmod g=rwx "$TESTDIR"
          cp -R "$path"/* "$envdir"
          cp -R "$path"/.flox* "$envdir"
          if [ -f "$path/.env" ]; then
            cp -R "$path/.env" "$envdir"
          fi
          chmod -R u+w "$envdir"

          # Copy any [include] dir dependencies
          if [ -f "$envdir/.flox/env/manifest.toml" ]; then
            for inc_dir in $(${pkgs.gnugrep}/bin/grep -oP 'dir\s*=\s*"\K[^"]+' "$envdir/.flox/env/manifest.toml"); do
              # Resolve relative to the env dir inside the temp tree
              inc_dest="$(realpath -m "$envdir/$inc_dir")"
              # Resolve the source from the repo
              inc_name="$(basename "$inc_dest")"
              inc_src="${inputs.self}/$inc_name"
              if [ -d "$inc_src" ] && [ ! -d "$inc_dest" ]; then
                mkdir -p "$inc_dest"
                cp -R "$inc_src"/* "$inc_dest" 2>/dev/null || true
                cp -R "$inc_src"/.flox* "$inc_dest"
                chmod -R u+w "$inc_dest"
                chown -R "$(whoami)" "$inc_dest"/.flox*
                chmod -R a+w,g+rw "$inc_dest"/.flox*
              fi
            done
          fi

          chown -R "$(whoami)" "$envdir"/.flox*
          chmod -R a+w,g+rw "$envdir"/.flox*

          cd "$envdir"
          echo "👉 Running tests in $TESTDIR"

          start_services=""
          if ${pkgs.jq}/bin/jq -e '.manifest.services // {} | length > 0' .flox/env/manifest.lock > /dev/null 2>&1; then
            start_services=" --start-services"
          fi

          # Ensure HOME is writable — some builders set HOME=/var/empty
          if [ ! -w "''${HOME:-/nonexistent}" ]; then
            export HOME=$(mktemp -d)
          fi

          echo "👉 Running $name test..."

          # On Linux, isolate in a user+network+PID namespace so
          # concurrent tests don't fight over ports and orphaned
          # services get killed automatically on exit.
          #
          # Namespace flags:
          #   --user        unprivileged user namespace; maps
          #                 caller to uid 65534 (nobody) inside
          #   --net         isolated network stack (own loopback)
          #   --pid --fork  isolated PID namespace; all children
          #                 are reaped when the namespace exits
          #
          # Why nobody (not root):
          #   --map-root-user would give CAP_NET_ADMIN (for lo)
          #   but PostgreSQL's initdb refuses to run as uid 0.
          #   We use plain --user so the process runs as nobody,
          #   which all services accept.
          #
          # slirp4netns:
          #   Provides internet inside the network namespace.
          #   Without it, --net gives only loopback — no route
          #   to the internet (pip/poetry/uv can't reach PyPI).
          #   slirp4netns creates a userspace TAP device (tap0)
          #   that tunnels outbound traffic to the host network:
          #     tap0 10.0.2.100 → slirp → host → internet
          #   It also brings up lo automatically (--configure),
          #   so we don't need CAP_NET_ADMIN.
          #
          # Home directory:
          #   Inside the namespace uid=65534 (nobody) whose home
          #   is /var/empty (read-only). We set HOME and XDG
          #   vars to a writable tmpdir so flox and nix can
          #   write config/cache. We also seed
          #   .nix-defexpr/channels so nix doesn't error on the
          #   missing directory.
          #
          # Synchronization:
          #   The namespace process writes a ready-file, then
          #   waits for slirp4netns to set up networking
          #   (signaled by a .done file). This ensures tap0 is
          #   configured before flox activate tries to reach
          #   the network.
          #
          # Falls back to direct execution if unshare fails.
          if [ "$(uname)" = "Linux" ] && command -v unshare >/dev/null 2>&1; then
            echo "👉 Isolating test in user+network+PID namespace..."
            NS_HOME=$(mktemp -d)
            mkdir -p "$NS_HOME/.nix-defexpr/channels"
            chmod 777 "$NS_HOME"
            NS_READY=$(mktemp -u)
            NS_DONE=$(mktemp -u)

            unshare --user --net --pid --fork ${pkgs.bashInteractive}/bin/bash --norc --noprofile -c \
               "export HOME=\"$NS_HOME\"; \
               export XDG_CONFIG_HOME=\"$NS_HOME/.config\"; \
               export XDG_DATA_HOME=\"$NS_HOME/.local/share\"; \
               export XDG_CACHE_HOME=\"$NS_HOME/.cache\"; \
               export FLOX_DISABLE_METRICS=true; \
               touch \"$NS_READY\"; \
               while [ ! -f \"$NS_DONE\" ]; do sleep 0.1; done; \
               cd \"$envdir\"; \
               eval \"flox activate$start_services -c '${pkgs.bashInteractive}/bin/bash test.sh'\"" &
            NS_PID=$!

            # Wait for namespace to be ready, then start slirp4netns
            while [ ! -f "$NS_READY" ]; do sleep 0.1; done
            slirp4netns --configure --mtu=65520 $NS_PID tap0 &
            SLIRP_PID=$!
            sleep 1
            touch "$NS_DONE"

            # Wait for the test to finish
            wait $NS_PID
            NS_EXIT=$?
            kill $SLIRP_PID 2>/dev/null || true
            wait $SLIRP_PID 2>/dev/null || true
            rm -f "$NS_READY" "$NS_DONE"

            if [ $NS_EXIT -eq 0 ]; then
              exit 0
            else
              echo "👉 Namespace isolation failed (exit=$NS_EXIT), falling back to direct execution..."
            fi
          fi
          eval "flox activate$start_services -c '${pkgs.bashInteractive}/bin/bash test.sh'"
        '';
      in
      {
        apps.run-test = {
          type = "app";
          program = "${runTestScript}/bin/run-test";
        };
        devShells.default = pkgs.mkShell {
          packages = [ pkgs.just ];
        };
      }
    );
}
