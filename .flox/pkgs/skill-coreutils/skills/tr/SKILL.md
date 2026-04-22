---
name: tr
description: >-
  Translate, squeeze, or delete characters. Use when converting case,
  removing characters, replacing delimiters, or cleaning text.
---

# tr - Translate or Delete Characters

## Synopsis

```
tr [OPTION]... STRING1 [STRING2]
```

Translate, squeeze, and/or delete characters from standard input, writing
to standard output. tr only reads from stdin (not files directly).

## Flags

| Flag | Description |
| ---- | ----------- |
| -d | Delete characters in STRING1, do not translate |
| -s | Squeeze repeated characters listed in the last operand |
| -c, -C | Use the complement of STRING1 |
| -t | Truncate STRING1 to the length of STRING2 |
| --help | Display help |
| --version | Output version |

## Character Classes

| Class | Meaning |
| ----- | ------- |
| [:alnum:] | All letters and digits |
| [:alpha:] | All letters |
| [:blank:] | Horizontal whitespace (space, tab) |
| [:cntrl:] | Control characters |
| [:digit:] | All digits |
| [:graph:] | Printable characters, not including space |
| [:lower:] | Lowercase letters |
| [:upper:] | Uppercase letters |
| [:print:] | Printable characters, including space |
| [:punct:] | Punctuation characters |
| [:space:] | Horizontal or vertical whitespace |
| [:xdigit:] | Hexadecimal digits |

## Escape Sequences

| Sequence | Meaning |
| -------- | ------- |
| \\\\ | Backslash |
| \\a | Bell (BEL) |
| \\b | Backspace |
| \\f | Form feed |
| \\n | Newline |
| \\r | Carriage return |
| \\t | Horizontal tab |
| \\v | Vertical tab |
| \\NNN | Octal value NNN (1 to 3 digits) |

## Range and Repeat

| Syntax | Meaning |
| ------ | ------- |
| CHAR1-CHAR2 | Range of characters from CHAR1 to CHAR2 |
| [CHAR*] | In STRING2, repeat CHAR as many times as needed |
| [CHAR*REPEAT] | REPEAT copies of CHAR |

## Examples

```bash
# Convert lowercase to uppercase
tr '[:lower:]' '[:upper:]' < file.txt

# Convert uppercase to lowercase
tr '[:upper:]' '[:lower:]' < file.txt

# Delete all digits
tr -d '[:digit:]' < file.txt

# Delete all non-printable characters
tr -d '[:cntrl:]' < file.txt

# Replace spaces with tabs
tr ' ' '\t' < file.txt

# Replace newlines with spaces (join lines)
tr '\n' ' ' < file.txt

# Squeeze repeated spaces into single space
tr -s ' ' < file.txt

# Squeeze repeated newlines (remove blank lines)
tr -s '\n' < file.txt

# Replace non-alphanumeric characters with newlines (word per line)
tr -cs '[:alnum:]' '\n' < file.txt

# Remove carriage returns (DOS to Unix line endings)
tr -d '\r' < dosfile.txt > unixfile.txt

# ROT13 encoding
tr 'A-Za-z' 'N-ZA-Mn-za-m' < file.txt

# Replace colons with newlines
tr ':' '\n' <<< "$PATH"

# Delete specific characters
tr -d 'aeiou' < file.txt

# Complement: delete everything except digits
tr -cd '[:digit:]' < file.txt
```

## Gotchas

- **tr reads ONLY from stdin.** You cannot pass filenames as arguments.
  Use `tr ... < file.txt` or `cat file.txt | tr ...`.
- Character classes must be enclosed in `[:class:]` with the square
  brackets. Using `tr lower upper` translates individual characters
  l/o/w/e/r, not the class.
- `-c` complements STRING1: it operates on all characters NOT in STRING1.
- `-s` with two strings: translates first, then squeezes. `-s` alone
  (one string): just squeezes.
- tr operates on single bytes, not multi-byte characters. For UTF-8 text,
  use `sed` or `awk` for character-level operations.
- Order matters: `tr 'abc' 'xyz'` maps a->x, b->y, c->z. If STRING2 is
  shorter, the last character is repeated.
