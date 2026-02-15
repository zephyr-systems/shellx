# ShellX Corpus Stability Report

Cases configured: 75

Cross-dialect runs executed: 3

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 1 | 1/1 | 1/1 | 0/1 | 0 | 1/1 | 0/0 | 0 | 0 | 3.267 | 12.500 | 1 |
| bash->posix | 1 | 1/1 | 1/1 | 1/1 | 0 | 1/1 | 0/0 | 0 | 0 | 9.313 | 19.000 | 1 |
| bash->zsh | 1 | 1/1 | 1/1 | 1/1 | 0 | 1/1 | 0/0 | 0 | 0 | 5.933 | 9.000 | 1 |

## Failures

- [FAIL] bashit-fzf (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=0(parse=0 compat=0) shims=4 src_fn=2 out_fn=25 msg= parser_msg=tests/corpus/.parser_check_bashit-fzf_2.fish (line 201): command substitutions not allowed in command position. Try var=(your-cmd) $var ...
	(__shellx_param_default EDITOR "vim") "$files"
	^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_bashit-fzf_2.fish
 parser_artifact=tests/corpus/.parser_check_bashit-fzf_2.fish path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash

## Parser Validation Failures

- [PARSER-FAIL] bashit-fzf (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-fzf_2.fish` exit=127 message=tests/corpus/.parser_check_bashit-fzf_2.fish (line 201): command substitutions not allowed in command position. Try var=(your-cmd) $var ...
	(__shellx_param_default EDITOR "vim") "$files"
	^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_bashit-fzf_2.fish
 parser_artifact=tests/corpus/.parser_check_bashit-fzf_2.fish path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- No parser validation skips.

## High Warning Runs


## Warning Categories

- No warnings recorded.

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 1 | 1 | 0 | 1 | 1 | 1 | 0 |
| bash->posix | 1 | 1 | 0 | 0 | 0 | 0 | 0 |
| bash->zsh | 1 | 0 | 0 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.

## Semantic Differential Checks

Cases: 0, Passed: 0, Skipped: 0

### Semantic Pair Summary

| Pair | Cases | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|

