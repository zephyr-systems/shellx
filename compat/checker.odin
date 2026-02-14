package compat

import "../ir"
import "core:fmt"
import "core:strings"

// Severity represents the severity level of a compatibility warning
Severity :: enum {
	Info, // Informational, no action needed
	Warning, // Potential issue, may need attention
	Error, // Will not work in target dialect
}

// CompatibilityWarning represents a single compatibility warning
CompatibilityWarning :: struct {
	feature:    string,
	severity:   Severity,
	message:    string,
	suggestion: string,
	line:       int, // Source line if available
	column:     int, // Source column if available
}

// CompatibilityResult contains all warnings from a compatibility check
CompatibilityResult :: struct {
	warnings:     [dynamic]CompatibilityWarning,
	has_errors:   bool,
	has_warnings: bool,
}

// create_compatibility_result creates a new result container
create_compatibility_result :: proc(allocator := context.allocator) -> CompatibilityResult {
	return CompatibilityResult {
		warnings = make([dynamic]CompatibilityWarning, allocator),
		has_errors = false,
		has_warnings = false,
	}
}

// destroy_compatibility_result cleans up the result
destroy_compatibility_result :: proc(result: ^CompatibilityResult) {
	delete(result.warnings)
}

// add_warning adds a warning to the result
add_warning :: proc(
	result: ^CompatibilityResult,
	feature: string,
	severity: Severity,
	message: string,
	suggestion: string,
) {
	for w in result.warnings {
		if w.feature == feature && w.message == message {
			return
		}
	}

	append(
		&result.warnings,
		CompatibilityWarning {
			feature = feature,
			severity = severity,
			message = message,
			suggestion = suggestion,
			line = 0,
			column = 0,
		},
	)

	if severity == .Error {
		result.has_errors = true
	} else if severity == .Warning {
		result.has_warnings = true
	}
}

// check_compatibility checks an IR program for compatibility issues
// Returns a result containing all warnings
UsedFeatures :: struct {
	condition_semantics: bool,
	indexed_arrays:      bool,
	assoc_arrays:        bool,
	fish_list_indexing:  bool,
	arrays_lists:        bool,
	zsh_hooks:           bool,
	fish_events:         bool,
	prompt_hooks:        bool,
	hooks_events:        bool,
	zle_widgets:         bool,
	parameter_expansion: bool,
	process_substitution: bool,
}

is_prompt_hook_name :: proc(name: string) -> bool {
	switch name {
	case "precmd", "preexec", "fish_prompt", "fish_right_prompt":
		return true
	}
	return false
}

is_fish_event_name :: proc(name: string) -> bool {
	switch name {
	case "fish_preexec", "fish_postexec", "fish_prompt", "fish_right_prompt":
		return true
	}
	return false
}

mark_hook_features_from_text :: proc(text: string, features: ^UsedFeatures) {
	if text == "" {
		return
	}
	if strings.contains(text, "add-zsh-hook ") {
		features.zsh_hooks = true
	}
	if strings.contains(text, "--on-event fish_preexec") ||
		strings.contains(text, "--on-event fish_postexec") ||
		strings.contains(text, "--on-event fish_prompt") ||
		strings.contains(text, "--on-event fish_right_prompt") ||
		strings.contains(text, "function fish_preexec") ||
		strings.contains(text, "function fish_postexec") {
		features.fish_events = true
	}
	if strings.contains(text, "function precmd") ||
		strings.contains(text, "function preexec") ||
		strings.contains(text, "precmd()") ||
		strings.contains(text, "preexec()") ||
		strings.contains(text, "function fish_prompt") ||
		strings.contains(text, "function fish_right_prompt") {
		features.prompt_hooks = true
	}
	features.hooks_events = features.zsh_hooks || features.fish_events || features.prompt_hooks
}

