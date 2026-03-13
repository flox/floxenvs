# Test Isolation Solutions

Three approaches for isolating floxenvs test runs on shared
builder machines. All solve the core problem: port conflicts
and orphaned services between concurrent test runs.

## Context

- Builders are Nix-capable Linux machines on a tailnet
- Test runner is a Nix flake app (`flake.nix`, `mkFloxEnvPkg`)
- Tests run over Tailscale+SSH (this works, don't replace it)
- `test.sh` is the entry point for every environment
- Service environments (postgres, mysql, elasticsearch) are
  the main source of conflicts

## Solution 1: Linux namespaces (standalone wrapper)

Run each test inside Linux namespaces using `unshare`. This
is independent of Nix — a plain bash wrapper that can be
used with any test execution method.

### How it works

The `isolated-test.sh` script (in this directory) wraps
any environment test:

```bash
./scripts/isolated-test.sh postgres --start-services
```

It calls `unshare --net --pid --fork` to create:

- **Network namespace**: own loopback, own port space.
  Postgres on port 15432 in one namespace does not conflict
  with Postgres on 15432 in another.
- **PID namespace**: all child processes (including services)
  are killed when the test exits. No orphaned MySQL or
  Elasticsearch left behind.

Inside the namespace it sets up loopback (`ip link set lo up`)
and runs `flox activate [--start-services] -- bash test.sh`.

### Integration with CI

Two options:

**Option A: Modify the Nix flake test runner**

The `mkFloxEnvPkg` in `flake.nix` already generates the
test scripts. Add `unshare` wrapping inside:

```bash
# Inside the generated test script:
if [ "$(uname)" == "Linux" ] && command -v unshare >/dev/null; then
  exec unshare --net --pid --fork bash -c '
    ip link set lo up 2>/dev/null || true
    cd "$TESTDIR"
    flox activate --start-services -- bash test.sh
  '
else
  flox activate --start-services -- bash test.sh
fi
```

Zero CI workflow changes — the SSH command stays identical.

**Option B: Wrap the SSH call in ci.yml**

Change the test step to invoke the wrapper over SSH:

```yaml
ssh remote-server \
  "cd /path/to/checkout && ./scripts/isolated-test.sh ${{ matrix.example }} ${{ matrix.start_services }}"
```

### Pros

- Simplest to implement (~10 lines of bash or Nix)
- Zero or near-zero overhead (~0ms namespace creation)
- Solves both port conflicts and orphaned services
- No additional packages on builders (util-linux is
  standard on Linux)
- Falls back gracefully on systems without support
- Works with the existing flake test runner

### Cons

- Requires user namespace support or root/CAP_SYS_ADMIN
  on the builder (check: `sysctl kernel.unprivileged_userns_clone`)
- Shared kernel — less isolation than a VM
- Linux only — no macOS support
- No GPU isolation (shared hardware)

### When to use

Good first step. Solves the immediate port conflict problem
with minimal effort. Can be implemented today.

## Solution 2: unshare via Nix flake (Nix-integrated)

Same `unshare` mechanism as Solution 1, but integrated into
the Nix flake derivation so that isolation is part of the
cached test script.

### How it works

Modify `mkFloxEnvPkg` in `flake.nix` to include `util-linux`
and `iproute2` in the derivation's dependencies and wrap the
test execution:

```nix
mkFloxEnvPkg = name: {
  packages ? with pkgs; [
    coreutils
    util-linux   # provides unshare
    iproute2     # provides ip (for loopback)
    flox.packages."${system}".default
  ],
}: pkgs.writeShellScriptBin "test-${name}" ''
  # ... existing setup (env vars, temp dir, copy files) ...

  # Isolate on Linux, fallback on Darwin
  if [ "$(uname)" == "Linux" ] \
      && command -v unshare >/dev/null 2>&1; then
    echo "Isolating in network+PID namespace..."
    exec unshare --net --pid --fork \
      ${pkgs.bashInteractive}/bin/bash -c '
        ip link set lo up 2>/dev/null || true
        cd "'"$TESTDIR"'"
        flox activate'"$start_services"' \
          -- ${pkgs.bashInteractive}/bin/bash test.sh
      '
  else
    flox activate$start_services \
      -- ${pkgs.bashInteractive}/bin/bash test.sh
  fi
'';
```

A concrete patch is in `flake-unshare-patch.nix`.

### Pros

Everything from Solution 1, plus:

- `util-linux` and `iproute2` are Nix-provided — no need
  to check if they exist on the builder
- The test script derivation (with isolation) is cached
  in the Nix store
- Declarative: isolation is part of the build, not a
  runtime wrapper
- Zero CI changes — `nix run .#apps.system.test-env` just
  works with isolation baked in

### Cons

- Same namespace limitations as Solution 1 (user ns
  support, shared kernel, Linux only)
- Slightly more complex than the standalone wrapper
- Need to update `flake.nix` (but it's a small change)

### When to use

Better than Solution 1 if you want isolation to be part of
the Nix derivation rather than an external wrapper. Same
isolation strength, better packaging.

## Solution 3: NixOS VM tests (strongest isolation)

Use the NixOS test framework (`nixos/lib/testing`) to run
each test in a fresh QEMU virtual machine. Full kernel
isolation.

### How it works

Add a `checks` output to `flake.nix` with VM test
definitions:

```nix
checks.x86_64-linux.test-postgres =
  nixpkgs.lib.nixos.runTest {
    name = "floxenvs-postgres";
    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [
        flox.packages.x86_64-linux.default
      ];
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
        "flox activate --start-services "
        "-- bash test.sh"
      )
    '';
  };
```

Run with:

```bash
nix build .#checks.x86_64-linux.test-postgres
```

### Caching

The VM image is a Nix derivation:

- Base NixOS image: cached after first build
- Flox package: cached from flox binary cache
- Environment files: cached per environment
- Only test execution runs fresh each time

On builders with populated Nix stores, subsequent runs
boot quickly because everything is cached.

### CI integration

Small change to the test step in `ci.yml`:

```yaml
ssh remote-server nix build \
  .#checks.${{ matrix.system }}.test-${{ matrix.example }} \
  --accept-flake-config
```

Failed test = failed Nix build = CI failure.

### Pros

- Full kernel isolation (separate VM per test)
- No port conflicts possible (own network stack)
- Services auto-cleaned on VM shutdown
- Nix caches VM images and all dependencies
- Declarative VM config, version-controlled
- Built-in multi-machine networking for complex tests
- No root or user namespace support required
- Well-documented in NixOS manual

### Cons

- NixOS guests only (tests run inside NixOS, not Ubuntu
  or other distros — acceptable since we control the env)
- Slower boot (~10-30s per VM vs ~0ms for namespaces)
- More complex Nix expressions to maintain
- QEMU required (available on Linux builders, not macOS)
- x86_64-linux and aarch64-linux only (no Darwin)
- First build of VM image is slow (subsequent cached)

### When to use

Best for service environments where port conflicts are the
actual problem. The stronger isolation is worth the boot
overhead for postgres, mysql, elasticsearch, redis, etc.

## Comparison

| | Namespaces | Nix+unshare | NixOS VMs |
| --- | --- | --- | --- |
| Isolation | Network+PID | Network+PID | Full kernel |
| Overhead | ~0ms | ~0ms | ~10-30s boot |
| Port conflicts | Solved | Solved | Solved |
| Orphaned svc | Solved (PID ns) | Solved (PID ns) | Solved (VM exit) |
| Nix caching | No | Script cached | VM image cached |
| CI changes | Small | None | Small |
| Root needed | Maybe | Maybe | No |
| macOS | No | No | No |
| GPU (future) | No | No | VFIO possible |
| Complexity | Low | Low | Medium |
| Deps on builder | util-linux | None (Nix provides) | None (Nix provides) |

## Darwin / macOS: no namespace support

**Confirmed:** macOS has no equivalent to `unshare --net`.
Darwin's kernel does not support Linux namespaces. There is
no way to give a process its own network stack on macOS
without a full VM.

What macOS does have:

- **`sandbox-exec` (Seatbelt):** Can deny network access
  but cannot isolate port spaces. Two processes still share
  the same loopback — port conflicts remain. Also
  deprecated by Apple (but still used by system software).
- **Virtualization.framework (Tart):** Full VM isolation,
  ~15-30s boot. This is the only real option for port
  isolation on macOS.
- **Darwin Containers:** Requires disabling SIP.
  Experimental, not production-ready.

### macOS mitigation options

1. **Accept no isolation on macOS.** Port conflicts are
   less likely on macOS because fewer builders and fewer
   concurrent test runs. Current behavior continues.

2. **Randomize ports per test run.** Instead of hardcoded
   `PGPORT=15432`, generate a random port. Doesn't solve
   orphaned services but prevents most port conflicts.
   Lightweight but fragile.

3. **Tart VMs on Mac minis (phase 3).** Full isolation via
   Virtualization.framework. Heavier but actually works.
   Requires Mac mini fleet provisioning.

### Recommendation for macOS

Start with option 1 (no isolation) — it matches current
behavior and macOS conflicts are rare. If they become a
problem, go straight to option 3 (Tart VMs). Port
randomization (option 2) is fragile and not worth the
complexity for a temporary workaround.

## Recommended approach

**Phase 1 (now):** Solution 2 (Nix+unshare) on Linux.
Modify `mkFloxEnvPkg` to wrap tests in namespaces. Zero CI
changes. Solves port conflicts and orphaned services on
Linux builders immediately. macOS continues without
isolation (current behavior).

**Phase 2 (if needed):** Solution 3 (NixOS VMs) for Linux
service environments that need stronger isolation.
Nix+unshare for non-service environments (go, python, rust).

**Phase 3 (future):** macOS isolation via Tart on Mac minis.
GPU testing via QEMU+VFIO on dedicated hardware.

## Files in this directory

- `isolated-test.sh` — Standalone namespace wrapper
  (Solution 1)
- `flake-unshare-patch.nix` — Concrete flake.nix patch
  (Solution 2)
- `ISOLATION.md` — Original research notes
- This file — Unified solution comparison
