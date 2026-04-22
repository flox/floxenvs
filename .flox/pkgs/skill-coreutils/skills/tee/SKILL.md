---
name: tee
description: >-
  Read from stdin, write to stdout and files simultaneously. Use when you
  need to save command output to a file while also seeing it, or writing
  to multiple files at once.
---

# tee - Read from Stdin, Write to Stdout and Files

## Synopsis

```
tee [OPTION]... [FILE]...
```

Copy standard input to each FILE, and also to standard output.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -a | --append | Append to files, do not overwrite |
| -i | --ignore-interrupts | Ignore the SIGINT signal |
| -p | | Warn if writing to a pipe that is not being read |
| | --output-error[=MODE] | Set behavior on write error: warn, warn-nopipe, exit, exit-nopipe |
| | --help | Display help |
| | --version | Output version |

## Examples

```bash
# Save output and display it
ls -la | tee listing.txt

# Append to a file instead of overwriting
echo "new entry" | tee -a log.txt

# Write to multiple files
command | tee file1.txt file2.txt

# Write to file and pipe to another command
command | tee output.log | grep "ERROR"

# Use with sudo to write to protected files
echo "setting" | sudo tee /etc/config.conf > /dev/null

# Append to multiple files
echo "log entry" | tee -a log1.txt log2.txt

# Capture intermediate pipeline output
cat data.txt | tee step1.txt | sort | tee step2.txt | uniq

# Discard stdout, only write to file
command | tee output.txt > /dev/null
```

## Gotchas

- `tee` overwrites files by default. Use `-a` to append.
- `sudo echo "text" > /etc/file` fails because the redirect happens in
  the current shell (not as root). Use `echo "text" | sudo tee /etc/file`
  instead.
- `tee` writes to stdout AND the file(s). If you only want the file, add
  `> /dev/null` after tee.
- When using `tee` in a pipeline, the stdout of `tee` goes to the next
  command in the pipe. The file gets a copy.
- If one of the output files fails (e.g., permission denied), `tee`
  continues writing to the others by default. Use `--output-error=exit`
  to stop on error.
