---
name: cp
description: >-
  Copy files and directories. Use when duplicating files, creating backups,
  or copying directory trees with preserved attributes.
---

# cp - Copy Files and Directories

## Synopsis

```
cp [OPTION]... SOURCE DEST
cp [OPTION]... SOURCE... DIRECTORY
```

Copy SOURCE to DEST, or multiple SOURCEs to DIRECTORY.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -r, -R | --recursive | Copy directories recursively |
| -a | --archive | Same as -dR --preserve=all (preserve everything) |
| -p | | Same as --preserve=mode,ownership,timestamps |
| | --preserve[=ATTR_LIST] | Preserve attributes: mode, ownership, timestamps, context, links, xattr, all |
| | --no-preserve=ATTR_LIST | Don't preserve specified attributes |
| -d | | Same as --no-dereference --preserve=links |
| -i | --interactive | Prompt before overwrite |
| -n | --no-clobber | Do not overwrite existing files |
| -f | --force | Remove existing destination file if needed |
| -u | --update | Copy only when SOURCE is newer or DEST missing |
| -l | --link | Hard link files instead of copying |
| -s | --symbolic-link | Make symbolic links instead of copying |
| -L | --dereference | Always follow symlinks in SOURCE |
| -P | --no-dereference | Never follow symlinks in SOURCE |
| -H | | Follow symlinks on command line only |
| -b | | Make backup of each existing destination file |
| | --backup[=CONTROL] | Make backup: none, off, numbered, t, existing, nil, simple, never |
| -S | --suffix=SUFFIX | Override backup suffix (default ~) |
| -t | --target-directory=DIR | Copy all SOURCE args into DIR |
| -T | --no-target-directory | Treat DEST as normal file, not directory |
| -v | --verbose | Explain what is being done |
| | --reflink[=WHEN] | Control copy-on-write: always, auto, never |
| | --sparse=WHEN | Control sparse files: auto, always, never |
| | --strip-trailing-slashes | Remove trailing slashes from SOURCE |
| -x | --one-file-system | Stay on this file system |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Copy a file
cp source.txt dest.txt

# Copy directory recursively
cp -r srcdir/ dstdir/

# Archive copy (preserve all attributes)
cp -a srcdir/ dstdir/

# Copy with backup
cp --backup=numbered file.txt /dest/

# Don't overwrite existing files
cp -n source.txt dest.txt

# Copy only newer files
cp -u source.txt dest.txt

# Interactive (prompt before overwrite)
cp -i source.txt dest.txt

# Verbose copy
cp -rv srcdir/ dstdir/

# Copy multiple files to a directory
cp file1.txt file2.txt /dest/dir/

# Create hard links instead of copying
cp -l file.txt link.txt

# Copy-on-write (fast, deferred copy on supporting fs)
cp --reflink=auto large_file.img copy.img
```

## Gotchas

- **Forgetting -r for directories** is the most common mistake. Without it,
  cp silently skips directories or errors out.
- `-a` is almost always what you want for directory copies (preserves
  permissions, symlinks, timestamps).
- `cp -r dir1 dir2` when dir2 exists creates `dir2/dir1/`. Use
  `cp -r dir1/ dir2/` or `-T` flag to control this.
- `-n` and `-i` behavior: `-n` silently skips, `-i` prompts. If both are
  given, `-n` takes precedence.
- `--reflink=auto` is a performance win on CoW filesystems (btrfs, APFS,
  XFS with reflink). Falls back to regular copy otherwise.
