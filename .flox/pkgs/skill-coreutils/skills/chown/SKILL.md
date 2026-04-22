---
name: chown
description: >-
  Change file owner and group. Use when adjusting file ownership,
  typically requires root/sudo.
---

# chown - Change File Owner and Group

## Synopsis

```
chown [OPTION]... [OWNER][:[GROUP]] FILE...
chown [OPTION]... --reference=RFILE FILE...
```

Change the user and/or group ownership of each FILE.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -R | --recursive | Operate on files and directories recursively |
| -v | --verbose | Output a diagnostic for every file processed |
| -c | --changes | Like -v but only report changes |
| -f | --silent, --quiet | Suppress most error messages |
| -h | --no-dereference | Affect symlinks instead of referenced files |
| | --dereference | Affect the referent of each symlink (default) |
| | --from=CURRENT_OWNER:GROUP | Change only if current owner/group matches |
| | --reference=RFILE | Use RFILE's owner and group |
| -H | | With -R, follow symlinks on command line |
| -L | | With -R, follow all symlinks |
| -P | | With -R, never follow symlinks (default) |
| | --preserve-root | Don't recurse on / (default) |
| | --no-preserve-root | Allow recursion on / |
| | --help | Display help |
| | --version | Output version |

## Ownership Formats

| Format | Effect |
| ------ | ------ |
| OWNER | Change owner only |
| OWNER:GROUP | Change owner and group |
| OWNER: | Change owner, set group to owner's login group |
| :GROUP | Change group only (same as chgrp) |

## Examples

```bash
# Change owner
chown user file.txt

# Change owner and group
chown user:group file.txt

# Change group only
chown :group file.txt

# Recursive ownership change
chown -R user:group dir/

# Verbose output
chown -v user:group file.txt

# Only change if current owner matches
chown --from=olduser newuser file.txt

# Copy ownership from another file
chown --reference=ref.txt target.txt

# Affect symlink itself (not target)
chown -h user:group symlink

# Change owner, set group to user's default
chown user: file.txt
```

## Gotchas

- `chown` typically requires root/sudo privileges. Regular users cannot
  change file ownership (this is a security feature).
- With `-R`, the default `-P` does NOT follow symlinks, which is usually
  what you want to avoid accidentally changing ownership outside the
  target directory.
- `chown user:group` is preferred over the older `chown user.group` form,
  which is ambiguous when usernames contain dots.
- `--from` is useful for safe bulk changes, ensuring you only modify
  files with the expected current ownership.
