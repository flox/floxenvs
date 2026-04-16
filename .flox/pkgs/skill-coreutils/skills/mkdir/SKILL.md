---
name: mkdir
description: >-
  Create directories. Use when making new directories, creating nested
  directory structures, or setting directory permissions at creation time.
---

# mkdir - Create Directories

## Synopsis

```
mkdir [OPTION]... DIRECTORY...
```

Create the DIRECTORY(ies), if they do not already exist.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -p | --parents | Create parent directories as needed, no error if existing |
| -m | --mode=MODE | Set file mode (permissions), like chmod |
| -v | --verbose | Print message for each created directory |
| -Z | | Set SELinux security context |
| | --context[=CTX] | Like -Z, or set SELinux/SMACK context to CTX |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Create a single directory
mkdir mydir

# Create nested directory structure
mkdir -p path/to/nested/dir

# Create with specific permissions
mkdir -m 755 mydir

# Create multiple directories
mkdir dir1 dir2 dir3

# Verbose creation
mkdir -pv path/to/deep/dir

# Create with restricted permissions
mkdir -m 700 private_dir
```

## Gotchas

- Without `-p`, mkdir fails if the parent directory doesn't exist or if
  the directory already exists.
- With `-p`, no error is reported for existing directories, and parent
  directories are created with default permissions modified by umask,
  regardless of the `-m` flag. Only the final directory gets the `-m`
  permissions.
- The `-m` flag accepts the same format as chmod: numeric (755) or
  symbolic (u=rwx,g=rx,o=rx).