mark_zle_features_from_text :: proc(text: string, features: ^UsedFeatures) {
	if text == "" {
		return
	}
	if strings.contains(text, "zle -N ") ||
		strings.contains(text, "bindkey ") ||
		strings.contains(text, " zle ") ||
		strings.has_prefix(strings.trim_space(text), "zle ") ||
		strings.contains(text, "BUFFER") ||
		strings.contains(text, "CURSOR") ||
		strings.contains(text, "LBUFFER") ||
		strings.contains(text, "RBUFFER") {
		features.zle_widgets = true
	}
}

contains_any :: proc(text: string, patterns: []string) -> bool {
	for pattern in patterns {
		if strings.contains(text, pattern) {
			return true
		}
	}
	return false
}

has_array_list_indicators :: proc(text: string) -> bool {
	if text == "" {
		return false
	}

	return contains_any(
		text,
		[]string{
			"=(",
			"[@]",
			"[*]",
			"declare -a",
			"typeset -a",
			"local -a",
			"readonly -a",
			"$argv[",
			"${",
		},
	) && (contains_any(text, []string{"=(", "[@]", "[*]", "$argv["}) || strings.contains(text, "["))
}

has_indexed_array_indicators :: proc(text: string) -> bool {
	if text == "" {
		return false
	}
	return contains_any(text, []string{
		"=(",
		"[@]",
		"[*]",
		"declare -a",
		"typeset -a",
		"local -a",
		"readonly -a",
	})
}

has_assoc_array_indicators :: proc(text: string) -> bool {
	if text == "" {
		return false
	}
	return contains_any(text, []string{
		"declare -A",
		"typeset -A",
		"local -A",
		"readonly -A",
		"][",
	})
}

has_fish_list_indexing_indicators :: proc(text: string) -> bool {
	if text == "" {
		return false
	}
	if strings.contains(text, "$argv[") {
		return true
	}
	for i := 0; i+1 < len(text); i += 1 {
		if text[i] != '$' {
			continue
		}
		j := i + 1
		for j < len(text) {
			c := text[j]
			if (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_' {
				j += 1
				continue
			}
			break
		}
		if j < len(text) && text[j] == '[' {
			return true
		}
	}
	return false
}

mark_features_from_text :: proc(text: string, features: ^UsedFeatures) {
	if text == "" {
		return
	}
	if strings.contains(text, "[[") || strings.contains(text, "]]") || strings.contains(text, "string match") {
		features.condition_semantics = true
	}
	if strings.contains(text, "${") {
		features.parameter_expansion = true
	}
	if strings.contains(text, "<(") || strings.contains(text, ">(") {
		features.process_substitution = true
	}
	features.indexed_arrays = features.indexed_arrays || has_indexed_array_indicators(text)
	features.assoc_arrays = features.assoc_arrays || has_assoc_array_indicators(text)
	features.fish_list_indexing = features.fish_list_indexing || has_fish_list_indexing_indicators(text)
	features.arrays_lists = features.indexed_arrays || features.assoc_arrays || features.fish_list_indexing || has_array_list_indicators(text)
	mark_hook_features_from_text(text, features)
	mark_zle_features_from_text(text, features)
}

scan_expr_features :: proc(expr: ir.Expression, features: ^UsedFeatures) {
	if expr == nil {
		return
	}

	#partial switch e in expr {
	case ^ir.ArrayLiteral:
		features.indexed_arrays = true
		features.arrays_lists = true
		for elem in e.elements {
			scan_expr_features(elem, features)
		}
	case ^ir.CallExpr:
		if e.function != nil {
			name := e.function.name
			if name == "test" || name == "[" || name == "[[" || name == "string" {
				features.condition_semantics = true
			}
			if name == "add-zsh-hook" {
				features.zsh_hooks = true
				features.hooks_events = true
			}
			if name == "emit" {
				features.fish_events = true
				features.hooks_events = true
			}
			if is_prompt_hook_name(name) {
				features.prompt_hooks = true
				features.hooks_events = true
			}
		}
		for arg in e.arguments {
			scan_expr_features(arg, features)
		}
	case:
		// Fall through to text heuristics for remaining expression types.
	}

	mark_features_from_text(ir.expr_to_string(expr), features)
}

