---
name: cat
description: >-
  Concatenate and display file contents. Use when viewing files,
  combining files, or creating files from stdin.
---

# cat - Concatenate Files

## Synopsis

```
cat [OPTION]... [FILE]...
```

Concatenate FILE(s) to standard output. With no FILE, or when FILE is -,
read standard input.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -n | --number | Number all output lines |
| -b | --number-nonblank | Number nonempty output lines (overrides -n) |
| -s | --squeeze-blank | Suppress repeated empty output lines |
| -E | --show-ends | Display $ at end of each line |
| -T | --show-tabs | Display TAB characters as ^I |
| -v | --show-nonprinting | Use ^ and M- notation for control/meta chars |
| -A | --show-all | Equivalent to -vET |
| -e | | Equivalent to -vE |
| -t | | Equivalent to -vT |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Display file contents
cat file.txt

# Concatenate multiple files
cat file1.txt file2.txt > combined.txt

# Number all lines
cat -n file.txt

# Number non-blank lines
cat -b file.txt

# Squeeze multiple blank lines into one
cat -s file.txt

# Show hidden characters (tabs, line endings)
cat -A file.txt

# Show tabs as ^I
cat -T file.txt

# Create a file from stdin (type content, Ctrl+D to end)
cat > newfile.txt

# Append to a file
cat >> existing.txt

# Concatenate with stdin in between
cat header.txt - footer.txt < body.txt
```

## Gotchas

- **Useless use of cat (UUOC):** `cat file | command` is almost always
  better written as `command < file` or `command file`. Most commands
  accept files as arguments.
- `cat` overwrites the output file if you redirect to the same file:
  ```bash
  # WRONG: destroys file.txt
  cat file.txt | sort > file.txt
  # RIGHT: use a temp file or sponge
  sort file.txt > sorted.txt && mv sorted.txt file.txt
  ```
- For large files, `cat` loads and outputs everything. Use `head`, `tail`,
  `less`, or `more` for partial viewing.
- `cat -v` is useful for debugging files with hidden characters like
  carriage returns (^M) from Windows line endings.
