#!/usr/bin/env bash
# Run volume.awk with several awk interpreters on both Shakespeare inputs,
# compare each output with the expected text, and print a pass/fail and
# timing table (best of 3 runs, wall-clock seconds, including start-up).
#
# usage: ./run.sh            (run ./fetch.sh first)
#
# Choose interpreters with AWKS (names separated by spaces), and override any
# command with its variable, for example:
#   AWKS="mawk hawk" HAWK_CMD=~/bin/hawk ./run.sh
# Interpreters that are not installed are skipped. The exit status is non-zero
# if any interpreter that ran gave a wrong result or failed.
set -uo pipefail
cd "$(dirname "$0")"
export LC_ALL=C   # length() counts bytes; see README.md
unset LANG LC_CTYPE

# Defaults: each interpreter is looked up on PATH under its usual name.
first_on_path() {   # print the first of the given names found on PATH
    local n
    for n in "$@"; do
        if command -v "$n" >/dev/null 2>&1; then echo "$n"; return 0; fi
    done
    echo "$1"
}
if [[ -z "${PYAWK_CMD:-}" ]]; then
    if [[ -n "${PYAWK_DIR:-}" ]]; then PYAWK_CMD="env PYTHONPATH=$PYAWK_DIR python3 -m pyawk"
    else PYAWK_CMD=pyawk; fi
fi
HAWK_CMD=${HAWK_CMD:-hawk}
MAWK_CMD=${MAWK_CMD:-mawk}
GAWK_CMD=${GAWK_CMD:-gawk}
GAWK_POSIX_CMD=${GAWK_POSIX_CMD:-$GAWK_CMD --posix}
ONETRUE_CMD=${ONETRUE_CMD:-$(first_on_path original-awk onetrue-awk bwk-awk nawk)}
BUSYBOX_CMD=${BUSYBOX_CMD:-busybox awk}
AWKS=${AWKS:-pyawk hawk mawk gawk gawk-posix onetrue busybox}
RUNS=${RUNS:-3}

command_for() {
    case $1 in
        pyawk) echo "$PYAWK_CMD" ;;
        hawk) echo "$HAWK_CMD" ;;
        mawk) echo "$MAWK_CMD" ;;
        gawk) echo "$GAWK_CMD" ;;
        gawk-posix) echo "$GAWK_POSIX_CMD" ;;
        onetrue) echo "$ONETRUE_CMD" ;;
        busybox) echo "$BUSYBOX_CMD" ;;
        *) return 1 ;;
    esac
}

# Is the interpreter available?  A quick run of a trivial program decides.
available() {
    # shellcheck disable=SC2086  # the command is deliberately word-split
    local first
    first=$(echo x | $1 '{ print $1 }' 2>/dev/null | head -n 1)
    [[ "$first" == x ]]
}

now() { date +%s%N; }   # nanoseconds since the epoch, an integer

inputs=(shakespeare_body.txt shakespeare_reversed.txt)
expected=(expected.txt expected-reversed.txt)
for f in "${inputs[@]}"; do
    if [[ ! -f data/$f ]]; then
        echo "run.sh: data/$f is missing; run ./fetch.sh first" >&2
        exit 2
    fi
done

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
failed=0
ran=0
rows=()
for name in $AWKS; do
    if ! cmd=$(command_for "$name"); then
        echo "run.sh: unknown interpreter name '$name'" >&2
        exit 2
    fi
    if ! available "$cmd"; then
        rows+=("$(printf '| %-10s | %-8s | %8s | %-8s | %8s |' "$name" skipped - skipped -)")
        echo "skip  $name: not available ($cmd)" >&2
        continue
    fi
    ran=$((ran + 1))
    row=$(printf '| %-10s ' "$name")
    for i in 0 1; do
        status=PASS
        best=
        for _ in $(seq "$RUNS"); do
            t0=$(now)
            # shellcheck disable=SC2086
            $cmd -f volume.awk "data/${inputs[$i]}" >"$out/stdout" 2>"$out/stderr"
            rc=$?
            t1=$(now)
            ns=$((t1 - t0))
            if [[ $rc -ne 0 ]] || ! cmp -s "$out/stdout" "${expected[$i]}"; then
                status=FAIL
                echo "FAIL  $name on ${inputs[$i]} (exit $rc):" >&2
                diff "${expected[$i]}" "$out/stdout" | head -20 >&2
                head -5 "$out/stderr" >&2
                break
            fi
            if [[ -z "$best" || $ns -lt $best ]]; then best=$ns; fi
        done
        [[ $status == FAIL ]] && { failed=1; best=-; } || best=$(printf '%d.%03d' $((best / 1000000000)) $((best / 1000000 % 1000)))
        row+=$(printf '| %-8s | %8s ' "$status" "$best")
    done
    rows+=("$row|")
done

echo
echo "LC_ALL=C, best of $RUNS runs, wall-clock seconds"
echo
echo "| awk        | body     |  seconds | reversed |  seconds |"
echo "|------------|----------|---------:|----------|---------:|"
printf '%s\n' "${rows[@]}"
if [[ $ran -eq 0 ]]; then
    echo "run.sh: no interpreter was available" >&2
    exit 2
fi
if [[ $failed -ne 0 ]]; then
    echo "run.sh: at least one interpreter FAILED" >&2
    exit 1
fi
echo
echo "run.sh: all $ran available interpreters PASS"
