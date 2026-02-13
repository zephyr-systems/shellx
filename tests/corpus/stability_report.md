# ShellX Corpus Stability Report

Cases configured: 55

Cross-dialect runs executed: 159

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.502 | 8.144 | 17 |
| bash->posix | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 4.476 | 9.431 | 16 |
| bash->zsh | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.589 | 4.046 | 10 |
| fish->bash | 14 | 14/14 | 14/14 | 11/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.403 | 7.938 | 14 |
| fish->posix | 14 | 14/14 | 14/14 | 11/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.754 | 9.539 | 14 |
| fish->zsh | 14 | 14/14 | 14/14 | 12/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.456 | 6.551 | 14 |
| zsh->bash | 21 | 21/21 | 21/21 | 19/21 | 0 | 16/16 | 5/5 | 3 | 0 | 2.026 | 5.278 | 13 |
| zsh->fish | 21 | 21/21 | 21/21 | 20/21 | 0 | 16/16 | 5/5 | 3 | 0 | 8.949 | 9.357 | 21 |
| zsh->posix | 21 | 21/21 | 21/21 | 19/21 | 0 | 16/16 | 5/5 | 3 | 0 | 2.971 | 11.986 | 17 |

## Failures

- [FAIL] zsh-you-should-use (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=3 src_fn=10 out_fn=20 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 364: syntax error near unexpected token `|'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 364: `        for entry in ${@s/line}; do|        for entry in ${/line}; do'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->fish translate=true parse=true parser=false/true exit=127 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=30 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 190): Missing end to balance this function definition
function check_alias_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-you-should-use (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=6 src_fn=10 out_fn=37 msg= parser_msg=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 544: syntax error near unexpected token `|'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 544: `	        for entry in ${@s/line}; do|	        for entry in ${/line}; do'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->bash translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=2 src_fn=14 out_fn=34 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_40.bash: line 354: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 354: `  local global_binary_paths="$(echo "$NVM_DIR"/v0*/bin/*(N) "$NVM_DIR"/versions/*/*/bin/*(N))"'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] zsh-nvm (plugin) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=3 compat=0) shims=5 src_fn=14 out_fn=45 msg= parser_msg=tests/corpus/.parser_check_zsh-nvm_42.sh: line 540: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 540: `	  global_binary_paths="$(echo "$NVM_DIR"/v0*/bin/*(N) "$NVM_DIR"/versions/*/*/bin/*(N))"'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [FAIL] fish-async-prompt (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=11 out_fn=34 msg= parser_msg=tests/corpus/.parser_check_fish-async-prompt_115.bash: line 228: syntax error near unexpected token `)'
tests/corpus/.parser_check_fish-async-prompt_115.bash: line 228: `	unset -f tus current-function)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [FAIL] fish-async-prompt (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=5 src_fn=11 out_fn=34 msg= parser_msg=tests/corpus/.parser_check_fish-async-prompt_116.zsh:218: parse error near `)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [FAIL] fish-async-prompt (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=4 src_fn=11 out_fn=24 msg= parser_msg=tests/corpus/.parser_check_fish-async-prompt_117.sh: line 151: syntax error near unexpected token `)'
tests/corpus/.parser_check_fish-async-prompt_117.sh: line 151: `	unset -f tus current-function)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [FAIL] fish-ssh-agent (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=2 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_fish-ssh-agent_118.bash: line 182: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_fish-ssh-agent_118.bash: line 182: `if __shellx_match -q -e darwin $(string lower (uname -s)); then'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [FAIL] fish-ssh-agent (plugin) fish->zsh translate=true parse=true parser=false/true exit=1 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=2 out_fn=18 msg= parser_msg=tests/corpus/.parser_check_fish-ssh-agent_119.zsh:183: parse error near `|'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [FAIL] fish-ssh-agent (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=0(parse=0 compat=0) shims=2 src_fn=2 out_fn=25 msg= parser_msg=tests/corpus/.parser_check_fish-ssh-agent_120.sh: line 305: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_fish-ssh-agent_120.sh: line 305: `if __shellx_match -q -e darwin $(string lower (uname -s)); then'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [FAIL] fish-completion-sync (plugin) fish->bash translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=2 src_fn=3 out_fn=19 msg= parser_msg=tests/corpus/.parser_check_fish-completion-sync_121.bash: line 161: syntax error near unexpected token `fish_completion_sync_filter' while looking for matching `)'
tests/corpus/.parser_check_fish-completion-sync_121.bash: line 161: `	FISH_COMPLETION_DATA_DIRS=($(fish_completion_sync_add_comp (fish_completion_sync_filter "" (string split ":" $XDG_DATA_DIRS))))'
 path=tests/corpus/repos/fish/fish-completion-sync/init.fish
- [FAIL] fish-completion-sync (plugin) fish->posix translate=true parse=true parser=false/true exit=2 err=None warnings=1(parse=1 compat=0) shims=3 src_fn=3 out_fn=26 msg= parser_msg=tests/corpus/.parser_check_fish-completion-sync_123.sh: line 284: syntax error near unexpected token `fish_completion_sync_filter' while looking for matching `)'
tests/corpus/.parser_check_fish-completion-sync_123.sh: line 284: `	FISH_COMPLETION_DATA_DIRS="$(fish_completion_sync_add_comp (fish_completion_sync_filter "" (string split ":" $XDG_DATA_DIRS)))"'
 path=tests/corpus/repos/fish/fish-completion-sync/init.fish

## Parser Validation Failures

- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_37.bash` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 364: syntax error near unexpected token `|'
tests/corpus/.parser_check_zsh-you-should-use_37.bash: line 364: `        for entry in ${@s/line}; do|        for entry in ${/line}; do'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->fish command=`fish --no-execute tests/corpus/.parser_check_zsh-you-should-use_38.fish` exit=127 message=tests/corpus/.parser_check_zsh-you-should-use_38.fish (line 190): Missing end to balance this function definition
function check_alias_usage
^~~~~~~^
warning: Error while reading file tests/corpus/.parser_check_zsh-you-should-use_38.fish
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-you-should-use (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-you-should-use_39.sh` exit=2 message=tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 544: syntax error near unexpected token `|'
tests/corpus/.parser_check_zsh-you-should-use_39.sh: line 544: `	        for entry in ${@s/line}; do|	        for entry in ${/line}; do'
 path=tests/corpus/repos/zsh/zsh-you-should-use/you-should-use.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->bash command=`bash -n tests/corpus/.parser_check_zsh-nvm_40.bash` exit=2 message=tests/corpus/.parser_check_zsh-nvm_40.bash: line 354: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_zsh-nvm_40.bash: line 354: `  local global_binary_paths="$(echo "$NVM_DIR"/v0*/bin/*(N) "$NVM_DIR"/versions/*/*/bin/*(N))"'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] zsh-nvm (plugin) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-nvm_42.sh` exit=2 message=tests/corpus/.parser_check_zsh-nvm_42.sh: line 540: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_zsh-nvm_42.sh: line 540: `	  global_binary_paths="$(echo "$NVM_DIR"/v0*/bin/*(N) "$NVM_DIR"/versions/*/*/bin/*(N))"'
 path=tests/corpus/repos/zsh/zsh-nvm/zsh-nvm.plugin.zsh
- [PARSER-FAIL] fish-async-prompt (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-async-prompt_115.bash` exit=2 message=tests/corpus/.parser_check_fish-async-prompt_115.bash: line 228: syntax error near unexpected token `)'
tests/corpus/.parser_check_fish-async-prompt_115.bash: line 228: `	unset -f tus current-function)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [PARSER-FAIL] fish-async-prompt (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-async-prompt_116.zsh` exit=1 message=tests/corpus/.parser_check_fish-async-prompt_116.zsh:218: parse error near `)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [PARSER-FAIL] fish-async-prompt (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-async-prompt_117.sh` exit=2 message=tests/corpus/.parser_check_fish-async-prompt_117.sh: line 151: syntax error near unexpected token `)'
tests/corpus/.parser_check_fish-async-prompt_117.sh: line 151: `	unset -f tus current-function)'
 path=tests/corpus/repos/fish/fish-async-prompt/conf.d/__async_prompt.fish
