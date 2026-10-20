#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and for error cases its standard error, and its exit
# status with the expected ones. Run from the repository root.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
FIX=$(pwd)/tests/fixtures
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_err NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
# As check, and standard error must equal EXPECTED_STDERR too.
check_err() {
    local name=$1 want_status=$2 want_err=$4
    printf '%s' "$3" > "$TMP/want"
    shift 4
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    printf '%s' "$want_err" > "$TMP/want_err"
    if [ "$status" -eq "$want_status" ] && cmp -s "$TMP/want" "$TMP/out" && cmp -s "$TMP/want_err" "$TMP/err"; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff "$TMP/want" "$TMP/out" | sed 's/^/    stdout /' | head -10
        diff "$TMP/want_err" "$TMP/err" | sed 's/^/    stderr /' | head -10
    fi
}

USAGE=$'Usage: grep [OPTION]... PATTERNS [FILE]...\nTry \'grep --help\' for more information.\n'
cd "$FIX" || exit 1
seq 1 20 > "$TMP/n.txt"
N=$TMP/n.txt

# Selecting lines
check "plain"              0 $'Foo fighters: foo, FOO and foobar\nend of foo\n'   foo poem.txt
check "no match"           1 ''                                   zebra poem.txt
check "-i"                 0 $'Foo fighters: foo, FOO and foobar\nend of foo\n'   -i FOO poem.txt
check "-v"                 0 $'alpha\n'                           -v foo tree/a.txt
check "-w"                 0 $'Foo fighters: foo, FOO and foobar\nend of foo\n'   -w foo poem.txt
check "-w rejects part"    1 ''                                   -w foob poem.txt
check "-x"                 0 $'end of foo\n'                      -x 'end of foo' poem.txt
check "-x -w"              1 ''                                   -x -w foo poem.txt
check "empty pattern"      0 $'5:\n'                              -n -x '' poem.txt
check "two -e"             0 $'jumps over the lazy dog.\nend of foo\n'   -e lazy -e 'end' poem.txt
check "newline patterns"   0 $'The quick brown fox\ncafé au lait\n'      $'quick\nlait' poem.txt
check "last line no nl"    0 $'b\n'                               b <(printf 'a\nb')
IN=poem.txt check "stdin"  0 $'café au lait\n'                    café
IN=poem.txt check "stdin dash" 0 $'(standard input):café au lait\ntree/a.txt:alpha\n'   -e café -e alpha - tree/a.txt

# Pattern syntax
check "BRE literal +"      0 $'a+b (x) {y} |z|\n'                 'a+b' poem.txt
check "BRE \\+"            0 $'a+b (x) {y} |z|\n'                 'a\++b' poem.txt
check "BRE group interval" 0 $'Foo fighters: foo, FOO and foobar\n'   '\(o\)\{2\}b' poem.txt
check "BRE alternation"    0 $'The quick brown fox\njumps over the lazy dog.\n'   'fox\|dog' poem.txt
check "BRE literal ^"      1 ''                                   'a^b' poem.txt
check "ERE"                0 $'jumps over the lazy dog.\na+b (x) {y} |z|\n'   -E '\{y\}|la(z|t)y' poem.txt
check "ERE literal {"      0 $'a+b (x) {y} |z|\n'                 -E '{y' poem.txt
check "fixed"              0 $'a+b (x) {y} |z|\n'                 -F '(x) {y}' poem.txt
check "fixed -i"           0 $'The quick brown fox\n'             -Fi 'THE Q' poem.txt
check "bracket classes"    0 $'jumps over the lazy dog.\n'          '[[:space:]]d[a-z]\{1\}[[:lower:]]\.$' poem.txt
check "class -o"           0 $'+\n(\n)\n{\n}\n|\n|\n'             -o '[^[:alnum:][:space:]]' <(sed -n 4p poem.txt)
check "word edges"         0 $'end of foo\n'                      '\<of\>' poem.txt
check "non-ASCII -i"       0 $'café au lait\n'                    -i 'CAFÉ' poem.txt

# Output modes
check "-n"                 0 $'3:Foo fighters: foo, FOO and foobar\n7:end of foo\n'   -n foo poem.txt
check "-c"                 0 $'2\n'                               -c foo poem.txt
check "-c -v"              0 $'5\n'                               -cv foo poem.txt
check "-o"                 0 $'foo\nfoo\nfoo\n'                   -o foo poem.txt
check "-o -i -n"           0 $'3:Foo\n3:foo\n3:FOO\n3:foo\n7:foo\n'   -oin foo poem.txt
check "-o -w"              0 $'foo\nfoo\n'                        -ow foo poem.txt
check "-o -v"              0 ''                                   -ov foo poem.txt
check "-H"                 0 $'poem.txt:end of foo\n'             -H 'end' poem.txt
check "two files"          0 $'poem.txt:end of foo\ntree/a.txt:foo in a\n'   'foo$\|in a' poem.txt tree/a.txt
check "-h"                 0 $'end of foo\nfoo in a\n'            -h 'foo$\|in a' poem.txt tree/a.txt
check "-c two files"       0 $'poem.txt:2\ntree/sub/b.txt:0\n'    -c foo poem.txt tree/sub/b.txt
check "-l"                 0 $'poem.txt\n'                        -l foo poem.txt tree/sub/b.txt
check "-L"                 0 $'tree/sub/b.txt\n'                  -L foo poem.txt tree/sub/b.txt
check "-L none listed"     0 ''                                   -L foo poem.txt
check "-l -c"              0 $'poem.txt\n'                        -c -l foo poem.txt
check "-q match"           0 ''                                   -q foo poem.txt
check "-q no match"        1 ''                                   -q zebra poem.txt

