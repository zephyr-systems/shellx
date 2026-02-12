# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.368 | 1.545 | 12 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.258 | 1.111 | 9 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0.250 | 0.884 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.513 | 2.744 | 9 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.478 | 2.444 | 8 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 0.514 | 2.744 | 9 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.958 | 1.128 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 1.021 | 2.407 | 12 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 0.913 | 1.121 | 8 |

## Failures


## High Warning Runs

- [WARN] zsh-autosuggestions zsh->bash warnings=31 shims=1 src_fn=30 out_fn=23 path=tests/corpus/repos/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
- [WARN] ohmyzsh-z zsh->bash warnings=26 shims=1 src_fn=14 out_fn=10 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->fish warnings=32 shims=4 src_fn=14 out_fn=10 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] ohmyzsh-z zsh->posix warnings=32 shims=2 src_fn=14 out_fn=8 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh
- [WARN] fish-replay fish->posix warnings=202 shims=0 src_fn=1 out_fn=0 path=tests/corpus/repos/fish/replay.fish/functions/replay.fish
- [WARN] zsh-spaceship zsh->bash warnings=24 shims=1 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->fish warnings=27 shims=4 src_fn=1 out_fn=9 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme
- [WARN] zsh-spaceship zsh->posix warnings=29 shims=2 src_fn=1 out_fn=7 path=tests/corpus/repos/zsh/spaceship-prompt/spaceship.zsh-theme

## Validator Rule Failures

- No validator rule failures.
