---
name: wc
description: >-
  Count lines, words, characters, and bytes. Use when counting file
  content, measuring file sizes, or counting items in pipelines.
---

# wc - Word, Line, Character, and Byte Count

## Synopsis

```
wc [OPTION]... [FILE]...
```

Print newline, word, and byte counts for each FILE, and a total line
if more than one FILE is specified.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -l | --lines | Print the newline count |
| -w | --words | Print the word count |
| -c | --bytes | Print the byte count |
| -m | --chars | Print the character count |
| -L | --max-line-length | Print the maximum display width (line length) |
| | --files0-from=F | Read input from files listed in NUL-terminated file F; use - for stdin |
| | --total=WHEN | When to print total: auto, always, only, never |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Default output (lines, words, bytes)
wc file.txt

# Count lines only
wc -l file.txt

# Count words only
wc -w file.txt

# Count bytes
wc -c file.txt

# Count characters (differs from bytes for multibyte encodings)
wc -m file.txt

# Maximum line length
wc -L file.txt

# Count lines from multiple files (with total)
wc -l *.txt

# Count lines from stdin (e.g., count files in directory)
find . -type f | wc -l

# Count lines without filename in output
wc -l < file.txt

# Only show total for multiple files
wc -l --total=only *.txt
```

## Gotchas

- `wc -l` counts newline characters. A file without a trailing newline
  will have its last line uncounted.
- `wc -l file.txt` prints the count AND the filename. To get just the
  number: `wc -l < file.txt`.
- `-c` counts bytes, `-m` counts characters. For ASCII they're the same;
  for UTF-8, one character may be multiple bytes.
- When piping, `wc` reads from stdin and does not print a filename.
- `-L` reports display width, not byte length. Tabs count as the number
  of spaces to the next tab stop.
