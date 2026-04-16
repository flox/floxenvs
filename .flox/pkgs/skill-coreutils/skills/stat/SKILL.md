---
name: stat
description: >-
  Display file or filesystem status. Use when checking file metadata like
  permissions, size, timestamps, inode, or filesystem information.
---

# stat - Display File or File System Status

## Synopsis

```
stat [OPTION]... FILE...
```

Display file or file system status.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -L | --dereference | Follow links |
| -f | --file-system | Display file system status instead of file status |
| -c | --format=FORMAT | Use the specified FORMAT instead of the default |
| | --printf=FORMAT | Like --format but interpret backslash escapes, no trailing newline |
| -t | --terse | Print information in terse form |
| | --help | Display help |
| | --version | Output version |

### Format Sequences (File)

| Sequence | Meaning |
| -------- | ------- |
| %a | Access rights in octal |
| %A | Access rights in human-readable form |
| %b | Number of blocks allocated |
| %B | Block size in bytes |
| %d | Device number in decimal |
| %D | Device number in hex |
| %f | Raw mode in hex |
| %F | File type |
| %g | Group ID of owner |
| %G | Group name of owner |
| %h | Number of hard links |
| %i | Inode number |
| %m | Mount point |
| %n | File name |
| %N | Quoted file name with dereference if symlink |
| %o | Optimal I/O transfer size hint |
| %s | Total size in bytes |
| %t | Major device type in hex |
| %T | Minor device type in hex |
| %u | User ID of owner |
| %U | User name of owner |
| %w | Time of file birth (- if unknown) |
| %W | Time of file birth as seconds since Epoch |
| %x | Time of last access |
| %X | Time of last access as seconds since Epoch |
| %y | Time of last data modification |
| %Y | Time of last modification as seconds since Epoch |
| %z | Time of last status change |
| %Z | Time of last status change as seconds since Epoch |

### Format Sequences (File System, with -f)

| Sequence | Meaning |
| -------- | ------- |
| %a | Free blocks available to non-superuser |
| %b | Total data blocks |
| %c | Total file nodes |
| %d | Free file nodes |
| %f | Free blocks |
| %i | File system ID in hex |
| %l | Maximum length of filenames |
| %n | File name |
| %s | Block size (for faster transfers) |
| %S | Fundamental block size |
| %t | File system type in hex |
| %T | File system type in human-readable form |

## Examples

```bash
# Default file status
stat file.txt

# Show only permissions in octal
stat -c '%a' file.txt

# Show file size in bytes
stat -c '%s' file.txt

# Show modification time
stat -c '%y' file.txt

# Custom format: name, size, permissions
stat -c '%n %s %A' file.txt

# Show file type
stat -c '%F' file.txt

# Show inode number
stat -c '%i' file.txt

# Show owner user and group
stat -c '%U:%G' file.txt

# Terse output (all info, single line)
stat -t file.txt

# File system info
stat -f /

# File system type
stat -f -c '%T' /

# Modification time as epoch seconds
stat -c '%Y' file.txt

# Compare with printf (interpret escapes)
stat --printf='Size: %s\nPerms: %a\n' file.txt
```

## Gotchas

- **GNU stat vs BSD stat:** The format specifiers are completely
  different between GNU and BSD (macOS). This skill documents GNU stat
  (from coreutils). BSD stat uses `-f` for format and different
  specifiers.
- `--format` adds a trailing newline; `--printf` does not (and
  interprets \\n, \\t, etc.).
- `%w` (birth time) may show `-` on filesystems that don't track it.
- `stat -c '%a'` shows permissions in octal (e.g., 644). `%A` shows
  human-readable (e.g., -rw-r--r--).
- For scripting, `stat -c '%Y'` (epoch seconds) is more parseable than
  `%y` (human-readable date).
