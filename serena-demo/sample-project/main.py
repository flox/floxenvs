"""Entry point exercised by the Serena MCP server in the
demo. Run with: python main.py World"""

from __future__ import annotations

import sys

from utils import greet, shout


def main(argv: list[str]) -> int:
    name = argv[1] if len(argv) > 1 else "world"
    print(shout(greet(name)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
