# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.398 | 0.304 | 0 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.313 | 0.613 | 0 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.390 | 0.750 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.152 | 0.900 | 0 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.152 | 0.900 | 0 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.061 | 0.900 | 0 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.869 | 0.485 | 0 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.875 | 0.191 | 0 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.869 | 0.309 | 0 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=30 shims=0 src_fn=30 out_fn=17 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-syntax-highlighting zsh->bash warnings=489 shims=0 src_fn=9 out_fn=0 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->fish warnings=709 shims=0 src_fn=9 out_fn=0 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->posix warnings=617 shims=0 src_fn=9 out_fn=1 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] ohmyzsh-git zsh->posix warnings=37 shims=0 src_fn=16 out_fn=3 path=tests/corpus/repos/zsh/ohmyzsh/plugins/git/git.plugin.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=25 shims=0 src_fn=14 out_fn=4 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=32 shims=0 src_fn=14 out_fn=1 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->bash warnings=48 shims=0 src_fn=1 out_fn=1 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->fish warnings=42 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->posix warnings=32 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] bashit-base bash->zsh warnings=79 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->fish warnings=84 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->posix warnings=79 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-fzf bash->zsh warnings=35 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->fish warnings=40 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->posix warnings=35 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-general bash->zsh warnings=44 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->fish warnings=49 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->posix warnings=44 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] fish-z fish->bash warnings=25 shims=0 src_fn=4 out_fn=0 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->zsh warnings=25 shims=0 src_fn=4 out_fn=0 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->posix warnings=25 shims=0 src_fn=4 out_fn=0 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] zsh-spaceship zsh->bash warnings=23 shims=0 src_fn=1 out_fn=1 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=30 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=27 shims=0 src_fn=1 out_fn=1 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
