# API Reference

This document describes the public `shellx` package API.

## Ownership Model

`TranslationResult` contains heap-owned fields (`output`, `warnings`, `required_shims`, `supported_features`, `degraded_features`, `unsupported_features`, `findings`, `errors`).
Call `destroy_translation_result(&result)` when done.

`SecurityScanResult` contains heap-owned fields (`findings`, `errors`, `ruleset_version`).
Call `destroy_security_scan_result(&result)` when done.

For `scan_security_batch`, call `destroy_security_scan_batch(&batch)` when done.

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
- `.ScanError`
- `.ScanParseError`
- `.ScanInvalidRule`
- `.ScanTimeout`
- `.ScanMaxFileSizeExceeded`
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
- `category: string`
- `confidence: f32`
- `matched_text: string`
- `fingerprint: string`

### `SecurityMatchKind`

- `.Substring`
- `.Regex`
- `.AstCommand`

### `SecurityScanPhase`

- `.Source`
- `.Translated`

### `SecurityScanPhases`

`bit_set[SecurityScanPhase; u8]`

### `AstParseFailureMode`

- `.FailOpen`
- `.FailClosed`

### `SecurityScanRule`

- `rule_id: string`
- `enabled: bool`
- `severity: FindingSeverity`
- `match_kind: SecurityMatchKind`
- `pattern: string` (substring or regex pattern payload)
- `category: string`
- `confidence: f32`
- `phases: SecurityScanPhases`
- `command_name: string` (for `.AstCommand`)
- `arg_pattern: string` (for `.AstCommand`)
- `message: string`
- `suggestion: string`

### `SecurityRuleOverride`

- `rule_id: string`
- `enabled: bool`
- `severity_override: FindingSeverity`
- `has_severity_override: bool`

### `SecurityScanPolicy`

- `use_builtin_rules: bool`
- `block_threshold: FindingSeverity`
- `custom_rules: []SecurityScanRule`
- `allowlist_paths: []string`
- `allowlist_commands: []string`
- `rule_overrides: []SecurityRuleOverride`
- `ruleset_version: string`

### `SecurityScanOptions`

- `max_file_size: int`
- `timeout_ms: int`
- `scan_translated_output: bool`
- `include_phases: SecurityScanPhases`
- `ast_parse_failure_mode: AstParseFailureMode`
- `max_files: int`
- `max_total_bytes: int`

Default: `DEFAULT_SECURITY_SCAN_OPTIONS`.

### `SecurityScanStats`

- `files_scanned: int`
- `lines_scanned: int`
- `rules_evaluated: int`
- `duration_ms: i64`

### `SecurityBatchItemResult`

- `filepath: string`
- `result: SecurityScanResult`

Default: `DEFAULT_SECURITY_SCAN_POLICY`.

### `SecurityScanResult`

- `success: bool`
- `blocked: bool`
- `findings: [dynamic]SecurityFinding`
- `error: Error`
- `errors: [dynamic]ErrorContext`
- `ruleset_version: string`
- `stats: SecurityScanStats`

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

### `scan_security(source_code, dialect, policy := DEFAULT_SECURITY_SCAN_POLICY, source_name := "<input>", options := DEFAULT_SECURITY_SCAN_OPTIONS, translated_output := "") -> SecurityScanResult`

Scans source text for policy findings and optional AST-aware checks.

Runtime failures (I/O/timeout/invalid rule/parse infra) set `success=false`.
Findings alone do not set `success=false`.

AST parse fallback behavior:

- `.FailOpen`: parse error is reported in `errors` but scan keeps `success=true`.
- `.FailClosed`: parse error sets `success=false`.

Example:

```odin
policy := shellx.DEFAULT_SECURITY_SCAN_POLICY
policy.custom_rules = []shellx.SecurityScanRule{
	{
		rule_id = "zephyr.custom.source_tmp",
		enabled = true,
		severity = .High,
		match_kind = .Regex,
		pattern = "/tmp/",
		message = "Temporary source path detected",
		suggestion = "Use trusted immutable module paths",
	},
}
opts := shellx.DEFAULT_SECURITY_SCAN_OPTIONS
opts.timeout_ms = 5000
result := shellx.scan_security(code, .Bash, policy, "<input>", opts)
defer shellx.destroy_security_scan_result(&result)
```

### `scan_security_file(filepath, dialect, policy := DEFAULT_SECURITY_SCAN_POLICY, options := DEFAULT_SECURITY_SCAN_OPTIONS) -> SecurityScanResult`

Reads a file and scans it for security findings.

### `scan_security_batch(files, dialect, policy := DEFAULT_SECURITY_SCAN_POLICY, options := DEFAULT_SECURITY_SCAN_OPTIONS, allocator := context.allocator) -> [dynamic]SecurityBatchItemResult`

Scans many files and returns one result per file.

Guardrails:

- `options.max_files`
- `options.max_total_bytes`

### `format_security_scan_json(result, pretty := false, allocator := context.allocator) -> string`

Returns a JSON representation of a scan result.

### `format_security_scan_batch_json(results, pretty := false, allocator := context.allocator) -> string`

Returns a JSON representation of batch scan results.

### `validate_security_policy(policy) -> [dynamic]ErrorContext`

Validates scanner policy and returns all actionable validation errors.

### `load_security_policy_json(data) -> (SecurityScanPolicy, [dynamic]ErrorContext, bool)`

Loads and validates a scanner policy from JSON.

Enum fields accept string labels (recommended), for example:

- `severity`: `"Info"`, `"Warning"`, `"High"`, `"Critical"`
- `match_kind`: `"Substring"`, `"Regex"`, `"AstCommand"`
- `phases`: `["Source"]`, `["Translated"]`

### `load_security_policy_file(path) -> (SecurityScanPolicy, [dynamic]ErrorContext, bool)`

Loads and validates a scanner policy from JSON file path.

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

### `destroy_security_scan_batch(results: ^[dynamic]SecurityBatchItemResult)`

Frees all heap allocations owned by `scan_security_batch` output.

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
