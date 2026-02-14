# Release Baseline (2026-02-14)

This file freezes the validated state used for ShellX `0.4.0`.

## Commands
- `odin test . -all-packages`
- `odin build tests/corpus/stability_runner.odin -file -out:build/stability_runner`
- `./build/stability_runner --semantic`

## Results
- Unit/integration tests: passing.
- Corpus report: `tests/corpus/stability_report.md`.
- Frozen copy: `tests/corpus/stability_report.golden.md`.
- Cross-dialect runs: `219`.
- Parser matrix: `219/219` passes.
- Parser validation failures: none.
- Semantic differential checks: `51/51` passed.

## Included runtime parity bridges
- Hook/event bridge shims (`precmd`/`preexec`/Fish events).
- ZLE widget bridge for Zsh widget/keybind patterns translated to Bash runtime helpers.
