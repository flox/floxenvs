---
name: cut
description: >-
  Remove sections from each line of files. Use when extracting columns,
  fields from CSV/TSV data, or specific character positions.
---

# cut - Remove Sections from Lines

## Synopsis

```
cut OPTION... [FILE]...
```

Print selected parts of lines from each FILE to standard output.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -f | --fields=LIST | Select only these fields (requires -d) |
| -d | --delimiter=DELIM | Use DELIM instead of TAB for field delimiter |
| -c | --characters=LIST | Select only these characters |
| -b | --bytes=LIST | Select only these bytes |
| -s | --only-delimited | Do not print lines not containing delimiters (with -f) |
| | --complement | Complement the set of selected bytes, characters, or fields |
| | --output-delimiter=STRING | Use STRING as the output delimiter |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| | --help | Display help |
| | --version | Output version |

### LIST Format

Use comma-separated values and/or ranges:

| Format | Meaning |
| ------ | ------- |
| N | Nth byte, character, or field (1-based) |
| N- | From Nth to end of line |
| N-M | From Nth to Mth (inclusive) |
| -M | From first to Mth |

## Examples

```bash
# Extract second field from TAB-separated data
cut -f2 data.tsv

# Extract fields from CSV
cut -d',' -f1,3 data.csv

# Extract first 10 characters of each line
cut -c1-10 file.txt

# Extract from character 5 to end
cut -c5- file.txt

# Extract multiple fields
cut -d':' -f1,3,5 /etc/passwd

# Change output delimiter
cut -d',' -f1,3 --output-delimiter=$'\t' data.csv

# Only print lines that contain the delimiter
cut -d',' -f2 -s data.csv

# Extract everything EXCEPT field 2
cut -d',' --complement -f2 data.csv

# Extract bytes (useful for fixed-width data)
cut -b1-8 fixed_width.txt

# Extract username and shell from /etc/passwd
cut -d: -f1,7 /etc/passwd
```

## Gotchas

- **cut uses single-character delimiters only.** You cannot use a
  multi-character string as a delimiter. For that, use `awk`.
- Default delimiter is TAB, not space. For space-delimited data, use
  `cut -d' '`, but note that multiple consecutive spaces are NOT treated
  as one delimiter (use `awk` for that).
- `-f` requires `-d` to be meaningful with non-TAB delimiters.
- Without `-s`, lines without the delimiter are passed through unchanged.
  Add `-s` to skip them.
- Fields are 1-indexed, not 0-indexed.
- `cut` cannot reorder fields. `cut -f3,1` outputs fields in their
  original order (1,3), not (3,1). Use `awk` to reorder.
