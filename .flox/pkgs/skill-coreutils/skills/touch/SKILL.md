---
name: touch
description: >-
  Change file timestamps or create empty files. Use when updating
  modification/access times or creating placeholder files.
---

# touch - Change File Timestamps

## Synopsis

```
touch [OPTION]... FILE...
```

Update the access and modification times of each FILE to the current time.
A FILE that does not exist is created empty, unless -c is supplied.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -a | | Change only the access time |
| -m | | Change only the modification time |
| -c | --no-create | Do not create any files |
| -d | --date=STRING | Parse STRING and use it instead of current time |
| -t | | Use [[CC]YY]MMDDhhmm[.ss] instead of current time |
| -r | --reference=FILE | Use this FILE's times instead of current time |
| -h | --no-dereference | Affect symbolic link instead of referenced file |
| | --time=WORD | Change the specified time: access/atime/use (-a) or modify/mtime (-m) |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Create an empty file (or update timestamp)
touch file.txt

# Create multiple files
touch file1.txt file2.txt file3.txt

# Don't create file if it doesn't exist
touch -c file.txt

# Set specific date/time
touch -d '2024-01-15 10:30:00' file.txt

# Set using timestamp format
touch -t 202401151030.00 file.txt

# Copy timestamp from another file
touch -r reference.txt target.txt

# Update only modification time
touch -m file.txt

# Update only access time
touch -a file.txt

# Set date relative to now
touch -d 'yesterday' file.txt
touch -d '2 hours ago' file.txt
touch -d 'next monday' file.txt
```

## Gotchas

- `touch` creates the file if it doesn't exist (unless `-c` is used).
  This is often used intentionally to create empty files.
- The `-d` flag accepts many date formats including relative dates like
  "yesterday", "2 days ago", "next week" (GNU extension).
- `-t` uses the format `[[CC]YY]MMDDhhmm[.ss]` which is different from
  ISO date format.
- `touch -r` is useful for making files have the same timestamp as a
  reference file (e.g., after processing).
