# Requirements: grep

## Introduction

`grep` searches files (or standard input) for lines that match one or more
patterns and prints them. This repository recreates the everyday core of GNU
grep 3.11 in Loup: basic, extended and fixed-string patterns, the common
output modes, context lines, recursive search and GNU's 0/1/2 exit statuses.
Matching uses the standard library's `system.regex` engine; grep's POSIX
pattern syntax is translated into that engine's syntax.

## Requirements

### Requirement 1: Selecting lines

**User Story:** As a shell user, I want the lines that match a pattern so that
I can find text in files.

#### Acceptance Criteria

1. WHEN grep is run as `grep [OPTION]... PATTERNS [FILE]...`, THE program SHALL
   print every line of each FILE that matches any of the PATTERNS.
2. WHEN PATTERNS contains newlines, THE program SHALL treat each line of it as
   a separate pattern; an empty pattern SHALL match every line.
3. WHEN `-e PATTERNS` is given (repeatable, also `--regexp`), THE program SHALL
   use those patterns and treat every operand as a FILE.
4. WHEN no FILE is given (and `-r` is not), or a FILE is `-`, THE program SHALL
   read standard input and call it `(standard input)`.
5. WHEN `-v` is given, THE program SHALL select the lines that do not match.
6. WHEN `-i` is given, THE program SHALL ignore case in patterns and data.
7. WHEN `-w` is given, THE program SHALL select only lines with a match that is
   preceded and followed by a non-word character or the line edge.
8. WHEN `-x` is given, THE program SHALL select only lines matched as a whole;
   `-x` SHALL take precedence over `-w`.
9. WHEN the last line of the input has no newline, THE program SHALL still
   treat it as a line and end its output line with a newline.

### Requirement 2: Pattern syntax

**User Story:** As a grep user, I want GNU's pattern dialects so that my
existing patterns keep working.

#### Acceptance Criteria

1. THE program SHALL interpret patterns as basic regular expressions (BRE) by
   default or with `-G`, as extended regular expressions (ERE) with `-E`, and
   as fixed strings with `-F`; two different ones SHALL be rejected with
   `conflicting matchers specified` and status 2.
2. In a BRE, THE program SHALL support `.`, `*`, `^` and `$` (anchors only at
   the start and end of the pattern or a group), bracket expressions, `\(\)`,
   `\{m,n\}`, and the GNU extensions `\|`, `\+` and `\?`; `( ) { } | + ?` SHALL
   be literal.
3. In an ERE, THE program SHALL support `( ) { } | + ? *`, with an unmatched `)`
   and an invalid `{` taken literally and a leading quantifier ignored.
4. THE program SHALL support bracket expressions with ranges, negation, a
   leading `]`, and the classes `[:alpha:] [:digit:] [:alnum:] [:upper:]
   [:lower:] [:space:] [:blank:] [:punct:] [:print:] [:graph:] [:cntrl:]
   [:xdigit:]`; a backslash inside brackets SHALL be literal.
5. THE program SHALL support the escapes `\w \W \s \S \b \B \< \>`, and treat
   a backslash before any other character as that character.
6. WHEN a pattern is invalid (unmatched `(`, `[` or `\{`, a trailing backslash,
   an unknown class name, `[:space:]` outside brackets), THE program SHALL
   print GNU's message and exit with status 2.
7. WHEN a pattern contains a back-reference (`\1` to `\9`), THE program SHALL
   report that back-references are not supported and exit with status 2.

### Requirement 3: Output modes

**User Story:** As a script author, I want counts, file names and quiet
checks so that I can use grep in pipelines and conditions.

#### Acceptance Criteria

1. WHEN `-n` is given, THE program SHALL prefix each output line with its line
   number.
2. WHEN more than one FILE is searched, or `-r` searches a directory, THE
   program SHALL prefix output lines with the file name; `-H` and `-h` SHALL
   force and suppress the prefix (the last one given wins).
3. THE prefix separator SHALL be `:` for selected lines and `-` for context
   lines.
4. WHEN `-o` is given, THE program SHALL print each non-empty match of a
   selected line on its own line instead of the line.
5. WHEN `-c` is given, THE program SHALL print the number of selected lines
   per file instead of the lines.
6. WHEN `-l` (or `-L`) is given, THE program SHALL print only the names of the
   files with (or without) a selected line; the last of the two wins and both
   override `-c`.
7. WHEN `-q` is given, THE program SHALL print nothing and exit with status 0
   at the first selected line.
8. WHEN a file contains a NUL byte or is not valid UTF-8 and a line of it is
   selected, THE program SHALL print `grep: FILE: binary file matches` on
   standard error instead of its lines (counts, names and `-q` are unaffected).

### Requirement 4: Context

**User Story:** As a reader of search results, I want lines around each match
so that I can see it in context.

#### Acceptance Criteria

1. WHEN `-A N`, `-B N` or `-C N` (also `-NUM`) is given, THE program SHALL print
   N lines after, before, or both around each selected line, each line at
   most once.
2. WHEN a group of output lines is not adjacent to the previous group (in the
   same or an earlier file), THE program SHALL print `--` between them.
3. WHEN both `-C` and `-A`/`-B` are given, `-A`/`-B` SHALL take precedence.
4. WHEN N is not a non-negative integer, THE program SHALL print
   `grep: N: invalid context length argument` and exit with status 2.

### Requirement 5: Files and recursion

**User Story:** As a developer, I want to search a whole tree so that I can
find code without listing files.

#### Acceptance Criteria

1. WHEN `-r` (or `-R`) is given, THE program SHALL search every file under each
   directory operand, in sorted path order; with no operand it SHALL search
   `.` and print paths relative to it.
2. WHEN a directory operand is given without `-r`, THE program SHALL print
   `grep: DIR: Is a directory` and remember the error.
3. WHEN a FILE does not exist, THE program SHALL print
   `grep: FILE: No such file or directory`, remember the error and continue.
4. WHEN `-s` is given, THE program SHALL not print the messages of 5.2 and 5.3.

### Requirement 6: Command line and exit status

**User Story:** As a shell user, I want GNU's option syntax and exit statuses
so that grep fits existing scripts.

#### Acceptance Criteria

1. THE program SHALL accept options anywhere before `--`, combined short
   options (`-inr`, `-A3`, `-efoo`), long options with `=VALUE` or a separate
   value, and unambiguous prefixes of long options.
2. WHEN an option is unknown, ambiguous, lacks its argument or has an
   unexpected one, or no pattern is given, THE program SHALL print the GNU
   message, `Usage: grep [OPTION]... PATTERNS [FILE]...` and
   `Try 'grep --help' for more information.` on standard error and exit with
   status 2.
3. WHEN `--help` or `--version` (`-V`) is given, THE program SHALL print the
   help text or `grep (loup-cmd-grep) 0.1.0` and exit with status 0.
4. THE exit status SHALL be 0 if any line was selected, 1 if none was, and 2
   if an error occurred, unless `-q` was given and a line was selected.
