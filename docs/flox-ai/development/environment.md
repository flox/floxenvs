# Environment

The Go toolchain and the audit tools are not on the host PATH; they come
from the repo's Flox/Nix environment.

## Getting a shell

Run commands inside the Nix dev shell and the Flox environment:

```sh
nix develop --command flox activate -- bash -c '
  cd .flox/pkgs/flox-ai && go build ./...'
```

`nix develop` provides the base dev shell (from the repo `flake.nix`);
`flox activate` layers the Flox environment on top, which is what puts
`go` and the six audit tools (`skill-tools`, `skill-validator`,
`claudelint`, `agnix`, `cclint`, `skillcheck`, `skillspector`) on PATH.

Run git the same way when you want the environment's hooks and tools:

```sh
nix develop --command flox activate -- bash -c 'git status'
```

## Quick checks

```sh
# build + unit tests + format
nix develop --command flox activate -- bash -c '
  cd .flox/pkgs/flox-ai && go build ./... && go test ./... && gofmt -l .'
```

## The audit tools

`flox-ai doctor` shows whether the six quality tools are available and
smoke-tested. Inside the activated environment they are present; outside
it they are not, and the audit falls back to failing checks unless you
set `REVIEW_SKILLS_DRY_RUN=1`.
