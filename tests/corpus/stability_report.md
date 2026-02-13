# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 1.779 | 8.563 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 3.884 | 9.964 | 14 |
| bash->zsh | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 2.842 | 4.262 | 9 |
| fish->bash | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 0 | 0 | 1.416 | 8.428 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 0 | 0 | 1.676 | 10.018 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 0 | 0 | 1.498 | 6.662 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 12/15 | 0 | 10/10 | 5/5 | 0 | 0 | 2.229 | 6.146 | 11 |
| zsh->fish | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 0 | 0 | 2.101 | 10.386 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 12/15 | 0 | 10/10 | 5/5 | 0 | 0 | 3.539 | 13.447 | 14 |

## Failures

- [FAIL] ohmyzsh-sudo (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=2 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 19: unexpected EOF while looking for matching `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=2 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 220: unexpected EOF while looking for matching `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] zsh-powerlevel10k (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=1 out_fn=12 msg= parser_msg=tests/corpus/.parser_check_zsh-powerlevel10k_91.bash: line 266: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-powerlevel10k_91.bash: line 266: `  typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale && { [[ -n $LC_ALL ]] && local LC_ALL=$__p9k_locale || local LC_CTYPE=$__p9k_locale; }''
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-powerlevel10k (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=1 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 472: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 472: `  typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale && { [[ -n $LC_ALL ]] && local LC_ALL=$__p9k_locale || local LC_CTYPE=$__p9k_locale; }''
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=0 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_103.bash: line 32: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-gnzh_103.bash: line 32: `ZSH_THEME_VIRTUALENV_PREFIX="%F{red}("'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=0 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 247: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 247: `ZSH_THEME_VIRTUALENV_PREFIX="%F{red}("'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme

## Parser Validation Failures

- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_16.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 19: unexpected EOF while looking for matching `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_18.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 220: unexpected EOF while looking for matching `}'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] zsh-powerlevel10k (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-powerlevel10k_91.bash` exit=2 message=tests/corpus/.parser_check_zsh-powerlevel10k_91.bash: line 266: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-powerlevel10k_91.bash: line 266: `  typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale && { [[ -n $LC_ALL ]] && local LC_ALL=$__p9k_locale || local LC_CTYPE=$__p9k_locale; }''
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-FAIL] zsh-powerlevel10k (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-powerlevel10k_93.sh` exit=2 message=tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 472: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 472: `  typeset -gr __p9k_intro_locale='[[ $langinfo[CODESET] != (utf|UTF)(-|)8 ]] && _p9k_init_locale && { [[ -n $LC_ALL ]] && local LC_ALL=$__p9k_locale || local LC_CTYPE=$__p9k_locale; }''
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-gnzh_103.bash` exit=2 message=tests/corpus/.parser_check_zsh-gnzh_103.bash: line 32: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-gnzh_103.bash: line 32: `ZSH_THEME_VIRTUALENV_PREFIX="%F{red}("'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-gnzh_105.sh` exit=2 message=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 247: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 247: `ZSH_THEME_VIRTUALENV_PREFIX="%F{red}("'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- No parser validation skips.

## High Warning Runs


## Warning Categories

- No warnings recorded.

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 12 | 0 | 12 | 14 | 4 | 0 |
| bash->posix | 16 | 12 | 0 | 0 | 0 | 0 | 0 |
| bash->zsh | 16 | 0 | 0 | 0 | 0 | 0 | 0 |
| fish->bash | 11 | 6 | 2 | 11 | 0 | 0 | 0 |
| fish->posix | 11 | 6 | 2 | 11 | 0 | 0 | 0 |
| fish->zsh | 11 | 6 | 3 | 11 | 0 | 0 | 0 |
| zsh->bash | 15 | 0 | 4 | 0 | 0 | 0 | 0 |
| zsh->fish | 15 | 15 | 4 | 15 | 14 | 1 | 0 |
| zsh->posix | 15 | 14 | 4 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.

## Semantic Differential Checks

Cases: 22, Passed: 22, Skipped: 0

### Semantic Pair Summary

| Pair | Cases | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| fish->bash | 4 | 4 | 0 | 0 |
| fish->posix | 1 | 1 | 0 | 0 |
| fish->zsh | 1 | 1 | 0 | 0 |
| zsh->fish | 4 | 4 | 0 | 0 |
| zsh->bash | 3 | 3 | 0 | 0 |
| zsh->posix | 1 | 1 | 0 | 0 |
| bash->fish | 3 | 3 | 0 | 0 |
| bash->zsh | 1 | 1 | 0 | 0 |
| posix->fish | 1 | 1 | 0 | 0 |
| posix->zsh | 1 | 1 | 0 | 0 |
| posix->bash | 1 | 1 | 0 | 0 |
| bash->posix | 1 | 1 | 0 | 0 |

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
- [PASS] plugin_ohmyzsh_z_zsh_to_bash zsh->bash exit=0 out="HAVE_z"
- [PASS] plugin_bashit_aliases_bash_to_posix bash->posix exit=0 out="HAVE_ALIAS_COMPLETION_CB"
- [PASS] plugin_fish_autopair_fish_to_bash fish->bash exit=0 out=""
