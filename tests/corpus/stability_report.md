# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 42 | 1.556 | 8.235 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.641 | 4.003 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.346 | 0.945 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 19 | 0.985 | 7.134 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.926 | 6.771 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 19 | 1.011 | 3.930 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 4 | 0.802 | 1.949 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 12/15 | 0 | 10/10 | 5/5 | 76 | 58 | 1.783 | 9.796 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 22 | 1.144 | 5.516 | 14 |

## Failures

- [FAIL] ohmyzsh-git (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=16 out_fn=32 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_8.fish (line 184): Missing end to balance this function definition
function gunwipall
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-git_8.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] zsh-powerlevel10k (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=8(parse=4 compat=4) shims=4 src_fn=1 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_zsh-powerlevel10k_92.fish (line 180): Unexpected end of string, expecting ')'
  set -g __p9k_dump_file (__shellx_param_default; set -g XDG_CACHE_HOME ""
                         ^
warning: Error while reading file tests/corpus/.parser_check_zsh-powerlevel10k_92.fish
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=14 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_95.fish (line 154): Missing end to balance this function definition
function git_toplevel
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-agnoster_95.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme

## Parser Validation Failures

- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-git_8.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-git_8.fish (line 184): Missing end to balance this function definition
function gunwipall
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-git_8.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-FAIL] zsh-powerlevel10k (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-powerlevel10k_92.fish` exit=127 message=tests/corpus/.parser_check_zsh-powerlevel10k_92.fish (line 180): Unexpected end of string, expecting ')'
  set -g __p9k_dump_file (__shellx_param_default; set -g XDG_CACHE_HOME ""
                         ^
warning: Error while reading file tests/corpus/.parser_check_zsh-powerlevel10k_92.fish
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-agnoster_95.fish` exit=127 message=tests/corpus/.parser_check_zsh-agnoster_95.fish (line 154): Missing end to balance this function definition
function git_toplevel
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-agnoster_95.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- No parser validation skips.

## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=36 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Validator Rule Failures

- No validator rule failures.
