package shellx

import "backend"
import ts "bindings/tree_sitter"
import "compat"
import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"
import "detection"
import "frontend"
import "ir"
import "optimizer"

// ShellDialect is the public shell dialect type used by the API.
ShellDialect :: ir.ShellDialect

// OptimizationLevel controls which optimizer passes run.
OptimizationLevel :: enum {
	None,
	Basic,
	Standard,
	Aggressive,
}

// TranslationOptions configures API behavior.
TranslationOptions :: struct {
	strict_mode:        bool,
	insert_shims:       bool,
	preserve_comments:  bool,
	source_name:        string,
	optimization_level: OptimizationLevel,
}

DEFAULT_TRANSLATION_OPTIONS :: TranslationOptions{
	optimization_level = .None,
}

// TranslationResult is the full output of a translation request.
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
	IOError,
	InternalError,
}

// translate converts shell source between dialects.
// The caller owns result.output/warnings/errors and should call destroy_translation_result(&result).
translate :: proc(
	source_code: string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
) -> TranslationResult {
	result := TranslationResult{success = true}

	source_name := options.source_name
	if source_name == "" {
		source_name = "<input>"
	}

	arena_size := len(source_code) * 8
	if arena_size < 8*1024*1024 {
		arena_size = 8 * 1024 * 1024
	}
	if arena_size > 64*1024*1024 {
		arena_size = 64 * 1024 * 1024
	}
	arena := ir.create_arena(arena_size)
	defer ir.destroy_arena(&arena)

	fe := frontend.create_frontend(from)
	defer frontend.destroy_frontend(&fe)

	tree, parse_err := frontend.parse(&fe, source_code)
	if parse_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ParseError,
			parse_err.message,
			ir.SourceLocation{file = source_name, line = parse_err.location.line, column = parse_err.location.column, length = parse_err.location.length},
			"Fix syntax errors and retry",
		)
		return result
	}
	defer frontend.destroy_tree(tree)

	parse_diags := frontend.collect_parse_diagnostics(tree, source_code, source_name)
	defer delete(parse_diags)

	// Parse diagnostics are fatal in strict mode and same-dialect mode.
	// For cross-dialect translation, keep them as warnings so translation can recover.
	if len(parse_diags) > 0 {
		if options.strict_mode || from == to {
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
			result.success = false
			return result
		}

		for diag in parse_diags {
			warning := fmt.tprintf(
				"Parse diagnostic at %s:%d:%d: %s",
				diag.location.file,
				diag.location.line,
				diag.location.column + 1,
				diag.message,
			)
			append(&result.warnings, warning)
		}
	}

	program, conv_err := convert_to_ir(&arena, from, tree, source_code)
	if conv_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			.ConversionError,
			conv_err.message,
			conv_err.location,
			"Inspect unsupported syntax around the reported location",
		)
		return result
	}

	if program == nil {
		result.success = false
		add_error_context(
			&result,
			.ConversionUnsupportedDialect,
			"Unsupported source dialect",
			ir.SourceLocation{file = source_name},
			"Use Bash, Zsh, Fish, or POSIX input",
		)
		return result
	}

	program.dialect = from
	propagate_program_file(program, source_name)

	validation_err := ir.validate_program(program)
	if validation_err.error != .None {
		result.success = false
		add_error_context(
			&result,
			validator_error_code(validation_err.error),
			validation_err.message,
			ir.SourceLocation{file = source_name},
			"Fix validation errors and retry",
		)
		return result
	}

	compat_result := compat.check_compatibility(from, to, program, source_code)
	defer compat.destroy_compatibility_result(&compat_result)

	for warning in compat_result.warnings {
		append(&result.warnings, warning.message)
		if options.insert_shims && compat.needs_shim(warning.feature, from, to) {
			append_unique(&result.required_shims, warning.feature)
		}
	}

	if options.strict_mode && compat.should_fail_on_strict(&compat_result) {
		result.success = false
		add_error_context(
			&result,
			.ValidationError,
			"Strict mode blocked translation due to compatibility errors",
			ir.SourceLocation{file = source_name},
			"Resolve compatibility errors or disable strict_mode",
		)
		return result
	}

	if options.preserve_comments {
		append(&result.warnings, "preserve_comments is not fully implemented yet")
	}

	if options.optimization_level != .None {
		opt_result := optimizer.optimize(program, to_optimizer_level(options.optimization_level))
		defer optimizer.destroy_optimize_result(&opt_result)
	}

	if options.insert_shims && len(result.required_shims) > 0 {
		apply_ir_shim_rewrites(program, result.required_shims[:], from, to)
	}

	emitted, emit_ok := emit_program(program, to)
	if !emit_ok {
		result.success = false
		add_error_context(
			&result,
			.EmissionError,
			"Failed to emit output for target dialect",
			ir.SourceLocation{file = source_name},
			"Use Bash, Zsh, Fish, or POSIX as target dialect",
		)
		return result
	}

	result.output = emitted
	if options.insert_shims && len(result.required_shims) > 0 {
		rewritten, changed := apply_shim_callsite_rewrites(emitted, result.required_shims[:], from, to, context.allocator)
		if changed {
			delete(emitted)
			emitted = rewritten
		} else {
			delete(rewritten)
		}

		shim_prelude := compat.build_shim_prelude(result.required_shims[:], from, to, context.allocator)
		if shim_prelude != "" {
			result.output = strings.concatenate([]string{shim_prelude, emitted}, context.allocator)
			delete(shim_prelude)
			delete(emitted)
		}
	}

	return result
}

