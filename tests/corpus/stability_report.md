# ShellX Corpus Stability Report

Cases configured: 55

Cross-dialect runs executed: 159

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.502 | 8.144 | 17 |
| bash->posix | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 4.515 | 9.431 | 16 |
| bash->zsh | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.628 | 4.097 | 10 |
| fish->bash | 14 | 14/14 | 14/14 | 13/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.397 | 7.866 | 14 |
| fish->posix | 14 | 14/14 | 14/14 | 13/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.741 | 9.467 | 14 |
| fish->zsh | 14 | 14/14 | 14/14 | 13/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.445 | 6.729 | 14 |
| zsh->bash | 21 | 21/21 | 21/21 | 15/21 | 0 | 16/16 | 5/5 | 3 | 0 | 2.063 | 5.141 | 13 |
| zsh->fish | 21 | 21/21 | 21/21 | 21/21 | 0 | 16/16 | 5/5 | 3 | 0 | 9.021 | 9.474 | 21 |
| zsh->posix | 21 | 21/21 | 21/21 | 15/21 | 0 | 16/16 | 5/5 | 3 | 0 | 3.020 | 11.947 | 17 |

## Failures

- [FAIL] zsh-autosuggestions (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=30 out_fn=36 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 549: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 549: `fi'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-autosuggestions (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=30 out_fn=42 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 591: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 591: `fi'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=9 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 918: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 918: `fi'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=9 out_fn=46 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 1053: syntax error: unexpected end of file from `{' command on line 723
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=0 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=1 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 293: syntax error: unexpected end of file from `{' command on line 286
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=1 out_fn=31 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 491: syntax error: unexpected end of file from `{' command on line 484
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=0 out_fn=12 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash: line 251: syntax error: unexpected end of file from `{' command on line 235
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=0 out_fn=31 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh: line 458: syntax error: unexpected end of file from `{' command on line 445
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=2 src_fn=14 out_fn=34 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_40.bash: line 557: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 557: `}'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=5 src_fn=14 out_fn=50 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_42.sh: line 713: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 713: `}'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] fish-replay (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_fish-replay_97.bash: line 149: syntax error: unexpected end of file from `{' command on line 144
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_fish-replay_98.zsh:137: parse error near `:'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=23 msg= parser_msg=tests/corpus/.parser_check_fish-replay_99.sh: line 272: syntax error: unexpected end of file from `{' command on line 267
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish

## Parser Validation Failures

- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_1.bash` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 549: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 549: `fi'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_3.sh` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 591: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 591: `fi'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 918: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 918: `fi'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 1053: syntax error: unexpected end of file from `{' command on line 723
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_19.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_21.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 293: syntax error: unexpected end of file from `{' command on line 286
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 491: syntax error: unexpected end of file from `{' command on line 484
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-copyfile (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash: line 251: syntax error: unexpected end of file from `{' command on line 235
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-FAIL] ohmyzsh-copyfile (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh: line 458: syntax error: unexpected end of file from `{' command on line 445
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-nvm_40.bash` exit=2 message=tests/corpus/.parser_check_zsh-nvm_40.bash: line 557: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 557: `}'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-nvm_42.sh` exit=2 message=tests/corpus/.parser_check_zsh-nvm_42.sh: line 713: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 713: `}'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] fish-replay (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-replay_97.bash` exit=2 message=tests/corpus/.parser_check_fish-replay_97.bash: line 149: syntax error: unexpected end of file from `{' command on line 144
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-replay_98.zsh` exit=1 message=tests/corpus/.parser_check_fish-replay_98.zsh:137: parse error near `:'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-replay_99.sh` exit=2 message=tests/corpus/.parser_check_fish-replay_99.sh: line 272: syntax error: unexpected end of file from `{' command on line 267
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
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
