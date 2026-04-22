---
name: mv
description: >-
  Move or rename files and directories. Use when relocating files,
  renaming, or moving across filesystems.
---

# mv - Move/Rename Files and Directories

## Synopsis

```
mv [OPTION]... SOURCE DEST
mv [OPTION]... SOURCE... DIRECTORY
```

Rename SOURCE to DEST, or move SOURCE(s) to DIRECTORY.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -i | --interactive | Prompt before overwrite |
| -n | --no-clobber | Do not overwrite existing files |
| -f | --force | Do not prompt before overwriting |
| -u | --update | Move only when SOURCE is newer or DEST missing |
| -v | --verbose | Explain what is being done |
| -b | | Make backup of each existing destination file |
| | --backup[=CONTROL] | Make backup: none, off, numbered, t, existing, nil, simple, never |
| -S | --suffix=SUFFIX | Override backup suffix (default ~) |
| -t | --target-directory=DIR | Move all SOURCE args into DIR |
| -T | --no-target-directory | Treat DEST as normal file |
| | --strip-trailing-slashes | Remove trailing slashes from SOURCE |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Rename a file
mv old.txt new.txt

# Move file to directory
mv file.txt /dest/dir/

# Move multiple files to directory
mv file1.txt file2.txt /dest/dir/

# Don't overwrite existing
mv -n source.txt dest.txt

# Interactive (prompt before overwrite)
mv -i source.txt dest.txt

# Move with backup of existing dest
mv --backup=numbered file.txt /dest/

# Move only if source is newer
mv -u source.txt dest.txt

# Verbose move
mv -v old_name/ new_name/

# Move into specific directory
mv -t /dest/dir/ file1.txt file2.txt
```

## Gotchas

- `mv` works on directories without `-r` (unlike `cp`).
- Moving across filesystems is a copy + delete operation and can be slow
  for large files.
- `-n` silently skips if destination exists. Check exit code if you need
  to know.
- `mv dir1 dir2` when dir2 exists moves dir1 inside dir2 as `dir2/dir1/`.
  Use `-T` to prevent this and treat dir2 as the target name.
- Moving a file that is open by another process is generally safe on Unix
  (the process keeps its file handle).
