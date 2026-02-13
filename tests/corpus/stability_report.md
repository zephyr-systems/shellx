# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 1 | 42 | 1.625 | 8.235 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.713 | 4.659 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.346 | 0.945 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 19 | 1.012 | 7.679 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.954 | 7.225 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/11 | 0 | 10/10 | 1/1 | 1 | 19 | 1.004 | 5.346 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 4 | 0.817 | 1.949 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 58 | 1.854 | 9.812 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 22 | 1.257 | 6.342 | 14 |

## Failures

- [FAIL] fish-tide-theme (theme) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=3 out_fn=29 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_122.zsh:297: parse error near `:'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish

## Parser Validation Failures

- [PARSER-FAIL] fish-tide-theme (theme) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-tide-theme_122.zsh` exit=1 message=tests/corpus/.parser_check_fish-tide-theme_122.zsh:297: parse error near `:'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- No parser validation skips.

## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=36 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 12 | 0 | 12 | 14 | 4 | 0 |
| bash->posix | 16 | 12 | 0 | 0 | 0 | 0 | 0 |
| bash->zsh | 16 | 0 | 0 | 0 | 0 | 0 | 0 |
| fish->bash | 11 | 6 | 2 | 11 | 0 | 0 | 0 |
| fish->posix | 11 | 5 | 2 | 11 | 0 | 0 | 0 |
| fish->zsh | 11 | 6 | 2 | 11 | 0 | 0 | 0 |
| zsh->bash | 15 | 0 | 4 | 0 | 0 | 0 | 0 |
| zsh->fish | 15 | 15 | 4 | 15 | 14 | 1 | 0 |
| zsh->posix | 15 | 14 | 4 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.

## Semantic Differential Checks

Cases: 19, Passed: 19, Skipped: 0

### Semantic Pair Summary

| Pair | Cases | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| fish->bash | 3 | 3 | 0 | 0 |
| fish->posix | 1 | 1 | 0 | 0 |
| fish->zsh | 1 | 1 | 0 | 0 |
| zsh->fish | 4 | 4 | 0 | 0 |
| zsh->bash | 2 | 2 | 0 | 0 |
| zsh->posix | 1 | 1 | 0 | 0 |
| bash->fish | 3 | 3 | 0 | 0 |
| bash->zsh | 1 | 1 | 0 | 0 |
| posix->fish | 1 | 1 | 0 | 0 |
| posix->zsh | 1 | 1 | 0 | 0 |
| posix->bash | 1 | 1 | 0 | 0 |

- [PASS] fish_gitnow_branch_compare fish->bash exit=0 out="SAME"
- [PASS] fish_list_index_bash fish->bash exit=0 out="two"
- [PASS] fish_list_index_posix fish->posix exit=0 out="green"
- [PASS] fish_string_match_zsh fish->zsh exit=0 out="ok"
- [PASS] fish_string_match_bash fish->bash exit=0 out="hit"
- [PASS] zsh_git_cmdsub_if_compare zsh->fish exit=0 out="ok"
- [PASS] zsh_param_default_callsite zsh->fish exit=0 out="/tmp/cache"
- [PASS] zsh_repo_root_cmdsub zsh->fish exit=0 out="/tmp/repo"
- [PASS] zsh_param_default_bash zsh->bash exit=0 out="fallback"
- [PASS] zsh_assoc_array_bash zsh->bash exit=0 out="bar"
- [PASS] zsh_case_posix zsh->posix exit=0 out="yes"
- [PASS] zsh_positional_fish zsh->fish exit=0 out="a-b"
- [PASS] bash_array_fish bash->fish exit=0 out="two"
- [PASS] bash_cond_fish bash->fish exit=0 out="ok"
- [PASS] bash_param_default_fish bash->fish exit=0 out="fallback"
- [PASS] bash_function_zsh bash->zsh exit=0 out="done"
- [PASS] posix_if_fish posix->fish exit=0 out="one"
- [PASS] posix_default_zsh posix->zsh exit=0 out="alt"
- [PASS] posix_case_bash posix->bash exit=0 out="match"
