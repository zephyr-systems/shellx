# ShellX Corpus Stability Report

Cases configured: 75

Cross-dialect runs executed: 6

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| posix->bash | 2 | 2/2 | 2/2 | 2/2 | 0 | 2/2 | 0/0 | 1 | 2 | 1.000 | 1.000 | 0 |
| posix->fish | 2 | 2/2 | 2/2 | 1/2 | 0 | 2/2 | 0/0 | 1 | 0 | 0.799 | 4.692 | 2 |
| posix->zsh | 2 | 2/2 | 2/2 | 2/2 | 0 | 2/2 | 0/0 | 1 | 2 | 1.000 | 0.000 | 0 |

## Failures

- [FAIL] autoconf-gendocs-sh (plugin) posix->fish translate=true parse=true parser=false/true exit=127 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=3 out_fn=21 msg= parser_msg=tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish (line 523): Unexpected end of string, quotes are not balanced
echo "Done, see $outdir/ subdirectory for new files."
                                                    ^
warning: Error while reading file tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish
 parser_artifact=tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish path=tests/corpus/repos/posix/autoconf/build-aux/gendocs.sh

## Parser Validation Failures

- [PARSER-FAIL] autoconf-gendocs-sh (plugin) posix->fish command=`fish --no-execute tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish` exit=127 message=tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish (line 523): Unexpected end of string, quotes are not balanced
echo "Done, see $outdir/ subdirectory for new files."
                                                    ^
warning: Error while reading file tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish
 parser_artifact=tests/corpus/.parser_check_autoconf-gendocs-sh_6.fish path=tests/corpus/repos/posix/autoconf/build-aux/gendocs.sh
- No parser validation skips.

## High Warning Runs


## Warning Categories


### posix->bash

- `parse_recovery/parse_diagnostic`: 1
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error
- `recovery_fallback/fallback`: 2
  - openrc-network-init (plugin) Applied POSIX preservation fallback due degraded translated output
  - autoconf-gendocs-sh (plugin) Applied POSIX preservation fallback due degraded translated output

### posix->fish

- `parse_recovery/parse_diagnostic`: 1
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error

### posix->zsh

- `parse_recovery/parse_diagnostic`: 1
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error
- `recovery_fallback/fallback`: 2
  - openrc-network-init (plugin) Applied POSIX preservation fallback due degraded translated output
  - autoconf-gendocs-sh (plugin) Applied POSIX preservation fallback due degraded translated output

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| posix->bash | 2 | 0 | 0 | 0 | 0 | 0 | 0 |
| posix->fish | 2 | 2 | 0 | 2 | 2 | 0 | 0 |
| posix->zsh | 2 | 0 | 0 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.
