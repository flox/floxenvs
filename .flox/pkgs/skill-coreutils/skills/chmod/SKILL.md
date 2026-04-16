---
name: chmod
description: >-
  Change file mode/permissions. Use when setting read/write/execute
  permissions on files and directories.
---

# chmod - Change File Mode Bits

## Synopsis

```
chmod [OPTION]... MODE[,MODE]... FILE...
chmod [OPTION]... OCTAL-MODE FILE...
chmod [OPTION]... --reference=RFILE FILE...
```

Change the file mode bits of each FILE to MODE. MODE can be symbolic
or octal.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -R | --recursive | Change files and directories recursively |
| -v | --verbose | Output a diagnostic for every file processed |
| -c | --changes | Like -v but only report changes |
| -f | --silent, --quiet | Suppress most error messages |
| | --reference=RFILE | Use RFILE's mode instead of specifying MODE |
| | --preserve-root | Don't recurse on / (default) |
| | --no-preserve-root | Allow recursion on / |
| | --help | Display help |
| | --version | Output version |

## Permission Modes

### Octal Mode

Each digit represents user/group/others: read=4, write=2, execute=1.

| Octal | Permission | Meaning |
| ----- | ---------- | ------- |
| 755 | rwxr-xr-x | Owner: all; group/others: read+execute |
| 644 | rw-r--r-- | Owner: read+write; group/others: read |
| 700 | rwx------ | Owner: all; group/others: none |
| 600 | rw------- | Owner: read+write; group/others: none |
| 777 | rwxrwxrwx | Everyone: all (avoid!) |
| 444 | r--r--r-- | Everyone: read only |
| 500 | r-x------ | Owner: read+execute; group/others: none |

### Symbolic Mode

Format: `[ugoa][+-=][rwxXstugo]`

| Symbol | Meaning |
| ------ | ------- |
| u | User (owner) |
| g | Group |
| o | Others |
| a | All (ugo) |
| + | Add permission |
| - | Remove permission |
| = | Set exact permission |
| r | Read |
| w | Write |
| x | Execute |
| X | Execute only if file is a directory or already has execute |
| s | Set user or group ID on execution (setuid/setgid) |
| t | Sticky bit |

## Examples

```bash
# Make script executable
chmod +x script.sh

# Set standard file permissions
chmod 644 file.txt

# Set standard directory permissions
chmod 755 dir/

# Recursive permission change
chmod -R 755 dir/

# Add execute for directories only (capital X)
chmod -R u=rwX,g=rX,o=rX dir/

# Remove write permission for group and others
chmod go-w file.txt

# Set exact permissions for user, add read for group
chmod u=rwx,g+r file.txt

# Copy permissions from another file
chmod --reference=source.txt target.txt

# Verbose output
chmod -v 644 file.txt

# Set setuid bit
chmod u+s /usr/local/bin/program

# Set sticky bit on directory
chmod +t /tmp/shared/

# Make files read-only
chmod a-w file.txt
```

## Gotchas

- **Never use 777** in production. It gives everyone full access.
- `chmod -R 755` sets execute on ALL files. Use `find` with `-type` to
  differentiate:
  ```bash
  find dir/ -type d -exec chmod 755 {} +
  find dir/ -type f -exec chmod 644 {} +
  ```
- Capital `X` is crucial for recursive operations: it adds execute only
  to directories and files that already have execute, avoiding making
  every file executable.
- `chmod` does not follow symlinks by default. The permissions of a
  symlink itself are typically ignored; the target's permissions matter.
- Setuid/setgid (chmod u+s, g+s) on scripts is ignored by most modern
  kernels for security reasons. It only works on compiled binaries.
