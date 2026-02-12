# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.449 | 2.128 | 11 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.271 | 1.037 | 11 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.313 | 0.607 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.371 | 2.771 | 8 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.427 | 2.604 | 8 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.450 | 2.660 | 8 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.903 | 1.015 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.980 | 3.027 | 10 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.906 | 1.364 | 9 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=23 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-autosuggestions zsh->posix warnings=30 shims=2 src_fn=30 out_fn=12 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] zsh-syntax-highlighting zsh->bash warnings=472 shims=1 src_fn=9 out_fn=6 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->fish warnings=487 shims=5 src_fn=9 out_fn=10 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] zsh-syntax-highlighting zsh->posix warnings=481 shims=2 src_fn=9 out_fn=7 path=tests/corpus/repos/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=10 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=33 shims=5 src_fn=14 out_fn=12 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=22 shims=2 src_fn=14 out_fn=8 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->bash warnings=45 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->fish warnings=39 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] ohmyzsh-colored-man-pages zsh->posix warnings=40 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/zsh/ohmyzsh/plugins/colored-man-pages/colored-man-pages.plugin.zsh
- [WARN] bashit-base bash->zsh warnings=80 shims=0 src_fn=15 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->fish warnings=83 shims=3 src_fn=15 out_fn=5 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-base bash->posix warnings=81 shims=1 src_fn=15 out_fn=1 path=tests/corpus/repos/bash/bash-it/plugins/available/base.plugin.bash
- [WARN] bashit-fzf bash->zsh warnings=37 shims=0 src_fn=2 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-general bash->zsh warnings=38 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->fish warnings=42 shims=4 src_fn=1 out_fn=5 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] bashit-general bash->posix warnings=39 shims=1 src_fn=1 out_fn=1 path=tests/corpus/repos/bash/bash-it/aliases/available/general.aliases.bash
- [WARN] fish-z fish->bash warnings=30 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->zsh warnings=25 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-z fish->posix warnings=52 shims=1 src_fn=4 out_fn=2 path=tests/corpus/repos/fish/z/conf.d/z.fish
- [WARN] fish-fzf fish->bash warnings=27 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-fzf fish->zsh warnings=20 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-fzf fish->posix warnings=20 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-spark fish->bash warnings=33 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [WARN] fish-spark fish->zsh warnings=26 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [WARN] fish-spark fish->posix warnings=32 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/spark.fish/functions/spark.fish
- [WARN] fish-autopair fish->zsh warnings=24 shims=2 src_fn=2 out_fn=3 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] fish-autopair fish->posix warnings=47 shims=1 src_fn=2 out_fn=2 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] zsh-agnoster zsh->posix warnings=59 shims=1 src_fn=14 out_fn=9 path=tests/corpus/repos/zsh/ohmyzsh/themes/agnoster.zsh-theme
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=30 shims=4 src_fn=1 out_fn=10 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme

## Validator Rule Failures

- No validator rule failures.
