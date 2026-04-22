---
name: realpath
description: >-
  Print the resolved absolute pathname. Use when resolving symlinks,
  converting relative to absolute paths, or canonicalizing paths.
---

# realpath - Print Resolved Absolute Pathname

## Synopsis

```
realpath [OPTION]... FILE...
```

Print the resolved absolute file name. All but the last component must
exist by default.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -e | --canonicalize-existing | All components must exist |
| -m | --canonicalize-missing | No path components need exist |
| -s | --strip, --no-symlinks | Don't expand symlinks |
| -q | --quiet | Suppress most error messages |
| -z | --zero | End each output line with NUL, not newline |
| | --relative-to=DIR | Print path relative to DIR |
| | --relative-base=DIR | Print absolute if not under DIR, relative if under |
| -L | --logical | Resolve .. before symlinks |
| -P | --physical | Resolve symlinks as encountered (default) |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Resolve to absolute path
realpath ./relative/path

# Resolve symlinks
realpath /usr/bin/python3

# Check that entire path exists
realpath -e /path/to/file

# Don't require path to exist
realpath -m /path/to/future/file

# Don't resolve symlinks (just canonicalize)
realpath -s ./path/../other/./file

# Path relative to another directory
realpath --relative-to=/home/user /home/user/project/src
# Output: project/src

# Relative path between two locations
realpath --relative-to=/home/user/project/src /home/user/project/lib
# Output: ../lib

# Suppress errors for missing paths
realpath -qm /nonexistent/path
```

## Gotchas

- Default behavior: all components except the last must exist. Use `-e`
  to require everything to exist, or `-m` to require nothing to exist.
- `-s` (no-symlinks) just cleans up the path (removes `.`, `..`,
  duplicate slashes) without resolving symlinks.
- `--relative-to` is very useful for computing relative paths between
  two locations.
- `realpath` is not available on all systems (it's a GNU coreutils
  addition). `readlink -f` is a common alternative.
- The difference between `-L` and `-P`: `-P` (default) resolves each
  symlink as it encounters it. `-L` resolves `..` textually first.
