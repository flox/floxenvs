---
name: tail
description: >-
  Output the last part of files. Use when viewing file endings, following
  log files in real-time, or reading from a specific line.
---

# tail - Output Last Part of Files

## Synopsis

```
tail [OPTION]... [FILE]...
```

Print the last 10 lines of each FILE to standard output.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -n | --lines=[+]NUM | Output last NUM lines; with + prefix, output starting at line NUM |
| -c | --bytes=[+]NUM | Output last NUM bytes; with + prefix, output starting at byte NUM |
| -f | --follow[=name\|descriptor] | Output appended data as file grows |
| -F | | Same as --follow=name --retry (follow by name, retry if file replaced) |
| | --retry | Keep trying to open a file if not accessible |
| -s | --sleep-interval=N | With -f, sleep N seconds between checks (default 1.0) |
| | --pid=PID | With -f, terminate after process PID dies |
| | --max-unchanged-stats=N | With --follow=name, reopen file after N iterations without change |
| -q | --quiet, --silent | Never print headers giving file names |
| -v | --verbose | Always print headers giving file names |
| -z | --zero-terminated | Line delimiter is NUL, not newline |
| | --help | Display help |
| | --version | Output version |

NUM may have a multiplier suffix: b (512), kB (1000), K (1024),
MB (1000000), M (1048576), GB, G, etc.

## Examples

```bash
# Show last 10 lines (default)
tail file.txt

# Show last 20 lines
tail -n 20 file.txt

# Follow a log file in real time
tail -f /var/log/app.log

# Follow by name (survives log rotation)
tail -F /var/log/app.log

# Output starting from line 100
tail -n +100 file.txt

# Show last 1000 bytes
tail -c 1000 file.txt

# Follow with custom sleep interval
tail -f -s 0.5 file.log

# Follow and stop when PID exits
tail -f --pid=$$ logfile.txt

# Follow multiple files
tail -f file1.log file2.log

# Output starting from byte 500
tail -c +500 file.txt
```

## Gotchas

- `tail -n +N` outputs starting FROM line N (inclusive), not the last N
  lines. This is useful for skipping headers: `tail -n +2 file.csv`
  skips the first line.
- `-f` follows by file descriptor (default). If the file is rotated
  (renamed and a new file created with same name), `-f` follows the old
  file. Use `-F` (or `--follow=name --retry`) for log rotation.
- `-F` is the preferred flag for monitoring log files that rotate.
- `tail -f` on a pipe reads from the pipe, but many programs buffer
  output when not writing to a terminal. Use `stdbuf -oL` or the
  program's unbuffer option.
- With multiple files and `-f`, output is interleaved with headers
  showing which file each line comes from.