scan_call_features :: proc(call: ir.Call, features: ^UsedFeatures) {
	if call.function != nil {
		name := call.function.name
		if name == "test" || name == "[" || name == "[[" || name == "string" || name == "string match" {
			features.condition_semantics = true
		}
		if name == "add-zsh-hook" {
			features.zsh_hooks = true
			features.hooks_events = true
		}
		if name == "emit" {
			features.fish_events = true
			features.hooks_events = true
		}
		if is_prompt_hook_name(name) || is_fish_event_name(name) {
			features.prompt_hooks = true
			if is_fish_event_name(name) {
				features.fish_events = true
			}
			features.hooks_events = true
		}
		if name == "zle" || name == "bindkey" {
			features.zle_widgets = true
		}
	}

	for arg in call.arguments {
		scan_expr_features(arg, features)
	}
}

scan_stmt_features :: proc(stmt: ir.Statement, features: ^UsedFeatures) {
	switch stmt.type {
	case .Assign:
		scan_expr_features(stmt.assign.value, features)
	case .Call:
		scan_call_features(stmt.call, features)
	case .Logical:
		features.condition_semantics = true
		for seg in stmt.logical.segments {
			scan_call_features(seg.call, features)
		}
	case .Case:
		features.condition_semantics = true
		scan_expr_features(stmt.case_.value, features)
		for arm in stmt.case_.arms {
			for nested in arm.body {
				scan_stmt_features(nested, features)
			}
		}
	case .Return:
		scan_expr_features(stmt.return_.value, features)
	case .Branch:
		features.condition_semantics = true
		scan_expr_features(stmt.branch.condition, features)
		for nested in stmt.branch.then_body {
			scan_stmt_features(nested, features)
		}
		for nested in stmt.branch.else_body {
			scan_stmt_features(nested, features)
		}
	case .Loop:
		scan_expr_features(stmt.loop.items, features)
		scan_expr_features(stmt.loop.condition, features)
		for nested in stmt.loop.body {
			scan_stmt_features(nested, features)
		}
	case .Pipeline:
		for cmd in stmt.pipeline.commands {
			scan_call_features(cmd, features)
		}
	}
}

scan_program_features :: proc(program: ^ir.Program) -> UsedFeatures {
	features := UsedFeatures{}
	if program == nil {
		return features
	}

	for fn in program.functions {
		if is_prompt_hook_name(fn.name) {
			features.prompt_hooks = true
			features.hooks_events = true
		}
		if is_fish_event_name(fn.name) {
			features.fish_events = true
			features.hooks_events = true
		}
		for stmt in fn.body {
			scan_stmt_features(stmt, &features)
		}
	}

	for stmt in program.statements {
		scan_stmt_features(stmt, &features)
	}

	return features
}

scan_source_features :: proc(source_code: string) -> UsedFeatures {
	features := UsedFeatures{}
	if source_code == "" {
		return features
	}

	if contains_any(source_code, []string{"[[", "]]", "string match", " test "}) {
		features.condition_semantics = true
	}
	if has_array_list_indicators(source_code) {
		features.indexed_arrays = true
		features.arrays_lists = true
	}
	if has_assoc_array_indicators(source_code) {
		features.assoc_arrays = true
		features.arrays_lists = true
	}
	if has_fish_list_indexing_indicators(source_code) {
		features.fish_list_indexing = true
		features.arrays_lists = true
	}
	mark_hook_features_from_text(source_code, &features)
	mark_zle_features_from_text(source_code, &features)
	if strings.contains(source_code, "${") {
		features.parameter_expansion = true
	}
	if contains_any(source_code, []string{"<(", ">("}) {
		features.process_substitution = true
	}

	return features
}

