# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 15/16 | 0 | 10/10 | 6/6 | 0 | 42 | 1.556 | 8.195 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 11/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.699 | 4.206 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 11/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.393 | 0.921 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 9/11 | 0 | 10/10 | 1/1 | 1 | 19 | 0.999 | 7.157 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 7/11 | 0 | 10/10 | 1/1 | 1 | 18 | 0.940 | 6.793 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/11 | 0 | 10/10 | 1/1 | 1 | 19 | 1.151 | 4.793 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 8/15 | 0 | 10/10 | 5/5 | 76 | 4 | 0.990 | 1.656 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 76 | 58 | 1.791 | 9.812 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 7/15 | 0 | 10/10 | 5/5 | 76 | 22 | 1.367 | 5.315 | 14 |

## Failures

- [FAIL] zsh-autosuggestions (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=30 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 565: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 565: `	done'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-autosuggestions (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=7(parse=4 compat=3) shims=3 src_fn=30 out_fn=20 msg= parser_msg=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 781: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 781: `}'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=7(parse=6 compat=1) shims=1 src_fn=9 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 171: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 171: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] zsh-syntax-highlighting (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=6 compat=3) shims=3 src_fn=9 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 164: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 164: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=15(parse=14 compat=1) shims=1 src_fn=14 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 435: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 435: `        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-z (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=17(parse=14 compat=3) shims=3 src_fn=14 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 306: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 306: `	        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-fzf (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=15(parse=14 compat=1) shims=1 src_fn=9 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 297: warning: here-document at line 273 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 298: syntax error: unexpected end of file from `{' command on line 272
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=9(parse=9 compat=0) shims=0 src_fn=2 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=10(parse=9 compat=1) shims=1 src_fn=2 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=0 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=0 out_fn=10 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 116: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 116: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=4(parse=4 compat=0) shims=0 src_fn=1 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=5(parse=4 compat=1) shims=1 src_fn=1 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 80: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 80: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] bashit-base (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=15 out_fn=13 msg= parser_msg=tests/corpus/.parser_check_bashit-base_40.zsh:26: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->fish translate=true parse=true parser=false/true exit=127 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=15 out_fn=23 msg= parser_msg=tests/corpus/.parser_check_bashit-base_41.fish (line 195): Missing end to balance this function definition
function mkcd
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_bashit-base_41.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-base (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=15 out_fn=25 msg= parser_msg=tests/corpus/.parser_check_bashit-base_42.sh: line 99: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-base_42.sh: line 99: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-general (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=1 out_fn=0 msg= parser_msg=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-general (plugin) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=1 out_fn=11 msg= parser_msg=tests/corpus/.parser_check_bashit-general_60.sh: line 77: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-general_60.sh: line 77: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] fish-done (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=8 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-done_71.zsh:256: parse error near `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-done (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=8 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_fish-done_72.sh: line 185: syntax error near unexpected token `wslvar' while looking for matching `)'
tests/corpus/.parser_check_fish-done_72.sh: line 185: `		powershell_exe="$(wslpath (wslvar windir)/System32/WindowsPowerShell/v1.0/powershell.exe)"'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-replay (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=15 msg= parser_msg=tests/corpus/.parser_check_fish-replay_73.bash: line 125: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 125: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=0 compat=2) shims=2 src_fn=1 out_fn=15 msg= parser_msg=tests/corpus/.parser_check_fish-replay_75.sh: line 128: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 128: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-autopair (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=2 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_fish-autopair_81.sh: line 80: syntax error near unexpected token `('
tests/corpus/.parser_check_fish-autopair_81.sh: line 80: `autopair_pairs=""()" "[]" "{}" '""' "''""'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [FAIL] zsh-agnoster (theme) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=0 src_fn=14 out_fn=8 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] zsh-agnoster (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=2(parse=1 compat=1) shims=1 src_fn=14 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 381: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 381: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [FAIL] bashit-atomic-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:46: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=27 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 118: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 118: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:46: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=22 out_fn=15 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 118: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 118: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] fish-tide-theme (theme) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=3 out_fn=23 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 180: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 180: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-tide-theme (theme) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=0 compat=3) shims=3 src_fn=3 out_fn=23 msg= parser_msg=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 183: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 183: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [FAIL] fish-starship-init (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=21 out_fn=20 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_124.zsh:164: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [FAIL] fish-starship-init (theme) bash->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=0 compat=1) shims=1 src_fn=21 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_126.sh: line 220: syntax error: arithmetic expression required
tests/corpus/.parser_check_fish-starship-init_126.sh: line 220: syntax error: `((  ))'
 path=tests/corpus/repos/fish/starship/install/install.sh

## Parser Validation Failures

- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_1.bash` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 565: syntax error near unexpected token `done'
tests/corpus/.parser_check_zsh-autosuggestions_1.bash: line 565: `	done'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-autosuggestions (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-autosuggestions_3.sh` exit=2 message=tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 781: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-autosuggestions_3.sh: line 781: `}'
 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 171: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_4.bash: line 171: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] zsh-syntax-highlighting (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh` exit=2 message=tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 164: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-syntax-highlighting_6.sh: line 164: `}'
 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_10.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 435: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 435: `        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_12.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 306: syntax error near unexpected token `done'
tests/corpus/.parser_check_ohmyzsh-z_12.sh: line 306: `	        done'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-fzf (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-fzf_15.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 297: warning: here-document at line 273 delimited by end-of-file (wanted `EOF')
tests/corpus/.parser_check_ohmyzsh-fzf_15.sh: line 298: syntax error: unexpected end of file from `{' command on line 272
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/fzf/fzf.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_16.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 79: `    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_18.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: unexpected argument `(' to conditional binary operator
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: syntax error near `(\'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 129: `	    if [[ "$realcmd" = (\$EDITOR|$editorcmd|${editorcmd:c}) \'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_19.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 56: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_21.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 116: syntax error near unexpected token `newline'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 116: `      *.tar.gz|      *.tgz'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 37: `  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 80: syntax error near unexpected token `v'
tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 80: `	  for k v in "${(@kv)less_termcap}"; do'
 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] bashit-base (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-base_40.zsh` exit=1 message=tests/corpus/.parser_check_bashit-base_40.zsh:26: parse error
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->fish command=`fish --no-execute tests/corpus/.parser_check_bashit-base_41.fish` exit=127 message=tests/corpus/.parser_check_bashit-base_41.fish (line 195): Missing end to balance this function definition
function mkcd
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_bashit-base_41.fish
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-base_42.sh` exit=2 message=tests/corpus/.parser_check_bashit-base_42.sh: line 99: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-base_42.sh: line 99: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-general (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-general_58.zsh` exit=1 message=tests/corpus/.parser_check_bashit-general_58.zsh:2: parse error
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] bashit-general (plugin) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-general_60.sh` exit=2 message=tests/corpus/.parser_check_bashit-general_60.sh: line 77: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-general_60.sh: line 77: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] fish-done (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-done_71.zsh` exit=1 message=tests/corpus/.parser_check_fish-done_71.zsh:256: parse error near `}'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-done (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-done_72.sh` exit=2 message=tests/corpus/.parser_check_fish-done_72.sh: line 185: syntax error near unexpected token `wslvar' while looking for matching `)'
tests/corpus/.parser_check_fish-done_72.sh: line 185: `		powershell_exe="$(wslpath (wslvar windir)/System32/WindowsPowerShell/v1.0/powershell.exe)"'
 path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-replay (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-replay_73.bash` exit=2 message=tests/corpus/.parser_check_fish-replay_73.bash: line 125: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_73.bash: line 125: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-replay_75.sh` exit=2 message=tests/corpus/.parser_check_fish-replay_75.sh: line 128: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-replay_75.sh: line 128: `}'
 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-autopair (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-autopair_81.sh` exit=2 message=tests/corpus/.parser_check_fish-autopair_81.sh: line 80: syntax error near unexpected token `('
tests/corpus/.parser_check_fish-autopair_81.sh: line 80: `autopair_pairs=""()" "[]" "{}" '""' "''""'
 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [PARSER-FAIL] zsh-agnoster (theme) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-agnoster_94.bash` exit=2 message=tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_94.bash: line 384: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] zsh-agnoster (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-agnoster_96.sh` exit=2 message=tests/corpus/.parser_check_zsh-agnoster_96.sh: line 381: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-agnoster_96.sh: line 381: `fi'
 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-atomic-theme_109.zsh` exit=1 message=tests/corpus/.parser_check_bashit-atomic-theme_109.zsh:46: parse error
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-atomic-theme_111.sh` exit=2 message=tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 118: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-atomic-theme_111.sh: line 118: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-brainy-theme_112.zsh` exit=1 message=tests/corpus/.parser_check_bashit-brainy-theme_112.zsh:46: parse error
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->posix command=`bash -n tests/corpus/.parser_check_bashit-brainy-theme_114.sh` exit=2 message=tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 118: syntax error: arithmetic expression required
tests/corpus/.parser_check_bashit-brainy-theme_114.sh: line 118: syntax error: `((  ))'
 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] fish-tide-theme (theme) fish->bash command=`bash -n tests/corpus/.parser_check_fish-tide-theme_121.bash` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_121.bash: line 180: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_121.bash: line 180: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-tide-theme (theme) fish->posix command=`bash -n tests/corpus/.parser_check_fish-tide-theme_123.sh` exit=2 message=tests/corpus/.parser_check_fish-tide-theme_123.sh: line 183: syntax error near unexpected token `}'
tests/corpus/.parser_check_fish-tide-theme_123.sh: line 183: `}'
 path=tests/corpus/repos/fish/tide/functions/fish_prompt.fish
- [PARSER-FAIL] fish-starship-init (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_fish-starship-init_124.zsh` exit=1 message=tests/corpus/.parser_check_fish-starship-init_124.zsh:164: parse error
 path=tests/corpus/repos/fish/starship/install/install.sh
- [PARSER-FAIL] fish-starship-init (theme) bash->posix command=`bash -n tests/corpus/.parser_check_fish-starship-init_126.sh` exit=2 message=tests/corpus/.parser_check_fish-starship-init_126.sh: line 220: syntax error: arithmetic expression required
tests/corpus/.parser_check_fish-starship-init_126.sh: line 220: syntax error: `((  ))'
 path=tests/corpus/repos/fish/starship/install/install.sh
- No parser validation skips.

## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=36 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Validator Rule Failures

- No validator rule failures.