// translate_file reads a file and translates it.
// The caller owns result.output/warnings/errors and should call destroy_translation_result(&result).
translate_file :: proc(
	filepath: string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
) -> TranslationResult {
	result := TranslationResult{success = true}

	data, ok := os.read_entire_file(filepath)
	if !ok {
		result.success = false
		add_error_context(
			&result,
			.IOError,
			"Failed to read input file",
			ir.SourceLocation{file = filepath},
			"Check file path and permissions",
		)
		return result
	}
	defer delete(data)

	opts := options
	if opts.source_name == "" {
		opts.source_name = filepath
	}

	return translate(string(data), from, to, opts)
}

// translate_batch translates multiple files.
// Caller owns the returned slice and each element's allocations.
// Use destroy_translation_result on each item, then delete(batch).
translate_batch :: proc(
	files: []string,
	from: ShellDialect,
	to: ShellDialect,
	options := DEFAULT_TRANSLATION_OPTIONS,
	allocator := context.allocator,
) -> [dynamic]TranslationResult {
	results := make([dynamic]TranslationResult, 0, len(files), allocator)
	for file in files {
		append(&results, translate_file(file, from, to, options))
	}
	return results
}

// get_version returns the library semantic version string.
get_version :: proc() -> string {
	return "0.1.0"
}

// detect_shell returns the best-effort shell dialect for source text.
detect_shell :: proc(code: string) -> ShellDialect {
	return detection.detect_dialect(code, "").dialect
}

// detect_shell_from_path uses both file path and content to detect dialect.
detect_shell_from_path :: proc(filepath: string, code: string) -> ShellDialect {
	return detection.detect_shell_from_path(filepath, code).dialect
}

convert_to_ir :: proc(
	arena: ^ir.Arena_IR,
	from: ShellDialect,
	tree: ^ts.Tree,
	source_code: string,
) -> (^ir.Program, frontend.FrontendError) {
	switch from {
	case .Bash:
		return frontend.bash_to_ir(arena, tree, source_code)
	case .Zsh:
		return frontend.zsh_to_ir(arena, tree, source_code)
	case .Fish:
		return frontend.fish_to_ir(arena, tree, source_code)
	case .POSIX:
		return frontend.bash_to_ir(arena, tree, source_code)
	}
	return nil, frontend.FrontendError{error = .ConversionError, message = "unsupported dialect"}
}

emit_program :: proc(program: ^ir.Program, to: ShellDialect) -> (string, bool) {
	switch to {
	case .Bash, .POSIX:
		be := backend.create_backend(to)
		defer backend.destroy_backend(&be)
		return backend.emit(&be, program, context.allocator), true
	case .Zsh:
		be := backend.create_zsh_backend()
		defer backend.destroy_zsh_backend(&be)
		raw := backend.emit_zsh(&be, program)
		return strings.clone(raw, context.allocator), true
	case .Fish:
		be := backend.create_fish_backend()
		defer backend.destroy_fish_backend(&be)
		raw := backend.emit_fish(&be, program)
		return strings.clone(raw, context.allocator), true
	}
	return "", false
}