- [PARSER-FAIL] fish-ssh-agent (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-ssh-agent_118.bash` exit=2 message=tests/corpus/.parser_check_fish-ssh-agent_118.bash: line 182: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_fish-ssh-agent_118.bash: line 182: `if __shellx_match -q -e darwin $(string lower (uname -s)); then'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [PARSER-FAIL] fish-ssh-agent (plugin) fish->zsh command=`zsh -n tests/corpus/.parser_check_fish-ssh-agent_119.zsh` exit=1 message=tests/corpus/.parser_check_fish-ssh-agent_119.zsh:183: parse error near `|'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [PARSER-FAIL] fish-ssh-agent (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-ssh-agent_120.sh` exit=2 message=tests/corpus/.parser_check_fish-ssh-agent_120.sh: line 305: syntax error near unexpected token `(' while looking for matching `)'
tests/corpus/.parser_check_fish-ssh-agent_120.sh: line 305: `if __shellx_match -q -e darwin $(string lower (uname -s)); then'
 path=tests/corpus/repos/fish/fish-ssh-agent/conf.d/halostatue_fish_ssh_agent.fish
- [PARSER-FAIL] fish-completion-sync (plugin) fish->bash command=`bash -n tests/corpus/.parser_check_fish-completion-sync_121.bash` exit=2 message=tests/corpus/.parser_check_fish-completion-sync_121.bash: line 161: syntax error near unexpected token `fish_completion_sync_filter' while looking for matching `)'
tests/corpus/.parser_check_fish-completion-sync_121.bash: line 161: `	FISH_COMPLETION_DATA_DIRS=($(fish_completion_sync_add_comp (fish_completion_sync_filter "" (string split ":" $XDG_DATA_DIRS))))'
 path=tests/corpus/repos/fish/fish-completion-sync/init.fish
- [PARSER-FAIL] fish-completion-sync (plugin) fish->posix command=`bash -n tests/corpus/.parser_check_fish-completion-sync_123.sh` exit=2 message=tests/corpus/.parser_check_fish-completion-sync_123.sh: line 284: syntax error near unexpected token `fish_completion_sync_filter' while looking for matching `)'
tests/corpus/.parser_check_fish-completion-sync_123.sh: line 284: `	FISH_COMPLETION_DATA_DIRS="$(fish_completion_sync_add_comp (fish_completion_sync_filter "" (string split ":" $XDG_DATA_DIRS)))"'
 path=tests/corpus/repos/fish/fish-completion-sync/init.fish
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
