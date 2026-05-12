---
name: ls
description: "List directory contents — view files, check permissions, sizes, timestamps, or sort/filter listings. Use when exploring directories, verifying file attributes, or building file-listing commands."
---

# ls — List Directory Contents

List information about files in a directory (current directory by default).
Sorts entries alphabetically unless a sort option is specified.

## When to Use ls vs Alternatives

| Task | Use | Why |
| ---- | --- | --- |
| Quick human-readable listing | `ls -lah` | Concise, familiar output |
| Scriptable file enumeration | `find . -maxdepth 1` | Handles special chars safely |
| Detailed metadata for one file | `stat file` | Structured, parseable output |
| Recursive search by criteria | `find . -name '*.log'` | Filters, actions built in |
| Count files in directory | `find . -maxdepth 1 -type f \| wc -l` | Correct with special filenames |

## Key Flag Combinations

```bash
# Full details with human-readable sizes (most common)
ls -lah

# Only directories
ls -d */

# Recently modified first
ls -lt

# Largest files first
ls -lSh

# Hidden files only (exclude . and ..)
ls -A -d .[^.]*

# Machine-friendly: one entry per line, no color
ls -1 --color=never

# Group directories first, then files
ls -la --group-directories-first

# Full ISO timestamps for precise comparison
ls -l --time-style=full-iso

# Skip compiled/generated files
ls --ignore='*.pyc' --ignore='__pycache__' --ignore='node_modules'
```

## Gotchas and Non-Obvious Behavior

### Never parse ls output in scripts

Filenames can contain spaces, newlines, tabs, and special characters that
break parsing. This is the single most common ls misuse:

```bash
# WRONG — breaks on filenames with spaces or special chars
for f in $(ls); do echo "$f"; done
ls -l | awk '{print $9}'

# RIGHT — use globs, find, or stat
for f in *; do echo "$f"; done
find . -maxdepth 1 -type f -print0 | xargs -0 -I{} echo "{}"
```

### Hidden files: -a vs -A

`-a` includes `.` and `..` directory entries, which inflates counts and
can cause recursive issues. Use `-A` (almost-all) when you want hidden
files without the directory self-references.

### Symlink behavior

`ls -l` shows info about the symlink itself. Add `-L` to dereference
and show the target's attributes. When symlinks point to missing targets,
`-L` will show an error while plain `ls -l` shows the dangling link.

### Color and piping

Color escape codes corrupt piped output. Use `--color=never` when piping
to other commands, or `--color=always` to force color through a pager.

### Locale-dependent sort order

Default alphabetical sort follows the current locale's collation rules,
which may interleave upper and lowercase. Set `LC_ALL=C` for strict
byte-order sorting when deterministic output matters.

### -f flag side effects

`-f` disables sorting but also implicitly enables `-a` and `-U`, and
disables `-l`, `-s`, and `--color`. It's faster on very large directories
but the side effects are easy to forget.
