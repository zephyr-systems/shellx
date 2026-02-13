# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Parser Matrix | Parser Skipped | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 1 | 0 | 1.781 | 8.563 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 12 | 0.713 | 4.659 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 16/16 | 0 | 10/10 | 6/6 | 0 | 0 | 0.346 | 0.945 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 0 | 1.058 | 7.721 | 11 |
| fish->posix | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 2 | 0.994 | 7.403 | 11 |
| fish->zsh | 11 | 11/11 | 11/11 | 11/11 | 0 | 10/10 | 1/1 | 1 | 0 | 1.140 | 5.827 | 11 |
| zsh->bash | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 0 | 0 | 0.822 | 2.050 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 0 | 0 | 2.101 | 10.386 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 15/15 | 0 | 10/10 | 5/5 | 0 | 22 | 1.262 | 6.444 | 14 |

## Failures


## Parser Validation Failures

- No parser validation failures.
- No parser validation skips.

## High Warning Runs


## Warning Categories


### bash->fish

- `parse_recovery/parse_diagnostic`: 1
  - bashit-aliases (plugin) Parse diagnostic at <input>:20:54: Syntax error

### bash->posix

- `arrays_maps/indexed_arrays`: 12
  - bashit-git (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - bashit-aliases (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - bashit-completion (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - bashit-base (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - bashit-fzf (plugin) Compat[indexed_arrays]: Array features are not POSIX portable

### fish->bash

- `parse_recovery/parse_diagnostic`: 1
  - fish-autopair (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->posix

- `hook_event/prompt_hooks`: 2
  - fish-done (plugin) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
  - fish-tide-theme (theme) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
- `parse_recovery/parse_diagnostic`: 1
  - fish-autopair (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### fish->zsh

- `parse_recovery/parse_diagnostic`: 1
  - fish-autopair (plugin) Parse diagnostic at <input>:1:1: Parse tree contains syntax errors

### zsh->posix

- `arrays_maps/indexed_arrays`: 14
  - zsh-autosuggestions (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - zsh-syntax-highlighting (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - ohmyzsh-git (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - ohmyzsh-z (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
  - ohmyzsh-fzf (plugin) Compat[indexed_arrays]: Array features are not POSIX portable
- `hook_event/prompt_hooks`: 4
  - zsh-autosuggestions (plugin) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
  - zsh-syntax-highlighting (plugin) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
  - ohmyzsh-z (plugin) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
  - zsh-spaceship (theme) Compat[prompt_hooks]: Shell hook/event behavior is not standardized in POSIX sh
- `hook_event/zsh_hooks`: 4
  - zsh-autosuggestions (plugin) Compat[zsh_hooks]: Zsh hook APIs (precmd/preexec/add-zsh-hook) do not map directly
  - zsh-syntax-highlighting (plugin) Compat[zsh_hooks]: Zsh hook APIs (precmd/preexec/add-zsh-hook) do not map directly
  - ohmyzsh-z (plugin) Compat[zsh_hooks]: Zsh hook APIs (precmd/preexec/add-zsh-hook) do not map directly
  - zsh-spaceship (theme) Compat[zsh_hooks]: Zsh hook APIs (precmd/preexec/add-zsh-hook) do not map directly

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
