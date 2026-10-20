# Tasks: grep

- [x] 1. Parse GNU grep's command line (clusters, permutation, long options and prefixes, `-NUM`, `-e`, context numbers, usage errors)
  - _Requirements: 1.3, 2.1, 4.3, 4.4, 6.1, 6.2, 6.3_
- [x] 2. Translate BRE, ERE and fixed strings into `system.regex` syntax, with `-i`, bracket expressions, classes and GNU error messages
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 1.6_
- [x] 3. Build the matcher: several patterns, `-w`, `-x`, `-o` parts
  - _Requirements: 1.1, 1.2, 1.7, 1.8, 3.4_
- [x] 4. Search loop with prefixes, `-v`, `-o`, context ring buffer and separators
  - _Requirements: 1.5, 3.1, 3.2, 3.3, 3.4, 4.1, 4.2_
- [x] 5. Inputs: standard input, files, `-r` walk, binary detection, missing files and directories, `-s`
  - _Requirements: 1.4, 1.9, 3.8, 5.1, 5.2, 5.3, 5.4_
- [x] 6. Output modes `-c`, `-l`, `-L`, `-q` and the exit status
  - _Requirements: 3.5, 3.6, 3.7, 6.4_
- [x] 7. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
