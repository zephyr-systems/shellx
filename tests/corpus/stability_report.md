# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 0/16 | 16 | 10/10 | 6/6 | 0 | 42 | 0.702 | 2.638 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 5/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.434 | 1.258 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 11/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.392 | 0.545 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 0/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.540 | 2.449 | 10 |
| fish->posix | 11 | 11/11 | 11/11 | 0/11 | 0 | 10/10 | 1/1 | 1 | 17 | 0.525 | 2.403 | 10 |
| fish->zsh | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.541 | 2.449 | 10 |
| zsh->bash | 15 | 15/15 | 15/15 | 9/15 | 0 | 10/10 | 5/5 | 76 | 4 | 0.989 | 1.470 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 0/15 | 15 | 10/10 | 5/5 | 76 | 58 | 1.174 | 2.971 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 2/15 | 0 | 10/10 | 5/5 | 76 | 22 | 0.991 | 1.625 | 14 |

## Failures

- [FAIL] zsh-autosuggestions (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=10(parse=4 compat=6) shims=6 src_fn=30 out_fn=17 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-autosuggestions (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=30 out_fn=24 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 85: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 85: `			user:_zsh_autosuggest_(bound|orig)_*)'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=12(parse=6 compat=6) shims=6 src_fn=9 out_fn=11 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=6 compat=3) shims=3 src_fn=9 out_fn=7 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 135: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 135: `	    () {'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=4(parse=4 compat=0) shims=0 src_fn=16 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 429: syntax error near unexpected token `new_name'
tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 429: `for old_name new_name ('
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=16 out_fn=6 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=16 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 389: syntax error near unexpected token `new_name'
tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 389: `for old_name new_name ('
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=12 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=17(parse=14 compat=3) shims=3 src_fn=14 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: syntax error near `(c'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: `	  if [[ $OSTYPE == (cygwin|msys) ]]; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-fzf (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=17(parse=14 compat=3) shims=3 src_fn=9 out_fn=7 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [FAIL] ohmyzsh-fzf (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=15(parse=14 compat=1) shims=1 src_fn=9 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 233: warning: here-document at line 209 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 234: syntax error: unexpected end of file from `{' command on line 208
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=9 compat=0) shims=0 src_fn=2 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=12(parse=9 compat=3) shims=3 src_fn=2 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=10(parse=9 compat=1) shims=1 src_fn=2 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=0 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=0 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 53: syntax error near unexpected token `;;'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 53: `        (( $+commands[pigz] )) && { tar -I pigz -xvf "$full_path" } || tar zxvf "$full_path" ;;'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=4(parse=4 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=8(parse=4 compat=4) shims=4 src_fn=1 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 101: syntax error near unexpected token `;'
tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 101: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=5(parse=0 compat=5) shims=5 src_fn=1 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 112: syntax error near unexpected token `;'
tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 112: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=0 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] bashit-git (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=12 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [FAIL] bashit-git (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=12 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_bashit-git_33.sh: line 42: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-git_33.sh: line 42: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [FAIL] bashit-aliases (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=1 out_fn=8 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [FAIL] bashit-aliases (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-aliases_36.sh: line 25: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-aliases_36.sh: line 25: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [FAIL] bashit-completion (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=2 out_fn=8 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [FAIL] bashit-completion (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-completion_39.sh: line 26: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-completion_39.sh: line 26: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [FAIL] bashit-base (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=15 out_fn=10 msg= parser_msg=tests/corpus/.parser_check_bashit-base_40.zsh:25: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=15 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=15 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_bashit-base_42.sh: line 15: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-base_42.sh: line 15: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-fzf (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=2 out_fn=8 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [FAIL] bashit-fzf (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-fzf_45.sh: line 19: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-fzf_45.sh: line 19: `	while ; do'
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [FAIL] bashit-tmux (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=0 out_fn=0 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/tmux.plugin.bash
- [FAIL] bashit-history (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/history.plugin.bash
- [FAIL] bashit-ssh (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=3 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/ssh.plugin.bash
- [FAIL] bashit-docker (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=8 out_fn=11 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [FAIL] bashit-docker (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=8 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_bashit-docker_57.sh: line 43: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-docker_57.sh: line 43: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [FAIL] bashit-general (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-general (plugin) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=1 out_fn=6 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-general (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-general_60.sh: line 14: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-general_60.sh: line 14: `	done'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] fish-z (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=4 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_fish-z_61.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-z_61.bash: line 42: `}'
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [FAIL] fish-z (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=4 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_fish-z_63.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-z_63.sh: line 42: `}'
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [FAIL] fish-fzf (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-fzf_64.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fzf_64.bash: line 42: `}'
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [FAIL] fish-fzf (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-fzf_66.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fzf_66.sh: line 42: `}'
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [FAIL] fish-tide (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=3 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-tide_67.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide_67.bash: line 42: `}'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [FAIL] fish-tide (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=3 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-tide_69.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide_69.sh: line 42: `}'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [FAIL] fish-done (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=10 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_fish-done_70.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-done_70.bash: line 103: `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-done (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=10 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_fish-done_72.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-done_72.sh: line 106: `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-replay (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-replay_73.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 48: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-replay_75.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 51: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-spark (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_fish-spark_76.bash: line 2: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-spark_76.bash: line 2: `}'
 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [FAIL] fish-spark (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_fish-spark_78.sh: line 2: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-spark_78.sh: line 2: `}'
 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [FAIL] fish-autopair (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=1 compat=2) shims=2 src_fn=2 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-autopair_79.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-autopair_79.bash: line 48: `}'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [FAIL] fish-autopair (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=2 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-autopair_81.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-autopair_81.sh: line 42: `}'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [FAIL] fish-colored-man-pages (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 42: `}'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [FAIL] fish-colored-man-pages (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 42: `}'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [FAIL] fish-gitnow (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=25 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-gitnow_85.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-gitnow_85.bash: line 48: `}'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [FAIL] fish-gitnow (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=25 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-gitnow_87.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-gitnow_87.sh: line 51: `}'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [FAIL] fish-fisher (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-fisher_88.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fisher_88.bash: line 48: `}'
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [FAIL] fish-fisher (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-fisher_90.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fisher_90.sh: line 51: `}'
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [FAIL] zsh-powerlevel10k (theme) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=8(parse=4 compat=4) shims=4 src_fn=1 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-powerlevel10k (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 56: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 56: `() {'
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=14 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=14 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 62: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 62: `	  () {'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-eastwood (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-eastwood_97.bash: line 4: syntax error near unexpected token `;'
tests/corpus/.parser_check_zsh-eastwood_97.bash: line 4: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [FAIL] zsh-eastwood (theme) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [FAIL] zsh-eastwood (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-eastwood_99.sh: line 4: syntax error near unexpected token `;'
tests/corpus/.parser_check_zsh-eastwood_99.sh: line 4: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [FAIL] zsh-spaceship (theme) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=18(parse=14 compat=4) shims=4 src_fn=1 out_fn=10 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=0 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 13: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 13: `() {'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] bashit-bobby-theme (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=2 out_fn=6 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [FAIL] bashit-bobby-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 14: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 14: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=22 out_fn=6 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 17: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 17: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=22 out_fn=6 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 17: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 17: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-candy-theme (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/candy/candy.theme.bash
- [FAIL] bashit-envy-theme (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/envy/envy.theme.bash
- [FAIL] fish-tide-theme (theme) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=4 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-tide-theme (theme) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=4 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-starship-init (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=21 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_124.zsh:151: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [FAIL] fish-starship-init (theme) bash->fish translate=true parse=true parser=false/false exit=-1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=21 out_fn=5 msg= parser_msg=parser execution error: Not_Exist path=tests/corpus/repos/fish/starship/install/install.sh
- [FAIL] fish-starship-init (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=21 out_fn=21 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_126.sh: line 33: syntax error near unexpected token `;'
tests/corpus/.parser_check_fish-starship-init_126.sh: line 33: `	if ; then'
 path=tests/corpus/repos/fish/starship/install/install.sh

## Parser Validation Failures

- [PARSER-SKIP] zsh-autosuggestions (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-autosuggestions_2.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_3.sh` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 85: syntax error near unexpected token `('
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 85: `			user:_zsh_autosuggest_(bound|orig)_*)'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-SKIP] zsh-syntax-highlighting (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 135: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 135: `	    () {'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-git_7.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 429: syntax error near unexpected token `new_name'
tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 429: `for old_name new_name ('
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-SKIP] ohmyzsh-git (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-git_8.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-git_9.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 389: syntax error near unexpected token `new_name'
tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 389: `for old_name new_name ('
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-SKIP] ohmyzsh-z (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-z_11.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_12.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: syntax error near `(c'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 512: `	  if [[ $OSTYPE == (cygwin|msys) ]]; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-SKIP] ohmyzsh-fzf (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-fzf_14.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [PARSER-FAIL] ohmyzsh-fzf (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-fzf_15.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 233: warning: here-document at line 209 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 234: syntax error: unexpected end of file from `{' command on line 208
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_16.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-SKIP] ohmyzsh-sudo (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-sudo_17.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_18.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_19.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-SKIP] ohmyzsh-extract (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-extract_20.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_21.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 53: syntax error near unexpected token `;;'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 53: `        (( $+commands[pigz] )) && { tar -I pigz -xvf "$full_path" } || tar zxvf "$full_path" ;;'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-SKIP] ohmyzsh-colored-man-pages (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-web-search (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-web-search_25.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 101: syntax error near unexpected token `;'
tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 101: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-SKIP] ohmyzsh-web-search (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-web-search_26.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-FAIL] ohmyzsh-web-search (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-web-search_27.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 112: syntax error near unexpected token `;'
tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 112: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-SKIP] ohmyzsh-copyfile (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-SKIP] bashit-git (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-git_32.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [PARSER-FAIL] bashit-git (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-git_33.sh` exit=2 message=tests/corpus/.parser_check_bashit-git_33.sh: line 42: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-git_33.sh: line 42: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [PARSER-SKIP] bashit-aliases (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-aliases_35.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [PARSER-FAIL] bashit-aliases (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-aliases_36.sh` exit=2 message=tests/corpus/.parser_check_bashit-aliases_36.sh: line 25: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-aliases_36.sh: line 25: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [PARSER-SKIP] bashit-completion (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-completion_38.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [PARSER-FAIL] bashit-completion (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-completion_39.sh` exit=2 message=tests/corpus/.parser_check_bashit-completion_39.sh: line 26: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-completion_39.sh: line 26: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [PARSER-FAIL] bashit-base (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-base_40.zsh` exit=1 message=tests/corpus/.parser_check_bashit-base_40.zsh:25: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-SKIP] bashit-base (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-base_41.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-base_42.sh` exit=2 message=tests/corpus/.parser_check_bashit-base_42.sh: line 15: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-base_42.sh: line 15: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-SKIP] bashit-fzf (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-fzf_44.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [PARSER-FAIL] bashit-fzf (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-fzf_45.sh` exit=2 message=tests/corpus/.parser_check_bashit-fzf_45.sh: line 19: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-fzf_45.sh: line 19: `	while ; do'
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [PARSER-SKIP] bashit-tmux (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-tmux_47.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/tmux.plugin.bash
- [PARSER-SKIP] bashit-history (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-history_50.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/history.plugin.bash
- [PARSER-SKIP] bashit-ssh (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-ssh_53.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/ssh.plugin.bash
- [PARSER-SKIP] bashit-docker (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-docker_56.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [PARSER-FAIL] bashit-docker (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-docker_57.sh` exit=2 message=tests/corpus/.parser_check_bashit-docker_57.sh: line 43: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-docker_57.sh: line 43: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [PARSER-FAIL] bashit-general (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-general_58.zsh` exit=1 message=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-SKIP] bashit-general (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-general_59.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] bashit-general (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-general_60.sh` exit=2 message=tests/corpus/.parser_check_bashit-general_60.sh: line 14: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-general_60.sh: line 14: `	done'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] fish-z (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-z_61.bash` exit=2 message=tests/corpus/.parser_check_fish-z_61.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-z_61.bash: line 42: `}'
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [PARSER-FAIL] fish-z (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-z_63.sh` exit=2 message=tests/corpus/.parser_check_fish-z_63.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-z_63.sh: line 42: `}'
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [PARSER-FAIL] fish-fzf (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-fzf_64.bash` exit=2 message=tests/corpus/.parser_check_fish-fzf_64.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fzf_64.bash: line 42: `}'
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [PARSER-FAIL] fish-fzf (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-fzf_66.sh` exit=2 message=tests/corpus/.parser_check_fish-fzf_66.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fzf_66.sh: line 42: `}'
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [PARSER-FAIL] fish-tide (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-tide_67.bash` exit=2 message=tests/corpus/.parser_check_fish-tide_67.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide_67.bash: line 42: `}'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [PARSER-FAIL] fish-tide (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-tide_69.sh` exit=2 message=tests/corpus/.parser_check_fish-tide_69.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide_69.sh: line 42: `}'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [PARSER-FAIL] fish-done (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-done_70.bash` exit=2 message=tests/corpus/.parser_check_fish-done_70.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-done_70.bash: line 103: `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-done (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-done_72.sh` exit=2 message=tests/corpus/.parser_check_fish-done_72.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-done_72.sh: line 106: `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-replay (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-replay_73.bash` exit=2 message=tests/corpus/.parser_check_fish-replay_73.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 48: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-replay_75.sh` exit=2 message=tests/corpus/.parser_check_fish-replay_75.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 51: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-spark (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-spark_76.bash` exit=2 message=tests/corpus/.parser_check_fish-spark_76.bash: line 2: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-spark_76.bash: line 2: `}'
 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [PARSER-FAIL] fish-spark (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-spark_78.sh` exit=2 message=tests/corpus/.parser_check_fish-spark_78.sh: line 2: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-spark_78.sh: line 2: `}'
 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [PARSER-FAIL] fish-autopair (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-autopair_79.bash` exit=2 message=tests/corpus/.parser_check_fish-autopair_79.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-autopair_79.bash: line 48: `}'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [PARSER-FAIL] fish-autopair (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-autopair_81.sh` exit=2 message=tests/corpus/.parser_check_fish-autopair_81.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-autopair_81.sh: line 42: `}'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [PARSER-FAIL] fish-colored-man-pages (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-colored-man-pages_82.bash` exit=2 message=tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 42: `}'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [PARSER-FAIL] fish-colored-man-pages (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-colored-man-pages_84.sh` exit=2 message=tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 42: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 42: `}'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [PARSER-FAIL] fish-gitnow (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-gitnow_85.bash` exit=2 message=tests/corpus/.parser_check_fish-gitnow_85.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-gitnow_85.bash: line 48: `}'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [PARSER-FAIL] fish-gitnow (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-gitnow_87.sh` exit=2 message=tests/corpus/.parser_check_fish-gitnow_87.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-gitnow_87.sh: line 51: `}'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [PARSER-FAIL] fish-fisher (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-fisher_88.bash` exit=2 message=tests/corpus/.parser_check_fish-fisher_88.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fisher_88.bash: line 48: `}'
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [PARSER-FAIL] fish-fisher (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-fisher_90.sh` exit=2 message=tests/corpus/.parser_check_fish-fisher_90.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-fisher_90.sh: line 51: `}'
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [PARSER-SKIP] zsh-powerlevel10k (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-powerlevel10k_92.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-FAIL] zsh-powerlevel10k (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-powerlevel10k_93.sh` exit=2 message=tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 56: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-powerlevel10k_93.sh: line 56: `() {'
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-SKIP] zsh-agnoster (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-agnoster_95.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-agnoster_96.sh` exit=2 message=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 62: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 62: `	  () {'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-eastwood (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-eastwood_97.bash` exit=2 message=tests/corpus/.parser_check_zsh-eastwood_97.bash: line 4: syntax error near unexpected token `;'
tests/corpus/.parser_check_zsh-eastwood_97.bash: line 4: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [PARSER-SKIP] zsh-eastwood (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-eastwood_98.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [PARSER-FAIL] zsh-eastwood (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-eastwood_99.sh` exit=2 message=tests/corpus/.parser_check_zsh-eastwood_99.sh: line 4: syntax error near unexpected token `;'
tests/corpus/.parser_check_zsh-eastwood_99.sh: line 4: `if ; then'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [PARSER-SKIP] zsh-spaceship (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-spaceship_101.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [PARSER-SKIP] zsh-gnzh (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-gnzh_104.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-gnzh_105.sh` exit=2 message=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 13: syntax error near unexpected token `)'
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 13: `() {'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-SKIP] bashit-bobby-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-bobby-theme_107.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [PARSER-FAIL] bashit-bobby-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-bobby-theme_108.sh` exit=2 message=tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 14: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 14: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-atomic-theme_109.zsh` exit=1 message=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-SKIP] bashit-atomic-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-atomic-theme_110.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-atomic-theme_111.sh` exit=2 message=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 17: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 17: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-brainy-theme_112.zsh` exit=1 message=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-SKIP] bashit-brainy-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-brainy-theme_113.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-brainy-theme_114.sh` exit=2 message=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 17: syntax error near unexpected token `;'
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 17: `	if ; then'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-SKIP] bashit-candy-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-candy-theme_116.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/candy/candy.theme.bash
- [PARSER-SKIP] bashit-envy-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-envy-theme_119.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/bash/bash-it/themes/envy/envy.theme.bash
- [PARSER-FAIL] fish-tide-theme (theme) fish->bash command=`bash -n tests/corpus/.parser_check_fish-tide-theme_121.bash` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-tide-theme (theme) fish->posix command=`bash -n tests/corpus/.parser_check_fish-tide-theme_123.sh` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-starship-init (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_fish-starship-init_124.zsh` exit=1 message=tests/corpus/.parser_check_fish-starship-init_124.zsh:151: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [PARSER-SKIP] fish-starship-init (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_fish-starship-init_125.fish` message=parser execution error: Not_Exist path=tests/corpus/repos/fish/starship/install/install.sh
- [PARSER-FAIL] fish-starship-init (theme) bash->posix command=`bash -n tests/corpus/.parser_check_fish-starship-init_126.sh` exit=2 message=tests/corpus/.parser_check_fish-starship-init_126.sh: line 33: syntax error near unexpected token `;'
tests/corpus/.parser_check_fish-starship-init_126.sh: line 33: `	if ; then'
 path=tests/corpus/repos/fish/starship/install/install.sh

## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=12 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Validator Rule Failures

- No validator rule failures.
