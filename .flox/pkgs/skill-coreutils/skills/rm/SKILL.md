---
name: rm
description: >-
  Remove files and directories. Use when deleting files, cleaning up
  temporary files, or removing directory trees. Exercise caution.
---

# rm - Remove Files and Directories

## Synopsis

```
rm [OPTION]... [FILE]...
```

Remove (unlink) FILEs. Does not remove directories by default.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -r, -R | --recursive | Remove directories and their contents recursively |
| -f | --force | Ignore nonexistent files, never prompt |
| -i | | Prompt before every removal |
| -I | | Prompt once before removing more than 3 files or recursively |
| | --interactive[=WHEN] | Prompt: never, once (-I), always (-i) |
| -d | --dir | Remove empty directories |
| -v | --verbose | Explain what is being done |
| | --one-file-system | When removing recursively, skip directories on different filesystems |
| | --no-preserve-root | Do not treat / specially |
| | --preserve-root[=all] | Do not remove / (default); =all rejects commands operating on / args |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Remove a file
rm file.txt

# Remove multiple files
rm file1.txt file2.txt file3.txt

# Remove directory recursively
rm -r directory/

# Force remove (no prompts, ignore missing)
rm -f file.txt

# Remove recursively with force (DANGEROUS)
rm -rf directory/

# Interactive removal (prompt each file)
rm -i *.log

# Prompt once before bulk removal
rm -I *.tmp

# Remove empty directory
rm -d empty_dir/

# Verbose removal
rm -rv directory/
```

## Gotchas

- **`rm -rf` is irreversible.** There is no trash/recycle bin. Always
  double-check the path, especially with variables:
  ```bash
  # DANGEROUS if $DIR is empty:
  rm -rf "$DIR"/*
  # SAFER: check first:
  [ -n "$DIR" ] && rm -rf "$DIR"/*
  ```
- `--preserve-root` is on by default in GNU coreutils, preventing
  `rm -rf /`. But `rm -rf /*` is NOT caught by this protection.
- `-f` overrides `-i`. If both are given, the last one wins.
- `-r` follows directory trees but does NOT follow symbolic links to
  directories (it removes the link itself).
- On some systems, removing a file that's open by a process doesn't free
  the space until the process closes its file descriptor.
- Use `-I` for a safer interactive mode that only prompts once for bulk
  operations (more than 3 files).
