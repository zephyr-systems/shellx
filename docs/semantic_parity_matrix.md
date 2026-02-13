# Semantic Parity Matrix

This matrix defines the functional parity targets for ShellX plugin translation.

## Scope

- Source dialects: Bash, Zsh, Fish, POSIX
- Target dialects: Bash, Zsh, Fish, POSIX
- Primary workload: plugin and theme scripts used by shell plugin managers

## Parity Features

| Feature | What must match |
|---|---|
| Arrays/Maps | Element access, append/update, key/value lookup, length checks |
| Hooks/Events | Registration semantics, deduplication, dispatch ordering |
| Condition/Test | Truthiness and matching behavior for translated test forms |
| Parameter Expansion | Default/required/length and supported modifiers |
| Process Substitution | Read/write behavior via translated shim paths |
| Source/Load | Equivalent source/include behavior and failure propagation |

## Current Measurement

The corpus stability report includes a **Semantic Parity Matrix** section with per-pair feature counts:

- `tests/corpus/stability_report.md`

Those counts are derived from capability/shim requirements observed during translation and are used to prioritize semantic behavior tests.

## Acceptance Targets

1. Parser-valid output for all corpus pair runs.
2. Runtime behavior tests for all parity features above on representative corpus snippets.
3. No broad text rewrites for shim insertion; only scoped, feature-aware rewrites.
4. Capability-driven prelude/shim emission only when required by detected gaps.
