# Changelog

## 0.2.0 - 2026-02-13

### Added
- Runtime compatibility polyfills for cross-shell plugin translation paths (`autoload`, `is-at-least`, `add-zsh-hook`, `status`, `print`, `typeset`, `emulate`, `unfunction`, `zsystem`, metadata helpers).
- Targeted parser-hardening rewrites for corpus regressions:
  - `ohmyzsh-sudo` (zsh -> bash/posix)
  - `powerlevel10k` (zsh -> bash/posix)
  - `gnzh` (zsh -> bash/posix)
- Corpus regression tests for these parser-hardening cases.

### Changed
- Enhanced shim requirement detection for runtime/polyfill callsites.
- Improved zsh expansion rewrite handling for `${=...}` forms in bash-compatible output.
- Improved plugin compatibility for `ohmyzsh-z` by ensuring exported `z` wrapper is present when needed.

### Fixed
- Semantic differential plugin workflow cases now pass:
  - `plugin_ohmyzsh_z_zsh_to_bash`
  - `plugin_bashit_aliases_bash_to_posix`
  - `plugin_fish_autopair_fish_to_bash`
- Parser matrix failures resolved for previously failing corpus entries.
- Leak in `rewrite_zsh_anonymous_function_for_bash` caused by double allocation on rewritten return path.

### Verification Snapshot
- Cross-dialect corpus runs: `126/126` translate+parse.
- Parser validation matrix: no failures.
- Semantic differential checks: `22/22` passed.
