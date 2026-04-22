---
name: ln
description: >-
  Create hard and symbolic links. Use when creating symlinks, hard links,
  or managing file references.
---

# ln - Make Links Between Files

## Synopsis

```
ln [OPTION]... TARGET LINK_NAME
ln [OPTION]... TARGET... DIRECTORY
```

Create a link to TARGET with the name LINK_NAME, or create links to
TARGETs in DIRECTORY.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -s | --symbolic | Make symbolic links instead of hard links |
| -f | --force | Remove existing destination files |
| -i | --interactive | Prompt before removing destinations |
| -n | --no-dereference | Treat LINK_NAME as normal file if it's a symlink to a dir |
| -r | --relative | Create symbolic links relative to link location |
| -v | --verbose | Print name of each linked file |
| -b | | Make backup of existing destination |
| | --backup[=CONTROL] | Make backup: none, numbered, existing, simple |
| -S | --suffix=SUFFIX | Override backup suffix |
| -t | --target-directory=DIR | Specify target directory |
| -T | --no-target-directory | Treat LINK_NAME as normal file |
| -L | --logical | Dereference TARGETs that are symbolic links |
| -P | --physical | Make hard links directly to symbolic links |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Create a symbolic link
ln -s /path/to/target linkname

# Create a hard link
ln target linkname

# Force overwrite existing link
ln -sf /new/target existing_link

# Create relative symbolic link
ln -sr /path/to/target linkname

# Create symlinks for multiple targets in a directory
ln -s /path/file1 /path/file2 /dest/dir/

# Verbose link creation
ln -sv /path/to/target linkname

# Update symlink (force + no-dereference for dir symlinks)
ln -sfn /new/target existing_dir_link
```

## Gotchas

- **Symbolic vs hard links:** Symlinks (-s) can cross filesystems and link
  to directories. Hard links cannot cross filesystems and cannot link to
  directories.
- **Relative paths in symlinks** are relative to the link's location, not
  the current working directory. Use `-r` to have ln compute the relative
  path for you.
- **Updating a symlink to a directory** requires `-sfn`. Without `-n`, ln
  would create a link inside the directory the existing link points to.
- Hard links share the same inode. Deleting the original file doesn't
  affect the hard link (unlike symlinks, which become dangling).
- To verify where a symlink points: `readlink -f linkname` or
  `realpath linkname`.
