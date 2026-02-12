package compat

import "../ir"
import "core:fmt"

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
check_compatibility :: proc(
	from: ir.ShellDialect,
	to: ir.ShellDialect,
	program: ^ir.Program,
	allocator := context.allocator,
) -> CompatibilityResult {
	result := create_compatibility_result(allocator)

	// Quick check if source and target are the same
	if from == to {
		return result // No compatibility issues when translating to same dialect
	}

	// Get capability differences
	differences := compare_capabilities(from, to, allocator)
	defer delete(differences)

	// If no capability differences, we're done
	if len(differences) == 0 {
		return result
	}

	// Check if program uses any unsupported features
	// This is a simplified check - a full implementation would scan the IR
	// For now, we generate warnings based on dialect pair

	// Bash/Zsh to Fish specific warnings
	if to == .Fish {
		for diff in differences {
			switch diff.feature {
			case "arrays":
				add_warning(
					&result,
					"arrays",
					.Warning,
					"Arrays are not supported in Fish",
					"Use 'set arr one two three' instead of 'arr=(one two three)'",
				)
			case "associative_arrays":
				add_warning(
					&result,
					"associative_arrays",
					.Error,
					"Associative arrays are not supported in Fish",
					"No direct equivalent. Consider restructuring your code.",
				)
			case "process_substitution":
				add_warning(
					&result,
					"process_substitution",
					.Error,
					"Process substitution <(command) is not supported in Fish",
					"Use a temporary file workaround instead",
				)
			case "parameter_expansion":
				add_warning(
					&result,
					"parameter_expansion",
					.Warning,
					"Parameter expansion modifiers are not supported in Fish",
					"Use the 'string' builtin instead",
				)
			case "here_documents":
				add_warning(
					&result,
					"here_documents",
					.Error,
					"Here documents (<<) are not supported in Fish",
					"Use multiple echo statements or printf instead",
				)
			}
		}
	}

	// Fish to Bash/Zsh specific warnings
	if from == .Fish && (to == .Bash || to == .Zsh) {
		// Fish lists become arrays - this is usually fine
		add_warning(
			&result,
			"lists",
			.Info,
			"Fish lists will be converted to arrays",
			"Arrays use parentheses: arr=(one two three)",
		)
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
format_result :: proc(result: ^CompatibilityResult, allocator := context.allocator) -> string {
	if len(result.warnings) == 0 {
		return "No compatibility issues found."
	}

	builder := make([dynamic]byte, allocator)

	// Summary
	fmt.sbprintf(&builder, "Compatibility Check Results:\n")
	fmt.sbprintf(&builder, "  Total warnings: %d\n", len(result.warnings))
	fmt.sbprintf(&builder, "  Errors: %v\n", result.has_errors)
	fmt.sbprintf(&builder, "  Warnings: %v\n\n", result.has_warnings)

	// Individual warnings
	for warning in result.warnings {
		formatted := format_warning(warning, allocator)
		fmt.sbprintf(&builder, "%s\n\n", formatted)
		delete(formatted)
	}

	return string(builder[:])
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
