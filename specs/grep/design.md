# Design: grep

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses the arguments
into `Options`, handles `--help` and `--version`, and calls
`commands.grep.run_grep`. `run_grep` compiles the patterns into a `Matcher`,
turns the operands into a list of inputs (expanding directories under `-r`),
reads each input whole, and hands its lines to `search_lines`, which returns
the output lines and the number of selected lines. Only `run_grep` prints.

```text
argv ─▶ parse_args ─▶ Options ─▶ build_matcher ─▶ Matcher (system.regex objects)
                                   └ translate (BRE / ERE / fixed ─▶ regex syntax)
operands ─▶ inputs (walk under -r) ─▶ read, is_binary, split_lines
        ─▶ search_lines (selection, -o, context ring) ─▶ output lines, count
```

## Modules

| Module | Contents |
|---|---|
| `source/main.loup` | entry point: `run(runtime.args())` |
| `source/appinfo.loup` | name, version, summary, exit statuses 0/1/2 |
| `source/cli/args.loup` | enums `Syntax`, `ListMode`; `Options`; `ArgError`; `parse_args` (getopt_long-style: permutation, clusters, `-NUM`, long-option prefixes) |
| `source/cli/usage.loup` | `usage()`, `version_line()`, `USAGE_LINE` |
| `source/cli/app.loup` | `run()`: parse, usage errors, help/version, `run_grep`, exceptions to status 2 |
| `source/commands/pattern.loup` | `translate(pattern, syntax, icase)`: POSIX BRE/ERE or fixed string to `system.regex` syntax; `join_alternatives` |
| `source/commands/matcher.loup` | class `Matcher` (`selects(line)`, `matches(line)` for `-o`); `build_matcher(opts)` |
| `source/commands/context.loup` | class `ContextRing`: the last B unprinted lines for `-B` |
| `source/commands/search.loup` | `SearchConfig`, `SearchResult`, `search_lines()` |
| `source/commands/inputs.loup` | `split_lines`, `is_binary`, `child_path`, `prefix_line` helpers |
| `source/commands/grep.loup` | `run_grep()`: inputs, errors, printing, exit status |

### Pattern translation

`system.regex` is a PCRE-style backtracking engine (`(?:)`, `\b`, lazy
quantifiers, no back-references, no case-insensitive flag, `^`/`$` anchor the
whole input). `translate` walks the pattern's code points and builds a list
of *pieces*, each tagged with a kind (`ATOM`, `QUANTIFIED`, `ANCHOR`, `OPEN`,
`ALT`):

- A literal becomes an atom: letters and digits as themselves, ASCII
  punctuation escaped (`\.`), anything else as `\x{HEX}`. With `-i` a letter
  becomes `[aA]`.
- A quantifier attaches to the previous piece. After a quantified piece it
  wraps it first (`a**` becomes `(?:a*)*`) so `?` never turns into a lazy
  marker. With nothing to repeat it is literal (BRE) or dropped (ERE).
- `\(` / `(` pushes the index of an `OPEN` piece; the closing parenthesis
  collapses everything after it into one atom `(?:...)`, so a following
  quantifier applies to the whole group. User groups are never capturing.
- BRE `^` is an anchor only after the start, `\(` or `\|`; BRE `$` only before
  the end, `\)` or `\|`. Elsewhere they are literal.
- A bracket expression is parsed into single characters, ranges and POSIX
  classes (ASCII ranges) and re-emitted as a `system.regex` class with every
  member escaped. With `-i`, letters and the ASCII parts of ranges get their
  other case, and `[:upper:]`/`[:lower:]` match both cases.
- `\<`, `\>` become `\b`; `` \` `` and `\'` become `^` and `$`.

Several patterns are joined as `(?:P1)|(?:P2)|...`. Errors come back as
`Err(message)` with GNU's wording.

### Matcher

`build_matcher` compiles three expressions from the joined pattern `P`:

| Mode | Line test (`selects`) | `-o` parts (`matches`) |
|---|---|---|
| plain | `(?:P)` | `findAll` of `(?:P)` |
| `-x` | `^(?:P)$` | `findAll` of `^(?:P)$` |
| `-w` | `(?:^\|\W)(?:P)(?:\W\|$)` | repeated search, see below |

