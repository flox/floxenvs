# iloom Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Filoom-demo%2Fdevcontainer.json)

Interactive demo of the [iloom](../iloom/) environment with
a styled banner showing the most-used commands.

## Quick start

```bash
flox activate -r flox/iloom-demo
gh auth login
il start <issue-number>
```

## What it provides

Everything from [iloom](../iloom/) plus:

- `gum` — styled terminal UI
- Welcome banner on activate

## Typical workflow

```bash
# 1. Authenticate the GitHub CLI (one-time per host)
gh auth login

# 2. Start a loom for an issue. iloom creates a git worktree
#    at ~/<project>-looms/issue-<n>/, runs analyze + plan, and
#    posts the plan as a comment on the issue.
il start 25

# 3. Work in the loom. The reasoning lives in the issue
#    comments — your teammates can pick up the thread.

# 4. Finish: validate the code, generate a session summary,
#    merge, and clean up the worktree.
il finish
```

For epics with child issues, swap step 2/3 for:

```bash
il plan 42        # decompose the epic into child issues
il swarm 42       # launch parallel agents on the children
```

## See also

- [iloom](../iloom/) — minimal environment for `[include]`
- [Upstream repo](https://github.com/iloom-ai/iloom-cli)
- [VS Code extension](https://marketplace.visualstudio.com/items?itemName=iloom-ai.iloom-vscode)
