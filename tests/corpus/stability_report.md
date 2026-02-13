# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 5/16 | 0 | 10/10 | 6/6 | 0 | 42 | 0.703 | 2.758 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 5/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.432 | 1.258 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 11/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.390 | 0.918 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 2/11 | 0 | 10/10 | 1/1 | 1 | 19 | 0.737 | 2.765 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 1/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.728 | 2.719 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/11 | 0 | 10/10 | 1/1 | 1 | 19 | 0.891 | 2.765 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 4/15 | 0 | 10/10 | 5/5 | 76 | 4 | 0.988 | 1.454 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 1/15 | 0 | 10/10 | 5/5 | 76 | 58 | 1.169 | 3.121 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 3/15 | 0 | 10/10 | 5/5 | 76 | 22 | 1.004 | 1.604 | 14 |

## Failures

- [FAIL] zsh-autosuggestions (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=30 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 552: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 552: `	done'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-autosuggestions (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=10(parse=4 compat=6) shims=6 src_fn=30 out_fn=24 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_2.fish (line 99): Missing end to balance this switch statement
		switch $widgets[$widget]
		^~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-autosuggestions_2.fish
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-autosuggestions (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=30 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 717: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 717: `}'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=7(parse=6 compat=1) shims=1 src_fn=9 out_fn=14 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 158: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 158: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=12(parse=6 compat=6) shims=6 src_fn=9 out_fn=15 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish (line 129): Missing end to balance this function definition
function _zsh_highlight__zle-line-finish
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=6 compat=3) shims=3 src_fn=9 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 100: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 100: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=4(parse=4 compat=0) shims=0 src_fn=16 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 435: syntax error: unexpected end of file from `{' command on line 218
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=16 out_fn=10 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_8.fish (line 139): Unsupported use of '='. In fish, please use 'set b "(git_current_branch)"'.
	  test  $# != 1 ; and b="(git_current_branch)"
	                      ^~~~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-git_8.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-git (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=16 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 395: syntax error: unexpected end of file from `{' command on line 97
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=15(parse=14 compat=1) shims=1 src_fn=14 out_fn=14 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 422: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 422: `        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=17 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_11.fish (line 63): Missing end to balance this function definition
function _zshz_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-z_11.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=17(parse=14 compat=3) shims=3 src_fn=14 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 242: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 242: `	        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-fzf (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=17(parse=14 compat=3) shims=3 src_fn=9 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-fzf_14.fish (line 42): Unsupported use of '='. In fish, please use 'set fzf_base "${FZF_BASE}"'.
	  test -d "${FZF_BASE}"; and fzf_base="${FZF_BASE}"
	                             ^~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-fzf_14.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [FAIL] ohmyzsh-fzf (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=15(parse=14 compat=1) shims=1 src_fn=9 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 233: warning: here-document at line 209 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 234: syntax error: unexpected end of file from `{' command on line 208
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=9 compat=0) shims=0 src_fn=2 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=12(parse=9 compat=3) shims=3 src_fn=2 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_17.fish (line 45): Unsupported use of '='. In fish, please use 'set LBUFFER "(fc -ln -1)"'.
	  test  -z $BUFFER ; and LBUFFER="(fc -ln -1)"
	                         ^~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-sudo_17.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=10(parse=9 compat=1) shims=1 src_fn=2 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=0 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=0 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_20.fish (line 34): Expected a string, but found a redirection
    cat >&2 <<'EOF'
             ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-extract_20.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 52: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 52: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=4(parse=4 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=8(parse=4 compat=4) shims=4 src_fn=1 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish (line 34): Expected keyword 'in', but found a string
	  for k v in "${(@kv)less_termcap}"
	        ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 102: syntax error near unexpected token `fi'
tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 102: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=5(parse=0 compat=5) shims=5 src_fn=1 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-web-search_26.fish (line 80): Unsupported use of '='. In fish, please use 'set param ""'.
    test  "$urls[$1]" == *\?*= ; and param=""
                                     ^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-web-search_26.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-web-search (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 113: syntax error near unexpected token `fi'
tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 113: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=0 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish (line 40): Expected end of the statement, but found an incomplete token
  echo ${(%) "\"%B\$1%b copied to clipboard.\"")
                                               ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] bashit-git (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=12 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_bashit-git_32.fish (line 33): ${ is not a valid variable in fish.
	echo "Running: git remote add origin ${GIT_HOSTING:?}:$1.git"
	                                      ^
warning: Error while reading file tests/corpus/.parser_check_bashit-git_32.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [FAIL] bashit-git (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=12 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_bashit-git_33.sh: line 43: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-git_33.sh: line 43: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [FAIL] bashit-aliases (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-aliases_36.sh: line 26: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-aliases_36.sh: line 26: `	fi'
 path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [FAIL] bashit-completion (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=2 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_bashit-completion_38.fish (line 51): ${ is not a valid variable in fish.
	compgen -W "${candidates[*]}" -- "${cur}"
	             ^
warning: Error while reading file tests/corpus/.parser_check_bashit-completion_38.fish
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [FAIL] bashit-completion (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-completion_39.sh: line 27: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-completion_39.sh: line 27: `	fi'
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [FAIL] bashit-base (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=15 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_bashit-base_40.zsh:25: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=15 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_bashit-base_41.fish (line 46): Variables cannot be bracketed. In fish, please use "$site".
	command curl -Ls "http://downforeveryoneorjustme.com/${site}"
	                                                      ^
warning: Error while reading file tests/corpus/.parser_check_bashit-base_41.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=15 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_bashit-base_42.sh: line 16: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-base_42.sh: line 16: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-fzf (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=2 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_bashit-fzf_44.fish (line 58): ${ is not a valid variable in fish.
	 "${files[@]}"
	   ^
warning: Error while reading file tests/corpus/.parser_check_bashit-fzf_44.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [FAIL] bashit-fzf (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-fzf_45.sh: line 20: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-fzf_45.sh: line 20: `	done'
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [FAIL] bashit-docker (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=0 compat=4) shims=4 src_fn=8 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_bashit-docker_56.fish (line 77): $@ is not supported. In fish, please use $argv.
	docker exec -it "$@" /bin/bash
	                  ^
warning: Error while reading file tests/corpus/.parser_check_bashit-docker_56.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [FAIL] bashit-docker (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=8 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_bashit-docker_57.sh: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-docker_57.sh: line 44: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [FAIL] bashit-general (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-general (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=1 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_bashit-general_59.fish (line 45): ${ is not a valid variable in fish.
command grep --color=auto "a" "${BASH_IT?}"/*.md
                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-general_59.fish
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-general (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-general_60.sh: line 14: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-general_60.sh: line 14: `	done'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] fish-z (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-z_61.bash: line 74: syntax error: unexpected end of file from `if' command on line 71
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [FAIL] fish-z (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-z_63.sh: line 74: syntax error: unexpected end of file from `if' command on line 71
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [FAIL] fish-fzf (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-fzf_64.bash: line 55: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [FAIL] fish-fzf (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-fzf_66.sh: line 55: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [FAIL] fish-tide (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=3 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-tide_67.bash: line 47: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-tide_67.bash: line 47: `	fi'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [FAIL] fish-tide (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=3 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-tide_69.sh: line 47: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-tide_69.sh: line 47: `	fi'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [FAIL] fish-done (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=8 out_fn=17 msg= parser_msg=tests/corpus/.parser_check_fish-done_70.bash: line 142: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-done_70.bash: line 142: `	fi'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-done (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=8 out_fn=17 msg= parser_msg=tests/corpus/.parser_check_fish-done_71.zsh:173: parse error near `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-done (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=8 out_fn=17 msg= parser_msg=tests/corpus/.parser_check_fish-done_72.sh: line 108: syntax error near unexpected token `wslvar' while looking for matching `)'
tests/corpus/.parser_check_fish-done_72.sh: line 108: `		powershell_exe="$(wslpath (wslvar windir)/System32/WindowsPowerShell/v1.0/powershell.exe)"'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-replay (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-replay_73.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 48: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-replay_75.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 51: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-autopair (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=2 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-autopair_81.sh: line 54: syntax error near unexpected token `('
tests/corpus/.parser_check_fish-autopair_81.sh: line 54: `autopair_pairs=""()" "[]" "{}" '""' "''""'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [FAIL] fish-colored-man-pages (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 44: `	fi'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [FAIL] fish-colored-man-pages (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 44: `	fi'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [FAIL] fish-gitnow (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=25 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-gitnow_85.bash: line 61: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-gitnow_85.bash: line 61: `	fi'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [FAIL] fish-gitnow (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=25 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-gitnow_87.sh: line 64: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-gitnow_87.sh: line 64: `	fi'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [FAIL] fish-fisher (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-fisher_88.bash: line 53: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [FAIL] fish-fisher (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=4 msg= parser_msg=tests/corpus/.parser_check_fish-fisher_90.sh: line 56: syntax error: unexpected end of file from `if' command on line 54
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [FAIL] zsh-powerlevel10k (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=8(parse=4 compat=4) shims=4 src_fn=1 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_zsh-powerlevel10k_92.fish (line 31): Missing end to balance this if statement
	  if (( ! $+__p9k_locale ))
	  ^^
warning: Error while reading file tests/corpus/.parser_check_zsh-powerlevel10k_92.fish
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=0 src_fn=14 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=4(parse=1 compat=3) shims=3 src_fn=14 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_95.fish (line 32): Unsupported use of '='. In fish, please use 'set bg "%K{$1}"'.
	  test  -n $1 ; and bg="%K{$1}"; or bg="%k"
	                    ^~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-agnoster_95.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=14 out_fn=7 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 317: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 317: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-eastwood (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-eastwood_97.bash: line 5: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-eastwood_97.bash: line 5: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [FAIL] zsh-eastwood (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-eastwood_99.sh: line 5: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-eastwood_99.sh: line 5: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [FAIL] zsh-spaceship (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=18(parse=14 compat=4) shims=4 src_fn=1 out_fn=10 msg= parser_msg=tests/corpus/.parser_check_zsh-spaceship_101.fish (line 77): ${ is not a valid variable in fish.
	  setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
	                                                 ^
warning: Error while reading file tests/corpus/.parser_check_zsh-spaceship_101.fish
 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=0 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_103.bash: line 34: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-gnzh_103.bash: line 34: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=0 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_104.fish (line 31): Unexpected end of string, incomplete parameter expansion
() {
   ^
warning: Error while reading file tests/corpus/.parser_check_zsh-gnzh_104.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] zsh-gnzh (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 45: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 45: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [FAIL] bashit-bobby-theme (theme) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=2 out_fn=7 msg= parser_msg=tests/corpus/.parser_check_bashit-bobby-theme_107.fish (line 58): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${bold_cyan?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-bobby-theme_107.fish
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [FAIL] bashit-bobby-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=2 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 15: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 15: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=22 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_110.fish (line 250): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${BICyan?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-atomic-theme_110.fish
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 18: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 18: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=22 out_fn=9 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_113.fish (line 248): Unexpected end of string, quotes are not balanced
set ___BRAINY_BOTTOM (__shellx_param_default ___BRAINY_BOTTOM "\"exitcode char\"")
                                                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-brainy-theme_113.fish
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=6 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 18: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 18: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-candy-theme (theme) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=3 msg= parser_msg=tests/corpus/.parser_check_bashit-candy-theme_116.fish (line 22): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${blue?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-candy-theme_116.fish
 path=tests/corpus/repos/bash/bash-it/themes/candy/candy.theme.bash
- [FAIL] fish-tide-theme (theme) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=3 out_fn=12 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-tide-theme (theme) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=3 out_fn=12 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-starship-init (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=21 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_124.zsh:151: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [FAIL] fish-starship-init (theme) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=21 out_fn=5 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_125.fish (line 31): Variables cannot be bracketed. In fish, please use "$BOLD".
	printf "${BOLD}${GREY}>${NO_COLOR} $*"
	         ^
warning: Error while reading file tests/corpus/.parser_check_fish-starship-init_125.fish
 path=tests/corpus/repos/fish/starship/install/install.sh
- [FAIL] fish-starship-init (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=21 out_fn=21 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_126.sh: line 34: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-starship-init_126.sh: line 34: `	fi'
 path=tests/corpus/repos/fish/starship/install/install.sh

## Parser Validation Failures

- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_1.bash` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 552: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 552: `	done'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-autosuggestions_2.fish` exit=127 message=tests/corpus/.parser_check_zsh-autosuggestions_2.fish (line 99): Missing end to balance this switch statement
		switch $widgets[$widget]
		^~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-autosuggestions_2.fish
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_3.sh` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 717: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 717: `}'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 158: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 158: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish` exit=127 message=tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish (line 129): Missing end to balance this function definition
function _zsh_highlight__zle-line-finish
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-syntax-highlighting_5.fish
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 100: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 100: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-git_7.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-git_7.bash: line 435: syntax error: unexpected end of file from `{' command on line 218
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-git_8.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-git_8.fish (line 139): Unsupported use of '='. In fish, please use 'set b "(git_current_branch)"'.
	  test  $# != 1 ; and b="(git_current_branch)"
	                      ^~~~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-git_8.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-FAIL] ohmyzsh-git (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-git_9.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-git_9.sh: line 395: syntax error: unexpected end of file from `{' command on line 97
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_10.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 422: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 422: `        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-z_11.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-z_11.fish (line 63): Missing end to balance this function definition
function _zshz_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-z_11.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_12.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 242: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 242: `	        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-fzf (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-fzf_14.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-fzf_14.fish (line 42): Unsupported use of '='. In fish, please use 'set fzf_base "${FZF_BASE}"'.
	  test -d "${FZF_BASE}"; and fzf_base="${FZF_BASE}"
	                             ^~~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-fzf_14.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [PARSER-FAIL] ohmyzsh-fzf (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-fzf_15.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 233: warning: here-document at line 209 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 234: syntax error: unexpected end of file from `{' command on line 208
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_16.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-sudo_17.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-sudo_17.fish (line 45): Unsupported use of '='. In fish, please use 'set LBUFFER "(fc -ln -1)"'.
	  test  -z $BUFFER ; and LBUFFER="(fc -ln -1)"
	                         ^~~~~~~~~~~~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-sudo_17.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_18.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 65: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_19.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-extract_20.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-extract_20.fish (line 34): Expected a string, but found a redirection
    cat >&2 <<'EOF'
             ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-extract_20.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_21.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 52: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 52: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish (line 34): Expected keyword 'in', but found a string
	  for k v in "${(@kv)less_termcap}"
	        ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-colored-man-pages_23.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 16: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-web-search (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-web-search_25.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 102: syntax error near unexpected token `fi'
tests/corpus/.parser_check_ohmyzsh-web-search_25.bash: line 102: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-FAIL] ohmyzsh-web-search (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-web-search_26.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-web-search_26.fish (line 80): Unsupported use of '='. In fish, please use 'set param ""'.
    test  "$urls[$1]" == *\?*= ; and param=""
                                     ^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-web-search_26.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-FAIL] ohmyzsh-web-search (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-web-search_27.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 113: syntax error near unexpected token `fi'
tests/corpus/.parser_check_ohmyzsh-web-search_27.sh: line 113: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/web-search/web-search.plugin.zsh
- [PARSER-FAIL] ohmyzsh-copyfile (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish` exit=127 message=tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish (line 40): Expected end of the statement, but found an incomplete token
  echo ${(%) "\"%B\$1%b copied to clipboard.\"")
                                               ^
warning: Error while reading file tests/corpus/.parser_check_ohmyzsh-copyfile_29.fish
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-FAIL] bashit-git (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-git_32.fish` exit=127 message=tests/corpus/.parser_check_bashit-git_32.fish (line 33): ${ is not a valid variable in fish.
	echo "Running: git remote add origin ${GIT_HOSTING:?}:$1.git"
	                                      ^
warning: Error while reading file tests/corpus/.parser_check_bashit-git_32.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [PARSER-FAIL] bashit-git (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-git_33.sh` exit=2 message=tests/corpus/.parser_check_bashit-git_33.sh: line 43: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-git_33.sh: line 43: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [PARSER-FAIL] bashit-aliases (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-aliases_36.sh` exit=2 message=tests/corpus/.parser_check_bashit-aliases_36.sh: line 26: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-aliases_36.sh: line 26: `	fi'
 path=tests/corpus/repos/bash/bash-it/completion/available/aliases.completion.bash
- [PARSER-FAIL] bashit-completion (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-completion_38.fish` exit=127 message=tests/corpus/.parser_check_bashit-completion_38.fish (line 51): ${ is not a valid variable in fish.
	compgen -W "${candidates[*]}" -- "${cur}"
	             ^
warning: Error while reading file tests/corpus/.parser_check_bashit-completion_38.fish
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [PARSER-FAIL] bashit-completion (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-completion_39.sh` exit=2 message=tests/corpus/.parser_check_bashit-completion_39.sh: line 27: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-completion_39.sh: line 27: `	fi'
 path=tests/corpus/repos/bash/bash-it/completion/available/bash-it.completion.bash
- [PARSER-FAIL] bashit-base (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-base_40.zsh` exit=1 message=tests/corpus/.parser_check_bashit-base_40.zsh:25: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-base_41.fish` exit=127 message=tests/corpus/.parser_check_bashit-base_41.fish (line 46): Variables cannot be bracketed. In fish, please use "$site".
	command curl -Ls "http://downforeveryoneorjustme.com/${site}"
	                                                      ^
warning: Error while reading file tests/corpus/.parser_check_bashit-base_41.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-base_42.sh` exit=2 message=tests/corpus/.parser_check_bashit-base_42.sh: line 16: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-base_42.sh: line 16: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-fzf (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-fzf_44.fish` exit=127 message=tests/corpus/.parser_check_bashit-fzf_44.fish (line 58): ${ is not a valid variable in fish.
	 "${files[@]}"
	   ^
warning: Error while reading file tests/corpus/.parser_check_bashit-fzf_44.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [PARSER-FAIL] bashit-fzf (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-fzf_45.sh` exit=2 message=tests/corpus/.parser_check_bashit-fzf_45.sh: line 20: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-fzf_45.sh: line 20: `	done'
 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [PARSER-FAIL] bashit-docker (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-docker_56.fish` exit=127 message=tests/corpus/.parser_check_bashit-docker_56.fish (line 77): $@ is not supported. In fish, please use $argv.
	docker exec -it "$@" /bin/bash
	                  ^
warning: Error while reading file tests/corpus/.parser_check_bashit-docker_56.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [PARSER-FAIL] bashit-docker (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-docker_57.sh` exit=2 message=tests/corpus/.parser_check_bashit-docker_57.sh: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-docker_57.sh: line 44: `	fi'
 path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [PARSER-FAIL] bashit-general (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-general_58.zsh` exit=1 message=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] bashit-general (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-general_59.fish` exit=127 message=tests/corpus/.parser_check_bashit-general_59.fish (line 45): ${ is not a valid variable in fish.
command grep --color=auto "a" "${BASH_IT?}"/*.md
                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-general_59.fish
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] bashit-general (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-general_60.sh` exit=2 message=tests/corpus/.parser_check_bashit-general_60.sh: line 14: syntax error near unexpected token `done'
tests/corpus/.parser_check_bashit-general_60.sh: line 14: `	done'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] fish-z (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-z_61.bash` exit=2 message=tests/corpus/.parser_check_fish-z_61.bash: line 74: syntax error: unexpected end of file from `if' command on line 71
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [PARSER-FAIL] fish-z (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-z_63.sh` exit=2 message=tests/corpus/.parser_check_fish-z_63.sh: line 74: syntax error: unexpected end of file from `if' command on line 71
 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [PARSER-FAIL] fish-fzf (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-fzf_64.bash` exit=2 message=tests/corpus/.parser_check_fish-fzf_64.bash: line 55: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [PARSER-FAIL] fish-fzf (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-fzf_66.sh` exit=2 message=tests/corpus/.parser_check_fish-fzf_66.sh: line 55: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [PARSER-FAIL] fish-tide (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-tide_67.bash` exit=2 message=tests/corpus/.parser_check_fish-tide_67.bash: line 47: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-tide_67.bash: line 47: `	fi'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [PARSER-FAIL] fish-tide (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-tide_69.sh` exit=2 message=tests/corpus/.parser_check_fish-tide_69.sh: line 47: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-tide_69.sh: line 47: `	fi'
 path=tests/corpus/repos/fish/tide/conf.d/_tide_init.fish
- [PARSER-FAIL] fish-done (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-done_70.bash` exit=2 message=tests/corpus/.parser_check_fish-done_70.bash: line 142: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-done_70.bash: line 142: `	fi'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-done (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-done_71.zsh` exit=1 message=tests/corpus/.parser_check_fish-done_71.zsh:173: parse error near `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-done (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-done_72.sh` exit=2 message=tests/corpus/.parser_check_fish-done_72.sh: line 108: syntax error near unexpected token `wslvar' while looking for matching `)'
tests/corpus/.parser_check_fish-done_72.sh: line 108: `		powershell_exe="$(wslpath (wslvar windir)/System32/WindowsPowerShell/v1.0/powershell.exe)"'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-replay (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-replay_73.bash` exit=2 message=tests/corpus/.parser_check_fish-replay_73.bash: line 48: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 48: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-replay_75.sh` exit=2 message=tests/corpus/.parser_check_fish-replay_75.sh: line 51: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 51: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-autopair (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-autopair_81.sh` exit=2 message=tests/corpus/.parser_check_fish-autopair_81.sh: line 54: syntax error near unexpected token `('
tests/corpus/.parser_check_fish-autopair_81.sh: line 54: `autopair_pairs=""()" "[]" "{}" '""' "''""'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [PARSER-FAIL] fish-colored-man-pages (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-colored-man-pages_82.bash` exit=2 message=tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-colored-man-pages_82.bash: line 44: `	fi'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [PARSER-FAIL] fish-colored-man-pages (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-colored-man-pages_84.sh` exit=2 message=tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 44: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-colored-man-pages_84.sh: line 44: `	fi'
 path=tests/corpus/repos/fish/colored_man_pages.fish/functions/man.fish
- [PARSER-FAIL] fish-gitnow (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-gitnow_85.bash` exit=2 message=tests/corpus/.parser_check_fish-gitnow_85.bash: line 61: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-gitnow_85.bash: line 61: `	fi'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [PARSER-FAIL] fish-gitnow (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-gitnow_87.sh` exit=2 message=tests/corpus/.parser_check_fish-gitnow_87.sh: line 64: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-gitnow_87.sh: line 64: `	fi'
 path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [PARSER-FAIL] fish-fisher (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-fisher_88.bash` exit=2 message=tests/corpus/.parser_check_fish-fisher_88.bash: line 53: syntax error: unexpected end of file from `if' command on line 51
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [PARSER-FAIL] fish-fisher (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-fisher_90.sh` exit=2 message=tests/corpus/.parser_check_fish-fisher_90.sh: line 56: syntax error: unexpected end of file from `if' command on line 54
 path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [PARSER-FAIL] zsh-powerlevel10k (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-powerlevel10k_92.fish` exit=127 message=tests/corpus/.parser_check_zsh-powerlevel10k_92.fish (line 31): Missing end to balance this if statement
	  if (( ! $+__p9k_locale ))
	  ^^
warning: Error while reading file tests/corpus/.parser_check_zsh-powerlevel10k_92.fish
 path=tests/corpus/repos/zsh/powerlevel10k/powerlevel10k.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-agnoster_94.bash` exit=2 message=tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-agnoster_95.fish` exit=127 message=tests/corpus/.parser_check_zsh-agnoster_95.fish (line 32): Unsupported use of '='. In fish, please use 'set bg "%K{$1}"'.
	  test  -n $1 ; and bg="%K{$1}"; or bg="%k"
	                    ^~~~~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-agnoster_95.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-agnoster_96.sh` exit=2 message=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 317: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 317: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-eastwood (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-eastwood_97.bash` exit=2 message=tests/corpus/.parser_check_zsh-eastwood_97.bash: line 5: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-eastwood_97.bash: line 5: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [PARSER-FAIL] zsh-eastwood (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-eastwood_99.sh` exit=2 message=tests/corpus/.parser_check_zsh-eastwood_99.sh: line 5: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-eastwood_99.sh: line 5: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/eastwood.zsh-theme
- [PARSER-FAIL] zsh-spaceship (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-spaceship_101.fish` exit=127 message=tests/corpus/.parser_check_zsh-spaceship_101.fish (line 77): ${ is not a valid variable in fish.
	  setopt noprompt{bang,cr,percent,subst} "prompt${^prompt_opts[@]}"
	                                                 ^
warning: Error while reading file tests/corpus/.parser_check_zsh-spaceship_101.fish
 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-gnzh_103.bash` exit=2 message=tests/corpus/.parser_check_zsh-gnzh_103.bash: line 34: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-gnzh_103.bash: line 34: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-gnzh_104.fish` exit=127 message=tests/corpus/.parser_check_zsh-gnzh_104.fish (line 31): Unexpected end of string, incomplete parameter expansion
() {
   ^
warning: Error while reading file tests/corpus/.parser_check_zsh-gnzh_104.fish
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-FAIL] zsh-gnzh (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-gnzh_105.sh` exit=2 message=tests/corpus/.parser_check_zsh-gnzh_105.sh: line 45: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-gnzh_105.sh: line 45: `}'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/gnzh.zsh-theme
- [PARSER-FAIL] bashit-bobby-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-bobby-theme_107.fish` exit=127 message=tests/corpus/.parser_check_bashit-bobby-theme_107.fish (line 58): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${bold_cyan?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-bobby-theme_107.fish
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [PARSER-FAIL] bashit-bobby-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-bobby-theme_108.sh` exit=2 message=tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 15: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-bobby-theme_108.sh: line 15: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-atomic-theme_109.zsh` exit=1 message=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-atomic-theme_110.fish` exit=127 message=tests/corpus/.parser_check_bashit-atomic-theme_110.fish (line 250): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${BICyan?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-atomic-theme_110.fish
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-atomic-theme_111.sh` exit=2 message=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 18: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 18: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-brainy-theme_112.zsh` exit=1 message=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:42: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-brainy-theme_113.fish` exit=127 message=tests/corpus/.parser_check_bashit-brainy-theme_113.fish (line 248): Unexpected end of string, quotes are not balanced
set ___BRAINY_BOTTOM (__shellx_param_default ___BRAINY_BOTTOM "\"exitcode char\"")
                                                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-brainy-theme_113.fish
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-brainy-theme_114.sh` exit=2 message=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 18: syntax error near unexpected token `fi'
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 18: `	fi'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] bashit-candy-theme (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-candy-theme_116.fish` exit=127 message=tests/corpus/.parser_check_bashit-candy-theme_116.fish (line 22): Unexpected end of string, incomplete parameter expansion
: "(__shellx_param_default THEME_CLOCK_COLOR "\${blue?")}"
                                                ^
warning: Error while reading file tests/corpus/.parser_check_bashit-candy-theme_116.fish
 path=tests/corpus/repos/bash/bash-it/themes/candy/candy.theme.bash
- [PARSER-FAIL] fish-tide-theme (theme) fish->bash command=`bash -n tests/corpus/.parser_check_fish-tide-theme_121.bash` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 103: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-tide-theme (theme) fish->posix command=`bash -n tests/corpus/.parser_check_fish-tide-theme_123.sh` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 106: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-starship-init (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_fish-starship-init_124.zsh` exit=1 message=tests/corpus/.parser_check_fish-starship-init_124.zsh:151: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [PARSER-FAIL] fish-starship-init (theme) bash->fish command=`fish --no-execute tests/corpus/.parser_check_fish-starship-init_125.fish` exit=127 message=tests/corpus/.parser_check_fish-starship-init_125.fish (line 31): Variables cannot be bracketed. In fish, please use "$BOLD".
	printf "${BOLD}${GREY}>${NO_COLOR} $*"
	         ^
warning: Error while reading file tests/corpus/.parser_check_fish-starship-init_125.fish
 path=tests/corpus/repos/fish/starship/install/install.sh
- [PARSER-FAIL] fish-starship-init (theme) bash->posix command=`bash -n tests/corpus/.parser_check_fish-starship-init_126.sh` exit=2 message=tests/corpus/.parser_check_fish-starship-init_126.sh: line 34: syntax error near unexpected token `fi'
tests/corpus/.parser_check_fish-starship-init_126.sh: line 34: `	fi'
 path=tests/corpus/repos/fish/starship/install/install.sh
- No parser validation skips.

## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=17 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Validator Rule Failures

- No validator rule failures.
