# Prototype: patched mkFloxEnvPkg with namespace isolation
#
# This shows the minimal change to flake.nix that adds
# network + PID namespace isolation to every test run.
#
# Diff from current:
#   + util-linux and iproute2 in packages
#   + unshare wrapper around flox activate
#   + loopback setup inside namespace
#
# To apply: replace mkFloxEnvPkg in flake.nix with this version.

# mkFloxEnvPkg = name: {
#   path ? "${inputs.self}/${name}",
#   packages ? with pkgs; [
#     coreutils
#     util-linux      # provides unshare
#     iproute2        # provides ip (for loopback)
#     flox.packages."${system}".default
#   ],
#   isolated ? true,
# }: pkgs.writeShellScriptBin "test-${name}" ''
#   set -exo pipefail
#
#   export FLOX_DISABLE_METRICS=true
#   export FLOX_ENVS_TESTING=1
#   export PATH="${lib.makeBinPath packages}:$PATH"
#   export LANG=
#   export LC_COLLATE="C"
#   export LC_CTYPE="C"
#   export LC_MESSAGES="C"
#   export LC_MONETARY="C"
#   export LC_NUMERIC="C"
#   export LC_TIME="C"
#   export LC_ALL=
#
#   mkdir -p /tmp/floxenvs
#   export TESTDIR="$(mktemp --directory --tmpdir=/tmp/floxenvs --suffix floxenvs-${name}-example || mktemp --directory --tmpdir=/tmp --suffix floxenvs-${name}-example )"
#   ret=$?
#   if [ $ret -ne 0 ] || [ "$TESTDIR" = ""] ; then
#     echo "Error: unable to create temp directory"
#     exit $ret
#   fi
#
#   chmod g=rwx "$TESTDIR"
#   cp -R ${path}/* $TESTDIR
#   cp -R ${path}/.flox* $TESTDIR
#   if [ -f ${path}/.env ]; then
#     cp -R ${path}/.env $TESTDIR
#   fi
#   chown -R $(whoami) $TESTDIR/.flox*
#   chmod -R a+w,g+rw $TESTDIR/.flox*
#
#   cd $TESTDIR
#   echo "Running tests in $TESTDIR"
#
#   start_services=""
#   if [ "$1" == "true" ]; then
#     start_services=" --start-services"
#   fi
#
#   if [ ! -f test.sh ]; then
#     echo "Error: No test.sh script found"
#     exit 1
#   fi
#
#   echo "Running ${name} test..."
#
#   # --- ISOLATION WRAPPER ---
#   # On Linux with namespace support, wrap in unshare for
#   # network + PID isolation. On Darwin or if unshare fails,
#   # fall back to direct execution.
#   if [ "$(uname)" == "Linux" ] && command -v unshare >/dev/null 2>&1; then
#     echo "Isolating test in network+PID namespace..."
#     exec unshare --net --pid --fork \
#       ${pkgs.bashInteractive}/bin/bash -c '
#         # Set up loopback in the new network namespace
#         ip link set lo up 2>/dev/null || true
#         cd "'"$TESTDIR"'"
#         flox activate'"$start_services"' -- ${pkgs.bashInteractive}/bin/bash test.sh
#       '
#   else
#     echo "No namespace support, running without isolation..."
#     flox activate$start_services -- ${pkgs.bashInteractive}/bin/bash test.sh
#   fi
#
#   ret=$?
#   if [ $ret -ne 0 ]; then
#     echo "Error: Tests failed"
#     exit $ret
#   fi
# '';
