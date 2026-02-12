# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.445 | 1.503 | 11 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.277 | 1.017 | 8 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.349 | 0.874 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.150 | 1.744 | 6 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.144 | 1.744 | 6 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.059 | 1.744 | 6 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.874 | 0.538 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.936 | 2.011 | 12 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.826 | 0.689 | 8 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=18 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=5 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=33 shims=4 src_fn=14 out_fn=6 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=28 shims=2 src_fn=14 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] bashit-fzf bash->zsh warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->fish warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] bashit-fzf bash->posix warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/bash/bash-it/plugins/available/fzf.plugin.bash
- [WARN] fish-fzf fish->bash warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-fzf fish->zsh warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-fzf fish->posix warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/fzf.fish/conf.d/fzf.fish
- [WARN] fish-autopair fish->bash warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] fish-autopair fish->zsh warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] fish-autopair fish->posix warnings=21 shims=0 src_fn=0 out_fn=0 path=tests/corpus/repos/fish/autopair.fish/conf.d/autopair.fish
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=5 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
