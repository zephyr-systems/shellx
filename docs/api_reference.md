# API Reference

This document describes the public `shellx` package API.

## Ownership Model

`TranslationResult` contains heap-owned fields (`output`, `warnings`, `required_shims`, `supported_features`, `degraded_features`, `unsupported_features`, `findings`, `errors`).
Call `destroy_translation_result(&result)` when done.

`SecurityScanResult` contains heap-owned fields (`findings`, `errors`).
Call `destroy_security_scan_result(&result)` when done.

For `translate_batch`, destroy each element, then `delete(batch)`.

## Enums

### `ShellDialect`

Represents shell dialects:

- `.Bash`
- `.Zsh`
- `.Fish`
- `.POSIX`

### `OptimizationLevel`

- `.None`
- `.Basic`
- `.Standard`
- `.Aggressive`

### `Error`

- `.None`
- `.ParseError`
- `.ParseSyntaxError`
- `.ConversionError`
- `.ConversionUnsupportedDialect`
- `.ValidationError`
- `.ValidationUndefinedVariable`
- `.ValidationDuplicateFunction`
- `.ValidationInvalidControlFlow`
- `.EmissionError`
- `.IOError`
- `.InternalError`

## Types

### `TranslationOptions`

Fields:

- `strict_mode: bool`
- `insert_shims: bool`
- `preserve_comments: bool`
- `source_name: string`
- `optimization_level: OptimizationLevel`

Default: `DEFAULT_TRANSLATION_OPTIONS`.

### `TranslationResult`

Fields:

- `success: bool`
- `output: string`
- `warnings: [dynamic]string`
- `required_shims: [dynamic]string`
- `required_caps: [dynamic]string`
- `supported_features: [dynamic]string`
- `degraded_features: [dynamic]string`
- `unsupported_features: [dynamic]string`
- `findings: [dynamic]SecurityFinding`
- `error: Error`
- `errors: [dynamic]ErrorContext`

### `SecurityFinding`

- `rule_id: string`
- `severity: FindingSeverity`
- `message: string`
- `location: SourceLocation`
- `suggestion: string`
- `phase: string` (`source` or `translated`)

### `SecurityScanRule`

- `rule_id: string`
- `severity: FindingSeverity`
- `pattern: string` (substring match)
- `message: string`
- `suggestion: string`

### `SecurityScanPolicy`

- `use_builtin_rules: bool`
- `block_threshold: FindingSeverity`
- `custom_rules: []SecurityScanRule`

Default: `DEFAULT_SECURITY_SCAN_POLICY`.

### `SecurityScanResult`

- `success: bool`
- `blocked: bool`
- `findings: [dynamic]SecurityFinding`
- `error: Error`
- `errors: [dynamic]ErrorContext`

## Functions

### `translate(source_code, from, to, options := DEFAULT_TRANSLATION_OPTIONS) -> TranslationResult`

Translates shell code between dialects.

Parameters:

- `source_code`: source script text
- `from`: source dialect
- `to`: target dialect
- `options`: translation options

Returns:

- `TranslationResult`

Example:

```odin
result := shellx.translate("echo hello", .Bash, .Fish)
defer shellx.destroy_translation_result(&result)
```

### `translate_file(filepath, from, to, options := DEFAULT_TRANSLATION_OPTIONS) -> TranslationResult`

Reads a file and translates it.

Example:

```odin
result := shellx.translate_file("script.sh", .Bash, .Zsh)
defer shellx.destroy_translation_result(&result)
```

### `translate_batch(files, from, to, options := DEFAULT_TRANSLATION_OPTIONS, allocator := context.allocator) -> [dynamic]TranslationResult`

Translates multiple files.

Example:

```odin
batch := shellx.translate_batch(files, .Bash, .Fish)
defer {
	for &result in batch {
		shellx.destroy_translation_result(&result)
	}
	delete(batch)
}
```

### `scan_security(source_code, dialect, policy := DEFAULT_SECURITY_SCAN_POLICY, source_name := "<input>") -> SecurityScanResult`

Scans source text for security findings without performing translation.

Example:

```odin
policy := shellx.DEFAULT_SECURITY_SCAN_POLICY
policy.custom_rules = []shellx.SecurityScanRule{
	{
		rule_id = "zephyr.custom.source_tmp",
		severity = .High,
		pattern = "/tmp/",
		message = "Temporary source path detected",
		suggestion = "Use trusted immutable module paths",
	},
}
result := shellx.scan_security(code, .Bash, policy)
defer shellx.destroy_security_scan_result(&result)
```

### `scan_security_file(filepath, dialect, policy := DEFAULT_SECURITY_SCAN_POLICY) -> SecurityScanResult`

Reads a file and scans it for security findings.

### `detect_shell(code) -> ShellDialect`

Detects source dialect from content heuristics.

### `detect_shell_from_path(filepath, code) -> ShellDialect`

Detects source dialect using path extension + content.

### `get_version() -> string`

Returns the library version string.

### `destroy_translation_result(result: ^TranslationResult)`

Frees all heap allocations owned by `TranslationResult`.

### `destroy_security_scan_result(result: ^SecurityScanResult)`

Frees all heap allocations owned by `SecurityScanResult`.

### `report_error(ctx: ErrorContext, source_code := "") -> string`

Formats a human-readable error message with location/suggestion context.

## Script Builder API

### `create_script_builder(dialect, arena_capacity := 1024 * 1024) -> ScriptBuilder`

Creates a procedural script builder with owned arena.

### `destroy_script_builder(builder: ^ScriptBuilder)`

Destroys builder-owned arena and invalidates builder program pointer.

### `script_add_var(builder, name, value, literal_type := .String, location := ir.SourceLocation{})`

Adds assignment statement.

### `script_add_call(builder, command, args: ..string)`

Adds call statement from string arguments.

### `script_emit(builder, target, allocator := context.allocator) -> string`

Emits generated script. Caller owns returned string.
