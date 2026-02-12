# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.676 | 2.655 | 12 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.432 | 1.152 | 11 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.464 | 0.890 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.443 | 2.549 | 9 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.429 | 2.493 | 9 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.535 | 2.549 | 9 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.892 | 1.041 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 1.011 | 3.204 | 13 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.918 | 1.408 | 13 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=23 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-autosuggestions zsh->posix warnings=30 shims=3 src_fn=30 out_fn=12 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=10 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=34 shims=6 src_fn=14 out_fn=12 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=23 shims=3 src_fn=14 out_fn=8 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-sudo zsh->posix warnings=20 shims=1 src_fn=2 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/sudo/sudo.plugin.zsh
- [WARN] zsh-agnoster zsh->posix warnings=59 shims=1 src_fn=14 out_fn=9 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=10 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=3 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] bashit-atomic-theme bash->posix warnings=37 shims=1 src_fn=22 out_fn=1 path=tests/corpus/repos/bash/bash-it/themes/atomic/atomic.theme.bash
- [WARN] bashit-brainy-theme bash->posix warnings=20 shims=0 src_fn=22 out_fn=0 path=tests/corpus/repos/bash/bash-it/themes/brainy/brainy.theme.bash

## Validator Rule Failures

- No validator rule failures.
