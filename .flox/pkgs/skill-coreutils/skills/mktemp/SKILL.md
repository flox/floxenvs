---
name: mktemp
description: >-
  Create a temporary file or directory safely. Use when you need secure
  temporary storage for scripts, avoiding race conditions and conflicts.
---

# mktemp - Create Temporary File or Directory

## Synopsis

```
mktemp [OPTION]... [TEMPLATE]
```

Create a temporary file or directory, safely, and print its name. TEMPLATE
must contain at least 3 consecutive 'X's in last component. If TEMPLATE
is not specified, tmp.XXXXXXXXXX is used and --tmpdir is implied.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -d | --directory | Create a directory, not a file |
| -u | --dry-run | Do not create anything; merely print a name (unsafe) |
| -q | --quiet | Suppress diagnostics about file/dir creation failure |
| -p | --tmpdir[=DIR] | Interpret TEMPLATE relative to DIR; if DIR not specified, use $TMPDIR or /tmp |
| | --suffix=SUFF | Append SUFF to TEMPLATE (TEMPLATE must not contain slashes unless using --tmpdir) |
| -t | | Interpret TEMPLATE as single file name relative to $TMPDIR or /tmp (deprecated in favor of --tmpdir) |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Create temp file (default)
tmpfile=$(mktemp)
echo "data" > "$tmpfile"

# Create temp directory
tmpdir=$(mktemp -d)

# Custom template
mktemp /tmp/myapp.XXXXXXXX

# Custom template with suffix
mktemp --suffix=.txt /tmp/myapp.XXXXXXXX

# Create in specific directory
mktemp -p /var/tmp myapp.XXXXXXXX

# Create temp file with suffix
mktemp --suffix=.json

# Use in scripts with cleanup
tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT
# ... use tmpfile ...

# Use temp directory with cleanup
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
# ... use tmpdir ...

# Dry run (see what name would be generated)
mktemp -u
```

## Gotchas

- **Always capture the output** of mktemp in a variable. The filename
  is randomized and you need to know it.
- **Always clean up** temp files/directories. Use `trap` with `EXIT`
  signal for reliable cleanup even on errors.
- `-u` (dry-run) is unsafe for actual use because another process could
  create the file between mktemp printing and you using it. Only use
  for debugging.
- Template requires at least 3 X's. More X's = more randomness.
- Default location is `$TMPDIR` (if set) or `/tmp`.
- The created file has mode 600 (owner read/write only). The created
  directory has mode 700.
