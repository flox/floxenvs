---
name: env
description: >-
  Run a command with a modified environment, or print the current
  environment. Use when setting environment variables for a single
  command, clearing the environment, or inspecting variables.
---

# env - Run a Command in a Modified Environment

## Synopsis

```
env [OPTION]... [NAME=VALUE]... [COMMAND [ARG]...]
```

Set each NAME to VALUE in the environment and run COMMAND. With no
COMMAND, print the resulting environment.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -i | --ignore-environment | Start with an empty environment |
| -u | --unset=NAME | Remove variable NAME from the environment |
| -0 | --null | End each output line with NUL, not newline |
| -C | --chdir=DIR | Change directory to DIR before running COMMAND |
| -S | --split-string=S | Process and split S into separate arguments |
| -v | --debug | Print verbose information for each processing step |
| | --default-signal[=SIG] | Reset handling of SIG to the default |
| | --ignore-signal[=SIG] | Set handling of SIG to do nothing |
| | --block-signal[=SIG] | Block delivery of SIG |
| | --list-signal-handling | List non-default signal handling to stderr |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Print all environment variables
env

# Run command with extra variable
env VAR=value command

# Run with multiple variables
env DB_HOST=localhost DB_PORT=5432 python app.py

# Run with empty environment
env -i /bin/bash

# Remove a variable for this command
env -u LD_PRELOAD command

# Change directory and run
env -C /tmp ls

# In shebangs with arguments (using -S)
#!/usr/bin/env -S python3 -u

# Print environment, NUL-separated (for parsing)
env -0

# Run with clean environment plus specific vars
env -i HOME="$HOME" PATH="$PATH" command
```

## Gotchas

- `env` is most commonly used in shebang lines: `#!/usr/bin/env python3`
  which finds `python3` in `$PATH` (more portable than hardcoding the
  path).
- `-S` (split string) is needed in shebangs when passing arguments:
  `#!/usr/bin/env -S python3 -u` because the kernel passes the entire
  string after `env` as a single argument.
- `env -i` gives a truly empty environment, which may break programs
  that depend on `$HOME`, `$PATH`, `$TERM`, etc.
- `env VAR=value command` is equivalent to `VAR=value command` in most
  shells, but `env` works as a standalone binary (useful in shebangs
  and non-shell contexts).
- Without COMMAND, `env` just prints the environment, which is equivalent
  to `printenv`.
