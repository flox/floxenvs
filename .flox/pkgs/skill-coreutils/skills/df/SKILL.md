---
name: df
description: >-
  Report file system disk space usage. Use when checking available disk
  space, monitoring filesystem capacity, or identifying full partitions.
---

# df - Report File System Disk Space Usage

## Synopsis

```
df [OPTION]... [FILE]...
```

Display information about the file system on which each FILE resides,
or all file systems by default.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -h | --human-readable | Print sizes in powers of 1024 (K, M, G) |
| -H | --si | Print sizes in powers of 1000 |
| -k | | Like --block-size=1K |
| -m | | Like --block-size=1M |
| -B | --block-size=SIZE | Scale sizes by SIZE before printing |
| -a | --all | Include pseudo, duplicate, inaccessible file systems |
| -i | --inodes | List inode information instead of block usage |
| -l | --local | Limit listing to local file systems |
| -T | --print-type | Print file system type |
| -t | --type=TYPE | Limit listing to file systems of TYPE |
| -x | --exclude-type=TYPE | Exclude file systems of TYPE |
| -P | --portability | Use POSIX output format |
| | --sync | Invoke sync before getting usage info |
| | --no-sync | Do not invoke sync (default) |
| | --total | Produce a grand total |
| | --output[=FIELD_LIST] | Use output format defined by FIELD_LIST, or all fields if omitted |
| | --help | Display help |
| | --version | Output version |

### Output Fields (for --output)

source, fstype, itotal, iused, iavail, ipcent, size, used, avail,
pcent, file, target

## Examples

```bash
# Human-readable disk usage
df -h

# Check specific path's filesystem
df -h /home

# Show filesystem types
df -hT

# Show only local filesystems
df -hl

# Show only ext4 filesystems
df -t ext4

# Exclude tmpfs from listing
df -h -x tmpfs -x devtmpfs

# Show inode usage
df -i

# Grand total of all filesystems
df -h --total

# Custom output columns
df --output=source,size,used,avail,pcent,target

# POSIX-compatible output
df -P
```

## Gotchas

- `df` shows filesystem-level usage, not directory-level. Use `du` for
  directory sizes.
- Deleted files that are still open by a process still consume space.
  `df` shows this space as used, but `du` won't account for it.
- `-h` and `-H` differ: `-h` uses 1024 (KiB, MiB), `-H` uses 1000
  (KB, MB). Most people want `-h`.
- Some pseudo-filesystems (tmpfs, devtmpfs) clutter output. Exclude them
  with `-x tmpfs -x devtmpfs`.
- The "Available" column may be less than "Size - Used" because
  filesystems reserve space for root (typically 5% on ext4).
