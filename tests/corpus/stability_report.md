# ShellX Corpus Stability Report

Cases configured: 55

Cross-dialect runs executed: 159

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.502 | 8.144 | 17 |
| bash->posix | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 4.549 | 9.741 | 16 |
| bash->zsh | 18 | 18/18 | 18/18 | 18/18 | 0 | 12/12 | 6/6 | 0 | 0 | 2.627 | 4.097 | 10 |
| fish->bash | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.419 | 8.218 | 14 |
| fish->posix | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.757 | 9.812 | 14 |
| fish->zsh | 14 | 14/14 | 14/14 | 14/14 | 0 | 13/13 | 1/1 | 1 | 0 | 1.482 | 7.557 | 14 |
| zsh->bash | 21 | 21/21 | 21/21 | 21/21 | 0 | 16/16 | 5/5 | 3 | 0 | 3.094 | 6.584 | 13 |
| zsh->fish | 21 | 21/21 | 21/21 | 21/21 | 0 | 16/16 | 5/5 | 3 | 0 | 9.067 | 9.494 | 21 |
| zsh->posix | 21 | 21/21 | 21/21 | 21/21 | 0 | 16/16 | 5/5 | 3 | 0 | 3.042 | 12.458 | 17 |

## Failures


## Parser Validation Failures

- No parser validation failures.
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
| fish->zsh | 14 | 10 | 4 | 14 | 0 | 0 | 0 |
| zsh->bash | 21 | 0 | 6 | 0 | 0 | 0 | 0 |
| zsh->fish | 21 | 18 | 6 | 18 | 20 | 1 | 0 |
| zsh->posix | 21 | 17 | 6 | 0 | 0 | 0 | 0 |

## Validator Rule Failures

- No validator rule failures.

## Semantic Differential Checks

Cases: 29, Passed: 29, Skipped: 0

### Semantic Pair Summary

| Pair | Cases | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| fish->bash | 4 | 4 | 0 | 0 |
| fish->posix | 1 | 1 | 0 | 0 |
| fish->zsh | 1 | 1 | 0 | 0 |
| zsh->fish | 4 | 4 | 0 | 0 |
| zsh->bash | 7 | 7 | 0 | 0 |
| zsh->posix | 4 | 4 | 0 | 0 |
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
- [PASS] plugin_ohmyzsh_z_arrays_cond_param_zsh_to_bash zsh->bash exit=0 out="ARR_OK\nCOND_OK\nPARAM_OK"
- [PASS] plugin_ohmyzsh_sudo_condition_zsh_to_posix zsh->posix exit=0 out="COND_OK\nHAVE_SUDO_FN"
- [PASS] plugin_ohmyzsh_extract_condition_zsh_to_bash zsh->bash exit=0 out="COND_OK\nHAVE_EXTRACT"
- [PASS] plugin_ohmyzsh_colored_man_param_zsh_to_posix zsh->posix exit=0 out="PARAM_OK\nCOLOR_OK"
- [PASS] plugin_ohmyzsh_copyfile_cond_param_zsh_to_bash zsh->bash exit=0 out="PARAM_OK\nCOND_OK\nHAVE_COPYFILE"
- [PASS] plugin_ysu_hooks_events_zsh_to_bash zsh->bash exit=0 out="HOOKS_OK"
- [PASS] plugin_zsh_nvm_param_zsh_to_posix zsh->posix exit=0 out="PARAM_OK\nHAVE_NVM_LOAD"
