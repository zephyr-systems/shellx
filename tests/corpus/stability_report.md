# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.333 | 1.384 | 10 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.183 | 0.803 | 8 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.257 | 0.727 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.189 | 1.542 | 8 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.177 | 1.320 | 7 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.195 | 1.320 | 7 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.886 | 0.418 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.946 | 2.075 | 10 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.829 | 0.727 | 7 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=18 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-syntax-highlighting zsh->bash warnings=1012 shims=1 src_fn=9 out_fn=2 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->fish warnings=1020 shims=4 src_fn=9 out_fn=5 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->posix warnings=1044 shims=2 src_fn=9 out_fn=3 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=5 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=33 shims=4 src_fn=14 out_fn=6 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=28 shims=2 src_fn=14 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->bash warnings=52 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->fish warnings=84 shims=1 src_fn=1 out_fn=1 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->posix warnings=31 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] bashit-base bash->zsh warnings=64 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->fish warnings=67 shims=3 src_fn=15 out_fn=4 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->posix warnings=65 shims=1 src_fn=15 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-fzf bash->zsh warnings=32 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->fish warnings=36 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->posix warnings=36 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-general bash->zsh warnings=60 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->fish warnings=25 shims=2 src_fn=1 out_fn=3 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->posix warnings=23 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] fish-z fish->bash warnings=24 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->zsh warnings=24 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->posix warnings=24 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=22 shims=4 src_fn=1 out_fn=5 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=38 shims=2 src_fn=1 out_fn=3 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
