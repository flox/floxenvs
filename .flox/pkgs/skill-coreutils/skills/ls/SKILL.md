---
name: ls
description: >-
  List directory contents. Use when you need to view files in a directory,
  check permissions, sizes, timestamps, or sort/filter file listings.
---

# ls - List Directory Contents

## Synopsis

```
ls [OPTION]... [FILE]...
```

List information about FILEs (current directory by default). Sorts entries
alphabetically unless a sort option is specified.

## Flags

### Display Control

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -a | --all | Show all entries including those starting with . |
| -A | --almost-all | Show all except . and .. |
| -B | --ignore-backups | Ignore entries ending with ~ |
| -d | --directory | List directories themselves, not contents |
| -I | --ignore=PATTERN | Don't list entries matching PATTERN |
| | --hide=PATTERN | Don't list entries matching PATTERN (overridden by -a/-A) |

### Format

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -l | | Long listing format (permissions, owner, size, date) |
| -1 | | One entry per line |
| -C | | List entries by columns (default for terminal) |
| -m | | Comma-separated list |
| -x | | List entries by lines instead of columns |
| | --format=WORD | across/horizontal (-x), commas (-m), long (-l), single-column (-1), verbose (-l), vertical (-C) |
| -g | | Like -l but don't show owner |
| -o | | Like -l but don't show group |
| -G | --no-group | In long listing, don't print group names |
| -n | --numeric-uid-gid | Like -l but show numeric UID/GID |

### Size Display

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -h | --human-readable | Print sizes in human-readable format (1K, 234M, 2G) |
| | --si | Like -h but use powers of 1000 not 1024 |
| -s | --size | Print allocated size in blocks |
| -k | --kibibytes | Default to 1024-byte blocks (with -s) |
| | --block-size=SIZE | Scale sizes by SIZE (e.g., --block-size=M) |

### Sorting

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -t | | Sort by modification time, newest first |
| -S | | Sort by file size, largest first |
| -v | | Natural sort of version numbers |
| -X | | Sort alphabetically by extension |
| -U | | Do not sort; list in directory order |
| -r | --reverse | Reverse sort order |
| -f | | Do not sort, enable -aU, disable -ls --color |
| | --sort=WORD | Sort by WORD: none (-U), size (-S), time (-t), version (-v), extension (-X) |
| | --group-directories-first | Group directories before files |

### Time Display

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -c | | With -lt: sort by ctime; with -l: show ctime |
| -u | | With -lt: sort by access time; with -l: show atime |
| | --time=WORD | Select time: access/atime/use (-u), ctime/status (-c), birth/creation |
| | --time-style=STYLE | Time display: full-iso, long-iso, iso, locale, +FORMAT |
| | --full-time | Like -l --time-style=full-iso |

### Indicators and Links

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -F | --classify | Append indicator (*/=>@\|) to entries |
| -p | | Append / to directories |
| | --file-type | Like -F but don't append * |
| -L | --dereference | Show info for link target, not the link |
| -H | --dereference-command-line | Follow symlinks on command line |
| -i | --inode | Print inode number of each file |
| | --hyperlink[=WHEN] | Hyperlink file names (always, auto, never) |

### Escaping and Color

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -b | --escape | Print C-style escapes for nongraphic chars |
| -q | --hide-control-chars | Print ? instead of nongraphic chars |
| -N | --literal | Print entry names without quoting |
| -Q | --quote-name | Enclose entry names in double quotes |
| | --quoting-style=WORD | literal, locale, shell, shell-always, shell-escape, shell-escape-always, c, escape |
| | --color[=WHEN] | Colorize output: always, auto, never |
| -w | --width=COLS | Set output width |
| -T | --tabsize=COLS | Set tab stop size |

### Other

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -R | --recursive | List subdirectories recursively |
| | --author | With -l, print author of each file |
| -D | --dired | Generate output for Emacs dired mode |
| | --help | Display help and exit |
| | --version | Output version and exit |

## Examples

```bash
# List all files with details, human-readable sizes
ls -lah

# List only directories
ls -d */

# Sort by modification time, newest first
ls -lt

# Sort by size, largest first
ls -lSh

# Recursive listing
ls -R

# Show inode numbers
ls -li

# One file per line (useful for scripting)
ls -1

# List with full timestamps
ls -l --full-time

# Ignore certain patterns
ls --ignore='*.pyc' --ignore='__pycache__'

# Show only hidden files
ls -d .*

# Natural version sort
ls -v file1.txt file10.txt file2.txt
```

## Gotchas

- **Do not parse ls output** in scripts. Filenames can contain spaces,
  newlines, and special characters that break parsing. Use `find`, `stat`,
  or shell globs instead.
- `-a` shows `.` and `..`, `-A` does not. Use `-A` when you want hidden
  files but not the directory entries.
- `ls -l` shows symlink info; add `-L` to see the target's info instead.
- Color output may interfere with piping. Use `--color=never` when piping
  or `--color=always` to force color through pipes.
- Default sort is locale-dependent. Set `LC_ALL=C` for byte-order sorting.
