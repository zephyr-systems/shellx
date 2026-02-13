# ShellX Corpus Stability Report

Cases configured: 55

Cross-dialect runs executed: 159

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.502 | 8.144 | 17 |
| bash->posix | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 4.515 | 9.431 | 16 |
| bash->zsh | 18 | 18/18 | 18/18 | 9/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.627 | 4.220 | 10 |
| fish->bash | 14 | 14/14 | 14/14 | 13/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.397 | 7.866 | 14 |
| fish->posix | 14 | 14/14 | 14/14 | 13/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.741 | 9.467 | 14 |
| fish->zsh | 14 | 14/14 | 14/14 | 6/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.444 | 7.777 | 14 |
| zsh->bash | 21 | 21/21 | 21/21 | 14/21 | 0 | 16/16 | 5/5 | 3 | 0 | 2.104 | 5.680 | 13 |
| zsh->fish | 21 | 21/21 | 21/21 | 20/21 | 0 | 16/16 | 5/5 | 3 | 0 | 9.067 | 9.480 | 21 |
| zsh->posix | 21 | 21/21 | 21/21 | 15/21 | 0 | 16/16 | 5/5 | 3 | 0 | 3.020 | 12.005 | 17 |

## Failures

- [FAIL] ohmyzsh-z (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=4 src_fn=14 out_fn=33 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 1206: unexpected EOF while looking for matching `)'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-z_10.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=2 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 82: syntax error near unexpected token `||'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 82: `      || "${realcmd:c}" = ($editorcmd|${editorcmd:c}) ]] \'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-sudo (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=2 out_fn=20 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 275: syntax error near unexpected token `||'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 275: `	      || "${realcmd:c}" = ($editorcmd|${editorcmd:c}) ]] \'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=0 out_fn=1 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: `}'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-extract_19.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-extract (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=0 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: `}'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-extract_21.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 319: syntax error: unexpected end of file from `{' command on line 312
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=1 out_fn=31 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 491: syntax error: unexpected end of file from `{' command on line 484
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=0 out_fn=12 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash: line 251: syntax error: unexpected end of file from `{' command on line 235
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] ohmyzsh-copyfile (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=0 out_fn=31 msg= parser_msg=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh: line 458: syntax error: unexpected end of file from `{' command on line 445
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=4 src_fn=10 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 506: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 506: `fi'
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_37.bash path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=31 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 244): Missing end to balance this if statement
	    if __zx_test "$position" = "before"
	    ^^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_38.fish path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=42 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 636: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 636: `fi'
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_39.sh path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=2 src_fn=14 out_fn=35 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_40.bash: line 444: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 444: `}'
 parser_artifact=tests/corpus/.parser_check_zsh-nvm_40.bash path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=5 src_fn=14 out_fn=51 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_42.sh: line 614: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 614: `}'
 parser_artifact=tests/corpus/.parser_check_zsh-nvm_42.sh path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] bashit-git (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=12 out_fn=24 msg= parser_msg=tests/corpus/.parser_check_bashit-git_49.zsh:279: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-git_49.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [FAIL] bashit-base (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=15 out_fn=28 msg= parser_msg=tests/corpus/.parser_check_bashit-base_58.zsh:239: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-base_58.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [FAIL] bashit-docker (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=8 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-docker_73.zsh:271: parse error near `__shellx_fn_invalid'
 parser_artifact=tests/corpus/.parser_check_bashit-docker_73.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [FAIL] bashit-general (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=1 out_fn=14 msg= parser_msg=tests/corpus/.parser_check_bashit-general_76.zsh:235: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_bashit-general_76.zsh path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [FAIL] bashit-proxy (plugin) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=21 out_fn=33 msg= parser_msg=tests/corpus/.parser_check_bashit-proxy_79.zsh:315: parse error near `__shellx_fn_invalid'
 parser_artifact=tests/corpus/.parser_check_bashit-proxy_79.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/proxy.plugin.bash
- [FAIL] fish-fzf (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=1 src_fn=1 out_fn=7 msg= parser_msg=tests/corpus/.parser_check_fish-fzf_89.zsh:81: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-fzf_89.zsh path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [FAIL] fish-done (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=8 out_fn=29 msg= parser_msg=tests/corpus/.parser_check_fish-done_95.zsh:286: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-done_95.zsh path=tests/corpus/repos/fish/done/conf.d/done.fish
- [FAIL] fish-replay (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_fish-replay_97.bash: line 149: syntax error: unexpected end of file from `{' command on line 144
 parser_artifact=tests/corpus/.parser_check_fish-replay_97.bash path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=16 msg= parser_msg=tests/corpus/.parser_check_fish-replay_98.zsh:137: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-replay_98.zsh path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-replay (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=23 msg= parser_msg=tests/corpus/.parser_check_fish-replay_99.sh: line 272: syntax error: unexpected end of file from `{' command on line 267
 parser_artifact=tests/corpus/.parser_check_fish-replay_99.sh path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [FAIL] fish-gitnow (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=25 out_fn=54 msg= parser_msg=tests/corpus/.parser_check_fish-gitnow_110.zsh:377: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-gitnow_110.zsh path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [FAIL] fish-fisher (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=1 out_fn=17 msg= parser_msg=tests/corpus/.parser_check_fish-fisher_113.zsh:141: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-fisher_113.zsh path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [FAIL] fish-async-prompt (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=11 out_fn=34 msg= parser_msg=tests/corpus/.parser_check_fish-async-prompt_116.zsh:215: parse error near `__async_prompt_setup...'
 parser_artifact=tests/corpus/.parser_check_fish-async-prompt_116.zsh path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [FAIL] fish-ssh-agent (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=2 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_fish-ssh-agent_119.zsh:145: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-ssh-agent_119.zsh path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [FAIL] fish-completion-sync (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=1(parse=1 compat=0) shims=2 src_fn=3 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_fish-completion-sync_122.zsh:141: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-completion-sync_122.zsh path=tests/corpus/repos/fish/fish-completion-sync/init.fish
- [FAIL] bashit-bobby-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=2 out_fn=2 msg= parser_msg=tests/corpus/.parser_check_bashit-bobby-theme_139.zsh:7: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-bobby-theme_139.zsh path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [FAIL] bashit-atomic-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-atomic-theme_142.zsh:186: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_bashit-atomic-theme_142.zsh path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [FAIL] bashit-brainy-theme (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=22 out_fn=22 msg= parser_msg=tests/corpus/.parser_check_bashit-brainy-theme_145.zsh:79: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-brainy-theme_145.zsh path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [FAIL] fish-starship-init (theme) bash->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=0 src_fn=21 out_fn=21 msg= parser_msg=tests/corpus/.parser_check_fish-starship-init_157.zsh:32: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_fish-starship-init_157.zsh path=tests/corpus/repos/fish/starship/install/install.sh

## Parser Validation Failures

- [PARSER-FAIL] ohmyzsh-z (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-z_10.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-z_10.bash: line 1206: unexpected EOF while looking for matching `)'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-z_10.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_16.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 82: syntax error near unexpected token `||'
tests/corpus/.parser_check_ohmyzsh-sudo_16.bash: line 82: `      || "${realcmd:c}" = ($editorcmd|${editorcmd:c}) ]] \'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-sudo_16.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-sudo (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-sudo_18.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 275: syntax error near unexpected token `||'
tests/corpus/.parser_check_ohmyzsh-sudo_18.sh: line 275: `	      || "${realcmd:c}" = ($editorcmd|${editorcmd:c}) ]] \'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-sudo_18.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_19.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_19.bash: line 156: `}'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-extract_19.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-extract (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-extract_21.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: syntax error near unexpected token `}'
tests/corpus/.parser_check_ohmyzsh-extract_21.sh: line 353: `}'
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-extract_21.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/extract/extract.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash: line 319: syntax error: unexpected end of file from `{' command on line 312
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_22.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-colored-man-pages (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh: line 491: syntax error: unexpected end of file from `{' command on line 484
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-colored-man-pages_24.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [PARSER-FAIL] ohmyzsh-copyfile (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash` exit=2 message=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash: line 251: syntax error: unexpected end of file from `{' command on line 235
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-copyfile_28.bash path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-FAIL] ohmyzsh-copyfile (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh` exit=2 message=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh: line 458: syntax error: unexpected end of file from `{' command on line 445
 parser_artifact=tests/corpus/.parser_check_ohmyzsh-copyfile_30.sh path=tests/corpus/repos/zsh/ohmyzsh/plugins/copyfile/copyfile.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_37.bash` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 506: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 506: `fi'
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_37.bash path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-you-should-use_38.fish` exit=127 message=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 244): Missing end to balance this if statement
	    if __zx_test "$position" = "before"
	    ^^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_38.fish path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_39.sh` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 636: syntax error near unexpected token `fi'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 636: `fi'
 parser_artifact=tests/corpus/.parser_check_zsh-you-should-use_39.sh path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-nvm_40.bash` exit=2 message=tests/corpus/.parser_check_zsh-nvm_40.bash: line 444: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 444: `}'
 parser_artifact=tests/corpus/.parser_check_zsh-nvm_40.bash path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-nvm_42.sh` exit=2 message=tests/corpus/.parser_check_zsh-nvm_42.sh: line 614: syntax error near unexpected token `}'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 614: `}'
 parser_artifact=tests/corpus/.parser_check_zsh-nvm_42.sh path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] bashit-git (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-git_49.zsh` exit=1 message=tests/corpus/.parser_check_bashit-git_49.zsh:279: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-git_49.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/git.plugin.bash
- [PARSER-FAIL] bashit-base (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-base_58.zsh` exit=1 message=tests/corpus/.parser_check_bashit-base_58.zsh:239: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-base_58.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [PARSER-FAIL] bashit-docker (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-docker_73.zsh` exit=1 message=tests/corpus/.parser_check_bashit-docker_73.zsh:271: parse error near `__shellx_fn_invalid'
 parser_artifact=tests/corpus/.parser_check_bashit-docker_73.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/docker.plugin.bash
- [PARSER-FAIL] bashit-general (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-general_76.zsh` exit=1 message=tests/corpus/.parser_check_bashit-general_76.zsh:235: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_bashit-general_76.zsh path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [PARSER-FAIL] bashit-proxy (plugin) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-proxy_79.zsh` exit=1 message=tests/corpus/.parser_check_bashit-proxy_79.zsh:315: parse error near `__shellx_fn_invalid'
 parser_artifact=tests/corpus/.parser_check_bashit-proxy_79.zsh path=tests/corpus/repos/bash/bash-it/plugins/available/proxy.plugin.bash
- [PARSER-FAIL] fish-fzf (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-fzf_89.zsh` exit=1 message=tests/corpus/.parser_check_fish-fzf_89.zsh:81: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-fzf_89.zsh path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [PARSER-FAIL] fish-done (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-done_95.zsh` exit=1 message=tests/corpus/.parser_check_fish-done_95.zsh:286: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-done_95.zsh path=tests/corpus/repos/fish/done/conf.d/done.fish
- [PARSER-FAIL] fish-replay (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-replay_97.bash` exit=2 message=tests/corpus/.parser_check_fish-replay_97.bash: line 149: syntax error: unexpected end of file from `{' command on line 144
 parser_artifact=tests/corpus/.parser_check_fish-replay_97.bash path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-replay_98.zsh` exit=1 message=tests/corpus/.parser_check_fish-replay_98.zsh:137: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-replay_98.zsh path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-replay (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-replay_99.sh` exit=2 message=tests/corpus/.parser_check_fish-replay_99.sh: line 272: syntax error: unexpected end of file from `{' command on line 267
 parser_artifact=tests/corpus/.parser_check_fish-replay_99.sh path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [PARSER-FAIL] fish-gitnow (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-gitnow_110.zsh` exit=1 message=tests/corpus/.parser_check_fish-gitnow_110.zsh:377: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-gitnow_110.zsh path=tests/corpus/repos/fish/gitnow/conf.d/gitnow.fish
- [PARSER-FAIL] fish-fisher (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-fisher_113.zsh` exit=1 message=tests/corpus/.parser_check_fish-fisher_113.zsh:141: parse error near `:'
 parser_artifact=tests/corpus/.parser_check_fish-fisher_113.zsh path=tests/corpus/repos/fish/fisher/functions/fisher.fish
- [PARSER-FAIL] fish-async-prompt (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-async-prompt_116.zsh` exit=1 message=tests/corpus/.parser_check_fish-async-prompt_116.zsh:215: parse error near `__async_prompt_setup...'
 parser_artifact=tests/corpus/.parser_check_fish-async-prompt_116.zsh path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [PARSER-FAIL] fish-ssh-agent (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-ssh-agent_119.zsh` exit=1 message=tests/corpus/.parser_check_fish-ssh-agent_119.zsh:145: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-ssh-agent_119.zsh path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [PARSER-FAIL] fish-completion-sync (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-completion-sync_122.zsh` exit=1 message=tests/corpus/.parser_check_fish-completion-sync_122.zsh:141: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_fish-completion-sync_122.zsh path=tests/corpus/repos/fish/fish-completion-sync/init.fish
- [PARSER-FAIL] bashit-bobby-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-bobby-theme_139.zsh` exit=1 message=tests/corpus/.parser_check_bashit-bobby-theme_139.zsh:7: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-bobby-theme_139.zsh path=tests/corpus/repos/bash/bash-it/themes/bobby/bobby.theme.bash
- [PARSER-FAIL] bashit-atomic-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-atomic-theme_142.zsh` exit=1 message=tests/corpus/.parser_check_bashit-atomic-theme_142.zsh:186: parse error near `}'
 parser_artifact=tests/corpus/.parser_check_bashit-atomic-theme_142.zsh path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [PARSER-FAIL] bashit-brainy-theme (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_bashit-brainy-theme_145.zsh` exit=1 message=tests/corpus/.parser_check_bashit-brainy-theme_145.zsh:79: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_bashit-brainy-theme_145.zsh path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash
- [PARSER-FAIL] fish-starship-init (theme) bash->zsh command=`zsh -n tests/corpus/.parser_check_fish-starship-init_157.zsh` exit=1 message=tests/corpus/.parser_check_fish-starship-init_157.zsh:32: parse error near `function'
 parser_artifact=tests/corpus/.parser_check_fish-starship-init_157.zsh path=tests/corpus/repos/fish/starship/install/install.sh
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
| zsh->bash | 21 | 8 | 6 | 0 | 0 | 0 | 0 |
| zsh->fish | 21 | 18 | 6 | 18 | 20 | 1 | 0 |
| zsh->posix | 21 | 17 | 6 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.