The `-w` line test is exact: the backtracking engine finds any match of `P`
with a non-word character (or the line edge) on both sides. For `-o -w` the
matches must not overlap their neighbours' boundary characters, and the
engine cannot search from an offset, so `Matcher` emulates one: to search
from scalar offset `k > 0` it runs `^(.*?\W)(P)(?:\W|$)` on
`line.substring(k - 1)` (one character of left context, so `\W`, `\b` and
`^` still see the real line); at `k = 0` it runs `^(.*?\W)??(P)(?:\W|$)` on
the line. Group 1's length gives the start of the match, group 2 its text.

### Search loop and context

`search_lines` walks the lines once. A selected line first flushes the
`ContextRing` (up to B earlier lines that were not printed) as context lines,
then prints itself, and sets an after-context counter to A. An unselected line
is printed as context while the counter is positive, otherwise pushed into the
ring, which keeps only the newest B lines. A separator `--` is printed before
a group whose first line is not adjacent to the last printed line; the caller
passes in whether anything was printed by earlier files, so separators also
appear between files. With `-o`, context lines are tracked but not printed.
For a binary input, the first selected line ends the search with
`binary = true`. With `-q`, `-l` and `-L` the search stops at the first
selected line.

### Inputs

Operands become `(path, label)` inputs: `-` is standard input
(`(standard input)`); a directory under `-r` expands with `io.fs.walk` (sorted,
files only) to `dir/rel`, or to `rel` for the implicit `.`. Files are read with
`readBytes` (standard input from `/dev/stdin`), checked by `is_binary` (a NUL
byte or invalid UTF-8) and decoded. Before reading, `run_grep` checks `exists`
and `isDir`, because native builds cannot catch the `IoError` of a failed read.

## Differences from the original

- Matching is leftmost-first (Perl style), not POSIX leftmost-longest. Line
  selection is the same; `-o` can print a shorter match when an alternation's
  earlier branch matches (`echo abcd | grep -oE 'ab|abcd'` prints `ab`).
- Back-references (`\1`...`\9`) are not supported (status 2); the engine has
  none.
- Character classes, `\w`, `-w` word characters and `-i` case folding of
  ranges and classes cover ASCII only (single non-ASCII letters do fold).
- No warnings for stray backslashes or leading `*`; `\d` and friends are
  literals, as in GNU grep.
- `-r` follows symbolic links and lists files in sorted order (GNU skips
  symlinks met during the walk and uses directory order). `-R` is the same as
  `-r`.
- A file that exists but cannot be read stops the program with
  `IoError: ...` and status 1 (the native runtime's read error cannot be
  caught); GNU reports it and goes on with status 2.
- With `-o -v` and context, GNU prints matches found in context lines; this
  version prints nothing for context lines under `-o`.
- Not implemented: `-f`, `-m`, `-b`, `-z`, `-a`/`-I`, `-T`, `-Z`, `--color`,
  `--include`/`--exclude`, `--label`, `--group-separator`, `-P`.
- `--version` prints a single line.

## Error handling

| Situation | Message (stderr) | Status |
|---|---|---|
| unknown/ambiguous option, missing or extra option argument | GNU text, `Usage:` line, `Try 'grep --help'...` | 2 |
| no pattern | `Usage:` line, `Try ...` | 2 |
| bad context length | `grep: N: invalid context length argument` | 2 |
| `-E` with `-F` etc. | `grep: conflicting matchers specified` | 2 |
| invalid pattern | `grep: Unmatched ( or \(` etc. | 2 |
| missing file, directory without `-r` | `grep: X: No such file or directory`, `grep: X: Is a directory` (not with `-s`) | 2 at the end, unless `-q` matched |
| binary file selected | `grep: X: binary file matches` | 0 |

An unexpected exception is reported as `grep: message` with status 2.

## Testing

- `tests/args_test.loup`: clusters, permutation, `--`, long options and
  prefixes, context numbers, every usage error.
- `tests/pattern_test.loup`: BRE/ERE/fixed translation, brackets, classes,
  `-i`, quantifier stacking, anchors, error messages; translated patterns run
  through `system.regex`.
- `tests/matcher_test.loup`: `selects` and `matches` for plain, `-w`, `-x`,
  `-i`, several patterns.
- `tests/context_test.loup`: the ring buffer.
- `tests/search_test.loup`: prefixes, `-v`, `-o`, context and separators,
  binary input, early stop.
- `tests/inputs_test.loup`: `split_lines`, `is_binary`, paths.
- `tests/app_test.loup`: exit statuses through `run()`.
- `tests/e2e.sh`: the native binary against fixtures in `tests/fixtures/` and
  files created under `$TMP`, comparing output and status.
