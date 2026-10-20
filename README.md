# loup-cmd-grep

GNU `grep` recreated in [Loup](https://code-craft.ai/references/loup): print
the lines that match patterns, with basic, extended and fixed-string patterns,
`-o`, counts, file lists, context lines, recursive search and GNU's 0/1/2 exit
statuses.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary. Matching uses the
standard library's `system.regex`; grep's POSIX syntax is translated into it.

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. The full release is at
<https://code-craft.ai/loup/download>, and commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                                    # native binary: build/grep
make ci                                       # check, unit tests, build, end-to-end tests
make run ARGS="-n main source/main.loup"      # run from source with loup run
```

```text
$ build/grep -n foo tests/fixtures/poem.txt
3:Foo fighters: foo, FOO and foobar
7:end of foo
$ build/grep -i -o 'FOO\w*' tests/fixtures/poem.txt
Foo
foo
FOO
foobar
foo
$ build/grep -E -w 'lazy|quick' tests/fixtures/poem.txt
The quick brown fox
jumps over the lazy dog.
$ build/grep -c -v foo tests/fixtures/poem.txt
5
$ build/grep -rn foo tests/fixtures/tree
tests/fixtures/tree/a.txt:2:foo in a
tests/fixtures/tree/sub/deeper/c.txt:1:deep foo
tests/fixtures/tree/sub/deeper/c.txt:2:foo again
$ build/grep -C1 -n '^4$' <(seq 1 9)
3-3
4:4
5-5
$ build/grep 'a\(' tests/fixtures/poem.txt; echo "exit $?"
grep: Unmatched ( or \(
exit 2
$ build/grep --version
grep (loup-cmd-grep) 0.1.0
```

`grep [OPTION]... PATTERNS [FILE]...`. PATTERNS may hold several patterns
separated by newlines. With no FILE, or with `-`, grep reads standard input;
with `-r` and no FILE it searches `.`.

| Option | Meaning |
|---|---|
| `-G`, `-E`, `-F` | basic regexps (default), extended regexps, fixed strings |
| `-e PATTERNS`, `--regexp` | patterns (repeatable); every operand is then a FILE |
| `-i`, `--no-ignore-case` | ignore case / do not |
| `-v` | select non-matching lines |
| `-w`, `-x` | match whole words / whole lines |
| `-n` | prefix line numbers |
| `-H`, `-h` | always / never prefix file names (default: when several files) |
| `-o` | print only the matched parts |
| `-c` | print a count of selected lines per file |
| `-l`, `-L` | print only names of files with / without selected lines |
| `-q` | print nothing; exit 0 at the first selected line |
| `-s` | no messages about missing files and directories |
| `-r`, `-R` | search directories recursively |
| `-A N`, `-B N`, `-C N`, `-N` | context lines after / before / around matches |
| `--help`, `-V`, `--version` | help text, version line |

Options can be combined (`-inr`, `-A2`, `-efoo`), may follow the operands
(`grep foo file -n`), and long options can be shortened to any unambiguous
prefix (`--ext`). `--` ends the options.

Exit status: `0` if a line was selected, `1` if none was, `2` on an error
(bad option or pattern, missing file, directory without `-r`), unless `-q`
was given and a line was selected.

## Differences from GNU grep

- Matching is leftmost-first (Perl style) rather than POSIX leftmost-longest.
  Which lines match is the same; `-o` can print a shorter match when an
  earlier alternative matches (`echo abcd | grep -oE 'ab|abcd'` prints `ab`).
- Back-references (`\1` to `\9`) are not supported: grep exits with status 2.
  `system.regex` has none.
- Bracket classes such as `[[:alpha:]]`, `\w`, the word characters of `-w`,
  and `-i` on ranges and classes cover ASCII only (single non-ASCII letters
  such as `é` do match case-insensitively).
- No warnings for stray backslashes or a leading `*`; `\d` and other unknown
  escapes are plain letters, as in GNU grep.
- `-r` follows symbolic links and visits files in sorted order (GNU grep skips
  links found while recursing and uses directory order); `-R` is the same as
  `-r`.
- A file that exists but cannot be read (no permission) stops grep with
  `IoError: ... Permission denied` and status 1, where GNU grep reports it and
  goes on (status 2): the native runtime's read error cannot be caught.
- Under `-o -v` with context, GNU grep prints matches from context lines;
  this version prints nothing for them.
- Not implemented: `-f`, `-m`, `-b`, `-z`, `-a`/`-I`, `-T`, `-Z`, `--color`,
  `--include`/`--exclude`, `--label`, `--group-separator`, `-P`.
- `--help` lists only the options above; `--version` prints a single line.

## Layout

```text
source/main.loup               # entry point
source/appinfo.loup            # name, version, exit statuses 0/1/2
source/cli/args.loup           # GNU getopt_long-style option parsing
source/cli/usage.loup          # --help and --version text
source/cli/app.loup            # run(): parse, usage errors, exit status
source/commands/pattern.loup   # BRE / ERE / fixed string -> system.regex syntax
source/commands/matcher.loup   # compiled patterns, -w / -x / -o matching
source/commands/context.loup   # ring buffer for -B context lines
source/commands/search.loup    # the per-file search loop
source/commands/inputs.loup    # lines, binary detection, paths
source/commands/grep.loup      # operands, recursion, printing
tests/*_test.loup              # unit tests (make test)
tests/e2e.sh                   # end-to-end tests of build/grep (make e2e)
tests/fixtures/                # files the end-to-end tests search
specs/grep/                    # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
