# Test Isolation for floxenvs

## Problem

When multiple environment tests run on the same builder
machine, services fight over ports and leave orphaned
processes:

- MySQL tests bind to port 3306 -- two concurrent runs clash
- Elasticsearch binds to its configured port -- same problem
- PostgreSQL on port 15432 -- same problem
- Orphaned service processes from failed runs block new runs

The Tailscale+SSH runner infrastructure works reliably. The
isolation between tests does not.

## Approaches Considered

### Option A: Linux namespaces (chosen for prototype)

Use `unshare` to give each test its own network and PID
namespace. Each test gets its own loopback interface with its
own port space -- no conflicts possible.

Pros:

- Lightest option, no VM overhead
- No KVM required, works on any Linux kernel 3.8+
- ~0ms startup overhead
- PID namespace auto-kills orphaned services on exit
- Available on all current builders

Cons:

- Shared kernel (less isolation than VMs)
- User namespaces may be restricted on some kernels
  (`sysctl kernel.unprivileged_userns_clone`)
- No GPU isolation (but GPU envs are future work)
- Linux only (not applicable to macOS builders)

### Option B: systemd-nspawn containers

Lightweight containers using systemd-nspawn. Full filesystem
and network isolation.

Pros:

- Stronger isolation than raw namespaces
- Built into systemd (available on most Linux builders)
- Supports private networking and filesystem overlay

Cons:

- Requires systemd (not available on all build systems)
- More complex setup than raw unshare
- Heavier than namespaces for the problem we're solving

### Option C: Firecracker microVMs

Full VM isolation with ~125ms boot time.

Pros:

- Strongest isolation (separate kernel)
- ~125ms boot, ~5MB memory overhead
- Battle-tested (used by AWS Lambda)

Cons:

- Requires KVM (`/dev/kvm`)
- More complex provisioning (needs kernel + rootfs images)
- Overkill for port conflict isolation
- No GPU passthrough

### Option D: QEMU/KVM with VFIO

Full VMs with GPU passthrough capability.

Pros:

- Supports GPU passthrough via VFIO
- Full OS isolation
- NixOS test framework provides declarative QEMU VMs

Cons:

- Heaviest option (~50-200ms boot)
- Requires dedicated GPU hardware for passthrough
- Complex setup

## Prototype: isolated-test.sh

The `scripts/isolated-test.sh` wrapper implements Option A
(Linux namespaces). It:

1. Detects available namespace support (unprivileged user
   namespaces, root, or none)
2. Creates a new namespace with:
   - Network namespace (own loopback, own port space)
   - PID namespace (orphaned services killed on exit)
   - Mount namespace (if root available)
3. Sets up loopback networking inside the namespace
4. Copies the environment to an isolated temp directory
5. Runs `flox activate [--start-services] -- bash test.sh`
6. Cleans up on exit

### Usage

```bash
# Run postgres test in isolation
./scripts/isolated-test.sh postgres --start-services

# Run go test (no services)
./scripts/isolated-test.sh go

# Run mysql test in isolation
./scripts/isolated-test.sh mysql --start-services
```

### Requirements

- Linux with user namespace support (kernel 3.8+)
- `unshare` from util-linux
- For full isolation: root or CAP_SYS_ADMIN
- Falls back gracefully if namespaces unavailable

## CI Integration

To use `isolated-test.sh` in the current CI workflow, the
test execution in `ci.yml` would change from running the Nix
flake app directly to running it through the isolation
wrapper.

### Current flow (flake.nix test runner)

```
ssh remote-server nix run .#apps.system.test-env -- true
```

The Nix flake app (`flake.nix`) copies the environment to
a temp dir and runs `flox activate -- bash test.sh`.

### Proposed flow (with isolation)

The isolation wrapper can be integrated at two levels:

**Level 1: Wrap the flake app (minimal change)**

Modify `flake.nix` `mkFloxEnvPkg` to run the test inside
an `unshare` namespace. This is the smallest CI change --
the SSH+Tailscale infrastructure stays identical.

**Level 2: Replace the flake app (bigger change)**

Use `isolated-test.sh` directly over SSH instead of the
Nix flake app. This simplifies the test runner but requires
Flox to be installed on the builder (instead of using Nix
to provide it).

### Recommended: Level 1

Modify the shell script inside `mkFloxEnvPkg` in
`flake.nix` to wrap the `flox activate` call with
`unshare --net --pid --fork`. This keeps the existing CI
pipeline intact and adds isolation transparently.

## Future Directions

### Phase 2: GPU testing (VFIO passthrough)

For CUDA/GPU environments (ollama, pytorch), we need
dedicated hardware with VFIO passthrough. This requires:

- Bare metal servers with NVIDIA GPUs
- IOMMU enabled (Intel VT-d or AMD-Vi)
- One physical GPU per test VM
- QEMU/KVM as the VM layer (Firecracker has no GPU support)

### Phase 3: macOS isolation (Tart)

For macOS environment testing:

- Mac mini fleet with Apple Silicon
- Tart (by Cirrus Labs) for macOS VMs
- ~15-30s boot time per VM
- No GPU passthrough (Metal requires bare metal)

### Hardware provisioning

Phases 2 and 3 require hardware procurement -- tracked as a
separate planning item in the environment health testing
effort.
