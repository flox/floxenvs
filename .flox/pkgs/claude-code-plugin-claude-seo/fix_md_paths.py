#!/usr/bin/env python3
"""Build-time helper: rewrite upstream-install path references in
plugin markdown files to ${CLAUDE_PLUGIN_ROOT}/<actual-path>.

The upstream repo's docs reference scripts and agent files at the
paths the upstream install.sh creates them at:

    ~/.claude/skills/seo/scripts/foo.py
    ~/.claude/skills/seo-image-gen/scripts/foo.py
    ~/.claude/agents/seo-foo.md
    skills/seo/scripts/foo.py            (bare relative form)
    agents/seo-foo.md                    (bare relative form)

In a Flox-managed install the same files live under the plugin root
exposed to Claude Code via ${CLAUDE_PLUGIN_ROOT}. This script walks
the plugin tree, indexes every file by every path suffix, and for
each reference picks the longest unambiguous suffix that matches a
real file. That mapping drives the rewrite.

Forwards-compatible: the index is built from whatever files are in
the plugin tree at build time, so new upstream files are picked up
automatically. Ambiguous suffixes (e.g. bare 'SKILL.md', which
collides 27 times) fall through to longer suffixes; if nothing
unambiguous is found, the reference is left alone.

Usage: fix_md_paths.py <plugin-dir>
"""

from __future__ import annotations

import os
import re
import sys


SUFFIXES_INDEXED = (".py", ".md", ".sh", ".json", ".txt", ".toml")
PREFIX = "${CLAUDE_PLUGIN_ROOT}/"

# Form 1: ~/, $HOME, or ${HOME} expansion of ~/.claude/<anything>.
HOME_REF_RE = re.compile(
    r"(?:~|\$HOME|\$\{HOME\})/\.claude/[A-Za-z0-9_./-]+"
)

# Form 2: bare 'skills/...' or 'agents/...' starting at a word
# boundary. Anchored to (skills|agents) on purpose so this does not
# match arbitrary relative paths.
BARE_REF_RE = re.compile(
    r"(?<![A-Za-z0-9_./~$-])(?:skills|agents)/[A-Za-z0-9_./-]+"
)


def build_indexes(
    plugin_dir: str,
) -> tuple[set[str], dict[str, set[str]]]:
    """Walk the plugin tree and build two indexes.

    Returns (all_relpaths, suffix_to_relpaths) where:
    - all_relpaths is the set of every rel-path of an indexed file
      (relative to plugin_dir, using '/' as separator)
    - suffix_to_relpaths maps every '/'-separated suffix of every
      rel-path back to the set of rel-paths that end with it. For a
      file at 'a/b/c/d.py' the suffixes are 'd.py', 'c/d.py',
      'b/c/d.py', and 'a/b/c/d.py'.
    """
    all_relpaths: set[str] = set()
    suffix_to_relpaths: dict[str, set[str]] = {}
    for root, _, files in os.walk(plugin_dir):
        for fn in files:
            if not fn.endswith(SUFFIXES_INDEXED):
                continue
            abs_path = os.path.join(root, fn)
            rel = os.path.relpath(abs_path, plugin_dir).replace(os.sep, "/")
            all_relpaths.add(rel)
            parts = rel.split("/")
            for i in range(len(parts)):
                suffix = "/".join(parts[i:])
                suffix_to_relpaths.setdefault(suffix, set()).add(rel)
    return all_relpaths, suffix_to_relpaths


def find_rel(
    trailing: str,
    all_relpaths: set[str],
    suffix_to_relpaths: dict[str, set[str]],
) -> str | None:
    """Resolve a reference's trailing path to a real rel-path.

    Strategy: try exact rel-path match first (so e.g.
    'skills/seo-image-gen/SKILL.md' resolves to itself even though
    it is also a suffix of 'extensions/banana/skills/seo-image-gen/
    SKILL.md'). Fall back to matching progressively shorter
    suffixes; accept a suffix only if it points to exactly one
    rel-path or to an exact rel-path.
    """
    if trailing in all_relpaths:
        return trailing
    parts = trailing.split("/")
    for i in range(1, len(parts)):
        suffix = "/".join(parts[i:])
        if not suffix:
            continue
        if suffix in all_relpaths:
            return suffix
        candidates = suffix_to_relpaths.get(suffix)
        if candidates is not None and len(candidates) == 1:
            return next(iter(candidates))
    return None


def trailing_after_dotclaude(ref: str) -> str:
    """Strip the leading '~/.claude/' (or $HOME/.claude/) prefix."""
    for prefix in ("~/.claude/", "$HOME/.claude/", "${HOME}/.claude/"):
        if ref.startswith(prefix):
            return ref[len(prefix):]
    return ref


def rewrite_text(
    text: str,
    all_relpaths: set[str],
    suffix_to_relpaths: dict[str, set[str]],
) -> tuple[str, int]:
    rewrites = 0

    def make_resolver(strip_dotclaude: bool):
        def resolve(match: re.Match[str]) -> str:
            nonlocal rewrites
            full = match.group(0)
            trailing = (
                trailing_after_dotclaude(full) if strip_dotclaude else full
            )
            rel = find_rel(trailing, all_relpaths, suffix_to_relpaths)
            if rel is None:
                return full
            replacement = PREFIX + rel
            if replacement == full:
                return full
            rewrites += 1
            return replacement
        return resolve

    text = HOME_REF_RE.sub(make_resolver(strip_dotclaude=True), text)
    text = BARE_REF_RE.sub(make_resolver(strip_dotclaude=False), text)
    return text, rewrites


def main(plugin_dir: str) -> None:
    all_relpaths, suffix_to_relpaths = build_indexes(plugin_dir)

    files_changed = 0
    refs_changed = 0
    for root, _, files in os.walk(plugin_dir):
        for fn in files:
            if not fn.endswith(".md"):
                continue
            path = os.path.join(root, fn)
            try:
                with open(path, "r", encoding="utf-8") as fh:
                    content = fh.read()
            except (UnicodeDecodeError, OSError):
                continue
            new_content, n = rewrite_text(
                content, all_relpaths, suffix_to_relpaths
            )
            if n == 0:
                continue
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new_content)
            files_changed += 1
            refs_changed += n

    print(
        f"fix_md_paths: rewrote {refs_changed} reference(s) "
        f"across {files_changed} markdown file(s); "
        f"indexed {len(all_relpaths)} file(s)"
    )


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: fix_md_paths.py <plugin-dir>", file=sys.stderr)
        sys.exit(2)
    main(sys.argv[1])
