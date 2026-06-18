# NNNN. Short decision title

Date: YYYY-MM-DD

Status: Proposed

## Context

What forces this decision? The constraints, the problem, the relevant
facts. Describe the situation neutrally — someone should be able to
reach a different decision from the same context.

## Decision

The decision we made, in active voice: "We will …". State it plainly.

## Consequences

What becomes easier and what becomes harder as a result. Use `+` for
benefits and `-` for costs/risks we accepted.

- `+` …
- `-` …

---

Process:

- One decision per file, numbered in order (`0001-…`, `0002-…`).
- Status is `Proposed`, then `Accepted`, then `Superseded by NNNN`.
- Records are immutable once accepted. To revisit, add a new record.
- Add a record for any choice that is significant and hard to reverse:
  a dependency, a public interface, a data shape, a security boundary,
  a build-system change.