# Context
check "-A"                 0 $'5\n6\n--\n15\n16\n'                -A1 5 "$N"
check "-B -n"              0 $'3-3\n4:4\n'                        -nB1 '^4$' "$N"
check "-C merged"          0 $'2\n3\n4\n5\n6\n'                   -C1 -e '^3$' -e '^5$' "$N"
check "-NUM"               0 $'9\n10\n11\n'                       -1 '^10$' "$N"
check "-A wins over -C"    0 $'8\n9\n10\n'                        -C2 -A0 '^10$' "$N"
check "context two files"  0 $'tree/a.txt-alpha\ntree/a.txt:foo in a\n--\ntree/sub/deeper/c.txt:deep foo\ntree/sub/deeper/c.txt-foo again\n'   -C1 'in a\|deep' tree/a.txt tree/sub/deeper/c.txt
check "context -o"         0 $'10\n--\n15\n'                      -o -C1 '1[05]' "$N"

# Files and recursion
check "-r"                 0 $'tree/a.txt:foo in a\ntree/sub/deeper/c.txt:deep foo\ntree/sub/deeper/c.txt:foo again\n'   -r foo tree
check "-r trailing slash"  0 $'tree/a.txt:foo in a\n'             -r 'in a' tree/
check "-r single file"     0 $'foo in a\n'                        -r foo tree/a.txt
check "-rc"                0 $'tree/a.txt:1\ntree/sub/b.txt:0\ntree/sub/deeper/c.txt:2\n'   -rc foo tree
check "-rL"                0 $'tree/sub/b.txt\n'                  -rL foo tree
check "-rh"                0 $'foo in a\n'                        -rh 'in a' tree
cd tree || exit 1
check "-r no operand"      0 $'a.txt:2:foo in a\nsub/deeper/c.txt:1:deep foo\nsub/deeper/c.txt:2:foo again\n'   -rn foo
cd "$FIX" || exit 1

printf 'text\0with nul foo\n' > "$TMP/bin.dat"
printf 'caf\351 foo\n' > "$TMP/latin1.txt"
check_err "binary"         0 '' "grep: $TMP/bin.dat: binary file matches"$'\n'   foo "$TMP/bin.dat"
check_err "invalid UTF-8"  0 '' "grep: $TMP/latin1.txt: binary file matches"$'\n'   foo "$TMP/latin1.txt"
check "binary -c"          0 $'1\n'                               -c foo "$TMP/bin.dat"
check "binary -l"          0 "$TMP/bin.dat"$'\n'                  -l foo "$TMP/bin.dat"

# Errors and exit statuses
check_err "missing file"   2 $'poem.txt:end of foo\n' $'grep: nope.txt: No such file or directory\n'   'end' nope.txt poem.txt
check_err "-s"             2 '' ''                                -s foo nope.txt
check_err "-q beats error" 0 '' $'grep: nope.txt: No such file or directory\n'   -q foo nope.txt poem.txt
check_err "directory"      2 '' $'grep: tree: Is a directory\n'   foo tree
check_err "no pattern"     2 '' "$USAGE"
check_err "bad option"     2 '' "grep: invalid option -- 'k'"$'\n'"$USAGE"   -k foo
check_err "bad long"       2 '' "grep: unrecognized option '--colour'"$'\n'"$USAGE"   --colour foo
check_err "ambiguous"      2 '' "grep: option '--files-with' is ambiguous; possibilities: '--files-with-matches' '--files-without-match'"$'\n'"$USAGE"   --files-with foo
check_err "missing value"  2 '' "grep: option requires an argument -- 'A'"$'\n'"$USAGE"   -A
check_err "bad context"    2 '' $'grep: x: invalid context length argument\n'   -A x foo
check_err "conflict"       2 '' $'grep: conflicting matchers specified\n'   -E -F foo
check_err "bad pattern"    2 '' $'grep: Unmatched ( or \\(\n'      'a\(' poem.txt
check_err "bad bracket"    2 '' $'grep: Unmatched [, [^, [:, [., or [=\n'   '[a' poem.txt
check_err "class syntax"   2 '' $'grep: character class syntax is [[:space:]], not [:space:]\n'   '[:space:]' poem.txt
check_err "back-reference" 2 '' $'grep: back-references (\\1 to \\9) are not supported\n'   '\(a\)\1' poem.txt
check "version"            0 $'grep (loup-cmd-grep) 0.1.0\n'      --version
check "long options"       0 $'7:end of foo\n'                    --line-number --regexp='of foo' --word-regexp poem.txt
check "options after files" 0 $'7:end of foo\n'                   'of foo' poem.txt -n
check "double dash"        1 ''                                   -- -n poem.txt

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
