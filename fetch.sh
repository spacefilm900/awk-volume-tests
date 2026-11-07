#!/usr/bin/env bash
# Download Project Gutenberg ebook #100 (The Complete Works of William
# Shakespeare) and build the two test inputs in data/:
#   data/shakespeare_body.txt      the text between the START and END markers
#   data/shakespeare_reversed.txt  the same words in reverse order (reverse.py)
# Every file is checked against the sha256 pinned below (from source.json).
# If Gutenberg has changed the file, this stops with a clear message.
set -euo pipefail
cd "$(dirname "$0")"
export LC_ALL=C

URL=https://www.gutenberg.org/cache/epub/100/pg100.txt
RAW_SHA256=eb61e33cab23dbe712ad57091ded6c7292ba91ac3bb2764f51a3223ec0068fe5
BODY_SHA256=a6209a86eb3de42530f24feaf317e94d43ea18d71ccb64a8cf5e54a368db23f2
REVERSED_SHA256=e1c76205e4ef19d7f7c2ab44d734bbb21423ba41c64ead4efe5ae9c698a3d6ac
START='*** START OF THE PROJECT GUTENBERG EBOOK THE COMPLETE WORKS OF WILLIAM SHAKESPEARE ***'
END='*** END OF THE PROJECT GUTENBERG EBOOK THE COMPLETE WORKS OF WILLIAM SHAKESPEARE ***'

mkdir -p data
raw=data/pg100.txt
# Remove old derived files first, so a failed run never leaves stale inputs.
rm -f data/shakespeare_body.txt data/shakespeare_reversed.txt

check() { # check FILE EXPECTED-SHA256 WHAT
    local got
    got=$(sha256sum "$1" | cut -d' ' -f1)
    if [[ "$got" != "$2" ]]; then
        echo "fetch.sh: $3 has the wrong sha256" >&2
        echo "  file:     $1" >&2
        echo "  expected: $2" >&2
        echo "  got:      $got" >&2
        return 1
    fi
    echo "ok  $1  sha256 $got"
}

if [[ -f "$raw" ]] && check "$raw" "$RAW_SHA256" "cached download" >/dev/null 2>&1; then
    echo "using cached $raw"
else
    echo "downloading $URL"
    curl -fsSL --retry 3 -o "$raw.part" "$URL"
    mv "$raw.part" "$raw"
fi
if ! check "$raw" "$RAW_SHA256" "the Gutenberg download"; then
    echo "fetch.sh: Project Gutenberg has changed pg100.txt since the expected" >&2
    echo "outputs were verified (2026-11-07). The results would not be comparable," >&2
    echo "so nothing was built. See README.md, 'If the download changes'." >&2
    exit 1
fi

# CRLF -> LF (every CR in the download is part of a CRLF pair), then keep only
# the lines strictly between the START and END marker lines.
sed 's/\r$//' "$raw" | python3 -c '
import sys
start, end = sys.argv[1].encode(), sys.argv[2].encode()
lines = sys.stdin.buffer.read().splitlines(keepends=True)
s = next(i for i, l in enumerate(lines) if l.rstrip(b"\n") == start)
e = next(i for i, l in enumerate(lines) if l.rstrip(b"\n") == end)
sys.stdout.buffer.write(b"".join(lines[s + 1:e]))
' "$START" "$END" > data/shakespeare_body.txt
check data/shakespeare_body.txt "$BODY_SHA256" "the extracted body"

python3 reverse.py data/shakespeare_body.txt data/shakespeare_reversed.txt
check data/shakespeare_reversed.txt "$REVERSED_SHA256" "the reversed file"
echo "fetch.sh: inputs ready in data/"
