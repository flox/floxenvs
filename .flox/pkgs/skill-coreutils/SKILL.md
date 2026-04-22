---
name: coreutils
description: >-
  GNU coreutils reference — fundamental Unix file, text, and shell utilities
  (ls, cp, mv, rm, cat, sort, cut, chmod, etc.). Use when working with file
  operations, text processing, permissions, or system commands.
---

# GNU Coreutils Reference

The GNU core utilities are the basic file, shell, and text manipulation
utilities of the GNU operating system. This skill covers the most commonly
used commands for file operations, text processing, permissions, disk usage,
path manipulation, and miscellaneous utilities.

## Common Usage Patterns

### File Operations

```bash
# List files with details and human-readable sizes
ls -lah

# Copy directory recursively, preserving attributes
cp -a src/ dst/

# Move/rename with no-clobber (don't overwrite)
mv -n old new

# Remove directory recursively (interactive for safety)
rm -ri dir/

# Create nested directories
mkdir -p path/to/nested/dir

# Create symbolic link
ln -s target linkname

# Update file timestamp or create empty file
touch file.txt
```

### Text Processing

```bash
# Number lines in a file
cat -n file.txt

# First/last N lines
head -n 20 file.txt
tail -n 20 file.txt

# Follow log file in real time
tail -f /var/log/app.log

# Count lines, words, bytes
wc -l file.txt

# Sort numerically, reverse, unique
sort -nru file.txt

# Count occurrences of duplicate lines (must sort first)
sort file.txt | uniq -c | sort -rn

# Extract fields (CSV column 2)
cut -d',' -f2 data.csv

# Character transliteration (lowercase to uppercase)
tr '[:lower:]' '[:upper:]' < file.txt

# Write to file and stdout simultaneously
command | tee output.log
```

### Permissions and Ownership

```bash
# Make script executable
chmod +x script.sh

# Set directory permissions recursively
chmod -R 755 dir/

# Change owner and group recursively
chown -R user:group dir/

# Remove write permission for others
chmod o-w file.txt
```

### Disk and File Info

```bash
# Human-readable disk usage summary
du -sh dir/

# Disk free space
df -h

# Detailed file metadata
stat file.txt
```

### Path Manipulation

```bash
# Extract filename from path
basename /path/to/file.txt        # file.txt
basename /path/to/file.txt .txt   # file

# Extract directory from path
dirname /path/to/file.txt         # /path/to

# Resolve to absolute path (resolving symlinks)
realpath ./relative/path
```

### Miscellaneous

```bash
# Create temporary file/directory
tmpfile=$(mktemp)
tmpdir=$(mktemp -d)

# Run command for each line of input
find . -name '*.log' | xargs rm

# Null-delimited xargs (handles spaces in filenames)
find . -name '*.log' -print0 | xargs -0 rm

# Run command with modified environment
env VAR=value command

# Generate number sequence
seq 1 10

# Shuffle lines randomly
shuf file.txt

# Format/display date
date '+%Y-%m-%d %H:%M:%S'
```

## Anti-Patterns / Don't Do This

```bash
# NEVER: rm -rf / or rm -rf * without thinking
# ALWAYS double-check paths with echo first
echo rm -rf "$DIR"/*   # verify expansion before running

# WRONG: cp directory without -r
cp dir/ newdir/        # fails silently or copies nothing
# RIGHT:
cp -r dir/ newdir/

# WRONG: chmod 777 (world-writable)
chmod 777 file         # security risk
# RIGHT: use minimal permissions
chmod 755 dir/; chmod 644 file

# WRONG: parsing ls output (breaks on spaces, special chars)
ls -l | awk '{print $9}'
# RIGHT: use find, glob, or stat
find . -maxdepth 1 -type f

# WRONG: useless use of cat
cat file | grep pattern
# RIGHT: grep reads files directly
grep pattern file

# WRONG: uniq without sort (only dedupes adjacent lines)
uniq file.txt
# RIGHT:
sort file.txt | uniq

# WRONG: xargs without -0 on filenames with spaces
find . -name '*.txt' | xargs rm
# RIGHT:
find . -name '*.txt' -print0 | xargs -0 rm

# WRONG: using relative paths with ln -s
ln -s ../file link     # breaks if link is moved
# RIGHT: use absolute paths for symlinks
ln -s /absolute/path/file link
```

## Available Sub-Skills

For full flag reference, read the specific sub-skill file:

| Command | Skill file | Description |
| ------- | ---------- | ----------- |
| `ls` | `@SKILL_DIR@/skills/ls/SKILL.md` | List directory contents |
| `cp` | `@SKILL_DIR@/skills/cp/SKILL.md` | Copy files and directories |
| `mv` | `@SKILL_DIR@/skills/mv/SKILL.md` | Move/rename files and directories |
| `rm` | `@SKILL_DIR@/skills/rm/SKILL.md` | Remove files and directories |
| `mkdir` | `@SKILL_DIR@/skills/mkdir/SKILL.md` | Create directories |
| `ln` | `@SKILL_DIR@/skills/ln/SKILL.md` | Create hard and symbolic links |
| `touch` | `@SKILL_DIR@/skills/touch/SKILL.md` | Change timestamps or create files |
| `chmod` | `@SKILL_DIR@/skills/chmod/SKILL.md` | Change file permissions |
| `chown` | `@SKILL_DIR@/skills/chown/SKILL.md` | Change file owner and group |
| `cat` | `@SKILL_DIR@/skills/cat/SKILL.md` | Concatenate and display files |
| `head` | `@SKILL_DIR@/skills/head/SKILL.md` | Output first part of files |
| `tail` | `@SKILL_DIR@/skills/tail/SKILL.md` | Output last part of files |
| `wc` | `@SKILL_DIR@/skills/wc/SKILL.md` | Word, line, character, and byte count |
| `sort` | `@SKILL_DIR@/skills/sort/SKILL.md` | Sort lines of text files |
| `uniq` | `@SKILL_DIR@/skills/uniq/SKILL.md` | Report or omit repeated lines |
| `cut` | `@SKILL_DIR@/skills/cut/SKILL.md` | Remove sections from lines |
| `tr` | `@SKILL_DIR@/skills/tr/SKILL.md` | Translate or delete characters |
| `tee` | `@SKILL_DIR@/skills/tee/SKILL.md` | Read stdin, write to stdout and files |
| `df` | `@SKILL_DIR@/skills/df/SKILL.md` | Report file system disk space usage |
| `du` | `@SKILL_DIR@/skills/du/SKILL.md` | Estimate file space usage |
| `stat` | `@SKILL_DIR@/skills/stat/SKILL.md` | Display file status and metadata |
| `date` | `@SKILL_DIR@/skills/date/SKILL.md` | Display or set date and time |
| `basename` | `@SKILL_DIR@/skills/basename/SKILL.md` | Strip directory and suffix from path |
| `dirname` | `@SKILL_DIR@/skills/dirname/SKILL.md` | Strip last component from path |
| `realpath` | `@SKILL_DIR@/skills/realpath/SKILL.md` | Resolve absolute pathname |
| `mktemp` | `@SKILL_DIR@/skills/mktemp/SKILL.md` | Create temporary file or directory |
| `xargs` | `@SKILL_DIR@/skills/xargs/SKILL.md` | Build and execute commands from stdin |
| `env` | `@SKILL_DIR@/skills/env/SKILL.md` | Run command with modified environment |
| `seq` | `@SKILL_DIR@/skills/seq/SKILL.md` | Print numeric sequences |
| `shuf` | `@SKILL_DIR@/skills/shuf/SKILL.md` | Shuffle lines or generate random permutations |
