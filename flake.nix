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
          export PATH="${lib.makeBinPath (with pkgs; [ coreutils flox.packages."${system}".default ] ++ lib.optionals stdenv.isLinux [ util-linux passt ])}:$PATH"
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

          # ── Linux namespace isolation ──────────────────────
          #
          # On Linux we isolate each test in its own network
          # and PID namespace so that:
          #   • concurrent tests don't fight over localhost
          #     ports (each gets its own 127.0.0.1)
          #   • orphaned service processes are reaped
          #     automatically when the namespace exits
          #
          # Two tools, layered:
          #
          #   pasta (from passt project, https://passt.top)
          #     Provides internet inside the network namespace.
          #     Attached by PID after the namespace starts —
          #     configures an eth0 interface with internet
          #     access via L4 socket mapping (no TAP/NAT) and
          #     exits. Flags:
          #       --config-net  configure the interface
          #       -t none       don't forward host TCP ports
          #       -u none       don't forward host UDP ports
          #
          #   Double unshare (outer + inner):
          #     Outer: --user --map-root-user --mount --net
          #            --pid --fork
          #       Maps caller to uid 0 inside so we can:
          #       • bind-mount a custom /etc/resolv.conf
          #         pointing to pasta's DNS (the host's
          #         resolv.conf points to 127.0.0.53 which is
          #         systemd-resolved — dead in the namespace;
          #         pasta exposes DNS via the gateway IP)
          #       • bind-mount a writable dir over /root so
          #         nix can read /root/.nix-defexpr/channels
          #     Inner: --user
          #       Drops from uid 0 to uid 65534 (nobody).
          #       Services like PostgreSQL's initdb refuse to
          #       run as root — this makes them happy.
          #       The mount namespace from the outer unshare
          #       is inherited, so resolv.conf stays mounted.
          #
          # The result: uid=nobody, isolated network with
          # internet + DNS, PID namespace for cleanup.
          #
          # Home directory:
          #   uid 65534 (nobody) has home /var/empty which is
          #   read-only. We set HOME and XDG vars to a
          #   writable tmpdir.
          #
          # Synchronization:
          #   Namespace signals readiness via a temp file,
          #   we attach pasta, then signal it to proceed.
          #
          # Falls back to direct execution if pasta or
          # unshare are unavailable.
          if [ "$(uname)" = "Linux" ] && command -v pasta >/dev/null 2>&1; then
            echo "👉 Isolating test in network+PID namespace (pasta)..."
            NS_HOME=$(mktemp -d)
            mkdir -p "$NS_HOME/.nix-defexpr/channels"
            chmod 777 "$NS_HOME"
            NS_READY=$(mktemp -u)
            NS_DONE=$(mktemp -u)

            # Outer namespace: root + mount for bind-mounts
            unshare --user --map-root-user --mount --net --pid --fork ${pkgs.bashInteractive}/bin/bash --norc --noprofile -c \
               "echo 'nameserver PASTA_DNS' > \"$NS_HOME/resolv.conf\"; \
               mount --bind \"$NS_HOME/resolv.conf\" /etc/resolv.conf; \
               mount --bind \"$NS_HOME\" /root; \
               touch \"$NS_READY\"; \
               while [ ! -f \"$NS_DONE\" ]; do sleep 0.1; done; \
               unshare --user ${pkgs.bashInteractive}/bin/bash --norc --noprofile -c \
                 \"export HOME=\\\"$NS_HOME\\\"; \
                 export XDG_CONFIG_HOME=\\\"$NS_HOME/.config\\\"; \
                 export XDG_DATA_HOME=\\\"$NS_HOME/.local/share\\\"; \
                 export XDG_CACHE_HOME=\\\"$NS_HOME/.cache\\\"; \
                 export FLOX_DISABLE_METRICS=true; \
                 cd \\\"$envdir\\\"; \
                 eval \\\"flox activate$start_services -c '${pkgs.bashInteractive}/bin/bash test.sh'\\\"\"" &
            NS_PID=$!

            # Wait for namespace, attach pasta for networking
            while [ ! -f "$NS_READY" ]; do sleep 0.1; done
            # pasta prints the gateway IP which is also the
            # DNS server; capture it and patch resolv.conf
            PASTA_OUT=$(pasta --config-net -t none -u none $NS_PID 2>&1)
            PASTA_DNS=$(echo "$PASTA_OUT" | grep -A1 "^DNS:" | tail -1 | tr -d ' ')
            if [ -n "$PASTA_DNS" ]; then
              echo "nameserver $PASTA_DNS" > "$NS_HOME/resolv.conf"
            fi
            touch "$NS_DONE"

            # Wait for the test to finish
            wait $NS_PID
            NS_EXIT=$?
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
