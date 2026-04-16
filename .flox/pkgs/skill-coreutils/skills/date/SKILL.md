---
name: date
description: >-
  Display or set the system date and time. Use when formatting dates,
  calculating relative dates, converting timestamps, or getting the
  current time in specific formats.
---

# date - Display or Set Date and Time

## Synopsis

```
date [OPTION]... [+FORMAT]
date [-u|--utc|--universal] [MMDDhhmm[[CC]YY][.ss]]
```

Display the current time in the given FORMAT, or set the system date.

## Flags

| Flag | Long Form | Description |
| ---- | --------- | ----------- |
| -d | --date=STRING | Display time described by STRING, not now |
| -f | --file=DATEFILE | Like -d but process each line of DATEFILE |
| -I | --iso-8601[=TIMESPEC] | Output ISO 8601 date/time: date, hours, minutes, seconds, ns |
| -R | --rfc-email | Output RFC 5322 format (email date) |
| | --rfc-3339=TIMESPEC | Output RFC 3339 format: date, seconds, ns |
| -r | --reference=FILE | Display last modification time of FILE |
| -s | --set=STRING | Set time described by STRING |
| -u | --utc, --universal | Print or set UTC time |
| | --debug | Annotate the parsed date |
| | --help | Display help |
| | --version | Output version |

## Format Sequences

### Date

| Sequence | Meaning | Example |
| -------- | ------- | ------- |
| %Y | Year (4 digit) | 2024 |
| %y | Year (2 digit) | 24 |
| %m | Month (01-12) | 03 |
| %d | Day of month (01-31) | 15 |
| %e | Day of month, space-padded ( 1-31) | 15 |
| %j | Day of year (001-366) | 074 |
| %u | Day of week (1-7, Monday=1) | 5 |
| %w | Day of week (0-6, Sunday=0) | 5 |
| %a | Abbreviated weekday name | Fri |
| %A | Full weekday name | Friday |
| %b, %h | Abbreviated month name | Mar |
| %B | Full month name | March |
| %C | Century | 20 |
| %G | ISO week year | 2024 |
| %V | ISO week number (01-53) | 11 |

### Time

| Sequence | Meaning | Example |
| -------- | ------- | ------- |
| %H | Hour (00-23) | 14 |
| %I | Hour (01-12) | 02 |
| %M | Minute (00-59) | 30 |
| %S | Second (00-60) | 45 |
| %N | Nanoseconds | 123456789 |
| %p | AM or PM | PM |
| %P | am or pm | pm |
| %Z | Timezone abbreviation | CET |
| %z | Timezone offset | +0100 |
| %:z | Timezone offset with colon | +01:00 |
| %s | Seconds since Unix epoch | 1710513045 |

### Combined

| Sequence | Meaning | Example |
| -------- | ------- | ------- |
| %c | Locale's date and time | Fri Mar 15 14:30:45 2024 |
| %x | Locale's date | 03/15/2024 |
| %X | Locale's time | 14:30:45 |
| %D | Date as %m/%d/%y | 03/15/24 |
| %F | Full date as %Y-%m-%d | 2024-03-15 |
| %T | Time as %H:%M:%S | 14:30:45 |
| %R | Time as %H:%M | 14:30 |
| %r | 12-hour time | 02:30:45 PM |

### Padding

| Sequence | Meaning |
| -------- | ------- |
| %-d | No padding (day: 5 instead of 05) |
| %_d | Space padding |
| %0d | Zero padding (default) |

## Examples

```bash
# ISO 8601 date
date '+%Y-%m-%d'

# Full ISO 8601 date and time
date -I seconds

# Timestamp for filenames
date '+%Y%m%d_%H%M%S'

# Unix epoch seconds
date '+%s'

# RFC 5322 format (for emails)
date -R

# Specific date formatting
date '+%A, %B %d, %Y'

# Relative dates
date -d 'yesterday'
date -d 'tomorrow'
date -d '3 days ago'
date -d 'next friday'
date -d '2 weeks'
date -d 'last month'

# Convert epoch to human-readable
date -d @1710513045

# UTC time
date -u

# File modification time
date -r file.txt

# Calculate future date
date -d '2024-01-01 + 90 days' '+%Y-%m-%d'

# Time in different timezone
TZ='America/New_York' date
TZ='Asia/Tokyo' date '+%H:%M %Z'

# Start of current month
date -d "$(date +%Y-%m-01)"

# End of current month
date -d "$(date -d 'next month' +%Y-%m-01) - 1 day" '+%Y-%m-%d'
```

## Gotchas

- **GNU date vs BSD date:** The `-d` flag works differently. GNU uses
  `-d STRING` for display. BSD uses `-v` for date math and `-j -f` for
  parsing. This skill documents GNU date.
- The `%s` format gives seconds since epoch (1970-01-01 00:00:00 UTC).
- `-d` accepts many natural language formats: "yesterday", "3 days ago",
  "next monday", "2024-01-01", "@epoch_seconds".
- `date -d @EPOCH` converts epoch seconds back to human-readable.
- Setting the system date (`date -s`) requires root privileges.
- `%N` (nanoseconds) is a GNU extension not available on all platforms.
- Use `TZ=` environment variable to get time in other timezones without
  changing system settings.
