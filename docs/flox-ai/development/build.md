# Build

flox-ai is a Nix `buildGoModule` package
(`.flox/pkgs/flox-ai/default.nix`), built through the repo flake.

## Building

```sh
flox build flox-ai
# output symlink: ./result-flox-ai
```

## vendorHash

The build pins a `vendorHash` over the module's dependencies. When the
dependency set changes (a new import, a rebase that merges `go.mod`),
the hash is stale and the build fails with an inconsistent-vendoring or
hash-mismatch error. Recompute it with the fake-hash dance:

1. Set `vendorHash` to a dummy value:
   `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`.
2. `flox build flox-ai` — it prints `got: sha256-…`.
3. Paste the real hash back into `default.nix` and rebuild.

When merging `go.mod`/`go.sum` conflicts, resolve `go.mod` to the union
and run `go mod tidy` to regenerate `go.sum` and prune; then redo the
vendorHash dance.

## The untracked-file gotcha

`flox build` builds from the **git tree** and excludes untracked files.
A new source or test file that is not yet `git add`-ed will be missing
from the build, producing confusing `undefined: …` errors. Always
`git add` new files before building or running the bats e2e.

## .gitignore caution

The repo `.gitignore` once carried an unanchored `audit/` rule (for
site-audit artifacts) that also matched the Go package
`internal/audit/`. It is anchored to `/audit/` so it only ignores the
repo-root directory. Watch for similarly broad rules when adding
packages whose names collide with ignore patterns.
