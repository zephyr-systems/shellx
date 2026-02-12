# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.483 | 1.289 | 11 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.317 | 0.772 | 8 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.391 | 0.646 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.381 | 1.743 | 9 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.355 | 1.410 | 7 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.401 | 1.410 | 8 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.874 | 0.510 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.923 | 1.840 | 12 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.887 | 0.633 | 7 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=18 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-syntax-highlighting zsh->bash warnings=494 shims=1 src_fn=9 out_fn=2 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->fish warnings=705 shims=4 src_fn=9 out_fn=5 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->posix warnings=618 shims=0 src_fn=9 out_fn=0 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] ohmyzsh-git zsh->posix warnings=38 shims=0 src_fn=16 out_fn=3 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=5 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=33 shims=4 src_fn=14 out_fn=6 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=28 shims=2 src_fn=14 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->bash warnings=35 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->fish warnings=29 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->posix warnings=35 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] bashit-base bash->zsh warnings=82 shims=0 src_fn=15 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->fish warnings=84 shims=2 src_fn=15 out_fn=3 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->posix warnings=83 shims=1 src_fn=15 out_fn=2 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-fzf bash->zsh warnings=28 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->fish warnings=34 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->posix warnings=21 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-general bash->zsh warnings=52 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->fish warnings=54 shims=2 src_fn=1 out_fn=3 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->posix warnings=52 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] fish-z fish->bash warnings=27 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->zsh warnings=22 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->posix warnings=49 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-fzf fish->bash warnings=26 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-replay fish->posix warnings=188 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [WARN] fish-autopair fish->posix warnings=55 shims=1 src_fn=2 out_fn=2 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=5 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
