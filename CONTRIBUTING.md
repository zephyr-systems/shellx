# Contributing

Thanks for contributing to ShellX.

## Development Setup

1. Install Odin and ensure `odin` is in `PATH`.
2. Clone the repository.
3. Run tests:

```bash
odin test . -all-packages
./scripts/test_runner.sh
```

## Code Style

- Keep changes focused and small.
- Prefer explicit ownership and cleanup in memory handling.
- Use existing module boundaries (`frontend`, `ir`, `optimizer`, `backend`, `compat`).
- Avoid introducing unnecessary API surface in `shellx` package.

## Testing Requirements

- Add or update tests for behavior changes.
- For translation changes, include integration coverage for affected dialect pairs.
- For API changes, include unit tests in `shellx_test.odin`.
- Run full test suite before submitting.

## Pull Request Process

1. Describe the problem and solution clearly.
2. Include test coverage for new behavior.
3. Mention any compatibility or memory-ownership implications.
4. Keep PR scope tight; split unrelated work.

## Areas That Need Help

- Dialect coverage and edge-case translation accuracy
- Compatibility diagnostics quality
- Frontend/backend parity improvements
- Performance profiling and optimization
