# ShellX Corpus Stability Report

Cases configured: 75

Cross-dialect runs executed: 219

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 24 | 24/24 | 24/24 | 24/24 | 0 | 17/17 | 7/7 | 4 | 0 | 2.221 | 7.929 | 22 |
| bash->posix | 24 | 24/24 | 24/24 | 24/24 | 0 | 17/17 | 7/7 | 4 | 1 | 4.035 | 10.231 | 20 |
| bash->zsh | 24 | 24/24 | 24/24 | 24/24 | 0 | 17/17 | 7/7 | 4 | 0 | 2.122 | 4.115 | 12 |
| fish->bash | 17 | 17/17 | 17/17 | 17/17 | 0 | 15/15 | 2/2 | 1 | 0 | 1.357 | 7.246 | 17 |
| fish->posix | 17 | 17/17 | 17/17 | 17/17 | 0 | 15/15 | 2/2 | 1 | 0 | 1.784 | 9.020 | 17 |
| fish->zsh | 17 | 17/17 | 17/17 | 17/17 | 0 | 15/15 | 2/2 | 1 | 0 | 1.405 | 6.602 | 17 |
| posix->bash | 3 | 3/3 | 3/3 | 3/3 | 0 | 3/3 | 0/0 | 2 | 3 | 1.000 | 1.000 | 0 |
| posix->fish | 3 | 3/3 | 3/3 | 3/3 | 0 | 3/3 | 0/0 | 2 | 0 | 0.943 | 4.692 | 3 |
| posix->zsh | 3 | 3/3 | 3/3 | 3/3 | 0 | 3/3 | 0/0 | 2 | 3 | 1.000 | 0.000 | 0 |
| zsh->bash | 29 | 29/29 | 29/29 | 29/29 | 0 | 22/22 | 7/7 | 12 | 0 | 3.280 | 6.284 | 17 |
| zsh->fish | 29 | 29/29 | 29/29 | 29/29 | 0 | 22/22 | 7/7 | 12 | 0 | 9.030 | 9.162 | 29 |
| zsh->posix | 29 | 29/29 | 29/29 | 28/29 | 0 | 22/22 | 7/7 | 12 | 1 | 3.033 | 12.683 | 22 |

## Failures

- [FAIL] zsh-pure-theme (theme) zsh->posix translate=true parse=true parser=false/true exit=2 err=None warnings=3(parse=2 compat=1) shims=6 src_fn=27 out_fn=67 msg= parser_msg=tests/corpus/.parser_check_zsh-pure-theme_210.sh: line 958: syntax error near unexpected token `then'
tests/corpus/.parser_check_zsh-pure-theme_210.sh: line 958: `				__shellx_list_set_index if [ $info[top $prompt_pure_vcs_info[top] ]]; then'
 parser_artifact=tests/corpus/.parser_check_zsh-pure-theme_210.sh path=tests/corpus/repos/zsh/pure/pure.zsh

## Parser Validation Failures

- [PARSER-FAIL] zsh-pure-theme (theme) zsh->posix command=`bash -n tests/corpus/.parser_check_zsh-pure-theme_210.sh` exit=2 message=tests/corpus/.parser_check_zsh-pure-theme_210.sh: line 958: syntax error near unexpected token `then'
tests/corpus/.parser_check_zsh-pure-theme_210.sh: line 958: `				__shellx_list_set_index if [ $info[top $prompt_pure_vcs_info[top] ]]; then'
 parser_artifact=tests/corpus/.parser_check_zsh-pure-theme_210.sh path=tests/corpus/repos/zsh/pure/pure.zsh
- No parser validation skips.

## High Warning Runs


## Warning Categories


### bash->fish