validator_error_code :: proc(err: ir.ValidatorErrorType) -> Error {
	switch err {
	case .UndefinedVariable:
		return .ValidationUndefinedVariable
	case .DuplicateFunction:
		return .ValidationDuplicateFunction
	case .InvalidControlFlow:
		return .ValidationInvalidControlFlow
	case .None:
		return .ValidationError
	}
	return .ValidationError
}

to_optimizer_level :: proc(level: OptimizationLevel) -> optimizer.OptimizationLevel {
	switch level {
	case .None:
		return .None
	case .Basic:
		return .Basic
	case .Standard:
		return .Standard
	case .Aggressive:
		return .Aggressive
	}
	return .Standard
}

append_unique :: proc(items: ^[dynamic]string, value: string) {
	for existing in items^ {
		if existing == value {
			return
		}
	}
	append(items, value)
}

has_required_shim :: proc(required_shims: []string, name: string) -> bool {
	for shim in required_shims {
		if shim == name {
			return true
		}
	}
	return false
}

is_string_match_call :: proc(call: ^ir.Call) -> bool {
	if call == nil || call.function == nil {
		return false
	}
	if call.function.name != "string" {
		return false
	}
	if len(call.arguments) == 0 {
		return false
	}
	first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
	return first == "match"
}

rewrite_condition_command_text_for_shim :: proc(expr: ^ir.TestCondition) {
	if expr == nil {
		return
	}
	trimmed := strings.trim_space(expr.text)
	if !strings.has_prefix(trimmed, "string match") {
		return
	}
	rest := strings.trim_space(trimmed[len("string match"):])
	if rest == "" {
		expr.text = "__shellx_match"
	} else {
		expr.text = strings.concatenate([]string{"__shellx_match ", rest}, context.allocator)
	}
	expr.syntax = .Command
}

rewrite_expr_for_shims :: proc(
	expr: ir.Expression,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
) {
	if expr == nil {
		return
	}
	#partial switch e in expr {
	case ^ir.TestCondition:
		if has_required_shim(required_shims, "condition_semantics") {
			cond_text := strings.trim_space(e.text)
			if to == .Fish {
				if e.syntax == .DoubleBracket || e.syntax == .TestBuiltin || e.syntax == .Unknown {
					if !strings.has_prefix(cond_text, "__shellx_test ") {
						e.text = strings.concatenate([]string{"__shellx_test ", cond_text}, context.allocator)
					}
					e.syntax = .Command
				}
			} else if from == .Fish && to != .Fish {
				rewrite_condition_command_text_for_shim(e)
				if e.syntax == .FishTest {
					e.syntax = .TestBuiltin
				}
			} else if to == .POSIX && e.syntax == .DoubleBracket {
				e.syntax = .TestBuiltin
			} else if (to == .Bash || to == .Zsh || to == .POSIX) && e.syntax == .FishTest {
				e.syntax = .TestBuiltin
			}
		}
	case ^ir.RawExpression:
	case ^ir.UnaryOp:
		rewrite_expr_for_shims(e.operand, required_shims, from, to)
	case ^ir.BinaryOp:
		rewrite_expr_for_shims(e.left, required_shims, from, to)
		rewrite_expr_for_shims(e.right, required_shims, from, to)
	case ^ir.CallExpr:
		for arg in e.arguments {
			rewrite_expr_for_shims(arg, required_shims, from, to)
		}
	case ^ir.ArrayLiteral:
		for elem in e.elements {
			rewrite_expr_for_shims(elem, required_shims, from, to)
		}
	}
}

