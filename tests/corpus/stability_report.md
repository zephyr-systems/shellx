# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.382 | 1.503 | 11 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.214 | 1.017 | 8 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.286 | 0.874 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.169 | 2.037 | 6 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.163 | 2.037 | 6 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.169 | 2.037 | 6 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.881 | 0.507 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.933 | 2.197 | 10 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.832 | 0.710 | 7 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=18 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=5 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=33 shims=4 src_fn=14 out_fn=6 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=28 shims=2 src_fn=14 out_fn=2 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=5 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=2 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
