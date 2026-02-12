# ShellX Corpus Stability Report

Cases configured: 42

Cross-dialect runs executed: 126

## Pair Summary

| Pair | Cases | Translate | Parse | Plugin Parse | Theme Parse | Parse Warn | Compat Warn | Avg Size Ratio | Avg Fn Ratio | With Shims |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bash->fish | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0 | 42 | 0.702 | 2.638 | 15 |
| bash->posix | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0 | 12 | 0.434 | 1.258 | 12 |
| bash->zsh | 16 | 16/16 | 16/16 | 10/10 | 6/6 | 0 | 0 | 0.392 | 0.545 | 0 |
| fish->bash | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 1 | 18 | 0.540 | 2.449 | 10 |
| fish->posix | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 1 | 17 | 0.525 | 2.403 | 10 |
| fish->zsh | 11 | 11/11 | 11/11 | 10/10 | 1/1 | 1 | 18 | 0.541 | 2.449 | 10 |
| zsh->bash | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 76 | 4 | 0.989 | 1.470 | 4 |
| zsh->fish | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 76 | 58 | 1.174 | 2.971 | 15 |
| zsh->posix | 15 | 15/15 | 15/15 | 10/10 | 5/5 | 76 | 22 | 0.991 | 1.625 | 14 |

## Failures


## High Warning Runs

- [WARN] ohmyzsh-z zsh->fish warnings=20(parse=14 compat=6) shims=6 src_fn=14 out_fn=12 path=tests/corpus/repos/zsh/ohmyzsh/plugins/z/z.plugin.zsh

## Validator Rule Failures

- No validator rule failures.
