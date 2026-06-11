---
name: csv-deduplicator
description: Use when you need to remove duplicate rows from a CSV file, keeping the first occurrence and preserving the header and column order.
---

# CSV Deduplicator

Remove duplicate rows from a CSV file while keeping the
header and the original column order intact.

## Use when

- A CSV has repeated rows that should collapse to one.
- You want to keep the first occurrence of each duplicate.
- The header row and column order must be preserved.

## Steps

1. Read the CSV, treating the first line as the header.
2. Hash each data row by its full set of cell values.
3. Emit a row the first time its hash is seen; skip later
   identical rows.
4. Write the header followed by the deduplicated rows in
   their original order.

## Example

```bash
csv-dedup input.csv > output.csv
```

Given an `input.csv` with two identical "Alice,30,NY" rows,
`output.csv` contains a single "Alice,30,NY" row.

## Notes

- Comparison is byte-exact on the joined cell values; it
  does not normalize whitespace or case.
- Rows that differ in any cell are treated as distinct.
