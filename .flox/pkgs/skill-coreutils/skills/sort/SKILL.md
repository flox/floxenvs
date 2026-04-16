---
name: sort
description: >-
  Sort lines of text files. Use when ordering data, deduplicating sorted
  data, sorting by specific fields/columns, or numeric/version sorting.
---

# sort - Sort Lines of Text Files

## Synopsis

```
sort [OPTION]... [FILE]...
```

Write sorted concatenation of all FILE(s) to standard output.

## Flags

### Sort Order

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -n | --numeric-sort | Compare according to string numerical value |
| -g | --general-numeric-sort | Compare according to general numerical value (supports scientific notation) |
| -h | --human-numeric-sort | Compare human readable numbers (2K, 1G) |
| -V | --version-sort | Natural sort of version numbers |
| -M | --month-sort | Compare as month names (JAN < FEB < ... < DEC) |
| -R | --random-sort | Shuffle, but group identical keys |
| -r | --reverse | Reverse the result of comparisons |

### Key Selection

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -k | --key=KEYDEF | Sort via a key: FIELD[.CHAR][OPTS][,FIELD[.CHAR][OPTS]] |
| -t | --field-separator=SEP | Use SEP instead of blank-to-non-blank transition |

### Output Control

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -u | --unique | Output only the first of equal runs (with -c, check strict ordering) |
| -o | --output=FILE | Write result to FILE instead of stdout |
| -s | --stable | Stabilize sort by disabling last-resort comparison |
| -c | --check | Check whether input is sorted; do not sort |
| -C | --check=quiet | Like -c but do not report first bad line |
| -m | --merge | Merge already sorted files; do not sort |

### Performance and Behavior

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -f | --ignore-case | Fold lowercase to uppercase for comparison |
| -b | --ignore-leading-blanks | Ignore leading blanks |
| -d | --dictionary-order | Consider only blanks and alphanumeric characters |
| -i | --ignore-nonprinting | Consider only printable characters |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| -S | --buffer-size=SIZE | Use SIZE for main memory buffer |
| -T | --temporary-directory=DIR | Use DIR for temporaries |
| | --parallel=N | Change number of sorts run concurrently to N |
| | --compress-program=PROG | Compress temporaries with PROG |
| | --help | Display help |
| | --version | Output version |

### Key Definition (KEYDEF)

Format: `F[.C][OPTS][,F[.C][OPTS]]`
- F = field number (1-based)
- C = character position within field (1-based)
- OPTS = one of [bdfgiMhnRrV] applied to this key only

## Examples

```bash
# Basic alphabetical sort
sort file.txt

# Numeric sort
sort -n numbers.txt

# Sort and remove duplicates
sort -u file.txt

# Reverse sort
sort -r file.txt

# Sort by second field (space-separated)
sort -k2 file.txt

# Sort CSV by third column numerically
sort -t',' -k3 -n data.csv

# Sort by second field, then third field numerically
sort -k2,2 -k3,3n file.txt

# Sort by human-readable sizes
du -sh */ | sort -h

# Version sort
sort -V versions.txt

# Sort in place (write back to same file)
sort -o file.txt file.txt

# Check if file is sorted
sort -c file.txt

# Sort with stable algorithm
sort -s -k1,1 file.txt

# Case-insensitive sort
sort -f file.txt

# Merge pre-sorted files
sort -m sorted1.txt sorted2.txt
```

## Gotchas

- **Key specification:** `-k2` means "from field 2 to end of line."
  Use `-k2,2` to sort by field 2 only.
- **sort + uniq pattern:** `sort | uniq` is common, but `sort -u` does
  both in one step (and is faster).
- `-n` sorts "10" after "9" (numerically). Without it, "10" comes before
  "9" (lexicographic).
- `-o file.txt file.txt` is safe (sort reads all input before writing).
- Default field separator is blank-to-non-blank transition. Use `-t` for
  CSV/TSV data.
- Sort is locale-dependent. Use `LC_ALL=C sort` for byte-order sorting
  which is faster and more predictable.
- `-h` (human-numeric) understands K, M, G, T suffixes. Useful with
  `du -h` and `ls -lh` output.
