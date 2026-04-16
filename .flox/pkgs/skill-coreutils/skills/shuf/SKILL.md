---
name: shuf
description: >-
  Generate random permutations. Use when shuffling lines, picking random
  items, generating random numbers, or sampling data.
---

# shuf - Generate Random Permutations

## Synopsis

```
shuf [OPTION]... [FILE]
shuf -e [OPTION]... [ARG]...
shuf -i LO-HI [OPTION]...
```

Write a random permutation of the input lines to standard output.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -e | --echo | Treat each ARG as an input line |
| -i | --input-range=LO-HI | Treat each number LO through HI as an input line |
| -n | --head-count=COUNT | Output at most COUNT lines |
| -o | --output=FILE | Write result to FILE instead of stdout |
| -r | --repeat | Output lines can be repeated (with -n) |
| | --random-source=FILE | Get random bytes from FILE |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Shuffle lines of a file
shuf file.txt

# Pick 1 random line
shuf -n 1 file.txt

# Pick 5 random lines (no repeats)
shuf -n 5 file.txt

# Pick from command-line arguments
shuf -e apple banana cherry grape

# Pick one random item
shuf -n 1 -e red green blue

# Random number from range
shuf -i 1-100 -n 1

# Shuffle numbers 1-52 (deck of cards)
shuf -i 1-52

# Random sample with replacement (repeats allowed)
shuf -r -n 10 -e heads tails

# Write shuffled output to file
shuf -o shuffled.txt input.txt

# Simulate dice rolls (6 rolls)
shuf -r -n 6 -i 1-6

# Random password characters
shuf -r -n 16 -e {a..z} {A..Z} {0..9} | tr -d '\n'

# Shuffle and take top 10% of a file
total=$(wc -l < file.txt)
count=$((total / 10))
shuf -n "$count" file.txt
```

## Gotchas

- Without `-r`, shuf performs a permutation (no repeats). Each input
  line appears at most once.
- `-r` (repeat) only makes sense with `-n`. Without `-n`, shuf with
  `-r` would output forever.
- `-i LO-HI` generates integers in range and shuffles them. Useful for
  random number generation without needing an input file.
- `-n 1` combined with `-e` or `-i` is a quick way to pick a random
  item or number.
- shuf reads the entire input into memory. For very large files, this
  can be problematic. Use `shuf -n COUNT` to limit output without
  reading everything (though it still reads the whole file internally).
