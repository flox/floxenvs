---
name: dirname
description: >-
  Strip last component from file name. Use when extracting the directory
  path from a full file path.
---

# dirname - Strip Last Component from File Name

## Synopsis

```
dirname [OPTION] NAME...
```

Output each NAME with its last non-slash component and trailing slashes
removed. If NAME contains no slashes, output '.'.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -z | --zero | End each output line with NUL, not newline |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Extract directory from path
dirname /path/to/file.txt
# Output: /path/to

# Current directory indicator
dirname file.txt
# Output: .

# Root-level file
dirname /file.txt
# Output: /

# Multiple arguments
dirname /path/to/file1.txt /other/file2.txt
# Output: /path/to\n/other

# In shell scripting: find script's directory
script_dir=$(dirname "$0")

# Navigate to script's directory
cd "$(dirname "$0")"

# Robust way to get script's absolute directory
script_dir=$(cd "$(dirname "$0")" && pwd)
```

## Gotchas

- `dirname` is purely string-based. It does not check if the directory
  exists or resolve symlinks. Use `realpath` for that.
- `dirname /path/to/` outputs `/path` (trailing slash means `to` is
  the last component).
- `dirname name` (no slashes) outputs `.` (current directory).
- For bash parameter expansion, `${var%/*}` is similar to
  `dirname "$var"` but behaves differently for paths without slashes.
- Multiple arguments are supported without special flags (unlike
  `basename` which needs `-a`).
