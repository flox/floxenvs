---
name: du
description: >-
  Estimate file space usage. Use when finding directory sizes, identifying
  large files/directories, or auditing disk usage.
---

# du - Estimate File Space Usage

## Synopsis

```
du [OPTION]... [FILE]...
```

Summarize file space usage of the set of FILEs, recursively for
directories.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -h | --human-readable | Print sizes in human-readable format (K, M, G) |
| -s | --summarize | Display only a total for each argument |
| -c | --total | Produce a grand total |
| -a | --all | Show counts for all files, not just directories |
| -d | --max-depth=N | Print total for directory only if N or fewer levels deep |
| -k | | Like --block-size=1K |
| -m | | Like --block-size=1M |
| -B | --block-size=SIZE | Scale sizes by SIZE |
| -b | --apparent-size, --bytes | Print apparent sizes rather than disk usage |
| | --apparent-size | Print apparent sizes rather than disk usage |
| -S | --separate-dirs | For directories, do not include size of subdirectories |
| -x | --one-file-system | Skip directories on different file systems |
| -L | --dereference | Dereference all symbolic links |
| -P | --no-dereference | Don't follow any symbolic links (default) |
| -D | --dereference-args | Dereference only symlinks listed on command line |
| -H | | Like --dereference-args (POSIX-compatible) |
| -l | --count-links | Count sizes many times if hard linked |
| -0 | --null | End each output line with NUL, not newline |
| | --files0-from=F | Summarize files from NUL-terminated list in file F |
| | --exclude=PATTERN | Exclude files matching PATTERN |
| -X | --exclude-from=FILE | Exclude patterns from FILE |
| | --time | Show time of last modification of any file in the directory |
| | --time=WORD | Show WORD time: atime, access, use, ctime, status |
| | --time-style=STYLE | Show time using STYLE: full-iso, long-iso, iso, +FORMAT |
| -t | --threshold=SIZE | Exclude entries smaller than SIZE (or larger if negative) |
| | --inodes | List inode usage instead of block usage |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Summarize directory size (human-readable)
du -sh dir/

# Top-level subdirectory sizes
du -h --max-depth=1

# Sorted by size (largest first)
du -sh */ | sort -hr

# Include all files, not just directories
du -ah dir/

# Grand total of multiple directories
du -shc dir1/ dir2/ dir3/

# Find largest subdirectories (top 10)
du -h --max-depth=1 | sort -hr | head -10

# Exclude patterns
du -sh --exclude='*.log' dir/

# Show apparent size (actual bytes, not disk blocks)
du -sb file.txt

# Stay on one filesystem
du -shx /

# Show with modification times
du -sh --time dir/

# Only show items larger than 100M
du -h --threshold=100M --max-depth=1

# Disk usage with inode count
du --inodes -s dir/
```

## Gotchas

- `du` reports disk usage (allocated blocks), not file size. Small files
  may show as 4K due to block size. Use `--apparent-size` for actual
  byte count.
- `du -sh` is the most common usage: summarize + human-readable.
- `du` without `-s` prints every subdirectory, which can be very verbose.
  Use `--max-depth=1` for top-level summary.
- Hard-linked files are counted only once by default. Use `-l` to count
  them each time they appear.
- `du` does not follow symlinks by default (`-P`). Use `-L` to follow
  them, but beware of infinite loops.
- `du` vs `df` discrepancy: `du` sums file sizes; `df` shows filesystem
  usage. Deleted-but-open files, filesystem overhead, and reserved blocks
  cause differences.
