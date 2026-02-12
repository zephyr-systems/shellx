# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.434 | 1.268 | 12 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.358 | 0.766 | 8 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.391 | 0.750 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.098 | 1.656 | 9 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.089 | 1.456 | 8 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.101 | 1.556 | 8 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.868 | 0.595 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.944 | 2.241 | 13 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.885 | 0.837 | 8 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=19 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-syntax-highlighting zsh->bash warnings=471 shims=1 src_fn=9 out_fn=2 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->fish warnings=593 shims=4 src_fn=9 out_fn=6 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->posix warnings=658 shims=2 src_fn=9 out_fn=4 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] ohmyzsh-git zsh->posix warnings=38 shims=0 src_fn=16 out_fn=3 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=6 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=34 shims=4 src_fn=14 out_fn=7 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=34 shims=2 src_fn=14 out_fn=4 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->bash warnings=47 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->fish warnings=58 shims=2 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->posix warnings=64 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] bashit-base bash->zsh warnings=77 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->fish warnings=80 shims=3 src_fn=15 out_fn=4 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->posix warnings=78 shims=1 src_fn=15 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-fzf bash->zsh warnings=27 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->fish warnings=25 shims=1 src_fn=2 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->posix warnings=25 shims=1 src_fn=2 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-general bash->zsh warnings=59 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->fish warnings=68 shims=2 src_fn=1 out_fn=3 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->posix warnings=66 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] fish-z fish->bash warnings=21 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->zsh warnings=29 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->posix warnings=23 shims=1 src_fn=4 out_fn=1 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-fzf fish->posix warnings=31 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=3 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=22 shims=4 src_fn=1 out_fn=6 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=22 shims=2 src_fn=1 out_fn=4 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