rewrite_call_for_shims :: proc(
	call: ^ir.Call,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
) {
	if call == nil || call.function == nil {
		return
	}

	if has_required_shim(required_shims, "hooks_events") && call.function.name == "add-zsh-hook" {
		call.function.name = "__shellx_register_hook"
	}

	if has_required_shim(required_shims, "condition_semantics") && from == .Fish && to != .Fish && is_string_match_call(call) {
		call.function.name = "__shellx_match"
		if len(call.arguments) > 0 {
			for i in 1 ..< len(call.arguments) {
				call.arguments[i-1] = call.arguments[i]
			}
			resize(&call.arguments, len(call.arguments)-1)
		}
	}

	for arg in call.arguments {
		rewrite_expr_for_shims(arg, required_shims, from, to)
	}
}

rewrite_stmt_for_shims :: proc(
	stmt: ^ir.Statement,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
) {
	switch stmt.type {
	case .Assign:
		rewrite_expr_for_shims(stmt.assign.value, required_shims, from, to)
	case .Call:
		rewrite_call_for_shims(&stmt.call, required_shims, from, to)
	case .Logical:
		for &seg in stmt.logical.segments {
			rewrite_call_for_shims(&seg.call, required_shims, from, to)
		}
	case .Case:
		rewrite_expr_for_shims(stmt.case_.value, required_shims, from, to)
		for &arm in stmt.case_.arms {
			for &nested in arm.body {
				rewrite_stmt_for_shims(&nested, required_shims, from, to)
			}
		}
	case .Return:
		rewrite_expr_for_shims(stmt.return_.value, required_shims, from, to)
	case .Branch:
		rewrite_expr_for_shims(stmt.branch.condition, required_shims, from, to)
		for &nested in stmt.branch.then_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to)
		}
		for &nested in stmt.branch.else_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to)
		}
	case .Loop:
		rewrite_expr_for_shims(stmt.loop.items, required_shims, from, to)
		rewrite_expr_for_shims(stmt.loop.condition, required_shims, from, to)
		for &nested in stmt.loop.body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to)
		}
	case .Pipeline:
		for &cmd in stmt.pipeline.commands {
			rewrite_call_for_shims(&cmd, required_shims, from, to)
		}
	}
}

apply_ir_shim_rewrites :: proc(
	program: ^ir.Program,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
) {
	if program == nil || len(required_shims) == 0 {
		return
	}
	for &fn in program.functions {
		for &stmt in fn.body {
			rewrite_stmt_for_shims(&stmt, required_shims, from, to)
		}
	}
	for &stmt in program.statements {
		rewrite_stmt_for_shims(&stmt, required_shims, from, to)
	}
}

apply_shim_callsite_rewrites :: proc(
	text: string,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed_any := false

	if has_required_shim(required_shims, "hooks_events") {
		out, changed_any = replace_with_flag(out, "add-zsh-hook precmd ", "__shellx_register_precmd ", changed_any, allocator)
		out, changed_any = replace_with_flag(out, "add-zsh-hook preexec ", "__shellx_register_preexec ", changed_any, allocator)
	}

	if has_required_shim(required_shims, "arrays_lists") {
		if to == .Fish {
			out, changed_any = replace_with_flag(out, "declare -a ", "__shellx_array_set ", changed_any, allocator)
		}
		if from == .Fish && (to == .Bash || to == .Zsh) {
			out, changed_any = replace_with_flag(out, "set ", "__shellx_list_to_array ", changed_any, allocator)
		}
	}

	return out, changed_any
}

replace_with_flag :: proc(
	text: string,
	from_s: string,
	to_s: string,
	changed_any: bool,
	allocator: mem.Allocator,
) -> (string, bool) {
	replaced, changed := strings.replace_all(text, from_s, to_s, allocator)
	if changed {
		delete(text)
		return replaced, true
	}
	if raw_data(replaced) != raw_data(text) {
		delete(replaced)
	}
	return text, changed_any
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
		case .Logical:
			set_location_file_if_empty(&stmt.logical.location, file)
			for &segment in stmt.logical.segments {
				set_location_file_if_empty(&segment.call.location, file)
			}
		case .Case:
			set_location_file_if_empty(&stmt.case_.location, file)
			for &arm in stmt.case_.arms {
				set_location_file_if_empty(&arm.location, file)
				for &nested in arm.body {
					walk_statement(&nested, file)
				}
			}
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

main :: proc() {
	// Library entry point.
}
