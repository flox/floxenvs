---
name: basename
description: >-
  Strip directory and suffix from filenames. Use when extracting just the
  filename from a path, or removing file extensions.
---

# basename - Strip Directory and Suffix from Filenames

## Synopsis

```
basename NAME [SUFFIX]
basename OPTION... NAME...
```

Print NAME with any leading directory components removed. If specified,
also remove a trailing SUFFIX.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -a | --multiple | Support multiple arguments, treat each as a NAME |
| -s | --suffix=SUFFIX | Remove trailing SUFFIX |
| -z | --zero | End each output line with NUL, not newline |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Extract filename from path
basename /path/to/file.txt
# Output: file.txt

# Remove extension
basename /path/to/file.txt .txt
# Output: file

# Remove extension with -s flag
basename -s .txt /path/to/file.txt
# Output: file

# Multiple files
basename -a /path/file1.txt /path/file2.txt
# Output: file1.txt\nfile2.txt

# Multiple files with suffix removal
basename -as .txt /path/file1.txt /path/file2.txt
# Output: file1\nfile2

# In shell scripting
filename=$(basename "$filepath")
name_no_ext=$(basename "$filepath" .txt)

# Common pattern: get script name
echo "Usage: $(basename "$0") [options]"
```

## Gotchas

- `basename` only does string manipulation on the path. It does not
  check if the file actually exists.
- Without `-a`, basename takes exactly one NAME argument (plus optional
  SUFFIX). Extra arguments are treated as the suffix.
- The SUFFIX is removed literally. `basename file.tar.gz .gz` gives
  `file.tar`, not `file`.
- For parameter expansion in bash, `${var##*/}` is equivalent to
  `basename "$var"` and avoids spawning a subprocess.
- `basename` strips only one level. `/path/to/` gives `to` (trailing
  slash is ignored).
