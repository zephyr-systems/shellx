package shellx

import "backend"
import "core:fmt"
import "core:mem"
import "frontend"
import "ir" // Import mem for mem.arena_allocator

// No separate import for ir/validator, as it's part of the 'ir' package.
ShellDialect :: ir.ShellDialect

TranslationOptions :: struct {
	strict_mode:       bool,
	insert_shims:      bool,
	preserve_comments: bool,
	source_name:       string,
}

TranslationResult :: struct {
	success:        bool,
	output:         string,
	warnings:       [dynamic]string,
	required_shims: [dynamic]string,
	error:          Error,
	errors:         [dynamic]ErrorContext,
}

Error :: enum {
	None,
	ParseError,
	ParseSyntaxError,
	ConversionError,
	ConversionUnsupportedDialect,
	ValidationError,
	ValidationUndefinedVariable,
	ValidationDuplicateFunction,
	ValidationInvalidControlFlow,
	EmissionError,
	InternalError,
}

translate :: proc(
	source_code: string,
	from: ShellDialect,
	to: ShellDialect,
	options := TranslationOptions{},
) -> TranslationResult {
	result := TranslationResult {
		success = true,
	}

	source_name := options.source_name
	if source_name == "" {
		source_name = "<input>"
	}

	fmt.println("Translate: Creating arena...")
	arena := ir.create_arena(1024 * 1024)
	defer ir.destroy_arena(&arena) // Ensure arena is destroyed at function exit

	fmt.println("Translate: Creating frontend...")
	fe := frontend.create_frontend(from)
	defer frontend.destroy_frontend(&fe)

	fmt.println("Translate: Parsing source...")
	tree, parse_err := frontend.parse(&fe, source_code)
	if parse_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ParseError,
			parse_err.message,
			ir.SourceLocation{
				file = source_name,
				line = parse_err.location.line,
				column = parse_err.location.column,
				length = parse_err.location.length,
			},
			"Fix syntax errors and try again",
		)
		return result
	}
	defer frontend.destroy_tree(tree)

	// Collect parser diagnostics (recovery mode): continue translation with diagnostics.
	parse_diags := frontend.collect_parse_diagnostics(tree, source_code, source_name)
	defer delete(parse_diags)
	for diag in parse_diags {
		add_error_context(
			&result,
			.ParseSyntaxError,
			diag.message,
			diag.location,
			diag.suggestion,
			diag.snippet,
		)
	}

	program: ^ir.Program
	conv_err: frontend.FrontendError

	switch from {
	case .Bash:
		program, conv_err = frontend.bash_to_ir(&arena, tree, source_code)
	case .Zsh:
		result.success = false
		add_error_context(
			&result,
			.ConversionUnsupportedDialect,
			"Zsh frontend conversion is not enabled in translate()",
			ir.SourceLocation{file = source_name},
			"Use Bash input for now or wire the Zsh conversion path",
		)
		return result
	case .Fish:
		result.success = false
		add_error_context(
			&result,
			.ConversionUnsupportedDialect,
			"Fish frontend conversion is not enabled in translate()",
			ir.SourceLocation{file = source_name},
			"Use Bash input for now or wire the Fish conversion path",
		)
		return result
	case .POSIX:
		result.success = false
		add_error_context(
			&result,
			.ConversionUnsupportedDialect,
			"POSIX frontend conversion is not enabled in translate()",
			ir.SourceLocation{file = source_name},
			"Use Bash input for now or wire the POSIX conversion path",
		)
		return result
	}

	if conv_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ConversionError,
			conv_err.message,
			conv_err.location,
			"Inspect unsupported/invalid syntax near the reported location",
		)
		return result
	}

	propagate_program_file(program, source_name)

	fmt.println("Translate: Validating IR...")
	validation_err: ir.ValidatorError = ir.validate_program(program)
	if validation_err.error != .None {
		result.success = false
		error_code: Error = .ValidationError
		switch validation_err.error {
		case .None:
			error_code = .ValidationError
		case .UndefinedVariable:
			error_code = .ValidationUndefinedVariable
		case .DuplicateFunction:
			error_code = .ValidationDuplicateFunction
		case .InvalidControlFlow:
			error_code = .ValidationInvalidControlFlow
		case:
			error_code = .ValidationError
		}
		add_error_context(
			&result,
			error_code,
			validation_err.message,
			ir.SourceLocation{file = source_name},
			"Fix validation errors and retry",
		)
		return result
	}

	fmt.println("Translate: Creating backend...")
	be := backend.create_backend(to)
	defer backend.destroy_backend(&be)

	fmt.println("Translate: Emitting code...")
	output := backend.emit(&be, program, mem.arena_allocator(&arena.arena))
	fmt.printf("Translate: Emission finished. Output length: %d\n", len(output))
	fmt.printf("Translate: Output content: '%s'\n", output)

	fmt.println("Translate: Assigning output...")
	result.output = output
	fmt.printf("Translate: Result output length: %d\n", len(result.output))
	fmt.printf("Translate: Result output content: '%s'\n", result.output)

	if len(result.errors) > 0 {
		result.success = false
	}

	return result
}

propagate_program_file :: proc(program: ^ir.Program, file: string) {
	if program == nil || file == "" {
		return
	}

	set_location_file_if_empty :: proc(loc: ^ir.SourceLocation, file: string) {
		if loc.file == "" {
			loc.file = file
		}
	}

	walk_statement :: proc(stmt: ^ir.Statement, file: string) {
		set_location_file_if_empty(&stmt.location, file)
		switch stmt.type {
		case .Assign:
			set_location_file_if_empty(&stmt.assign.location, file)
		case .Call:
			set_location_file_if_empty(&stmt.call.location, file)
		case .Return:
			set_location_file_if_empty(&stmt.return_.location, file)
		case .Branch:
			set_location_file_if_empty(&stmt.branch.location, file)
			for &nested in stmt.branch.then_body {
				walk_statement(&nested, file)
			}
			for &nested in stmt.branch.else_body {
				walk_statement(&nested, file)
			}
		case .Loop:
			set_location_file_if_empty(&stmt.loop.location, file)
			for &nested in stmt.loop.body {
				walk_statement(&nested, file)
			}
		case .Pipeline:
			set_location_file_if_empty(&stmt.pipeline.location, file)
			for &cmd in stmt.pipeline.commands {
				set_location_file_if_empty(&cmd.location, file)
			}
		}
	}

	for &fn in program.functions {
		set_location_file_if_empty(&fn.location, file)
		for &stmt in fn.body {
			walk_statement(&stmt, file)
		}
	}

	for &stmt in program.statements {
		walk_statement(&stmt, file)
	}
}

detect_shell :: proc(code: string) -> ShellDialect {
	return .Bash
}

detect_shell_from_path :: proc(filepath: string, code: string) -> ShellDialect {
	return .Bash
}

// Main entry point - ShellX is a library, not a CLI tool.
// Use the API: translate(), detect_shell()
main :: proc() {
	fmt.println("ShellX is a library package.")
	fmt.println("Import it with: import \"shellx\"")
	fmt.println("Use: shellx.translate() or shellx.detect_shell()")
}
