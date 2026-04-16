---
name: seq
description: >-
  Print a sequence of numbers. Use when generating number sequences for
  loops, creating numbered lists, or padding numbers.
---

# seq - Print a Sequence of Numbers

## Synopsis

```
seq [OPTION]... LAST
seq [OPTION]... FIRST LAST
seq [OPTION]... FIRST INCREMENT LAST
```

Print numbers from FIRST to LAST, in steps of INCREMENT. Default FIRST
and INCREMENT are 1.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -f | --format=FORMAT | Use printf-style FORMAT |
| -s | --separator=STRING | Use STRING to separate numbers (default: newline) |
| -w | --equal-width | Equalize width by padding with leading zeros |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Count 1 to 10
seq 10

# Count 5 to 15
seq 5 15

# Count by 2 (odd numbers)
seq 1 2 20

# Count by 0.5
seq 0 0.5 5

# Count down
seq 10 -1 1

# Zero-padded numbers
seq -w 1 100

# Custom separator (comma)
seq -s, 1 10

# Space-separated
seq -s' ' 1 10

# Custom format (3 decimal places)
seq -f '%.3f' 0 0.1 1

# Use in for loop
for i in $(seq 1 5); do echo "Item $i"; done

# Generate padded filenames
for i in $(seq -w 1 100); do touch "file_$i.txt"; done

# Generate as printf format
seq -f 'user%03g' 1 10
```

## Gotchas

- `seq` handles floating point numbers, but beware of floating-point
  precision issues. `seq 0 0.1 1` may or may not include 1.0.
- `-w` pads based on the widest number in the sequence. For fixed-width,
  use `-f '%03g'` instead.
- In bash, `{1..10}` (brace expansion) is an alternative for integer
  sequences but doesn't support variables. `seq` works with variables.
- The FORMAT string uses printf conventions: `%g` (general), `%f`
  (float), `%e` (scientific).
- `seq` counts DOWN if FIRST > LAST and INCREMENT is negative. If
  INCREMENT is positive but FIRST > LAST, nothing is printed.
