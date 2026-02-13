# ShellX Corpus Stability Report

Cases configured: 55

Cross-dialect runs executed: 159

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.502 | 8.144 | 17 |
| bash->posix | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 4.515 | 9.431 | 16 |
| bash->zsh | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.628 | 4.097 | 10 |
| fish->bash | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.397 | 7.938 | 14 |
| fish->posix | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.741 | 9.539 | 14 |
| fish->zsh | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.445 | 6.801 | 14 |
| zsh->bash | 21 | 21/21 | 21/21 | 19/21 | 0 | 16/16 | 5/5 | 3 | 0 | 2.063 | 5.185 | 13 |
| zsh->fish | 21 | 21/21 | 21/21 | 19/21 | 0 | 16/16 | 5/5 | 3 | 0 | 9.068 | 9.474 | 21 |
| zsh->posix | 21 | 21/21 | 21/21 | 19/21 | 0 | 16/16 | 5/5 | 3 | 0 | 3.020 | 11.951 | 17 |

## Failures

- [FAIL] zsh-you-should-use (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=10 out_fn=24 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 479: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 479: `}'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 190): Missing end to balance this function definition
function check_alias_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=41 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 635: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 635: `}'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=2 src_fn=14 out_fn=35 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_40.bash: line 558: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 558: `done'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=3 compat=0) shims=4 src_fn=14 out_fn=38 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_41.fish (line 245): Missing end to balance this switch statement
	    switch $argv[1]
	    ^~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-nvm_41.fish
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=5 src_fn=14 out_fn=43 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_42.sh: line 714: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 714: `done'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh

## Parser Validation Failures

- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_37.bash` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 479: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 479: `}'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-you-should-use_38.fish` exit=127 message=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 190): Missing end to balance this function definition
function check_alias_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_39.sh` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 635: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 635: `}'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-nvm_40.bash` exit=2 message=tests/corpus/.parser_check_zsh-nvm_40.bash: line 558: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 558: `done'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-nvm_41.fish` exit=127 message=tests/corpus/.parser_check_zsh-nvm_41.fish (line 245): Missing end to balance this switch statement
	    switch $argv[1]
	    ^~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-nvm_41.fish
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-nvm_42.sh` exit=2 message=tests/corpus/.parser_check_zsh-nvm_42.sh: line 714: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 714: `done'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- No parser validation skips.

## High Warning Runs


## Warning Categories


### fish->bash

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->posix

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->zsh

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### zsh->bash

- `parse_recovery/parse_diagnostic`: 3
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed

### zsh->fish

- `parse_recovery/parse_diagnostic`: 3
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed

### zsh->posix

- `parse_recovery/parse_diagnostic`: 3
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 14 | 0 | 14 | 16 | 4 | 0 |
| bash->posix | 18 | 14 | 0 | 0 | 0 | 0 | 0 |
| bash->zsh | 18 | 0 | 0 | 0 | 0 | 0 | 0 |
| fish->bash | 14 | 9 | 3 | 14 | 0 | 0 | 0 |
| fish->posix | 14 | 8 | 3 | 14 | 0 | 0 | 0 |
| fish->zsh | 14 | 9 | 4 | 14 | 0 | 0 | 0 |
| zsh->bash | 21 | 0 | 6 | 0 | 0 | 0 | 0 |
| zsh->fish | 21 | 18 | 6 | 18 | 20 | 1 | 0 |
| zsh->posix | 21 | 17 | 6 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.