check_compatibility :: proc(
	from: ir.ShellDialect,
	to: ir.ShellDialect,
	program: ^ir.Program,
	source_code := "",
	allocator := context.allocator,
) -> CompatibilityResult {
	result := create_compatibility_result(allocator)

	// Quick check if source and target are the same
	if from == to {
		return result // No compatibility issues when translating to same dialect
	}

	features := scan_program_features(program)
	source_features := scan_source_features(source_code)
	features.condition_semantics = features.condition_semantics || source_features.condition_semantics
	features.indexed_arrays = features.indexed_arrays || source_features.indexed_arrays
	features.assoc_arrays = features.assoc_arrays || source_features.assoc_arrays
	features.fish_list_indexing = features.fish_list_indexing || source_features.fish_list_indexing
	features.arrays_lists = features.arrays_lists || source_features.arrays_lists
	features.zsh_hooks = features.zsh_hooks || source_features.zsh_hooks
	features.fish_events = features.fish_events || source_features.fish_events
	features.prompt_hooks = features.prompt_hooks || source_features.prompt_hooks
	features.hooks_events = features.hooks_events || source_features.hooks_events
	features.zle_widgets = features.zle_widgets || source_features.zle_widgets
	features.parameter_expansion = features.parameter_expansion || source_features.parameter_expansion
	features.process_substitution = features.process_substitution || source_features.process_substitution

	if to == .Fish {
		if features.indexed_arrays {
			add_warning(
				&result,
				"indexed_arrays",
				.Error,
				"Indexed array semantics may not translate directly to Fish lists",
				"Insert array/list bridge shim and normalize indexing semantics",
			)
		}
		if features.assoc_arrays {
			add_warning(
				&result,
				"assoc_arrays",
				.Error,
				"Associative arrays are not natively compatible with Fish",
				"Use map emulation helpers or flatten key/value representation",
			)
		}
		if features.fish_list_indexing && from != .Fish {
			add_warning(
				&result,
				"fish_list_indexing",
				.Warning,
				"List indexing semantics may differ after translation to Fish",
				"Use list bridge shim and normalize index access patterns",
			)
		}
		if features.condition_semantics {
			add_warning(
				&result,
				"condition_semantics",
				.Warning,
				"Condition/test semantics may differ in Fish",
				"Use fish 'test' and 'string match' wrappers for translated conditions",
			)
		}
		if features.parameter_expansion {
			add_warning(
				&result,
				"parameter_expansion",
				.Warning,
				"Parameter expansion modifiers may not be compatible with Fish",
				"Rewrite with fish 'string' builtins or use parameter shim wrappers",
			)
		}
		if features.process_substitution {
			add_warning(
				&result,
				"process_substitution",
				.Error,
				"Process substitution is not supported in Fish",
				"Use temporary files and process-substitution shim wrappers",
			)
		}
		if features.zsh_hooks {
			add_warning(
				&result,
				"zsh_hooks",
				.Warning,
				"Zsh hook registration APIs differ in Fish",
				"Use hook bridge shims for add-zsh-hook/precmd/preexec mapping",
			)
		}
		if features.fish_events {
			add_warning(
				&result,
				"fish_events",
				.Warning,
				"Fish event handlers may not map directly",
				"Use fish event bridge shims and explicit registration wrappers",
			)
		}
		if features.prompt_hooks {
			add_warning(
				&result,
				"prompt_hooks",
				.Warning,
				"Prompt hook function semantics differ in Fish",
				"Use hook bridge shims for prompt/preexec flow",
			)
		}
	}

	if to == .POSIX {
		if features.indexed_arrays || features.assoc_arrays {
			add_warning(
				&result,
				"indexed_arrays",
				.Error,
				"Array features are not POSIX portable",
				"Flatten arrays or use shim helpers that emulate list behavior",
			)
		}
		if features.zsh_hooks || features.fish_events || features.prompt_hooks {
			add_warning(
				&result,
				"prompt_hooks",
				.Warning,
				"Shell hook/event behavior is not standardized in POSIX sh",
				"Use portable function wrappers and explicit call sites",
			)
		}
		if features.condition_semantics && from == .Fish {
			add_warning(
				&result,
				"condition_semantics",
				.Warning,
				"Fish test semantics can differ from POSIX test",
				"Use shim wrapper that maps Fish condition operators to POSIX test",
			)
		}
	}

	if from == .Fish && (to == .Bash || to == .Zsh) {
		if features.fish_list_indexing || features.arrays_lists {
			add_warning(
				&result,
				"fish_list_indexing",
				.Warning,
				"Fish list behavior may not map one-to-one to Bash/Zsh arrays",
				"Use list/array bridge shim for indexing and joining behavior",
			)
		}
		if features.condition_semantics {
			add_warning(
				&result,
				"condition_semantics",
				.Warning,
				"Fish condition syntax differs from Bash/Zsh test syntax",
				"Use condition bridge shim wrappers to normalize behavior",
			)
		}
		if features.fish_events || features.prompt_hooks {
			add_warning(
				&result,
				"fish_events",
				.Warning,
				"Fish event functions do not directly map to Bash/Zsh hooks",
				"Use hook/event bridge shim and explicit registration wrappers",
			)
		}
	}

	if from == .Zsh && (to == .Bash || to == .POSIX) {
		if features.zsh_hooks || features.prompt_hooks {
			add_warning(
				&result,
				"zsh_hooks",
				.Warning,
				"Zsh hook APIs (precmd/preexec/add-zsh-hook) do not map directly",
				"Use hook bridge shims and explicit registration wrappers",
			)
		}
		if features.zle_widgets {
			add_warning(
				&result,
				"zle_widgets",
				.Warning,
				"ZLE widgets/key bindings are Zsh-specific and need runtime emulation",
				"Use zle widget bridge shim (zle -N/bindkey -> __shellx_zle_* runtime)",
			)
		}
	}

	return result
}

