---
name: head
description: >-
  Output the first part of files. Use when viewing the beginning of
  files, checking file headers, or previewing file contents.
---

# head - Output First Part of Files

## Synopsis

```
head [OPTION]... [FILE]...
```

Print the first 10 lines of each FILE to standard output. With more
than one FILE, precede each with a header.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -n | --lines=[-]NUM | Print first NUM lines; with - prefix, print all but last NUM lines |
| -c | --bytes=[-]NUM | Print first NUM bytes; with - prefix, print all but last NUM bytes |
| -q | --quiet, --silent | Never print headers giving file names |
| -v | --verbose | Always print headers giving file names |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| | --help | Display help |
| | --version | Output version |

NUM may have a multiplier suffix: b (512), kB (1000), K (1024),
MB (1000000), M (1048576), GB, G, and so on.

## Examples

```bash
# Show first 10 lines (default)
head file.txt

# Show first 20 lines
head -n 20 file.txt

# Show first 100 bytes
head -c 100 file.txt

# Show all lines except the last 5
head -n -5 file.txt

# Show all bytes except the last 100
head -c -100 file.txt

# Show first line of multiple files with headers
head -n 1 *.txt

# Show first line without filename header
head -qn 1 *.txt

# Show first 1K bytes
head -c 1K file.txt
```

## Gotchas

- The negative form (`head -n -5`) prints everything EXCEPT the last 5
  lines. This is very useful but often forgotten.
- Default is 10 lines when `-n` is not specified.
- With multiple files, headers are printed by default. Use `-q` to
  suppress them.
- `head -c` counts bytes, not characters. For multi-byte encodings
  (UTF-8), this may split a character.
