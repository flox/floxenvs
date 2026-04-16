---
name: uniq
description: >-
  Report or omit repeated lines. Use when deduplicating adjacent lines,
  counting occurrences, or finding unique/duplicate lines. Input must be
  sorted first.
---

# uniq - Report or Omit Repeated Lines

## Synopsis

```
uniq [OPTION]... [INPUT [OUTPUT]]
```

Filter adjacent matching lines from INPUT (or stdin), writing to OUTPUT
(or stdout). With no options, matching lines are merged to the first
occurrence.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -c | --count | Prefix lines by the number of occurrences |
| -d | --repeated | Only print duplicate lines, one for each group |
| -D | | Print all duplicate lines |
| | --all-repeated[=METHOD] | Like -D: none (default), prepend, separate (blank line between groups) |
| -u | --unique | Only print unique lines (lines that are NOT repeated) |
| -i | --ignore-case | Ignore case when comparing |
| -f | --skip-fields=N | Avoid comparing the first N fields |
| -s | --skip-chars=N | Avoid comparing the first N characters |
| -w | --check-chars=N | Compare no more than N characters per line |
| | --group[=METHOD] | Show all items, separated by empty line: separate, prepend, append, both |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Remove adjacent duplicate lines
sort file.txt | uniq

# Count occurrences of each line
sort file.txt | uniq -c

# Top 10 most frequent lines
sort file.txt | uniq -c | sort -rn | head -10

# Show only duplicate lines
sort file.txt | uniq -d

# Show only unique lines (no duplicates)
sort file.txt | uniq -u

# Show all duplicates (not just first of each group)
sort file.txt | uniq -D

# Case-insensitive deduplication
sort -f file.txt | uniq -i

# Ignore first field when comparing
uniq -f 1 file.txt

# Compare only first 10 characters
uniq -w 10 file.txt

# Skip first 5 characters when comparing
uniq -s 5 file.txt
```

## Gotchas

- **uniq only removes ADJACENT duplicates.** You MUST sort the input
  first. `uniq file.txt` without sorting will only dedupe consecutive
  identical lines.
- `sort -u` is equivalent to `sort | uniq` and is faster (single pass).
- `-c` output has leading whitespace before the count, which can affect
  further parsing. Use `awk` or `sed` to trim if needed.
- `-d` shows one copy of each duplicated line. `-D` shows ALL copies
  (every instance).
- `-u` shows lines that appear exactly once (the opposite of -d).
- Fields for `-f` are delimited by blanks (spaces and tabs).