// format_warning formats a single warning as a string
format_warning :: proc(warning: CompatibilityWarning, allocator := context.allocator) -> string {
	severity_str: string
	switch warning.severity {
	case .Info:
		severity_str = "INFO"
	case .Warning:
		severity_str = "WARNING"
	case .Error:
		severity_str = "ERROR"
	}

	return fmt.aprintf(
		"[%s] %s: %s\n  Suggestion: %s",
		severity_str,
		warning.feature,
		warning.message,
		warning.suggestion,
		allocator = allocator,
	)
}

// format_result formats all warnings in a result
format_result :: proc(
	result: ^CompatibilityResult,
	allocator := context.temp_allocator,
) -> string {
	if len(result.warnings) == 0 {
		return "No compatibility issues found."
	}

	// Use temp allocator for building string
	builder := strings.builder_make(0, 1024, context.temp_allocator)

	// Summary
	strings.write_string(&builder, "Compatibility Check Results:\n")
	fmt.sbprintf(&builder, "  Total warnings: %d\n", len(result.warnings))
	fmt.sbprintf(&builder, "  Errors: %v\n", result.has_errors)
	fmt.sbprintf(&builder, "  Warnings: %v\n\n", result.has_warnings)

	// Individual warnings
	for warning in result.warnings {
		formatted := format_warning(warning, context.temp_allocator)
		strings.write_string(&builder, formatted)
		strings.write_string(&builder, "\n\n")
	}

	// Copy final string to provided allocator
	return strings.clone(strings.to_string(builder), allocator)
}

// has_errors returns true if the result contains any errors
has_errors :: proc(result: ^CompatibilityResult) -> bool {
	return result.has_errors
}

// has_warnings returns true if the result contains any warnings
has_warnings :: proc(result: ^CompatibilityResult) -> bool {
	return result.has_warnings
}

// should_fail_on_strict returns true if strict mode should fail
should_fail_on_strict :: proc(result: ^CompatibilityResult) -> bool {
	return result.has_errors
}
