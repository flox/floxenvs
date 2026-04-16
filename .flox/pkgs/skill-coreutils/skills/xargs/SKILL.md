---
name: xargs
description: >-
  Build and execute command lines from standard input. Use when running a
  command on each item from a list, processing find output, or parallelizing
  commands.
---

# xargs - Build and Execute Commands from Standard Input

## Synopsis

```
xargs [OPTION]... [COMMAND [INITIAL-ARGS]]
```

Read items from stdin, delimited by blanks or newlines, and execute
COMMAND with those items as arguments. Default command is echo.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -0 | --null | Items are terminated by NUL, not whitespace |
| -d | --delimiter=DELIM | Items are terminated by DELIM character |
| -I | --replace[=R] | Replace R (default {}) in COMMAND with input item; implies -L 1 |
| -L | --max-lines=MAX | Use at most MAX non-blank input lines per command line |
| -n | --max-args=MAX | Use at most MAX arguments per command line |
| -s | --max-chars=MAX | Limit command line length to MAX characters |
| -P | --max-procs=MAX | Run at most MAX processes at a time (0 = unlimited) |
| -p | --interactive | Prompt before executing each command line |
| -t | --verbose | Print the command line before executing |
| -r | --no-run-if-empty | If stdin is empty, do not run command (GNU default) |
| -x | --exit | Exit if the size limit (-s) is exceeded |
| -a | --arg-file=FILE | Read items from FILE instead of stdin |
| -E | --eof=EOF_STRING | Set logical EOF string (underscores if -0 not given) |
| | --process-slot-var=NAME | Set env var NAME to unique slot number in each parallel process |
| | --show-limits | Show limits on command-line length |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Basic usage: remove files found by find
find . -name '*.tmp' | xargs rm

# Handle filenames with spaces (NUL-delimited)
find . -name '*.log' -print0 | xargs -0 rm

# Replace pattern in command
find . -name '*.txt' | xargs -I{} cp {} /backup/

# Limit arguments per command (3 files at a time)
find . -name '*.jpg' | xargs -n 3 echo

# Parallel execution (4 processes)
find . -name '*.png' | xargs -P 4 -I{} convert {} -resize 50% {}

# One argument per line
cat urls.txt | xargs -L 1 curl -O

# Interactive (confirm each command)
find . -name '*.bak' | xargs -p rm

# Verbose (show commands as they run)
find . -name '*.c' | xargs -t gcc -c

# Process with custom delimiter
echo "a:b:c:d" | xargs -d: -n1 echo

# Read from file instead of stdin
xargs -a filelist.txt rm

# Parallel downloads
cat urls.txt | xargs -P 8 -I{} wget {}

# Show system limits
xargs --show-limits < /dev/null

# Run at most one command if input is empty
echo "" | xargs -r ls  # Does not run ls
```

## Gotchas

- **Filenames with spaces/quotes break xargs.** Always use `-print0`
  with find and `-0` with xargs for safe handling.
- `-I{}` implies `-L 1` (one input item per command) and disables
  multiple arguments per invocation.
- Without `-r`, xargs runs the command once even with empty input.
  GNU xargs defaults to `-r` behavior, but POSIX does not.
- `-P 0` means unlimited parallelism. Use `-P $(nproc)` for CPU-bound
  tasks.
- xargs splits on whitespace by default. Quoted strings are handled
  but it's fragile. Prefer `-0` or `-d '\n'`.
- When using `-I`, the replacement string must appear in the command
  template. Forgotten `{}` means the input is silently ignored.
- Exit code: xargs returns 123 if any command invocation returns 1-125,
  124 if the command returns 255, 125 if killed by signal.
- `-n` controls batch size. Without it, xargs fills up the command line
  to the system limit.
