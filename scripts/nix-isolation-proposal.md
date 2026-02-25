# Nix-Native Test Isolation Proposal

## Why Nix-native?

The floxenvs builders are already Nix-capable machines. The
test runner is already a Nix flake app (`flake.nix`). Using
Nix for isolation means:

- Nix store caching for free (VM images, dependencies)
- No additional tooling to install on builders
- Declarative, reproducible test environments
- Consistent with the existing test execution model

## Approach 1: unshare in mkFloxEnvPkg (minimal change)

Add `util-linux` to the test script's packages and wrap
the `flox activate` call with `unshare`. This is the
smallest possible change.

### Current mkFloxEnvPkg (simplified)

```nix
mkFloxEnvPkg = name: { packages ? [ coreutils flox ], ... }:
  pkgs.writeShellScriptBin "test-${name}" ''
    # ... setup ...
    flox activate$start_services -- bash test.sh
  '';
```

### Proposed change

```nix
mkFloxEnvPkg = name: {
  packages ? with pkgs; [
    coreutils
    util-linux   # <-- adds unshare
    iproute2     # <-- adds ip (for loopback setup)
    flox.packages."${system}".default
  ],
  isolated ? true,   # <-- new flag
}: pkgs.writeShellScriptBin "test-${name}" ''
  # ... existing setup ...

  if [ "${if isolated then "1" else "0"}" == "1" ]; then
    echo "Running in isolated namespace..."
    exec unshare --net --pid --fork bash -c '
      # Set up loopback in the namespace
      ip link set lo up 2>/dev/null || true
      cd '"$TESTDIR"'
      flox activate'"$start_services"' -- bash test.sh
    '
  else
    flox activate$start_services -- bash test.sh
  fi
'';
```

### Pros

- Minimal change to existing flake.nix (~10 lines)
- No CI workflow changes needed at all
- Nix caches the test script derivation (with deps)
- Isolation is transparent to test.sh authors
- Falls back gracefully on systems without namespace support

### Cons

- Requires root or user namespace support on builder
- Less isolation than a full VM
- Linux only (macOS builders can't use unshare)

## Approach 2: NixOS VM tests (stronger isolation)

The NixOS test framework (`nixos/tests`) provides
declarative QEMU VMs for testing. Each test gets a fresh
VM with its own kernel, networking, and filesystem.

### How it works

```nix
# In flake.nix, add a checks output:
checks.x86_64-linux.test-postgres =
  nixpkgs.lib.nixos.runTest {
    name = "floxenvs-postgres";
    nodes.machine = { pkgs, ... }: {
      # Install Flox in the VM
      environment.systemPackages = [
        flox.packages.x86_64-linux.default
      ];
      # Forward the environment files
      virtualisation.sharedDirectories.env = {
        source = "${self}/postgres";
        target = "/env";
      };
    };
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed(
        "cd /env && "
        "FLOX_ENVS_TESTING=1 "
        "flox activate --start-services -- bash test.sh"
      )
    '';
  };
```

### Pros

- Full kernel isolation (separate VM per test)
- Nix caches the VM image and all dependencies
- Declarative: VM config is version-controlled
- Built-in multi-machine networking for complex tests
- Well-documented in NixOS manual
- No port conflicts possible (separate network stack)
- Services auto-cleaned on VM shutdown

### Cons

- NixOS guests only (tests run inside NixOS, not Ubuntu)
  - This is fine for floxenvs since we control the test env
- Slower boot (~10-30s per VM vs ~0ms for unshare)
- More complex Nix expressions
- QEMU required (available on Linux builders, not macOS)
- x86_64-linux and aarch64-linux only (no Darwin)

### Caching benefits

With NixOS VM tests, the VM image is a Nix derivation:

- Base NixOS image: cached after first build
- Flox package: cached from flox binary cache
- Test environment files: cached per environment
- Only the test execution itself runs fresh each time

On builders with a populated Nix store, subsequent test
runs boot in seconds because everything is cached.

## Approach 3: Hybrid (recommended)

Combine both approaches:

- **Linux service environments** (postgres, mysql,
  elasticsearch, redis, etc.): Use NixOS VM tests for
  strong isolation. These are the environments that
  actually fight over ports.

- **Linux non-service environments** (go, python, rust,
  etc.): Use unshare namespace isolation. Lightweight,
  fast, sufficient since there are no port conflicts.

- **macOS environments**: No isolation available via Nix
  on Darwin. Continue with current approach. Future
  work: Tart VMs on Mac minis.

### Implementation plan

Phase 1: Add `unshare` wrapping to `mkFloxEnvPkg`

- Modify `flake.nix` to include `util-linux` and `iproute2`
- Wrap `flox activate` with `unshare --net --pid --fork`
- Add loopback setup inside the namespace
- Test with postgres, mysql, elasticsearch
- Zero CI changes needed

Phase 2: Add NixOS VM tests for service environments

- Add `checks` output to `flake.nix`
- Create VM test definitions for service environments
- Run via `nix flake check` or targeted
  `nix build .#checks.system.test-env`
- Update CI to use VM tests for service environments

Phase 3: GPU and macOS (future)

- GPU: QEMU+VFIO on dedicated hardware
- macOS: Tart VMs on Mac mini fleet

## Integration with current CI

### Phase 1 (unshare) — no CI changes

The `nix run .#apps.system.test-env` command already runs
the test script from `mkFloxEnvPkg`. Adding `unshare`
inside that script means the SSH command in ci.yml stays
identical:

```yaml
ssh remote-server nix run .#apps.system.test-env -- true
```

The isolation is invisible to CI.

### Phase 2 (NixOS VM tests) — small CI change

Add a new CI job or modify the test job to use:

```yaml
ssh remote-server nix build \
  .#checks.system.test-env \
  --accept-flake-config
```

The NixOS test framework returns success/failure as the
build result. Failed tests = failed Nix build.
