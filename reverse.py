#!/usr/bin/env python3
"""Build the reversed Shakespeare input from the extracted body.

usage: python3 reverse.py BODY REVERSED

The line order is reversed, and so is the order of the whitespace-separated
words within every line. Each line is rejoined with single ASCII spaces, so
runs of spaces and leading or trailing spaces disappear, and blank lines stay
blank. The result has exactly the same words as the body, in reverse order.
This is the same transformation as the original verified run
(prepare.py, 2026-11-07); fetch.sh checks the output's sha256.
"""
import sys
from pathlib import Path


def reverse(body: bytes) -> bytes:
    # bytes.split() with no argument splits on runs of ASCII whitespace.
    lines = body.splitlines()[::-1]
    return b"".join(b" ".join(line.split()[::-1]) + b"\n" for line in lines)


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    body = Path(sys.argv[1]).read_bytes()
    result = reverse(body)
    # Independent check: the whole word sequence is exactly reversed.
    assert result.split() == body.split()[::-1], "word sequence is not an exact reversal"
    assert result.count(b"\n") == body.count(b"\n"), "line count changed"
    Path(sys.argv[2]).write_bytes(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
