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
		loc := validation_err.location
		if loc.file == "" {
			loc.file = source_name
		}
		result.success = false
		add_error_context(
			&result,
			validator_error_code(validation_err.error),
			validation_err.message,
			loc,
			"Fix validation errors and retry",
			"",
			validation_err.rule,
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

	recovery_mode := from == .Zsh && to == .Bash && len(parse_diags) > 0
	if recovery_mode {
		fe_check := frontend.create_frontend(.Bash)
		tree_check, parse_check := frontend.parse(&fe_check, emitted)
		needs_fallback := parse_check.error != .None || tree_check == nil
		if tree_check != nil {
			diags_check := frontend.collect_parse_diagnostics(tree_check, emitted, "<recovery-check>")
			if len(diags_check) > 0 {
				needs_fallback = true
			}
			delete(diags_check)
			frontend.destroy_tree(tree_check)
		}
		frontend.destroy_frontend(&fe_check)

		if needs_fallback {
			delete(emitted)
			emitted = strings.clone(source_code, context.allocator)
		}
	}

	result.output = emitted
	rewritten_target, target_changed := rewrite_target_callsites(emitted, from, to, context.allocator)
	if target_changed {
		delete(emitted)
		emitted = rewritten_target
	} else {
		delete(rewritten_target)
	}

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
		} else {
			result.output = emitted
		}
	} else {
		result.output = emitted
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

has_array_bridge_shim :: proc(required_shims: []string) -> bool {
	return has_required_shim(required_shims, "arrays_lists") ||
		has_required_shim(required_shims, "indexed_arrays") ||
		has_required_shim(required_shims, "assoc_arrays") ||
		has_required_shim(required_shims, "fish_list_indexing")
}

has_hook_bridge_shim :: proc(required_shims: []string) -> bool {
	return has_required_shim(required_shims, "hooks_events") ||
		has_required_shim(required_shims, "zsh_hooks") ||
		has_required_shim(required_shims, "fish_events") ||
		has_required_shim(required_shims, "prompt_hooks")
}

is_string_match_call :: proc(call: ^ir.Call) -> bool {
	if call == nil {
		return false
	}

	if call.function != nil && call.function.name == "string" {
		if len(call.arguments) == 0 {
			return false
		}
		first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
		return first == "match"
	}

	if call.function != nil && strings.trim_space(call.function.name) == "" && len(call.arguments) >= 2 {
		first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
		second := strings.trim_space(ir.expr_to_string(call.arguments[1]))
		return first == "string" && second == "match"
	}

	return false
}

drop_call_arguments :: proc(call: ^ir.Call, n: int) {
	if call == nil || n <= 0 {
		return
	}
	if len(call.arguments) <= n {
		resize(&call.arguments, 0)
		return
	}
	for i in n ..< len(call.arguments) {
		call.arguments[i-n] = call.arguments[i]
	}
	resize(&call.arguments, len(call.arguments)-n)
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

	if has_hook_bridge_shim(required_shims) && call.function.name == "add-zsh-hook" {
		call.function.name = "__shellx_register_hook"
	}

	if has_required_shim(required_shims, "condition_semantics") && from == .Fish && to != .Fish && is_string_match_call(call) {
		call.function.name = "__shellx_match"
		if len(call.arguments) >= 2 {
			first := strings.trim_space(ir.expr_to_string(call.arguments[0]))
			second := strings.trim_space(ir.expr_to_string(call.arguments[1]))
			if first == "string" && second == "match" {
				drop_call_arguments(call, 2)
			} else {
				drop_call_arguments(call, 1)
			}
		} else if len(call.arguments) == 1 {
			drop_call_arguments(call, 1)
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

	if has_hook_bridge_shim(required_shims) {
		out, changed_any = replace_with_flag(out, "add-zsh-hook precmd ", "__shellx_register_precmd ", changed_any, allocator)
		out, changed_any = replace_with_flag(out, "add-zsh-hook preexec ", "__shellx_register_preexec ", changed_any, allocator)
	}

	if has_array_bridge_shim(required_shims) {
		if to == .Fish {
			out, changed_any = replace_with_flag(out, "declare -a ", "__shellx_array_set ", changed_any, allocator)
		}
		if from == .Fish && (to == .Bash || to == .Zsh) {
			out, changed_any = replace_with_flag(out, "set ", "__shellx_list_to_array ", changed_any, allocator)
		}
	}

	if has_required_shim(required_shims, "parameter_expansion") {
		rewritten, changed := rewrite_parameter_expansion_callsites(out, to, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
		}
	}

	if has_required_shim(required_shims, "process_substitution") {
		rewritten, changed := rewrite_process_substitution_callsites(out, to, allocator)
		if changed {
			delete(out)
			out = rewritten
			changed_any = true
		} else {
			delete(rewritten)
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

find_substring :: proc(s: string, needle: string) -> int {
	if len(needle) == 0 || len(s) < len(needle) {
		return -1
	}
	last := len(s) - len(needle)
	for i in 0 ..< last+1 {
		matched := true
		for j in 0 ..< len(needle) {
			if s[i+j] != needle[j] {
				matched = false
				break
			}
		}
		if matched {
			return i
		}
	}
	return -1
}

escape_double_quoted :: proc(s: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	for i in 0 ..< len(s) {
		c := s[i]
		if c == '\\' || c == '"' || c == '$' || c == '`' {
			strings.write_byte(&builder, '\\')
		}
		strings.write_byte(&builder, c)
	}

	return strings.clone(strings.to_string(builder), allocator)
}

rewrite_parameter_expansion_callsites :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Fish {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		inner_start := -1
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			inner_start = i + 2
		} else if text[i] == '{' {
			inner_start = i + 1
		}

		if inner_start >= 0 {
			j := inner_start
			for j < len(text) && text[j] != '}' {
				j += 1
			}
			if j < len(text) && text[j] == '}' {
				inner := strings.trim_space(text[inner_start:j])
				repl := ""

				if len(inner) > 1 && inner[0] == '#' {
					var_name := strings.trim_space(inner[1:])
					if var_name != "" {
						repl = fmt.tprintf("(__shellx_param_length %s)", var_name)
					}
				} else {
					idx := find_substring(inner, ":-")
					if idx < 0 {
						idx = find_substring(inner, ":=")
					}
					if idx > 0 {
						var_name := strings.trim_space(inner[:idx])
						default_value := strings.trim_space(inner[idx+2:])
						if var_name != "" {
							escaped_default := escape_double_quoted(default_value, allocator)
							repl = fmt.tprintf("(__shellx_param_default %s \"%s\")", var_name, escaped_default)
							delete(escaped_default)
						}
					}
				}

				if repl != "" {
					strings.write_string(&builder, repl)
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_process_substitution_callsites :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if to != .Fish && to != .POSIX {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && (text[i] == '<' || text[i] == '>') && text[i+1] == '(' {
			direction := text[i]
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '(' {
					depth += 1
				} else if text[j] == ')' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				cmd := strings.trim_space(text[i+2 : j])
				escaped_cmd := escape_double_quoted(cmd, allocator)
				fn := "__shellx_psub_in"
				if direction == '>' {
					fn = "__shellx_psub_out"
				}

				if to == .Fish {
					strings.write_string(&builder, fmt.tprintf("(%s \"%s\")", fn, escaped_cmd))
				} else {
					strings.write_string(&builder, fmt.tprintf("$(%s \"%s\")", fn, escaped_cmd))
				}

				delete(escaped_cmd)
				changed = true
				i = j + 1
				continue
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_target_callsites :: proc(
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	if from == .Zsh && to == .Bash {
		first, first_changed := rewrite_zsh_parameter_expansion_for_bash(text, allocator)
		second, second_changed := rewrite_zsh_syntax_for_bash(first, allocator)
		delete(first)
		secondb, secondb_changed := rewrite_empty_then_blocks_for_bash(second, allocator)
		delete(second)
		third, third_changed := rewrite_unsupported_zsh_expansions_for_bash(secondb, allocator)
		delete(secondb)
		if third_changed && !strings.contains(third, "__shellx_zsh_expand()") {
			shim_body := strings.trim_space(`
__shellx_zsh_expand() {
  # fallback shim for zsh-only parameter expansion forms not directly translatable
  printf "%s" ""
}
`)
			shim := strings.concatenate([]string{shim_body, "\n\n"}, allocator)
			with_shim := strings.concatenate([]string{shim, third}, allocator)
			delete(shim)
			delete(third)
			return with_shim, true
		}
		return third, first_changed || second_changed || secondb_changed || third_changed
	}
	return strings.clone(text, allocator), false
}

rewrite_empty_then_blocks_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, i in lines {
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if strings.trim_space(line) != "then" {
			continue
		}

		k := i + 1
		for k < len(lines) {
			trimmed_k := strings.trim_space(lines[k])
			if trimmed_k == "" || strings.has_prefix(trimmed_k, "#") {
				k += 1
				continue
			}
			if strings.has_prefix(trimmed_k, "elif") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :\n")
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_if_group_pattern_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "[[") {
		return strings.clone(line, allocator), false
	}
	eq_idx := find_substring(line, "== (")
	if eq_idx < 0 {
		return strings.clone(line, allocator), false
	}
	open_idx := eq_idx + 3
	if open_idx >= len(line) || line[open_idx] != '(' {
		return strings.clone(line, allocator), false
	}
	depth := 0
	close_idx := -1
	for i in open_idx ..< len(line) {
		if line[i] == '(' {
			depth += 1
		} else if line[i] == ')' {
			depth -= 1
			if depth == 0 {
				close_idx = i
				break
			}
		}
	}
	if close_idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:eq_idx]
	pattern := line[open_idx : close_idx+1] // includes ( ... )
	suffix := line[close_idx+1:]
	rewritten := fmt.tprintf("%s=~ ^%s$%s", prefix, pattern, suffix)
	return strings.clone(rewritten, allocator), true
}

rewrite_zsh_anonymous_function_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(line)
	if trimmed != "() {" {
		return strings.clone(line, allocator), false
	}
	indent_len := len(line) - len(strings.trim_left_space(line))
	indent := ""
	if indent_len > 0 {
		indent = line[:indent_len]
	}
	return strings.clone(strings.concatenate([]string{indent, "{"}), allocator), true
}

rewrite_zsh_case_group_pattern_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if strings.contains(line, "[[") || !strings.contains(line, "|") {
		return strings.clone(line, allocator), false
	}
	open_idx := find_substring(line, "(")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	close_idx := -1
	for i in open_idx+1 ..< len(line) {
		if line[i] == ')' {
			close_idx = i
			break
		}
	}
	if close_idx < 0 {
		return strings.clone(line, allocator), false
	}
	group := line[open_idx+1 : close_idx]
	if !strings.contains(group, "|") {
		return strings.clone(line, allocator), false
	}
	for i in 0 ..< len(group) {
		c := group[i]
		if c == ' ' || c == '\t' || c == '$' || c == '{' || c == '}' {
			return strings.clone(line, allocator), false
		}
	}
	prefix := line[:open_idx]
	suffix := line[close_idx+1:]
	has_terminal_close := false
	if len(suffix) > 0 && suffix[len(suffix)-1] == ')' {
		has_terminal_close = true
		suffix = suffix[:len(suffix)-1]
	}
	parts := strings.split(group, "|")
	defer delete(parts)
	if len(parts) < 2 {
		return strings.clone(line, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	for p, idx in parts {
		if idx > 0 {
			strings.write_byte(&builder, '|')
		}
		strings.write_string(&builder, prefix)
		strings.write_string(&builder, p)
		strings.write_string(&builder, suffix)
	}
	if has_terminal_close {
		strings.write_byte(&builder, ')')
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_always_block_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	rewritten, changed := strings.replace_all(line, "} always {", "}; {", allocator)
	if changed {
		return rewritten, true
	}
	if raw_data(rewritten) != raw_data(line) {
		delete(rewritten)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_conditional_anonymous_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(line, allocator)
	changed_any := false
	repl, changed := strings.replace_all(out, "&& () {", "&& {", allocator)
	if changed {
		delete(out)
		out = repl
		changed_any = true
	} else if raw_data(repl) != raw_data(out) {
		delete(repl)
	}
	repl, changed = strings.replace_all(out, "|| () {", "|| {", allocator)
	if changed {
		delete(out)
		out = repl
		changed_any = true
	} else if raw_data(repl) != raw_data(out) {
		delete(repl)
	}
	return out, changed_any
}

rewrite_zsh_empty_function_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	open_idx := find_substring(line, "(){}")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:open_idx+2]
	suffix := line[open_idx+4:]
	return strings.clone(strings.concatenate([]string{prefix, " { :; }", suffix}), allocator), true
}

rewrite_zsh_if_group_command_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "then") || !strings.contains(line, "{") || !strings.contains(line, "}") {
		return strings.clone(line, allocator), false
	}
	repl, changed := strings.replace_all(line, " } 2>/dev/null; then", "; } 2>/dev/null; then", allocator)
	if changed {
		return repl, true
	}
	if raw_data(repl) != raw_data(line) {
		delete(repl)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_inline_brace_group_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !(strings.contains(line, "|| {") || strings.contains(line, "&& {")) {
		return strings.clone(line, allocator), false
	}
	if !strings.contains(line, " }") || strings.contains(line, "; }") {
		return strings.clone(line, allocator), false
	}
	repl, changed := strings.replace_all(line, " }", "; }", allocator)
	if changed {
		return repl, true
	}
	if raw_data(repl) != raw_data(line) {
		delete(repl)
	}
	return strings.clone(line, allocator), false
}

rewrite_zsh_for_paren_syntax_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(line, "for ") || !strings.contains(line, "); do") || !strings.contains(line, " (") {
		return strings.clone(line, allocator), false
	}
	for_idx := find_substring(line, "for ")
	open_idx := find_substring(line, " (")
	close_idx := find_substring(line, "); do")
	if for_idx < 0 || open_idx < 0 || close_idx < 0 || open_idx <= for_idx+4 || close_idx <= open_idx+2 {
		return strings.clone(line, allocator), false
	}
	var_name := strings.trim_space(line[for_idx+4 : open_idx])
	iter_expr := strings.trim_space(line[open_idx+2 : close_idx])
	if var_name == "" || iter_expr == "" {
		return strings.clone(line, allocator), false
	}
	iter_replaced, iter_changed := strings.replace_all(iter_expr, "(/)", "/", allocator)
	if iter_changed {
		iter_expr = iter_replaced
	} else if raw_data(iter_replaced) != raw_data(iter_expr) {
		delete(iter_replaced)
	}
	prefix := line[:for_idx]
	suffix := line[close_idx+5:] // keep anything after '; do'
	rewritten := strings.concatenate([]string{prefix, "for ", var_name, " in ", iter_expr, "; do", suffix}, allocator)
	if iter_changed {
		delete(iter_replaced)
	}
	return rewritten, true
}

rewrite_zsh_dynamic_function_line_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(line)
	if strings.has_prefix(trimmed, "eval ") {
		return strings.clone(line, allocator), false
	}
	if strings.contains(line, "\"") {
		return strings.clone(line, allocator), false
	}
	if !strings.contains(line, "${") || !strings.contains(line, "() {") {
		return strings.clone(line, allocator), false
	}
	escaped := escape_double_quoted(strings.trim_space(line), allocator)
	rewritten := strings.clone(strings.concatenate([]string{"eval \"", escaped, "\""}), allocator)
	delete(escaped)
	return rewritten, true
}

rewrite_zsh_syntax_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	next := ""
	for line, i in lines {
		cur := strings.clone(line, allocator)
		next, c1 := rewrite_zsh_anonymous_function_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c1 {
			changed = true
		}

		c2 := false
		next, c2 = rewrite_zsh_if_group_pattern_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c2 {
			changed = true
		}

		c3 := false
		next, c3 = rewrite_zsh_case_group_pattern_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c3 {
			changed = true
		}

		c4 := false
		next, c4 = rewrite_zsh_always_block_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c4 {
			changed = true
		}

		c5 := false
		next, c5 = rewrite_zsh_conditional_anonymous_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c5 {
			changed = true
		}

		c6 := false
		next, c6 = rewrite_zsh_empty_function_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c6 {
			changed = true
		}

		c7 := false
		next, c7 = rewrite_zsh_if_group_command_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c7 {
			changed = true
		}

		c8 := false
		next, c8 = rewrite_zsh_dynamic_function_line_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c8 {
			changed = true
		}

		c9 := false
		next, c9 = rewrite_zsh_inline_brace_group_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c9 {
			changed = true
		}

		c10 := false
		next, c10 = rewrite_zsh_for_paren_syntax_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c10 {
			changed = true
		}

		strings.write_string(&builder, cur)
		delete(cur)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_unsupported_zsh_expansions_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}
			if j < len(text) && depth == 0 {
				inner := text[i+2 : j]
				if strings.contains(inner, "${${") ||
					strings.contains(inner, "(q)") ||
					strings.contains(inner, "(qq)") ||
					strings.contains(inner, ":h") ||
					strings.contains(inner, ":t") ||
					strings.contains(inner, ":r") ||
					strings.contains(inner, ":e") ||
					strings.contains(inner, ":a") ||
					strings.contains(inner, ":A") {
					orig := text[i : j+1]
					escaped := escape_double_quoted(orig, allocator)
					strings.write_string(&builder, "$(__shellx_zsh_expand \"")
					strings.write_string(&builder, escaped)
					strings.write_string(&builder, "\")")
					delete(escaped)
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

is_param_name_char :: proc(c: byte) -> bool {
	if c >= 'a' && c <= 'z' {
		return true
	}
	if c >= 'A' && c <= 'Z' {
		return true
	}
	if c >= '0' && c <= '9' {
		return true
	}
	if c == '_' || c == '@' || c == '*' || c == '#' || c == '?' {
		return true
	}
	return false
}

is_simple_param_name :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for i in 0 ..< len(s) {
		if !is_param_name_char(s[i]) {
			return false
		}
	}
	return true
}

rewrite_zsh_modifier_parameter_tokens :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(inner) {
		token_len := 0
		mode := ""
		if i+4 <= len(inner) && inner[i:i+4] == "(@k)" {
			token_len = 4
			mode = "keys"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@Pk)" {
			token_len = 5
			mode = "indirect_keys"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@On)" {
			token_len = 5
			mode = "array_sorted_desc"
		} else if i+5 <= len(inner) && inner[i:i+5] == "(@on)" {
			token_len = 5
			mode = "array_sorted_asc"
		} else if i+3 <= len(inner) && inner[i:i+3] == "(@)" {
			token_len = 3
			mode = "array"
		} else if i+3 <= len(inner) && inner[i:i+3] == "(k)" {
			token_len = 3
			mode = "keys"
		}

		if token_len > 0 {
			j := i + token_len
			for j < len(inner) && is_param_name_char(inner[j]) {
				j += 1
			}
			if j > i+token_len {
				name := inner[i+token_len : j]
				switch mode {
				case "keys":
					strings.write_string(&builder, fmt.tprintf("!%s[@]", name))
				case "indirect_keys":
					var_ref := ""
					is_digits := true
					for ch in name {
						if ch < '0' || ch > '9' {
							is_digits = false
							break
						}
					}
					if is_digits {
						if len(name) == 1 {
							var_ref = fmt.tprintf("$%s", name)
						} else {
							var_ref = strings.concatenate([]string{"${", name, "}"})
						}
					} else {
						var_ref = fmt.tprintf("$%s", name)
					}
					raw_expr := strings.concatenate(
						[]string{
							"$(eval \"printf '%s\\n' \\\"\\${!",
							var_ref,
							"[@]}\\\"\")",
						},
					)
					if i == 0 && j == len(inner) {
						tmp_raw := strings.concatenate([]string{"__SHELLX_RAW__", raw_expr})
						out_raw := strings.clone(tmp_raw, allocator)
						delete(tmp_raw)
						delete(raw_expr)
						return out_raw, true
					}
					strings.write_string(&builder, raw_expr)
					delete(raw_expr)
				case "array_sorted_desc", "array_sorted_asc":
					// Preserve element expansion even when zsh sorting modifiers are unavailable.
					// This keeps script behavior functionally usable instead of emitting zsh-only syntax.
					strings.write_string(&builder, fmt.tprintf("%s[@]", name))
				case "array":
					strings.write_string(&builder, fmt.tprintf("%s[@]", name))
				}
				changed = true
				i = j
				continue
			}
		}

		strings.write_byte(&builder, inner[i])
		i += 1
	}

	if !changed {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_case_modifiers_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	if len(inner) < 3 {
		return strings.clone(inner, allocator), false
	}
	suffix := inner[len(inner)-2:]
	base := inner[:len(inner)-2]
	if base == "" || !is_simple_param_name(base) {
		return strings.clone(inner, allocator), false
	}
	switch suffix {
	case ":l":
		return strings.clone(fmt.tprintf("%s,,", base), allocator), true
	case ":u":
		return strings.clone(fmt.tprintf("%s^^", base), allocator), true
	}
	return strings.clone(inner, allocator), false
}

rewrite_zsh_settest_expansion_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	trimmed := strings.trim_space(inner)
	if len(trimmed) < 2 || trimmed[0] != '+' {
		return strings.clone(inner, allocator), false
	}
	target := strings.trim_space(trimmed[1:])
	if target == "" {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.concatenate([]string{target, "+1"}), allocator), true
}

rewrite_zsh_inline_case_modifiers_for_bash :: proc(inner: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(inner) {
		if is_param_name_char(inner[i]) {
			start := i
			j := i
			for j < len(inner) && is_param_name_char(inner[j]) {
				j += 1
			}
			if j+1 < len(inner) && inner[j] == ':' && (inner[j+1] == 'l' || inner[j+1] == 'u') {
				if start == 0 || !is_param_name_char(inner[start-1]) {
					name := inner[start:j]
					if inner[j+1] == 'l' {
						strings.write_string(&builder, fmt.tprintf("%s,,", name))
					} else {
						strings.write_string(&builder, fmt.tprintf("%s^^", name))
					}
					changed = true
					i = j + 2
					continue
				}
			}
		}

		strings.write_byte(&builder, inner[i])
		i += 1
	}

	if !changed {
		return strings.clone(inner, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_parameter_expansion_for_bash :: proc(
	text: string,
	allocator := context.allocator,
) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			depth := 1
			j := i + 2
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				inner := text[i+2 : j]
				rewrite_stage1, stage1_changed := rewrite_zsh_modifier_parameter_tokens(inner, allocator)
				rewrite_stage2, stage2_changed := rewrite_zsh_settest_expansion_for_bash(rewrite_stage1, allocator)
				rewrite_stage3, stage3_changed := rewrite_zsh_inline_case_modifiers_for_bash(rewrite_stage2, allocator)
				rewrite_stage4, stage4_changed := rewrite_zsh_case_modifiers_for_bash(rewrite_stage3, allocator)
				if stage1_changed || stage2_changed || stage3_changed || stage4_changed {
					changed = true
				}
				if strings.has_prefix(rewrite_stage4, "__SHELLX_RAW__") {
					strings.write_string(&builder, rewrite_stage4[len("__SHELLX_RAW__"):])
				} else {
					strings.write_string(&builder, "${")
					strings.write_string(&builder, rewrite_stage4)
					strings.write_byte(&builder, '}')
				}
				delete(rewrite_stage1)
				delete(rewrite_stage2)
				delete(rewrite_stage3)
				delete(rewrite_stage4)
				i = j + 1
				continue
			}
		}
		if text[i] == '{' {
			prev_non_space := byte(0)
			for k := i-1; k >= 0; k -= 1 {
				c := text[k]
				if c == ' ' || c == '\t' {
					continue
				}
				prev_non_space = c
				break
			}
			if prev_non_space == ')' {
				strings.write_byte(&builder, text[i])
				i += 1
				continue
			}
			depth := 1
			j := i + 1
			for j < len(text) {
				if text[j] == '{' {
					depth += 1
				} else if text[j] == '}' {
					depth -= 1
					if depth == 0 {
						break
					}
				}
				j += 1
			}

			if j < len(text) && depth == 0 {
				inner := text[i+1 : j]
				if strings.contains(inner, "\n") || strings.contains(inner, ";") {
					strings.write_byte(&builder, text[i])
					i += 1
					continue
				}
				rewrite_stage1, stage1_changed := rewrite_zsh_modifier_parameter_tokens(inner, allocator)
				rewrite_stage2, stage2_changed := rewrite_zsh_settest_expansion_for_bash(rewrite_stage1, allocator)
				rewrite_stage3, stage3_changed := rewrite_zsh_inline_case_modifiers_for_bash(rewrite_stage2, allocator)
				rewrite_stage4, stage4_changed := rewrite_zsh_case_modifiers_for_bash(rewrite_stage3, allocator)
				if stage1_changed || stage2_changed || stage3_changed || stage4_changed {
					changed = true
					if strings.has_prefix(rewrite_stage4, "__SHELLX_RAW__") {
						strings.write_string(&builder, rewrite_stage4[len("__SHELLX_RAW__"):])
					} else {
						strings.write_string(&builder, "${")
						strings.write_string(&builder, rewrite_stage4)
						strings.write_byte(&builder, '}')
					}
				} else {
					strings.write_byte(&builder, '{')
					strings.write_string(&builder, inner)
					strings.write_byte(&builder, '}')
				}
				delete(rewrite_stage1)
				delete(rewrite_stage2)
				delete(rewrite_stage3)
				delete(rewrite_stage4)
				i = j + 1
				continue
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	out := strings.clone(strings.to_string(builder), allocator)
	tilde_rewritten, tilde_changed := strings.replace_all(out, "${~", "${", allocator)
	if tilde_changed {
		delete(out)
		out = tilde_rewritten
		changed = true
	} else {
		if raw_data(tilde_rewritten) != raw_data(out) {
			delete(tilde_rewritten)
		}
	}
	return out, changed
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
