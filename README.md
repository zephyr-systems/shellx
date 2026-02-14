# ShellX

![CI](https://img.shields.io/badge/CI-local%20tests-blue)
![License](https://img.shields.io/badge/license-MIT-blue)

ShellX is an Odin library for translating shell scripts between dialects:

- Bash
- Zsh
- Fish
- POSIX shell

## Vision

ShellX aims to provide a practical shell translation pipeline that is:

- Safe to embed in other Odin projects
- Explicit about errors and compatibility limits
- Fast enough for batch translation workflows

## Features

- Dialect detection from source text and file path
- End-to-end translation pipeline:
  - Parse -> IR -> optimize -> emit
- Structured error reporting with source locations
- Compatibility analysis and optional shim discovery
- Runtime bridge shims for cross-shell hook/event and ZLE-widget compatibility
- Batch and file-based translation APIs
- Builder utilities for constructing scripts in tests/examples

## Installation

ShellX is currently consumed as source in an Odin workspace.

1. Clone the repository.
2. Ensure Odin is installed and available in `PATH`.
3. Build or test from the repo root:

```bash
odin test . -all-packages
```

## Quick Start

```odin
package app

import "core:fmt"
import "shellx"

main :: proc() {
	result := shellx.translate("x=5\necho $x\n", .Bash, .Fish)
	defer shellx.destroy_translation_result(&result)

	if !result.success {
		fmt.println("translation failed")
		for err in result.errors {
			fmt.println(shellx.report_error(err))
		}
		return
	}

	fmt.println(result.output)
}
```

## Usage Examples

### Detect source dialect

```odin
dialect := shellx.detect_shell(source_code)
```

```odin
dialect := shellx.detect_shell_from_path("script.zsh", source_code)
```

### Translate from file

```odin
result := shellx.translate_file("./script.sh", .Bash, .Zsh)
defer shellx.destroy_translation_result(&result)
```

### Read structured translation report

`TranslationResult` includes compatibility and security metadata for policy engines.

```odin
opts := shellx.DEFAULT_TRANSLATION_OPTIONS
opts.insert_shims = true
opts.strict_mode = true

result := shellx.translate_file("./plugin.zsh", .Zsh, .Bash, opts)
defer shellx.destroy_translation_result(&result)

if !result.success {
	// strict_mode can fail when unsupported_features is non-empty
	for feature in result.unsupported_features {
		fmt.println("unsupported:", feature)
	}
	for finding in result.findings {
		fmt.println("finding:", finding.rule_id, finding.severity, finding.phase)
	}
	return
}

for feature in result.supported_features {
	fmt.println("supported:", feature)
}
for feature in result.degraded_features {
	fmt.println("degraded:", feature)
}
for finding in result.findings {
	fmt.println("finding:", finding.rule_id, finding.severity, finding.phase)
}
```

### Batch translation

```odin
results := shellx.translate_batch(files, .Bash, .Fish)
defer {
	for &r in results {
		shellx.destroy_translation_result(&r)
	}
	delete(results)
}
```

### Security scanning API

Use ShellX as structured scanner (hybrid built-in + caller policy rules):

```odin
policy := shellx.DEFAULT_SECURITY_SCAN_POLICY
policy.custom_rules = []shellx.SecurityScanRule{
	{
		rule_id = "zephyr.custom.source_tmp",
		enabled = true,
		severity = .High,
		match_kind = .Regex,
		category = "source",
		confidence = 0.9,
		phases = { .Source },
		pattern = "/tmp/",
		message = "Temporary source path detected",
		suggestion = "Use trusted immutable module paths",
	},
}
policy.allowlist_paths = []string{"trusted/vendor"}
policy.ruleset_version = "zephyr-policy-2026-02"

opts := shellx.DEFAULT_SECURITY_SCAN_OPTIONS
opts.max_file_size = 4 * 1024 * 1024
opts.timeout_ms = 5000
opts.ast_parse_failure_mode = .FailOpen
opts.max_files = 0
opts.max_total_bytes = 0

scan := shellx.scan_security_file("./plugin.zsh", .Zsh, policy, opts)
defer shellx.destroy_security_scan_result(&scan)

// success=false only for scanner runtime failures (I/O, timeout, invalid rule)
if !scan.success {
	for err in scan.errors {
		fmt.println(shellx.report_error(err))
	}
}

if scan.blocked {
	for finding in scan.findings {
		fmt.println("blocked:", finding.rule_id, finding.severity, finding.fingerprint)
	}
}

json_blob := shellx.format_security_scan_json(scan, true)
defer delete(json_blob)
fmt.println(json_blob)
```

Policy loading + validation:

```odin
policy_json := `{"use_builtin_rules":true,"block_threshold":2}`
loaded_policy, validation_errors, ok := shellx.load_security_policy_json(policy_json)
defer {
	for err in validation_errors {
		delete(err.rule_id)
		delete(err.message)
		delete(err.suggestion)
		delete(err.snippet)
	}
	delete(validation_errors)
}
if !ok {
	for err in validation_errors {
		fmt.println(shellx.report_error(err))
	}
	return
}
policy = loaded_policy
```

Batch scanning:

```odin
files := []string{"./plugins/a.plugin.zsh", "./plugins/b.plugin.zsh"}
batch := shellx.scan_security_batch(files, .Zsh, policy, opts)
defer shellx.destroy_security_scan_batch(&batch)

batch_json := shellx.format_security_scan_batch_json(batch[:], true)
defer delete(batch_json)
fmt.println(batch_json)
```

Full Zephyr-oriented example:

- `examples/zephyr_security_scan.odin`

### Build scripts programmatically

```odin
builder := shellx.create_script_builder(.Bash)
defer shellx.destroy_script_builder(&builder)

shellx.script_add_var(&builder, "name", "world")
shellx.script_add_call(&builder, "echo", "hello", "$name")

output := shellx.script_emit(&builder, .Bash)
defer delete(output)
```

## Documentation

- [API reference](docs/api_reference.md)
- [Architecture](docs/architecture.md)
- [IR specification](docs/ir_spec.md)
- [Compatibility matrix](docs/compatibility_matrix.md)
- [Explicit failure boundaries](docs/compatibility_matrix.md#explicit-failure-boundaries)
- [Contributing](CONTRIBUTING.md)

## Status

ShellX has reached a production baseline for corpus-covered plugin/theme translation:

- Parser matrix: `219/219` passes
- Parser validation failures: `0`
- Semantic differential checks: `51/51` passed
- Unit tests: `120/120` passed
- No silent degradation: translation avoids no-op/stub fallback behavior

Run the integration tests below for the current baseline.

## Golden Stability Snapshot

Baseline validated on **2026-02-14**:

- Cross-dialect corpus runs: `219`
- Parser matrix: `219/219` passes
- Parser validation failures: `0`
- Semantic differential checks: `51/51` passed

Notable baseline capabilities:

- Hook/event bridge shims (`precmd`/`preexec`/Fish events) for runtime parity.
- ZLE widget bridge for `zle -N` / `bindkey` flows when targeting Bash.
- Semantic probes for async workers, signal traps, subshell boundaries, pipeline status, and terminal-control behavior.

Reproduce:

```bash
odin test . -all-packages
odin build tests/corpus/stability_runner.odin -file -out:build/stability_runner
./build/stability_runner --semantic
```

Artifacts:

- Latest report: `tests/corpus/stability_report.md`
- Frozen baseline: `tests/corpus/stability_report.golden.md`
- Release baseline notes: `docs/release_baseline_2026-02-14.md`
