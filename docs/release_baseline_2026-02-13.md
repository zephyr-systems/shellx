# Release Baseline (2026-02-13)

This file freezes the validated state used for ShellX `0.2.0`.

## Commands
- `odin test . -all-packages`
- `odin build tests/corpus/stability_runner.odin -file -out:build/stability_runner`
- `./build/stability_runner --semantic`

## Results
- Unit/integration tests: passing.
- Corpus report: `tests/corpus/stability_report.md`.
- Frozen copy: `tests/corpus/stability_report.golden.md`.
- Cross-dialect runs: `126`.
- Parser validation failures: none.
- Semantic differential checks: `22/22` passed.