- `parse_recovery/parse_diagnostic`: 4
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:37:19: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:883:29: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:1211:17: Syntax error
  - direnv-stdlib (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### bash->posix

- `arrays_maps/indexed_arrays`: 1
  - bash-preexec (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
- `parse_recovery/parse_diagnostic`: 4
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:37:19: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:883:29: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:1211:17: Syntax error
  - direnv-stdlib (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### bash->zsh

- `parse_recovery/parse_diagnostic`: 4
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:37:19: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:883:29: Syntax error
  - ble-sh-make-command (plugin) Parse diagnostic at <input>:1211:17: Syntax error
  - direnv-stdlib (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->bash

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->posix

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->zsh

- `parse_recovery/parse_diagnostic`: 1
  - fish-completion-sync (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### posix->bash

- `parse_recovery/parse_diagnostic`: 2
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error
  - busybox-install-sh (plugin) Parse diagnostic at <input>:1:1: Syntax error
- `recovery_fallback/fallback`: 3
  - openrc-network-init (plugin) Applied POSIX preservation fallback due degraded translated output
  - busybox-install-sh (plugin) Applied POSIX preservation fallback due degraded translated output
  - autoconf-gendocs-sh (plugin) Applied POSIX preservation fallback due degraded translated output

### posix->fish

- `parse_recovery/parse_diagnostic`: 2
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error
  - busybox-install-sh (plugin) Parse diagnostic at <input>:1:1: Syntax error

### posix->zsh

- `parse_recovery/parse_diagnostic`: 2
  - openrc-network-init (plugin) Parse diagnostic at <input>:33:10: Syntax error
  - busybox-install-sh (plugin) Parse diagnostic at <input>:1:1: Syntax error
- `recovery_fallback/fallback`: 3
  - openrc-network-init (plugin) Applied POSIX preservation fallback due degraded translated output
  - busybox-install-sh (plugin) Applied POSIX preservation fallback due degraded translated output
  - autoconf-gendocs-sh (plugin) Applied POSIX preservation fallback due degraded translated output

### zsh->bash

- `parse_recovery/parse_diagnostic`: 12
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:60:50: Syntax error
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:103:82: Syntax error

### zsh->fish

- `parse_recovery/parse_diagnostic`: 12
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:60:50: Syntax error
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:103:82: Syntax error

### zsh->posix

- `arrays_maps/indexed_arrays`: 1
  - zsh-pure-theme (theme) Compat[indexed_arrays]: Array features are not POSIX portable
- `parse_recovery/parse_diagnostic`: 12
  - zsh-nvm (plugin) Parse diagnostic at <input>:1:1: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:208:34: Syntax error
  - zsh-nvm (plugin) Parse diagnostic at <input>:0:0: 1 additional diagnostics suppressed
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:45:25: Syntax error
  - fast-syntax-highlighting (plugin) Parse diagnostic at <input>:258:35: Syntax error

## Semantic Parity Matrix

| Pair | Cases | Arrays/Maps | Hooks/Events | Condition/Test | Param Expansion | Process Subst | Source |
|---|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 24 | 18 | 0 | 18 | 21 | 6 | 0 |
| bash->posix | 24 | 18 | 0 | 0 | 0 | 0 | 0 |
| bash->zsh | 24 | 0 | 0 | 0 | 0 | 0 | 0 |
| fish->bash | 17 | 10 | 4 | 17 | 0 | 0 | 0 |
| fish->posix | 17 | 9 | 4 | 17 | 0 | 0 | 0 |
| fish->zsh | 17 | 11 | 5 | 17 | 0 | 0 | 0 |
| posix->bash | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| posix->fish | 3 | 3 | 0 | 3 | 3 | 0 | 0 |
| posix->zsh | 3 | 0 | 0 | 0 | 0 | 0 | 0 |
| zsh->bash | 29 | 0 | 8 | 0 | 0 | 0 | 0 |
| zsh->fish | 29 | 23 | 8 | 24 | 26 | 2 | 0 |
| zsh->posix | 29 | 22 | 8 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.

## Semantic Differential Checks

Cases: 35, Passed: 34, Skipped: 0

### Semantic Pair Summary

| Pair | Cases | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| fish->bash | 5 | 5 | 0 | 0 |
| fish->posix | 1 | 1 | 0 | 0 |
| fish->zsh | 2 | 2 | 0 | 0 |
| zsh->fish | 5 | 5 | 0 | 0 |
| zsh->bash | 8 | 8 | 0 | 0 |
| zsh->posix | 5 | 5 | 0 | 0 |
| bash->fish | 3 | 3 | 0 | 0 |
| bash->zsh | 1 | 1 | 0 | 0 |
| posix->fish | 1 | 1 | 0 | 0 |
| posix->zsh | 1 | 1 | 0 | 0 |
| posix->bash | 1 | 1 | 0 | 0 |
| bash->posix | 2 | 1 | 1 | 0 |

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
- [PASS] plugin_ohmyzsh_z_arrays_cond_param_zsh_to_bash zsh->bash exit=0 out="ARR_OK\nCOND_OK\nPARAM_OK"
- [PASS] plugin_ohmyzsh_sudo_condition_zsh_to_posix zsh->posix exit=0 out="COND_OK\nHAVE_SUDO_FN"
- [PASS] plugin_ohmyzsh_extract_condition_zsh_to_bash zsh->bash exit=0 out="COND_OK\nHAVE_EXTRACT"
- [PASS] plugin_ohmyzsh_colored_man_param_zsh_to_posix zsh->posix exit=0 out="PARAM_OK\nCOLOR_OK"
- [PASS] plugin_ohmyzsh_copyfile_cond_param_zsh_to_bash zsh->bash exit=0 out="PARAM_OK\nCOND_OK\nHAVE_COPYFILE"
- [PASS] plugin_ysu_hooks_events_zsh_to_bash zsh->bash exit=0 out="HOOKS_OK"
- [PASS] plugin_zsh_nvm_param_zsh_to_posix zsh->posix exit=0 out="PARAM_OK\nHAVE_NVM_LOAD"
- [PASS] plugin_zsh_assoc_sparse_zsh_to_bash zsh->bash exit=0 out="ARR_SPARSE_OK"
- [PASS] plugin_fish_kv_iter_fish_to_zsh fish->zsh exit=0 out="KV:f=fetch\nKV:c=commit"
- [PASS] probe_zsh_nested_index_zsh_to_posix zsh->posix exit=0 out="NESTED_OK"
- [PASS] probe_zsh_assoc_keycheck_zsh_to_fish zsh->fish exit=0 out="KEYCHECK_OK"
- [FAIL] probe_bash_sparse_preserve_bash_to_posix bash->posix src_exit=0 dst_exit=0 src_out="SPARSE_IDX_100:git\nSPARSE_OK" dst_out="SPARSE_OK" src_err="" dst_err=""
- [PASS] probe_fish_map_merge_fish_to_bash fish->bash exit=0 out="a,b,b,c\nMERGE_OK"
