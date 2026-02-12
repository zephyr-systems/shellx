# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.513 | 2.537 | 11 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.357 | 1.310 | 11 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.323 | 0.880 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.515 | 2.919 | 9 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.513 | 2.919 | 9 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.516 | 2.919 | 9 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.970 | 1.239 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 1.057 | 3.153 | 9 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.998 | 1.405 | 9 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=23 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-autosuggestions zsh->posix warnings=30 shims=2 src_fn=30 out_fn=12 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=10 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=32 shims=4 src_fn=14 out_fn=12 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=22 shims=2 src_fn=14 out_fn=8 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] zsh-agnoster zsh->posix warnings=59 shims=1 src_fn=14 out_fn=9 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=10 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme

## Validator Rule Failures

- No validator rule failures.
