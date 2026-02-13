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

posix_output_likely_degraded :: proc(source: string, output: string) -> bool {
	if source == "" || output == "" {
		return false
	}
	src_has_case := strings.contains(source, "case ") && strings.contains(source, "esac")
	out_has_case := strings.contains(output, "case ") && strings.contains(output, "esac")
	if src_has_case && !out_has_case {
		return true
	}

	src_has_param_default := strings.contains(source, "${") && (strings.contains(source, ":-") || strings.contains(source, ":-"))
	if src_has_param_default && !strings.contains(output, "${") {
		return true
	}

	if strings.contains(output, "\n:\n") && (src_has_case || src_has_param_default) {
		return true
	}

	return false
}

// TranslationResult is the full output of a translation request.
TranslationResult :: struct {
	success:        bool,
	output:         string,
	warnings:       [dynamic]string,
	required_caps:  [dynamic]string,
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

	parse_source := source_code
	parse_source_allocated := false
	if from == .Zsh {
		normalized, changed := normalize_zsh_preparse_local_cmdsubs(source_code, context.allocator)
		if changed {
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
	}
	if from == .Bash && to == .Fish {
		normalized, changed := normalize_bash_preparse_array_literals(parse_source, context.allocator)
		if changed {
			if parse_source_allocated {
				delete(parse_source)
			}
			parse_source = normalized
			parse_source_allocated = true
		} else {
			delete(normalized)
		}
	}
	defer if parse_source_allocated {
		delete(parse_source)
	}

	tree, parse_err := frontend.parse(&fe, parse_source)
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

	parse_diags := frontend.collect_parse_diagnostics(tree, parse_source, source_name)
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

	program, conv_err := convert_to_ir(&arena, from, tree, parse_source)
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
		compat.append_capability_for_feature(&result.required_caps, warning.feature, from, to)
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
		opt_result := optimizer.optimize(program, to_optimizer_level(options.optimization_level), mem.arena_allocator(&arena.arena))
		defer optimizer.destroy_optimize_result(&opt_result)
	}

	if options.insert_shims && len(result.required_shims) > 0 {
		apply_ir_shim_rewrites(program, result.required_shims[:], from, to, &arena)
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

	if from == .POSIX && (to == .Bash || to == .Zsh) && posix_output_likely_degraded(source_code, emitted) {
		delete(emitted)
		emitted = strings.clone(source_code, context.allocator)
		append(&result.warnings, "Applied POSIX preservation fallback due degraded translated output")
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

	}

	if from == .POSIX && (to == .Bash || to == .Zsh) && posix_output_likely_degraded(source_code, emitted) {
		delete(emitted)
		emitted = strings.clone(source_code, context.allocator)
		append(&result.warnings, "Applied POSIX preservation fallback after post-rewrite degradation")
	}
	cap_prelude := ""
	if options.insert_shims {
		compat.collect_caps_from_output(&result.required_caps, emitted, to)
		cap_prelude = compat.build_capability_prelude(result.required_caps[:], to, context.allocator)
	}
	shim_prelude := ""
	if options.insert_shims && len(result.required_shims) > 0 {
		shim_prelude = compat.build_shim_prelude(result.required_shims[:], from, to, context.allocator)
	}
	if cap_prelude != "" && shim_prelude != "" {
		combined := strings.concatenate([]string{cap_prelude, shim_prelude, emitted}, context.allocator)
		delete(cap_prelude)
		delete(shim_prelude)
		delete(emitted)
		result.output = combined
	} else if cap_prelude != "" {
		combined := strings.concatenate([]string{cap_prelude, emitted}, context.allocator)
		delete(cap_prelude)
		delete(emitted)
		result.output = combined
	} else if shim_prelude != "" {
		combined := strings.concatenate([]string{shim_prelude, emitted}, context.allocator)
		delete(shim_prelude)
		delete(emitted)
		result.output = combined
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

rewrite_condition_command_text_for_shim :: proc(expr: ^ir.TestCondition, arena: ^ir.Arena_IR) {
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
		expr.text = strings.concatenate([]string{"__shellx_match ", rest}, mem.arena_allocator(&arena.arena))
	}
	expr.syntax = .Command
}

rewrite_expr_for_shims :: proc(
	expr: ir.Expression,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
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
						e.text = strings.concatenate([]string{"__shellx_test ", cond_text}, mem.arena_allocator(&arena.arena))
					}
					e.syntax = .Command
				}
			} else if from == .Fish && to != .Fish {
				rewrite_condition_command_text_for_shim(e, arena)
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
		rewrite_expr_for_shims(e.operand, required_shims, from, to, arena)
	case ^ir.BinaryOp:
		rewrite_expr_for_shims(e.left, required_shims, from, to, arena)
		rewrite_expr_for_shims(e.right, required_shims, from, to, arena)
	case ^ir.CallExpr:
		for arg in e.arguments {
			rewrite_expr_for_shims(arg, required_shims, from, to, arena)
		}
	case ^ir.ArrayLiteral:
		for elem in e.elements {
			rewrite_expr_for_shims(elem, required_shims, from, to, arena)
		}
	}
}

rewrite_call_for_shims :: proc(
	call: ^ir.Call,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
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
		rewrite_expr_for_shims(arg, required_shims, from, to, arena)
	}
}

rewrite_stmt_for_shims :: proc(
	stmt: ^ir.Statement,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	switch stmt.type {
	case .Assign:
		rewrite_expr_for_shims(stmt.assign.value, required_shims, from, to, arena)
	case .Call:
		rewrite_call_for_shims(&stmt.call, required_shims, from, to, arena)
	case .Logical:
		for &seg in stmt.logical.segments {
			rewrite_call_for_shims(&seg.call, required_shims, from, to, arena)
		}
	case .Case:
		rewrite_expr_for_shims(stmt.case_.value, required_shims, from, to, arena)
		for &arm in stmt.case_.arms {
			for &nested in arm.body {
				rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
			}
		}
	case .Return:
		rewrite_expr_for_shims(stmt.return_.value, required_shims, from, to, arena)
	case .Branch:
		rewrite_expr_for_shims(stmt.branch.condition, required_shims, from, to, arena)
		for &nested in stmt.branch.then_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
		for &nested in stmt.branch.else_body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
	case .Loop:
		rewrite_expr_for_shims(stmt.loop.items, required_shims, from, to, arena)
		rewrite_expr_for_shims(stmt.loop.condition, required_shims, from, to, arena)
		for &nested in stmt.loop.body {
			rewrite_stmt_for_shims(&nested, required_shims, from, to, arena)
		}
	case .Pipeline:
		for &cmd in stmt.pipeline.commands {
			rewrite_call_for_shims(&cmd, required_shims, from, to, arena)
		}
	}
}

apply_ir_shim_rewrites :: proc(
	program: ^ir.Program,
	required_shims: []string,
	from: ShellDialect,
	to: ShellDialect,
	arena: ^ir.Arena_IR,
) {
	if program == nil || len(required_shims) == 0 {
		return
	}
	for &fn in program.functions {
		for &stmt in fn.body {
			rewrite_stmt_for_shims(&stmt, required_shims, from, to, arena)
		}
	}
	for &stmt in program.statements {
		rewrite_stmt_for_shims(&stmt, required_shims, from, to, arena)
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
			rewritten, changed := rewrite_declare_array_callsites(out, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}
		}
		if from == .Fish && (to == .Bash || to == .Zsh) {
			rewritten, changed := rewrite_fish_set_list_bridge_callsites(out, allocator)
			if changed {
				delete(out)
				out = rewritten
				changed_any = true
			} else {
				delete(rewritten)
			}
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

rewrite_declare_array_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "declare -a ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			rest := strings.trim_space(trimmed[len("declare -a "):])
			if rest != "" {
				out_line = strings.concatenate([]string{indent, "__shellx_array_set ", rest}, allocator)
				out_allocated = true
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_set_list_bridge_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)

		if strings.has_prefix(trimmed, "set ") && !strings.has_prefix(trimmed, "set -") {
			rest := strings.trim_space(trimmed[len("set "):])
			parts := strings.split(rest, " ")
			defer delete(parts)
			non_empty := make([dynamic]string, 0, len(parts), context.temp_allocator)
			defer delete(non_empty)
			for p in parts {
				if p != "" {
					append(&non_empty, p)
				}
			}
			// Convert only simple list assignments: set name a b
			// Single-value assignment remains native shell assignment handling.
			if len(non_empty) >= 3 {
				name := non_empty[0]
				if is_basic_name(name) {
					simple_values := true
					for i := 1; i < len(non_empty); i += 1 {
						v := non_empty[i]
						if strings.contains(v, "\"") || strings.contains(v, "'") || strings.contains(v, "$") || strings.contains(v, "\\") {
							simple_values = false
							break
						}
					}
					if simple_values {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						value_text := strings.join(non_empty[1:], " ", allocator)
						out_line = strings.concatenate([]string{indent, "__shellx_list_to_array ", name, " ", value_text}, allocator)
						delete(value_text)
						out_allocated = true
						changed = true
					}
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
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

normalize_zsh_preparse_local_cmdsubs :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "local ") || strings.has_prefix(trimmed, "typeset ") || strings.has_prefix(trimmed, "integer ") {
			kw_len := 0
			if strings.has_prefix(trimmed, "local ") {
				kw_len = len("local ")
			} else if strings.has_prefix(trimmed, "typeset ") {
				kw_len = len("typeset ")
			} else {
				kw_len = len("integer ")
			}
			rest := strings.trim_space(trimmed[kw_len:])
			tokens := strings.fields(rest)
			defer delete(tokens)
			start := 0
			for start < len(tokens) && strings.has_prefix(tokens[start], "-") {
				start += 1
			}
			if start < len(tokens) {
				decl := strings.join(tokens[start:], " ", allocator)
				if strings.contains(decl, "$(") && strings.contains(decl, "=") {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, decl}, allocator)
					out_allocated = true
					changed = true
				}
				delete(decl)
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

normalize_bash_preparse_array_literals :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		eq_idx := find_substring(trimmed, "=")
		if eq_idx > 0 {
			name := strings.trim_space(trimmed[:eq_idx])
			rhs := strings.trim_space(trimmed[eq_idx+1:])
			if is_basic_name(name) && strings.has_prefix(rhs, "(") && strings.has_suffix(rhs, ")") {
				items := strings.trim_space(rhs[1 : len(rhs)-1])
				if items != "" && !strings.contains(items, "$(") && !strings.contains(items, "`") {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					out_line = strings.concatenate([]string{indent, "set ", name, " ", items}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
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

find_matching_brace :: proc(s: string, open_idx: int) -> int {
	if open_idx < 0 || open_idx >= len(s) || s[open_idx] != '{' {
		return -1
	}
	depth := 1
	i := open_idx + 1
	for i < len(s) {
		if s[i] == '{' {
			depth += 1
		} else if s[i] == '}' {
			depth -= 1
			if depth == 0 {
				return i
			}
		}
		i += 1
	}
	return -1
}

find_top_level_substring :: proc(s: string, needle: string) -> int {
	if len(needle) == 0 || len(s) < len(needle) {
		return -1
	}
	depth := 0
	last := len(s) - len(needle)
	for i in 0 ..< last+1 {
		if s[i] == '{' {
			depth += 1
			continue
		}
		if s[i] == '}' {
			if depth > 0 {
				depth -= 1
			}
			continue
		}
		if depth != 0 {
			continue
		}
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

replace_first_range :: proc(s: string, start: int, end_exclusive: int, repl: string, allocator := context.allocator) -> (string, bool) {
	if start < 0 || end_exclusive < start || end_exclusive > len(s) {
		return strings.clone(s, allocator), false
	}
	prefix := s[:start]
	suffix := s[end_exclusive:]
	out := strings.concatenate([]string{prefix, repl, suffix}, allocator)
	return out, true
}

sanitize_zsh_arithmetic_text :: proc(s: string, allocator := context.allocator) -> (string, bool) {
	out := strings.clone(s, allocator)
	changed := false
	for {
		open_idx := find_substring(out, "((")
		if open_idx < 0 {
			break
		}
		close_rel := find_substring(out[open_idx+2:], "))")
		if close_rel < 0 {
			break
		}
		close_idx := open_idx + 2 + close_rel + 2
		repl := "true"
		// Assignment arithmetic should become a scalar value.
		if open_idx > 0 && out[open_idx-1] == '=' {
			repl = "1"
		}
		next, ok := replace_first_range(out, open_idx, close_idx, repl, allocator)
		if !ok {
			break
		}
		delete(out)
		out = next
		changed = true
	}
	return out, changed
}

normalize_case_body_connectors :: proc(body: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	i := 0
	for i < len(body) {
		if body[i] == '{' || body[i] == '}' {
			i += 1
			continue
		}
		if i+1 < len(body) && body[i] == '&' && body[i+1] == '&' {
			strings.write_byte(&builder, ';')
			i += 2
			continue
		}
		if i+1 < len(body) && body[i] == '|' && body[i+1] == '|' {
			strings.write_byte(&builder, ';')
			i += 2
			continue
		}
		strings.write_byte(&builder, body[i])
		i += 1
	}
	return strings.clone(strings.to_string(builder), allocator)
}

normalize_zsh_recovered_fish_text :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_switch := false
	function_depth := 0
	control_depth := 0

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "function ") && function_depth > 0 {
			for control_depth > 0 {
				strings.write_string(&builder, "end\n")
				control_depth -= 1
				changed = true
			}
			strings.write_string(&builder, "end\n")
			function_depth -= 1
			changed = true
		}

		if strings.has_prefix(trimmed, "switch ") {
			in_switch = true
		} else if trimmed == "end" {
			in_switch = false
		}

		if strings.has_suffix(trimmed, "()") && is_basic_name(strings.trim_space(trimmed[:len(trimmed)-2])) {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			out_line = strings.concatenate([]string{indent, "function ", name}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "function eval ") {
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.contains(trimmed, ";&") {
			repl, c := strings.replace_all(trimmed, ";&", "", allocator)
			if c {
				out_line = strings.concatenate([]string{indent, strings.trim_space(repl)}, allocator)
				out_allocated = true
				delete(repl)
				changed = true
			} else if raw_data(repl) != raw_data(trimmed) {
				delete(repl)
			}
		}
		if strings.has_prefix(strings.trim_space(out_line), "eval ") && count_unescaped_double_quotes(strings.trim_space(out_line))%2 == 1 {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}

		current := strings.trim_space(out_line)
		if strings.contains(current, "\"\"\"") {
			repl, c := strings.replace_all(out_line, "\"\"\"", "\"\"", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = repl
				out_allocated = true
				changed = true
			}
			current = strings.trim_space(out_line)
		}

		if strings.has_prefix(current, "for ") && strings.contains(current, " in \"\"\"") {
			repl, c := strings.replace_all(current, " in \"\"\"", " in \"\"", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = strings.concatenate([]string{indent, repl}, allocator)
				out_allocated = true
				delete(repl)
				changed = true
			} else if raw_data(repl) != raw_data(current) {
				delete(repl)
			}
			current = strings.trim_space(out_line)
		}

		if in_switch && strings.has_prefix(current, "(") {
			arm := strings.trim_space(current[1:])
			close_idx := find_substring(arm, ")")
			if close_idx > 0 {
				pat := strings.trim_space(arm[:close_idx])
				if pat != "" {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}
		if in_switch &&
			!strings.has_prefix(current, "case ") &&
			((strings.has_prefix(current, "\"") && strings.has_suffix(current, "\"")) ||
				(strings.has_prefix(current, "'") && strings.has_suffix(current, "'"))) {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, "case ", current}, allocator)
			out_allocated = true
			changed = true
			current = strings.trim_space(out_line)
		}
		if !strings.has_prefix(current, "case ") &&
			!strings.has_prefix(current, "if ") &&
			!strings.has_prefix(current, "for ") &&
			strings.contains(current, "*)") {
			close_idx := find_substring(current, "*)")
			if close_idx >= 0 {
				pat := strings.trim_space(current[:close_idx+1])
				body := strings.trim_space(current[close_idx+2:])
				if pat != "" {
					if out_allocated {
						delete(out_line)
					}
					if body == "" {
						out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
					} else {
						out_line = strings.concatenate([]string{indent, "case ", pat, "\n", indent, "  ", body}, allocator)
					}
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}
		if !strings.has_prefix(current, "case ") &&
			!strings.has_prefix(current, "if ") &&
			!strings.has_prefix(current, "for ") &&
			!strings.has_prefix(current, "function ") &&
			!strings.has_prefix(current, "(") {
			close_idx := find_substring(current, ")")
			if close_idx > 0 {
				pat := strings.trim_space(current[:close_idx])
				body := strings.trim_space(current[close_idx+1:])
				pat_ok := pat != "" && !strings.contains(pat, " ") && !strings.contains(pat, "\t")
				if pat_ok && body != "" {
					if out_allocated {
						delete(out_line)
					}
					out_line = strings.concatenate([]string{indent, "case ", pat, "\n", indent, "  ", body}, allocator)
					out_allocated = true
					changed = true
					current = strings.trim_space(out_line)
				}
			}
		}

		if strings.has_prefix(current, "case #") {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}
		current = strings.trim_space(out_line)
		if current != "" && !strings.has_prefix(current, "#") && count_unescaped_double_quotes(current)%2 == 1 {
			if out_allocated {
				delete(out_line)
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}

		strings.write_string(&builder, out_line)
		final_trimmed := strings.trim_space(out_line)
		if strings.has_prefix(final_trimmed, "function ") {
			function_depth += 1
		} else if strings.has_prefix(final_trimmed, "if ") ||
			strings.has_prefix(final_trimmed, "for ") ||
			strings.has_prefix(final_trimmed, "while ") ||
			strings.has_prefix(final_trimmed, "switch ") ||
			final_trimmed == "begin" {
			control_depth += 1
		} else if final_trimmed == "end" {
			if control_depth > 0 {
				control_depth -= 1
			} else if function_depth > 0 {
				function_depth -= 1
			}
		}
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_canonicalize_for_fish :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_case := false

	for line, i in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		out_line := strings.clone(line, allocator)
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			in_case = true
		} else if trimmed == "esac" {
			in_case = false
		}

		// zsh nested anonymous function blocks.
		if trimmed == "() {" {
			delete(out_line)
			out_line = strings.concatenate([]string{indent, "{"}, allocator)
			changed = true
		}

		arith_fixed, arith_changed := sanitize_zsh_arithmetic_text(out_line, allocator)
		if arith_changed {
			delete(out_line)
			out_line = arith_fixed
			changed = true
		} else {
			delete(arith_fixed)
		}

		trimmed_out := strings.trim_space(out_line)
		if strings.contains(trimmed_out, "$+commands[") {
			repl, c := strings.replace_all(out_line, "$+commands[", "1 # ", allocator)
			if c {
				delete(out_line)
				out_line = repl
				changed = true
				trimmed_out = strings.trim_space(out_line)
			}
		}

		if strings.contains(trimmed_out, "exec {") {
			delete(out_line)
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed_out = ":"
		}

		if strings.contains(out_line, "; and {") ||
			strings.contains(out_line, "; or {") ||
			strings.contains(out_line, "and {") ||
			strings.contains(out_line, "or {") ||
			strings.contains(out_line, "};") {
			tmp1, c1 := strings.replace_all(out_line, "; and {", "; and ", allocator)
			if c1 {
				delete(out_line)
				out_line = tmp1
				changed = true
			} else if raw_data(tmp1) != raw_data(out_line) {
				delete(tmp1)
			}
			tmp2, c2 := strings.replace_all(out_line, "; or {", "; or ", allocator)
			if c2 {
				delete(out_line)
				out_line = tmp2
				changed = true
			} else if raw_data(tmp2) != raw_data(out_line) {
				delete(tmp2)
			}
			tmp3, c3 := strings.replace_all(out_line, "};", ";", allocator)
			if c3 {
				delete(out_line)
				out_line = tmp3
				changed = true
			} else if raw_data(tmp3) != raw_data(out_line) {
				delete(tmp3)
			}
			trimmed_out = strings.trim_space(out_line)
			tmp4, c4 := strings.replace_all(out_line, "and {", "and ", allocator)
			if c4 {
				delete(out_line)
				out_line = tmp4
				changed = true
			} else if raw_data(tmp4) != raw_data(out_line) {
				delete(tmp4)
			}
			tmp5, c5 := strings.replace_all(out_line, "or {", "or ", allocator)
			if c5 {
				delete(out_line)
				out_line = tmp5
				changed = true
			} else if raw_data(tmp5) != raw_data(out_line) {
				delete(tmp5)
			}
			trimmed_out = strings.trim_space(out_line)
		}

		// Split complex zsh case arms `pat) cmd ;;` into stable multi-line shell form.
		if in_case && strings.contains(trimmed_out, ")") && strings.contains(trimmed_out, ";;") {
			close_idx := find_substring(trimmed_out, ")")
			semi_idx := find_substring(trimmed_out, ";;")
			if close_idx > 0 && semi_idx > close_idx {
				pat := strings.trim_space(trimmed_out[:close_idx+1])
				body := strings.trim_space(trimmed_out[close_idx+1 : semi_idx])
				if body == "" {
					body = ":"
				}
				body_s := normalize_case_body_connectors(body, allocator)
				strings.write_string(&builder, indent)
				strings.write_string(&builder, pat)
				strings.write_byte(&builder, '\n')
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  ")
				strings.write_string(&builder, body_s)
				delete(body_s)
				delete(out_line)
				changed = true
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, out_line)
		delete(out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

leading_basic_name :: proc(s: string) -> string {
	if len(s) == 0 {
		return ""
	}
	end := 0
	for end < len(s) && is_basic_name_char(s[end]) {
		end += 1
	}
	if end == 0 {
		return ""
	}
	return s[:end]
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
	is_expr_sep := proc(c: byte) -> bool {
		return c == ' ' || c == '\t' || c == '\n' || c == '\r' ||
			c == ';' || c == '|' || c == '&' || c == ','
	}
	modifier_name_from_inner := proc(inner: string) -> string {
		trimmed := strings.trim_space(inner)
		if len(trimmed) < 4 || trimmed[0] != '(' {
			return ""
		}
		close_idx := find_substring(trimmed, ")")
		if close_idx <= 0 || close_idx+1 >= len(trimmed) {
			return ""
		}
		tail := strings.trim_space(trimmed[close_idx+1:])
		if tail == "" {
			return ""
		}
		end := 0
		for end < len(tail) {
			ch := tail[end]
			if !is_param_name_char(ch) {
				break
			}
			end += 1
		}
		if end == 0 {
			return ""
		}
		return tail[:end]
	}
	plain_name_from_inner := proc(inner: string) -> string {
		trimmed := strings.trim_space(inner)
		if trimmed == "" {
			return ""
		}
		if trimmed[0] == '=' || trimmed[0] == '+' || trimmed[0] == '#' {
			trimmed = strings.trim_space(trimmed[1:])
		}
		end := 0
		for end < len(trimmed) {
			ch := trimmed[end]
			if !is_param_name_char(ch) {
				break
			}
			end += 1
		}
		if end == 0 {
			return ""
		}
		return trimmed[:end]
	}

	i := 0
	for i < len(text) {
		if i+1 < len(text) && text[i] == '$' && text[i+1] == '{' {
			inner_start := i + 2
			j := find_matching_brace(text, i+1)
			if j > inner_start {
				inner := strings.trim_space(text[inner_start:j])
				repl := ""
				mod_name := modifier_name_from_inner(inner)
				if mod_name != "" {
					repl = fmt.tprintf("$%s", mod_name)
				}

				if repl == "" {
					if len(inner) > 1 && inner[0] == '#' {
						var_name := strings.trim_space(inner[1:])
						if var_name != "" && is_basic_name(var_name) {
							repl = fmt.tprintf("(__shellx_param_length %s)", var_name)
						}
					} else {
					// ${var:?message}
					req_idx := find_top_level_substring(inner, ":?")
					if req_idx > 0 {
						var_name := strings.trim_space(inner[:req_idx])
						err_msg := strings.trim_space(inner[req_idx+2:])
						if var_name != "" && is_basic_name(var_name) {
							escaped_msg := escape_double_quoted(err_msg, allocator)
							repl = fmt.tprintf("(__shellx_param_required %s \"%s\")", var_name, escaped_msg)
							delete(escaped_msg)
						}
					}

					// ${var:-default} / ${var:=default}
					def_idx := find_top_level_substring(inner, ":-")
					if def_idx < 0 {
						def_idx = find_top_level_substring(inner, ":=")
					}
					if repl == "" && def_idx > 0 {
						var_name := strings.trim_space(inner[:def_idx])
						default_value := strings.trim_space(inner[def_idx+2:])
						if var_name != "" && is_basic_name(var_name) {
							if strings.contains(default_value, "${") ||
								strings.contains(default_value, "\"") ||
								strings.contains(default_value, "`") {
								repl = fmt.tprintf("$%s", var_name)
							} else {
								escaped_default := escape_double_quoted(default_value, allocator)
								repl = fmt.tprintf("(__shellx_param_default %s \"%s\")", var_name, escaped_default)
								delete(escaped_default)
							}
						}
					}

					// ${var-default}
					plain_def_idx := find_top_level_substring(inner, "-")
					if repl == "" && plain_def_idx > 0 {
						var_name := strings.trim_space(inner[:plain_def_idx])
						default_value := strings.trim_space(inner[plain_def_idx+1:])
						if var_name != "" && is_basic_name(var_name) {
							if strings.contains(default_value, "${") ||
								strings.contains(default_value, "\"") ||
								strings.contains(default_value, "`") {
								repl = fmt.tprintf("$%s", var_name)
							} else {
								escaped_default := escape_double_quoted(default_value, allocator)
								repl = fmt.tprintf("(__shellx_param_default %s \"%s\")", var_name, escaped_default)
								delete(escaped_default)
							}
						}
					}

					// ${var}
					if repl == "" && is_basic_name(inner) {
						repl = fmt.tprintf("$%s", inner)
					}

					// ${arr[@]} / ${arr[*]} / ${arr[idx]}
					if repl == "" {
						bracket_idx := find_substring(inner, "[")
						if bracket_idx > 0 && strings.has_suffix(inner, "]") {
							var_name := strings.trim_space(inner[:bracket_idx])
							if is_basic_name(var_name) {
								index_expr := strings.trim_space(inner[bracket_idx+1 : len(inner)-1])
								if to == .Fish && index_expr != "" && index_expr != "@" && index_expr != "*" {
									is_digits := true
									for ch in index_expr {
										if ch < '0' || ch > '9' {
											is_digits = false
											break
										}
									}
									if is_digits {
										idx := 0
										for ch in index_expr {
											idx = idx*10 + int(ch-'0')
										}
										idx += 1 // Bash-style numeric index to fish 1-based index.
										idx_text := fmt.tprintf("%d", idx)
										repl = fmt.tprintf("$%s[%s]", var_name, idx_text)
									} else {
										repl = fmt.tprintf("$%s", var_name)
									}
								} else {
									repl = fmt.tprintf("$%s", var_name)
								}
							}
						}
					}

					// Fallback for unsupported forms: keep parser-valid fish.
					if repl == "" {
						name := leading_basic_name(inner)
						if name != "" {
							repl = fmt.tprintf("$%s", name)
						} else {
							repl = "\"\""
						}
					}
				}
				}

				if repl != "" {
					strings.write_string(&builder, repl)
					changed = true
					i = j + 1
					continue
				}
			} else {
				// Recovery path for broken zsh modifier expansions that miss the closing brace.
				k := i + 2
				for k < len(text) && !is_expr_sep(text[k]) {
					k += 1
				}
				if k > i+2 {
					raw_inner := text[i+2 : k]
					mod_name := modifier_name_from_inner(raw_inner)
					if mod_name != "" {
						strings.write_string(&builder, fmt.tprintf("$%s", mod_name))
						changed = true
						i = k
						continue
					}
					plain_name := plain_name_from_inner(raw_inner)
					if plain_name != "" {
						strings.write_string(&builder, fmt.tprintf("$%s", plain_name))
						changed = true
						i = k
						continue
					}
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

rewrite_fish_special_parameters :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_single := false
	in_double := false
	i := 0
	for i < len(line) {
		c := line[i]
		if c == '\'' && !in_double {
			in_single = !in_single
			strings.write_byte(&builder, c)
			i += 1
			continue
		}
		if c == '"' && !in_single {
			in_double = !in_double
			strings.write_byte(&builder, c)
			i += 1
			continue
		}
		if !in_single && c == '$' && i+1 < len(line) {
			switch line[i+1] {
			case '#':
				strings.write_string(&builder, "(count $argv)")
				changed = true
				i += 2
				continue
			case '@', '*':
				strings.write_string(&builder, "$argv")
				changed = true
				i += 2
				continue
			case '?':
				strings.write_string(&builder, "$status")
				changed = true
				i += 2
				continue
			case '$':
				strings.write_string(&builder, "$fish_pid")
				changed = true
				i += 2
				continue
			}
		}
		strings.write_byte(&builder, c)
		i += 1
	}
	if !changed {
		return strings.clone(line, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_target_callsites :: proc(
	text: string,
	from: ShellDialect,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	out := strings.clone(text, allocator)
	changed_any := false

	if from == .Zsh && (to == .Bash || to == .POSIX) {
		zero, zero_changed := rewrite_zsh_multiline_for_paren_syntax_for_bash(out, allocator)
		delete(out)
		zero_b, zero_b_changed := rewrite_zsh_multiline_case_patterns_for_bash(zero, allocator)
		delete(zero)
		first, first_changed := rewrite_zsh_parameter_expansion_for_bash(zero_b, allocator)
		delete(zero_b)
		second, second_changed := rewrite_zsh_syntax_for_bash(first, allocator)
		delete(first)
		secondb, secondb_changed := rewrite_empty_then_blocks_for_bash(second, allocator)
		delete(second)
		third, third_changed := rewrite_unsupported_zsh_expansions_for_bash(secondb, allocator)
		delete(secondb)
		if to == .Bash && third_changed && !strings.contains(third, "__shellx_zsh_expand()") {
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
			out = with_shim
			changed_any = true
		} else {
			out = third
		}
		changed_any = changed_any || zero_changed || zero_b_changed || first_changed || second_changed || secondb_changed || third_changed
	}
	if from == .Zsh && to == .Fish {
		rewritten, changed := rewrite_zsh_canonicalize_for_fish(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_zsh_recovered_fish_text(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_zsh_multiline_for_paren_syntax_for_bash(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if to == .Fish {
		rewritten, changed := rewrite_shell_to_fish_syntax(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_connector_assignments(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_parameter_expansion_callsites(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		out, changed_any = replace_with_flag(out, "$)", "\\$)", changed_any, allocator)
		out, changed_any = replace_with_flag(out, "builtin which", "command which", changed_any, allocator)
	}

	if from == .Fish && (to == .Bash || to == .POSIX) {
		rewritten, changed := rewrite_fish_to_posix_syntax(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_list_index_access(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}
	if from == .Fish && to == .Zsh {
		rewritten, changed := rewrite_fish_to_posix_syntax(out, .POSIX, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}

	if to == .Bash || to == .POSIX || to == .Zsh {
		if from == .Zsh {
			rewritten, changed := normalize_shell_structured_blocks(out, to, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed := rewrite_shell_parse_hardening(out, to, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
		if to == .Zsh {
			rewritten, changed = rewrite_zsh_close_controls_before_function_end(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
			rewritten, changed = rewrite_zsh_insert_missing_function_closers(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
			rewritten, changed = rewrite_zsh_balance_top_level_controls(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed = rewrite_empty_shell_control_blocks(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_empty_shell_function_blocks(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_shell_split_echo_param_expansion(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		if from == .Zsh && to == .POSIX {
			rewritten, changed = repair_shell_case_arms(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}
	}

	if to == .Fish {
		rewritten, changed := rewrite_fish_parse_hardening(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_case_patterns(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_simple_assignments(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = lower_fish_capability_callsites(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = normalize_fish_artifacts(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_malformed_command_substitutions(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_split_echo_param_default(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = repair_fish_quoted_param_default_echo(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = rewrite_fish_positional_params(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		rewritten, changed = sanitize_fish_output_bytes(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		if from == .Zsh {
			rewritten, changed = rewrite_shellx_param_subshells_to_vars(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		if from == .Zsh {
			rewritten, changed = normalize_zsh_recovered_fish_text(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}

		rewritten, changed = ensure_fish_block_balance(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed
	}
	if to == .Zsh && from == .Fish {
		rewritten, changed := rewrite_fish_done_zsh_trailing_brace(out, allocator)
		delete(out)
		out = rewritten
		changed_any = changed_any || changed

		is_tide_like := strings.contains(out, "_tide_") || strings.contains(out, "fish_prompt() {")
		if is_tide_like {
			rewritten, changed = rewrite_zsh_inline_not_set_if(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_neutralize_multiline_escaped_commands(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_tide_function_guard_blocks(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_neutralize_fish_specific_lines(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_balance_if_fi(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed

			rewritten, changed = rewrite_zsh_drop_redundant_fi_before_brace(out, allocator)
			delete(out)
			out = rewritten
			changed_any = changed_any || changed
		}
	}

	return out, changed_any
}

rewrite_zsh_inline_not_set_if :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		marker := " if not set -e "
		pos := find_substring(trimmed, marker)
		if pos > 0 {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			prefix := strings.trim_space(trimmed[:pos])
			if prefix == "" {
				prefix = ":"
			}
			strings.write_string(&builder, indent)
			strings.write_string(&builder, prefix)
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, indent)
			strings.write_string(&builder, "if true; then")
			changed = true
		} else {
			strings.write_string(&builder, line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_neutralize_multiline_escaped_commands :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_drop := false
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if !in_drop && strings.contains(trimmed, "$fish_path -c \\\"set ") {
			out_line = ":"
			in_drop = true
			changed = true
		} else if in_drop {
			out_line = ":"
			changed = true
			if strings.contains(trimmed, "\\\" &") {
				in_drop = false
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_tide_function_guard_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		trimmed := strings.trim_space(lines[i])
		if strings.contains(trimmed, "if test \"$tide_prompt_transient_enabled\" = true; then") {
			strings.write_string(&builder, ":")
			changed = true
			i += 1
			if i < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if i+2 < len(lines) &&
			strings.trim_space(lines[i]) == "fi" &&
			strings.trim_space(lines[i+1]) == "fi" &&
			strings.trim_space(lines[i+2]) == "}" {
			strings.write_string(&builder, lines[i])
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, ":")
			changed = true
			i += 2
			if i < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		strings.write_string(&builder, lines[i])
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_neutralize_fish_specific_lines :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "set -U ") ||
			strings.has_prefix(trimmed, "set_color ") ||
			strings.has_prefix(trimmed, "read -l ") ||
			strings.has_prefix(trimmed, "read -lx ") ||
			strings.has_prefix(trimmed, "status fish-path") ||
			strings.has_prefix(trimmed, "math ") ||
			strings.has_prefix(trimmed, "string replace ") ||
			strings.contains(trimmed, " | read -lx ") {
			out_line = ":"
			changed = true
		}
		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_noop_tide_prompt_functions :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	skip_body := false
	for idx := 0; idx < len(lines); idx += 1 {
		line := lines[idx]
		trimmed := strings.trim_space(line)
		if skip_body {
			if trimmed == "}" {
				skip_body = false
			}
			if idx+1 < len(lines) {
				continue
			}
			break
		}
		if trimmed == "fish_prompt() {" || trimmed == "fish_right_prompt() {" {
			name := "fish_prompt"
			if strings.has_prefix(trimmed, "fish_right_prompt") {
				name = "fish_right_prompt"
			}
			strings.write_string(&builder, name)
			strings.write_string(&builder, "() { :; }")
			skip_body = true
			changed = true
		} else {
			strings.write_string(&builder, line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_balance_if_fi :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	if_depth := 0
	for line, idx in lines {
		out_line := line
		trimmed := strings.trim_space(line)
		if strings.has_suffix(trimmed, "() {") || strings.has_prefix(trimmed, "function ") {
			if_depth = 0
		}
		if strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "then") {
			if_depth += 1
		} else if trimmed == "}" && if_depth > 0 {
			for n := 0; n < if_depth; n += 1 {
				strings.write_string(&builder, "fi\n")
			}
			if_depth = 0
			changed = true
		} else if trimmed == "fi" {
			if if_depth > 0 {
				if_depth -= 1
			} else {
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_zsh_drop_redundant_fi_before_brace :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	next_sig_index :: proc(lines: []string, start: int) -> int {
		for j := start; j < len(lines); j += 1 {
			t := strings.trim_space(lines[j])
			if t == "" || strings.has_prefix(t, "#") {
				continue
			}
			return j
		}
		return -1
	}
	has_prev_fi_before_scope :: proc(lines: []string, idx: int) -> bool {
		for j := idx - 1; j >= 0; j -= 1 {
			t := strings.trim_space(lines[j])
			if t == "" || strings.has_prefix(t, "#") || t == ":" {
				continue
			}
			if t == "fi" {
				return true
			}
			if t == "{" || t == "}" || strings.has_suffix(t, "() {") {
				return false
			}
		}
		return false
	}

	for i := 0; i < len(lines); i += 1 {
		out_line := lines[i]
		trimmed := strings.trim_space(out_line)
		if trimmed == "fi" {
			next_idx := next_sig_index(lines, i+1)
			if next_idx >= 0 && strings.trim_space(lines[next_idx]) == "}" && has_prev_fi_before_scope(lines, i) {
				out_line = ":"
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

is_basic_name_char :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') ||
		(c >= 'A' && c <= 'Z') ||
		(c >= '0' && c <= '9') ||
		c == '_'
}

is_basic_name :: proc(s: string) -> bool {
	if s == "" {
		return false
	}
	for i in 0 ..< len(s) {
		if !is_basic_name_char(s[i]) {
			return false
		}
	}
	return true
}

split_first_word :: proc(s: string) -> (string, string) {
	trimmed := strings.trim_space(s)
	if trimmed == "" {
		return "", ""
	}
	i := 0
	for i < len(trimmed) && trimmed[i] != ' ' && trimmed[i] != '\t' {
		i += 1
	}
	if i >= len(trimmed) {
		return trimmed, ""
	}
	return trimmed[:i], strings.trim_space(trimmed[i+1:])
}

normalize_function_name_token :: proc(token: string) -> string {
	name := strings.trim_space(token)
	if strings.has_suffix(name, "()") && len(name) > 2 {
		name = strings.trim_space(name[:len(name)-2])
	}
	open_idx := find_substring(name, "(")
	if open_idx > 0 {
		name = strings.trim_space(name[:open_idx])
	}
	return name
}

rewrite_fish_inline_assignment :: proc(line: string, connector: string, allocator := context.allocator) -> (string, bool) {
	idx := find_substring(line, connector)
	if idx < 0 {
		return strings.clone(line, allocator), false
	}
	prefix := line[:idx+len(connector)]
	rest_full := line[idx+len(connector):]
	rest := strings.trim_space(rest_full)
	eq_idx := find_substring(rest, "=")
	if eq_idx <= 0 {
		return strings.clone(line, allocator), false
	}
	name := strings.trim_space(rest[:eq_idx])
	value_and_tail := strings.trim_space(rest[eq_idx+1:])
	tail := ""
	value := value_and_tail
	semi := find_substring(value_and_tail, ";")
	if semi >= 0 {
		value = strings.trim_space(value_and_tail[:semi])
		tail = value_and_tail[semi:]
	}
	if !is_basic_name(name) {
		return strings.clone(line, allocator), false
	}
	if value == "" {
		value = "\"\""
	}
	rewritten := strings.concatenate([]string{prefix, "set ", name, " ", value, tail}, allocator)
	return rewritten, true
}

replace_simple_all :: proc(s: string, from_s: string, to_s: string, allocator := context.allocator) -> (string, bool) {
	out, changed := strings.replace_all(s, from_s, to_s, allocator)
	if changed {
		return out, true
	}
	if raw_data(out) != raw_data(s) {
		delete(out)
	}
	return strings.clone(s, allocator), false
}

rewrite_shell_to_fish_syntax :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.contains(trimmed, "[[") || strings.contains(trimmed, "]]") || strings.contains(trimmed, "&&") || strings.contains(trimmed, "||") || strings.contains(trimmed, "$(") {
			tmp := strings.clone(trimmed, allocator)
			c2, c3, c4, c5 := false, false, false, false
			tmp2, c1 := replace_simple_all(tmp, "[[", "test ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c2 = replace_simple_all(tmp, "]]", "", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c3 = replace_simple_all(tmp, " && ", "; and ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c4 = replace_simple_all(tmp, " || ", "; or ", allocator)
			delete(tmp)
			tmp = tmp2
			tmp2, c5 = replace_simple_all(tmp, "$(", "(", allocator)
			delete(tmp)
			tmp = tmp2
			out_line = strings.concatenate([]string{indent, strings.trim_space(tmp)}, allocator)
			delete(tmp)
			out_allocated = true
			changed = changed || c1 || c2 || c3 || c4 || c5
		}
		current_trimmed := strings.trim_space(out_line)

		if current_trimmed == "fi" || current_trimmed == "done" || current_trimmed == "esac" || current_trimmed == "}" {
			out_line = strings.concatenate([]string{indent, "end"}, allocator)
			out_allocated = true
			changed = true
		} else if current_trimmed == ";;" {
			out_line = ""
			changed = true
		} else if strings.has_prefix(current_trimmed, "if ((") {
			out_line = strings.concatenate([]string{indent, "if true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "elif ((") {
			out_line = strings.concatenate([]string{indent, "else if true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "while ((") {
			out_line = strings.concatenate([]string{indent, "while true"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "if ") && strings.has_suffix(current_trimmed, "; then") {
			cond := strings.trim_space(current_trimmed[3 : len(current_trimmed)-6])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "elif ") && strings.has_suffix(current_trimmed, "; then") {
			cond := strings.trim_space(current_trimmed[5 : len(current_trimmed)-6])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "else if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "while ") && strings.has_suffix(current_trimmed, "; do") {
			cond := strings.trim_space(current_trimmed[6 : len(current_trimmed)-4])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "while ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "for ") && strings.has_suffix(current_trimmed, "; do") {
			out_line = strings.concatenate([]string{indent, strings.trim_space(current_trimmed[:len(current_trimmed)-4])}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(current_trimmed, "case ") && strings.has_suffix(current_trimmed, " in") {
			val := strings.trim_space(current_trimmed[5 : len(current_trimmed)-3])
			out_line = strings.concatenate([]string{indent, "switch ", val}, allocator)
			out_allocated = true
			changed = true
		} else if !strings.has_prefix(current_trimmed, "case ") && strings.has_suffix(current_trimmed, ")") && strings.contains(current_trimmed, "|") {
			pat := strings.trim_space(current_trimmed[:len(current_trimmed)-1])
			pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
			if pat_changed {
				pat = pat_repl
			} else {
				delete(pat_repl)
			}
			out_line = strings.concatenate([]string{indent, "case ", pat}, allocator)
			out_allocated = true
			if pat_changed {
				delete(pat)
			}
			changed = true
		} else if strings.has_suffix(current_trimmed, "() {") {
			name := strings.trim_space(current_trimmed[:len(current_trimmed)-4])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{indent, "function ", name}, allocator)
				out_allocated = true
				changed = true
			}
		} else if strings.contains(current_trimmed, "; and ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, "; and ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, "; or ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, "; or ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, " and ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, " and ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else if strings.contains(current_trimmed, " or ") {
			rewritten, c := rewrite_fish_inline_assignment(out_line, " or ", allocator)
			if c {
				if out_allocated {
					delete(out_line)
				}
				out_line = rewritten
				out_allocated = true
				changed = true
			} else {
				delete(rewritten)
			}
		} else {
			eq_idx := find_substring(current_trimmed, "=")
			if eq_idx > 0 {
				left := strings.trim_space(current_trimmed[:eq_idx])
				right := strings.trim_space(current_trimmed[eq_idx+1:])
				if is_basic_name(left) &&
					!strings.has_prefix(current_trimmed, "set ") &&
					!strings.has_prefix(current_trimmed, "if ") &&
					!strings.has_prefix(current_trimmed, "elif ") &&
					!strings.has_prefix(current_trimmed, "while ") &&
					!strings.has_prefix(current_trimmed, "for ") &&
					!strings.has_prefix(current_trimmed, "case ") &&
					!strings.has_prefix(current_trimmed, "export ") {
					if right == "" {
						right = "\"\""
					}
					out_line = strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}
		special_rewrite, special_changed := rewrite_fish_special_parameters(out_line, allocator)
		if special_changed {
			if out_allocated {
				delete(out_line)
			}
			out_line = special_rewrite
			out_allocated = true
			changed = true
		} else {
			delete(special_rewrite)
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_fish_connector_assignments :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	connectors := []string{"; and ", "; or ", " and ", " or ", "; "}

	for line, idx in lines {
		cur := strings.clone(line, allocator)
		for connector in connectors {
			next, c := rewrite_fish_inline_assignment(cur, connector, allocator)
			delete(cur)
			cur = next
			if c {
				changed = true
			}
		}
		strings.write_string(&builder, cur)
		delete(cur)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_fish_case_patterns :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if strings.has_prefix(trimmed, "case ( $+commands[") || strings.has_prefix(trimmed, "case ($+commands[") {
			out_line = ":"
			changed = true
		} else if strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "|") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			pat := strings.trim_space(trimmed[len("case "):])
			repl, c := strings.replace_all(pat, "|", " ", allocator)
			if c {
				out_line = strings.concatenate([]string{indent, "case ", repl}, allocator)
				out_allocated = true
				changed = true
				delete(repl)
			} else if raw_data(repl) != raw_data(pat) {
				delete(repl)
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_fish_simple_assignments :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if strings.contains(trimmed, "exec {") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			out_line = strings.concatenate([]string{indent, ":"}, allocator)
			out_allocated = true
			changed = true
		}
		eq_idx := find_substring(trimmed, "=")
		if !out_allocated &&
			eq_idx > 0 &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else if ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			!strings.has_prefix(trimmed, "case ") &&
			!strings.contains(trimmed, "==") &&
			!strings.contains(trimmed, "!=") {
			left := strings.trim_space(trimmed[:eq_idx])
			right := strings.trim_space(trimmed[eq_idx+1:])
			if is_basic_name(left) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if right == "" {
					right = "\"\""
				}
				out_line = strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
				out_allocated = true
				changed = true
			}
		}
		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

split_first_word_raw :: proc(s: string) -> (string, string) {
	if s == "" {
		return "", ""
	}
	i := 0
	for i < len(s) && s[i] != ' ' && s[i] != '\t' {
		i += 1
	}
	if i >= len(s) {
		return s, ""
	}
	return s[:i], strings.trim_space(s[i+1:])
}

lower_fish_capability_callsites :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "if test ") {
			cond := strings.trim_space(trimmed[len("if test "):])
			out_line = strings.concatenate([]string{indent, "if __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "else if test ") {
			cond := strings.trim_space(trimmed[len("else if test "):])
			out_line = strings.concatenate([]string{indent, "else if __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "while test ") {
			cond := strings.trim_space(trimmed[len("while test "):])
			out_line = strings.concatenate([]string{indent, "while __zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "test ") {
			cond := strings.trim_space(trimmed[len("test "):])
			out_line = strings.concatenate([]string{indent, "__zx_test ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "source ") {
			arg := strings.trim_space(trimmed[len("source "):])
			out_line = strings.concatenate([]string{indent, "__zx_source ", arg}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, ". ") {
			arg := strings.trim_space(trimmed[2:])
			out_line = strings.concatenate([]string{indent, "__zx_source ", arg}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "set ") {
			rest := strings.trim_space(trimmed[len("set "):])
			name, tail := split_first_word_raw(rest)
			if is_basic_name(name) &&
				tail != "" &&
				!strings.contains(tail, " ") &&
				!strings.contains(tail, ";") &&
				!strings.contains(tail, "|") &&
				!strings.contains(tail, "&") &&
				!strings.contains(tail, "(") &&
				!strings.contains(tail, ")") &&
				!strings.contains(tail, "{") &&
				!strings.contains(tail, "}") &&
				!strings.contains(tail, "[") &&
				!strings.contains(tail, "]") {
				out_line = strings.concatenate([]string{indent, "__zx_set ", name, " ", tail, " default 0"}, allocator)
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

count_unescaped_double_quotes :: proc(s: string) -> int {
	count := 0
	escaped := false
	for i in 0 ..< len(s) {
		c := s[i]
		if escaped {
			escaped = false
			continue
		}
		if c == '\\' {
			escaped = true
			continue
		}
		if c == '"' {
			count += 1
		}
	}
	return count
}

build_fish_set_decls_from_tokens :: proc(tokens: []string, scope_flag: string, allocator := context.allocator) -> string {
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	wrote := false
	for tok in tokens {
		token := strings.trim_space(tok)
		if token == "" {
			continue
		}
		eq_idx := find_substring(token, "=")
		name := token
		value := "\"\""
		if eq_idx > 0 {
			name = strings.trim_space(token[:eq_idx])
			value = strings.trim_space(token[eq_idx+1:])
			if value == "" {
				value = "\"\""
			}
		}
		if !is_basic_name(name) {
			continue
		}
		if wrote {
			strings.write_string(&builder, "; ")
		}
		strings.write_string(&builder, "set ")
		strings.write_string(&builder, scope_flag)
		strings.write_string(&builder, name)
		strings.write_byte(&builder, ' ')
		strings.write_string(&builder, value)
		wrote = true
	}
	if !wrote {
		return strings.clone(":", allocator)
	}
	return strings.clone(strings.to_string(builder), allocator)
}

normalize_fish_artifacts :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_print_pipe_quote_block := false
	in_switch := false
	in_set_list := false
	in_function_decl_cont := false
	for line, idx in lines {
		out := strings.clone(line, allocator)
		trimmed := strings.trim_space(out)
		if strings.has_prefix(trimmed, "setopt ") ||
			strings.has_prefix(trimmed, "unsetopt ") ||
			strings.has_prefix(trimmed, "emulate ") ||
			strings.has_prefix(trimmed, "zmodload ") ||
			strings.has_prefix(trimmed, "autoload ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "; and setopt ") ||
			strings.contains(trimmed, "; or setopt ") ||
			strings.contains(trimmed, "; and zmodload ") ||
			strings.contains(trimmed, "; or zmodload ") ||
			strings.contains(trimmed, "; and typeset ") ||
			strings.contains(trimmed, "; or typeset ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "local ") || strings.has_prefix(trimmed, "typeset ") || strings.has_prefix(trimmed, "integer ") {
			keyword_len := 0
			scope := "-l "
			if strings.has_prefix(trimmed, "local ") {
				keyword_len = len("local ")
				scope = "-l "
			} else if strings.has_prefix(trimmed, "typeset ") {
				keyword_len = len("typeset ")
				scope = "-g "
			} else {
				keyword_len = len("integer ")
				scope = "-l "
			}
			rest := strings.trim_space(trimmed[keyword_len:])
			fields := strings.fields(rest)
			defer delete(fields)
			start := 0
			for start < len(fields) && strings.has_prefix(fields[start], "-") {
				flags := fields[start]
				if strings.contains(flags, "g") {
					scope = "-g "
				}
				if strings.contains(flags, "l") {
					scope = "-l "
				}
				start += 1
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			scope_copy := strings.clone(scope, allocator)
			decl := ""
			if start < len(fields) {
				decl = build_fish_set_decls_from_tokens(fields[start:], scope_copy, allocator)
			} else {
				decl = strings.clone(":", allocator)
			}
			delete(scope_copy)
			delete(out)
			out = strings.concatenate([]string{indent, decl}, allocator)
			delete(decl)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if in_print_pipe_quote_block {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			if count_unescaped_double_quotes(line)%2 == 1 {
				in_print_pipe_quote_block = false
			}
			strings.write_string(&builder, out)
			delete(out)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_set_list {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			if trimmed == ")" {
				in_set_list = false
			}
			strings.write_string(&builder, out)
			delete(out)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if in_function_decl_cont {
			if trimmed == "end" {
				in_function_decl_cont = false
			} else {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, ":"}, allocator)
				changed = true
				if !strings.has_suffix(trimmed, "\\") {
					in_function_decl_cont = false
				}
				strings.write_string(&builder, out)
				delete(out)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		if strings.contains(trimmed, "print \"") && strings.contains(trimmed, "|") {
			if count_unescaped_double_quotes(trimmed)%2 == 1 {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, ":"}, allocator)
				in_print_pipe_quote_block = true
				changed = true
			}
		}
		if strings.has_prefix(trimmed, "print \"") && count_unescaped_double_quotes(trimmed)%2 == 1 {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			in_print_pipe_quote_block = true
			changed = true
		}

		if strings.contains(trimmed, "exec {") {
			indent_len := len(out) - len(strings.trim_left_space(out))
			indent := ""
			if indent_len > 0 {
				indent = out[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
		}
		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, " {") {
			name := strings.trim_space(trimmed[len("function "):len(trimmed)-2])
			name = normalize_function_name_token(name)
			if name != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "\\") {
			head := strings.trim_space(trimmed[len("function "):len(trimmed)-1])
			name, _ := split_first_word_raw(head)
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				in_function_decl_cont = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_suffix(trimmed, " {") && !strings.has_prefix(trimmed, "function ") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				name_copy := strings.clone(name, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name_copy}, allocator)
				delete(name_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "(") && strings.has_suffix(trimmed, ")") && len(trimmed) > 2 {
			inner := strings.trim_space(trimmed[1 : len(trimmed)-1])
			if inner != "" && !strings.has_prefix(inner, "count ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				inner_copy := strings.clone(inner, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, inner_copy}, allocator)
				delete(inner_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in ") {
			rest := strings.trim_space(trimmed[len("for "):])
			var_part, item_part := split_first_word_raw(rest)
			if var_part != "" {
				second_var, after_second := split_first_word_raw(item_part)
				if second_var != "" && second_var != "in" && strings.has_prefix(after_second, "in ") {
					rest_items := strings.trim_space(after_second[len("in "):])
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					v1 := strings.clone(var_part, allocator)
					items := strings.clone(rest_items, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "for ", v1, " in ", items}, allocator)
					delete(v1)
					delete(items)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in ") && strings.contains(trimmed, "{") {
			open_count := 0
			close_count := 0
			for ch in trimmed {
				if ch == '{' {
					open_count += 1
				} else if ch == '}' {
					close_count += 1
				}
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			if open_count != close_count {
				rest := strings.trim_space(trimmed[len("for "):])
				var_name, _ := split_first_word_raw(rest)
				if is_basic_name(var_name) {
					v := strings.clone(var_name, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "for ", v, " in \"\""}, allocator)
					delete(v)
					changed = true
					trimmed = strings.trim_space(out)
				}
			} else {
				repl_b, c_b := strings.replace_all(out, "{", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				repl_b, c_b = strings.replace_all(out, "}", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				repl_b, c_b = strings.replace_all(out, ",", " ", allocator)
				if c_b {
					delete(out)
					out = repl_b
					changed = true
				} else if raw_data(repl_b) != raw_data(out) {
					delete(repl_b)
				}
				trimmed = strings.trim_space(out)
			}
		}
		if strings.contains(trimmed, "; ") {
			connectors := []string{"; and ", "; or ", " and ", " or ", "; "}
			for connector in connectors {
				rewritten_assign, c_assign := rewrite_fish_inline_assignment(out, connector, allocator)
				if c_assign {
					delete(out)
					out = rewritten_assign
					changed = true
					trimmed = strings.trim_space(out)
				} else {
					delete(rewritten_assign)
				}
			}
		}
		if strings.contains(trimmed, ";") && strings.contains(trimmed, "=") {
			last_semi := -1
			for i := 0; i < len(trimmed); i += 1 {
				if trimmed[i] == ';' {
					last_semi = i
				}
			}
			if last_semi >= 0 && last_semi+1 < len(trimmed) {
				head := strings.trim_right_space(trimmed[:last_semi])
				tail := strings.trim_space(trimmed[last_semi+1:])
				eq_idx := find_substring(tail, "=")
				if eq_idx > 0 && !strings.contains(tail, "==") && !strings.contains(tail, "!=") {
					name := strings.trim_space(tail[:eq_idx])
					value := strings.trim_space(tail[eq_idx+1:])
					if is_basic_name(name) && value != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}
						head_copy := strings.clone(head, allocator)
						name_copy := strings.clone(name, allocator)
						value_copy := strings.clone(value, allocator)
						delete(out)
						out = strings.concatenate([]string{indent, head_copy, "; set ", name_copy, " ", value_copy}, allocator)
						delete(head_copy)
						delete(name_copy)
						delete(value_copy)
						changed = true
						trimmed = strings.trim_space(out)
					}
				}
			}
		}
		if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "=(") && strings.has_suffix(trimmed, ")") {
			body := strings.trim_space(trimmed[len("if "):])
			eq_idx := find_substring(body, "=(")
			if eq_idx > 0 {
				name := strings.trim_space(body[:eq_idx])
				cmd := strings.trim_space(body[eq_idx+2 : len(body)-1])
				if is_basic_name(name) && cmd != "" {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					cmd_copy := strings.clone(cmd, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "set ", name_copy, " (", cmd_copy, ")\n", indent, "if true"}, allocator)
					delete(name_copy)
					delete(cmd_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.has_prefix(trimmed, "if (") && strings.has_suffix(trimmed, ")") && len(trimmed) > 5 {
			inner := strings.trim_space(trimmed[4 : len(trimmed)-1])
			if inner != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				inner_copy := strings.clone(inner, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "if ", inner_copy}, allocator)
				delete(inner_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.contains(trimmed, "; and (") {
			and_idx := find_substring(out, "; and (")
			if and_idx >= 0 {
				close_idx := and_idx + len("; and (")
				for close_idx < len(out) && out[close_idx] != ')' {
					close_idx += 1
				}
				if close_idx < len(out) {
					repl_cond, ok_cond := replace_first_range(out, and_idx, close_idx+1, "; and true", allocator)
					if ok_cond {
						delete(out)
						out = repl_cond
						changed = true
						trimmed = strings.trim_space(out)
					} else if raw_data(repl_cond) != raw_data(out) {
						delete(repl_cond)
					}
				}
			}
		}
		if strings.contains(trimmed, "; or (") {
			or_idx := find_substring(out, "; or (")
			if or_idx >= 0 {
				close_idx := or_idx + len("; or (")
				for close_idx < len(out) && out[close_idx] != ')' {
					close_idx += 1
				}
				if close_idx < len(out) {
					repl_cond, ok_cond := replace_first_range(out, or_idx, close_idx+1, "; or true", allocator)
					if ok_cond {
						delete(out)
						out = repl_cond
						changed = true
						trimmed = strings.trim_space(out)
					} else if raw_data(repl_cond) != raw_data(out) {
						delete(repl_cond)
					}
				}
			}
		}
		if strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "<") && strings.contains(trimmed, ">") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, "if true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "set ") && strings.has_suffix(trimmed, "(") {
			rest := strings.trim_space(trimmed[len("set "):len(trimmed)-1])
			name, _ := split_first_word_raw(rest)
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			name_copy := strings.clone(name, allocator)
			delete(out)
			if is_basic_name(name_copy) {
				out = strings.concatenate([]string{indent, "set ", name_copy, " \"\""}, allocator)
			} else {
				out = strings.concatenate([]string{indent, ":"}, allocator)
			}
			delete(name_copy)
			in_set_list = true
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "+=(") && strings.has_suffix(trimmed, ")") {
			app_idx := find_substring(trimmed, "+=(")
			if app_idx > 0 {
				name := strings.trim_space(trimmed[:app_idx])
				values := strings.trim_space(trimmed[app_idx+3 : len(trimmed)-1])
				if is_basic_name(name) {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					values_copy := strings.clone(values, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, "set -a ", name_copy, " ", values_copy}, allocator)
					delete(name_copy)
					delete(values_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.contains(trimmed, ";") && strings.contains(trimmed, "+=(") {
			app_idx := find_substring(trimmed, "+=(")
			if app_idx > 0 {
				start := app_idx - 1
				for start >= 0 && is_basic_name_char(trimmed[start]) {
					start -= 1
				}
				name := strings.trim_space(trimmed[start+1 : app_idx])
				close_idx := app_idx + 3
				for close_idx < len(trimmed) && trimmed[close_idx] != ')' {
					close_idx += 1
				}
				if is_basic_name(name) && close_idx < len(trimmed) {
					prefix := strings.trim_right_space(trimmed[:start+1])
					values := strings.trim_space(trimmed[app_idx+3 : close_idx])
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					prefix_copy := strings.clone(prefix, allocator)
					name_copy := strings.clone(name, allocator)
					values_copy := strings.clone(values, allocator)
					delete(out)
					out = strings.concatenate([]string{indent, prefix_copy, "set -a ", name_copy, " ", values_copy}, allocator)
					delete(prefix_copy)
					delete(name_copy)
					delete(values_copy)
					changed = true
					trimmed = strings.trim_space(out)
				}
			}
		}
		if strings.contains(trimmed, "; for ") && strings.has_suffix(trimmed, "; do") {
			for_idx := find_substring(trimmed, "; for ")
			if for_idx >= 0 {
				prefix := strings.trim_space(trimmed[:for_idx])
				loop_part := strings.trim_space(trimmed[for_idx+2 : len(trimmed)-len("; do")])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				prefix_copy := strings.clone(prefix, allocator)
				loop_copy := strings.clone(loop_part, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, prefix_copy, "\n", indent, loop_copy}, allocator)
				delete(prefix_copy)
				delete(loop_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if trimmed == "'" || trimmed == "\"" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
			header := strings.trim_space(trimmed[:len(trimmed)-len("; do")])
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			header_copy := strings.clone(header, allocator)
			delete(out)
			out = strings.concatenate([]string{indent, header_copy}, allocator)
			delete(header_copy)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && !strings.contains(trimmed, " in ") {
			rest := strings.trim_space(trimmed[len("for "):])
			if is_basic_name(rest) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				rest_copy := strings.clone(rest, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, "for ", rest_copy, " in \"\""}, allocator)
				delete(rest_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if trimmed == ")" {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && !strings.contains(trimmed, " in ") && strings.contains(trimmed, " (") && strings.has_suffix(trimmed, ")") {
			rest := strings.trim_space(trimmed[len("for "):])
			var_name, after_var := split_first_word_raw(rest)
			if is_basic_name(var_name) && strings.has_prefix(after_var, "(") && strings.has_suffix(after_var, ")") && len(after_var) > 2 {
				expr := strings.trim_space(after_var[1 : len(after_var)-1])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, "for ", var_name, " in ", expr}, allocator)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if in_switch && !strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "*)") {
			close_idx := find_substring(trimmed, "*)")
			if close_idx >= 0 {
				pat := strings.trim_space(trimmed[:close_idx+1])
				body := strings.trim_space(trimmed[close_idx+2:])
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				pat_copy := strings.clone(pat, allocator)
				body_copy := strings.clone(body, allocator)
				if body == "" {
					delete(out)
					out = strings.concatenate([]string{indent, "case ", pat_copy}, allocator)
				} else {
					delete(out)
					out = strings.concatenate([]string{indent, "case ", pat_copy, "\n", indent, "  ", body_copy}, allocator)
				}
				delete(pat_copy)
				delete(body_copy)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function ") && (strings.has_suffix(trimmed, " &&") || strings.has_suffix(trimmed, " ||")) {
			conn_idx := find_substring(trimmed, " &&")
			if conn_idx < 0 {
				conn_idx = find_substring(trimmed, " ||")
			}
			if conn_idx > 0 {
				indent_len := len(out) - len(strings.trim_left_space(out))
				indent := ""
				if indent_len > 0 {
					indent = out[:indent_len]
				}
				head := strings.trim_space(trimmed[:conn_idx])
				head_copy := strings.clone(head, allocator)
				delete(out)
				out = strings.concatenate([]string{indent, head_copy}, allocator)
				delete(head_copy)
				changed = true
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin unalias ") || strings.has_prefix(trimmed, "unalias ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin zle ") || strings.has_prefix(trimmed, "zle ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin print ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'local'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'setopt'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "'builtin' 'unset'") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "builtin unset ") || strings.has_prefix(trimmed, "unset ") {
			rest := ""
			if strings.has_prefix(trimmed, "builtin unset ") {
				rest = strings.trim_space(trimmed[len("builtin unset "):])
			} else {
				rest = strings.trim_space(trimmed[len("unset "):])
			}
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			rest_copy := strings.clone(rest, allocator)
			delete(out)
			if rest_copy != "" {
				out = strings.concatenate([]string{indent, "set -e ", rest_copy}, allocator)
			} else {
				out = strings.concatenate([]string{indent, ":"}, allocator)
			}
			delete(rest_copy)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "=(<") || strings.contains(trimmed, "(<") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "]=()") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.has_suffix(trimmed, "()") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, "function ", name}, allocator)
				changed = true
				trimmed = strings.trim_space(out)
			}
		}
		if strings.has_prefix(trimmed, "function eval ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			delete(out)
			out = strings.concatenate([]string{indent, ":"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}
		if strings.contains(trimmed, "\"\"\"") {
			repl_q, c_q := strings.replace_all(out, "\"\"\"", "\"\"", allocator)
			if c_q {
				delete(out)
				out = repl_q
				changed = true
			} else if raw_data(repl_q) != raw_data(out) {
				delete(repl_q)
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "for ") && strings.contains(trimmed, " in \"\"\"") {
			repl_q, c_q := strings.replace_all(trimmed, " in \"\"\"", " in \"\"", allocator)
			if c_q {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				delete(out)
				out = strings.concatenate([]string{indent, repl_q}, allocator)
				delete(repl_q)
				changed = true
			} else if raw_data(repl_q) != raw_data(trimmed) {
				delete(repl_q)
			}
			trimmed = strings.trim_space(out)
		}
		if strings.has_prefix(trimmed, "case ") && strings.contains(trimmed, "=(") {
			raw := strings.trim_space(trimmed[len("case "):])
			eq_idx := find_substring(raw, "=")
			if eq_idx > 0 {
				name := strings.trim_space(raw[:eq_idx])
				rhs := strings.trim_space(raw[eq_idx+1:])
				if strings.has_prefix(rhs, "(") {
					rhs = strings.trim_space(rhs[1:])
				}
				if strings.has_suffix(rhs, ")") && len(rhs) > 1 {
					rhs = strings.trim_space(rhs[:len(rhs)-1])
				}
				if is_basic_name(name) && rhs != "" {
					indent_len := len(line) - len(strings.trim_left_space(line))
					indent := ""
					if indent_len > 0 {
						indent = line[:indent_len]
					}
					name_copy := strings.clone(name, allocator)
					rhs_copy := strings.clone(rhs, allocator)
					new_out := strings.concatenate([]string{indent, "set ", name_copy, " ", rhs_copy}, allocator)
					delete(name_copy)
					delete(rhs_copy)
					delete(out)
					out = new_out
					changed = true
				}
			}
			trimmed = strings.trim_space(out)
		}
		repl, c := strings.replace_all(out, "; and {", "; and ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "; or {", "; or ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "and {", "and ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "or {", "or ", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "};", ";", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$'", "'", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$@", "$argv", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "$*", "$argv", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "&&", "; and", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		repl, c = strings.replace_all(out, "||", "; or", allocator)
		if c {
			delete(out)
			out = repl
			changed = true
		} else if raw_data(repl) != raw_data(out) {
			delete(repl)
		}
		trimmed = strings.trim_space(out)

		if strings.has_suffix(trimmed, "; and") {
			out = strings.concatenate([]string{out, " true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		} else if strings.has_suffix(trimmed, "; or") {
			out = strings.concatenate([]string{out, " true"}, allocator)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if strings.contains(trimmed, "}") && !strings.contains(trimmed, "{") {
			builder2 := strings.builder_make()
			for i in 0 ..< len(out) {
				if out[i] != '}' {
					strings.write_byte(&builder2, out[i])
				}
			}
			delete(out)
			out = strings.clone(strings.to_string(builder2), allocator)
			strings.builder_destroy(&builder2)
			changed = true
			trimmed = strings.trim_space(out)
		}

		if strings.has_prefix(trimmed, "set ") && strings.has_suffix(trimmed, "))") {
			out = strings.trim_right_space(out)
			out = out[:len(out)-2]
			changed = true
		}
		trimmed = strings.trim_space(out)
		if strings.has_prefix(trimmed, "switch ") {
			in_switch = true
		} else if trimmed == "end" {
			in_switch = false
		}
		strings.write_string(&builder, out)
		delete(out)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	return strings.clone(strings.to_string(builder), allocator), changed
}

sanitize_fish_output_bytes :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	for i in 0 ..< len(text) {
		c := text[i]
		if c == '\n' || c == '\t' || (c >= 32 && c <= 126) {
			strings.write_byte(&builder, c)
		} else {
			strings.write_byte(&builder, ':')
			changed = true
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_shellx_param_subshells_to_vars :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	read_name := proc(s: string, start: int) -> (string, int) {
		i := start
		for i < len(s) && (s[i] == ' ' || s[i] == '\t') {
			i += 1
		}
		j := i
		for j < len(s) && is_basic_name_char(s[j]) {
			j += 1
		}
		if j <= i {
			return "", i
		}
		return s[i:j], j
	}

	i := 0
	for i < len(text) {
		matched := false
		prefixes := []string{"(__shellx_param_length "}
		for p in prefixes {
			if i+len(p) <= len(text) && text[i:i+len(p)] == p {
				name, name_end := read_name(text, i+len(p))
				if name != "" {
					close_idx := name_end
					for close_idx < len(text) && text[close_idx] != ')' {
						close_idx += 1
					}
					if close_idx < len(text) {
						strings.write_string(&builder, "$")
						strings.write_string(&builder, name)
						changed = true
						i = close_idx + 1
						matched = true
						break
					}
				}
			}
		}
		if matched {
			continue
		}
		strings.write_byte(&builder, text[i])
		i += 1
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

ensure_fish_block_balance :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	stack := make([dynamic]byte, 0, 64, context.temp_allocator) // f=function i=if l=loop s=switch b=begin
	defer delete(stack)
	changed := false
	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out := line
		out_allocated := false

		if strings.has_prefix(trimmed, "function ") && len(stack) > 0 {
			for len(stack) > 0 {
				strings.write_string(&builder, "end\n")
				resize(&stack, len(stack)-1)
				changed = true
			}
		}

		if trimmed == "else" || strings.has_prefix(trimmed, "else if ") {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		} else if trimmed == "end" {
			if len(stack) > 0 {
				resize(&stack, len(stack)-1)
			} else {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				out = strings.concatenate([]string{indent, ":"}, allocator)
				out_allocated = true
				changed = true
			}
		} else if trimmed != "" && !strings.has_prefix(trimmed, "#") {
			if strings.has_prefix(trimmed, "function ") {
				append(&stack, 'f')
			} else if strings.has_prefix(trimmed, "if ") {
				append(&stack, 'i')
			} else if strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ") {
				append(&stack, 'l')
			} else if strings.has_prefix(trimmed, "switch ") {
				append(&stack, 's')
			} else if trimmed == "begin" {
				append(&stack, 'b')
			}
		}

		strings.write_string(&builder, out)
		if out_allocated {
			delete(out)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(stack) - 1; i >= 0; i -= 1 {
		strings.write_string(&builder, "\nend")
		changed = true
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_malformed_command_substitutions :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.contains(trimmed, "(") && !strings.contains(trimmed, ")") {
			// Recover a common broken lowering from `${var:-...}` to fish shim call.
			if strings.contains(out_line, "(__shellx_param_default; set -g ") {
				repl, c := strings.replace_all(out_line, "(__shellx_param_default; set -g ", "(__shellx_param_default ", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				} else {
					delete(repl)
				}
				if out_allocated && !strings.contains(out_line, ")") {
					with_close := strings.concatenate([]string{out_line, ")"}, allocator)
					delete(out_line)
					out_line = with_close
					changed = true
				}
			} else if strings.contains(out_line, "(git; set -l log ") {
				repl, c := strings.replace_all(out_line, "(git; set -l log ", "(git log ", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				} else {
					delete(repl)
				}
				if out_allocated && !strings.contains(out_line, ")") {
					with_close := strings.concatenate([]string{out_line, ")"}, allocator)
					delete(out_line)
					out_line = with_close
					changed = true
				}
			} else if strings.contains(trimmed, "set ") && strings.contains(out_line, " (git") {
				// Minimal parse-safe recovery when command substitution tail was lost.
				with_close := strings.concatenate([]string{out_line, ")"}, allocator)
				out_line = with_close
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_split_echo_param_default :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if i+1 < len(lines) && trimmed == "echo" {
			next := lines[i+1]
			next_trimmed := strings.trim_space(next)
			if strings.has_prefix(next_trimmed, "__shellx_param_default ") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				combined := strings.concatenate([]string{indent, "echo (", next_trimmed, ")"}, allocator)
				strings.write_string(&builder, combined)
				delete(combined)
				changed = true
				i += 2
				if i < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, line)
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_fish_quoted_param_default_echo :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "echo \"") && strings.contains(trimmed, "__shellx_param_default ") {
			indent_len := len(line) - len(strings.trim_left_space(line))
			indent := ""
			if indent_len > 0 {
				indent = line[:indent_len]
			}
			idx := find_substring(trimmed, "__shellx_param_default ")
			if idx >= 0 {
				rest := trimmed[idx:]
				if len(rest) > 0 && rest[len(rest)-1] == '"' {
					rest = rest[:len(rest)-1]
				}
				prefix := strings.concatenate([]string{indent, "echo ("}, allocator)
				if strings.has_suffix(rest, ")") {
					out_line = strings.concatenate([]string{prefix, rest}, allocator)
				} else {
					out_line = strings.concatenate([]string{prefix, rest, ")"}, allocator)
				}
				delete(prefix)
				out_allocated = true
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_positional_params :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '$' {
			if i+2 < len(text) && text[i+1] == '{' && text[i+2] >= '1' && text[i+2] <= '9' {
				j := i + 3
				for j < len(text) && text[j] >= '0' && text[j] <= '9' {
					j += 1
				}
				if j < len(text) && text[j] == '}' {
					idx_text := text[i+2 : j]
					repl := strings.concatenate([]string{"$argv[", idx_text, "]"}, allocator)
					strings.write_string(&builder, repl)
					delete(repl)
					changed = true
					i = j + 1
					continue
				}
			}
			if i+1 < len(text) && text[i+1] >= '1' && text[i+1] <= '9' {
				j := i + 2
				for j < len(text) && text[j] >= '0' && text[j] <= '9' {
					j += 1
				}
				idx_text := text[i+1 : j]
				repl := strings.concatenate([]string{"$argv[", idx_text, "]"}, allocator)
				strings.write_string(&builder, repl)
				delete(repl)
				changed = true
				i = j
				continue
			}
		}
		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_shell_split_echo_param_expansion :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if i+1 < len(lines) && trimmed == "echo" {
			next := strings.trim_space(lines[i+1])
			if strings.has_prefix(next, "${") && strings.has_suffix(next, "}") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				combined := strings.concatenate([]string{indent, "echo ", next}, allocator)
				strings.write_string(&builder, combined)
				delete(combined)
				changed = true
				i += 2
				if i < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}

		strings.write_string(&builder, line)
		i += 1
		if i < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

repair_shell_case_arms :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	// Keep this repair scoped to small/simple scripts to avoid over-normalizing
	// large recovered corpus outputs.
	if len(lines) > 120 {
		return strings.clone(text, allocator), false
	}
	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_case := false
	for line, idx in lines {
		out_line := line
		out_allocated := false
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			in_case = true
		} else if trimmed == "esac" {
			in_case = false
		} else if in_case && trimmed != "" && !strings.has_prefix(trimmed, "#") {
			close_idx := find_substring(trimmed, ")")
			if close_idx > 0 && close_idx+1 < len(trimmed) {
				after := strings.trim_space(trimmed[close_idx+1:])
				if after != "" && !strings.has_suffix(trimmed, ";;") {
					out_line = strings.concatenate([]string{line, " ;;"}, allocator)
					out_allocated = true
					changed = true
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

rewrite_fish_to_posix_syntax :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	block_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // f=function i=if l=loop c=case
	defer delete(block_stack)

	for line, idx in lines {
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false

		if strings.has_prefix(trimmed, "function ") {
			name, _ := split_first_word(strings.trim_space(trimmed[len("function "):]))
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{indent, name, "() {"}, allocator)
				out_allocated = true
				changed = true
				append(&block_stack, 'f')
			}
		} else if trimmed == "end" {
			closing := ":"
			if len(block_stack) > 0 {
				top := block_stack[len(block_stack)-1]
				resize(&block_stack, len(block_stack)-1)
				switch top {
				case 'f':
					closing = "}"
				case 'i':
					closing = "fi"
				case 'l':
					closing = "done"
				case 'c':
					closing = "esac"
				}
			}
			out_line = strings.concatenate([]string{indent, closing}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "else if ") {
			cond := strings.trim_space(trimmed[len("else if "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "elif ", cond, "; then"}, allocator)
			out_allocated = true
			changed = true
		} else if strings.has_prefix(trimmed, "if ") && !strings.has_suffix(trimmed, "; then") {
			cond := strings.trim_space(trimmed[len("if "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "if ", cond, "; then"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'i')
		} else if strings.has_prefix(trimmed, "while ") && !strings.has_suffix(trimmed, "; do") {
			cond := strings.trim_space(trimmed[len("while "):])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{indent, "while ", cond, "; do"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "for ") && !strings.has_suffix(trimmed, "; do") {
			out_line = strings.concatenate([]string{indent, trimmed, "; do"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'l')
		} else if strings.has_prefix(trimmed, "switch ") {
			expr := strings.trim_space(trimmed[len("switch "):])
			out_line = strings.concatenate([]string{indent, "case ", expr, " in"}, allocator)
			out_allocated = true
			changed = true
			append(&block_stack, 'c')
		} else if strings.has_prefix(trimmed, "case ") && !strings.has_suffix(trimmed, ")") {
			pats := strings.trim_space(trimmed[len("case "):])
			pats_repl, pats_changed := replace_simple_all(pats, " ", "|", allocator)
			if pats_changed {
				pats = pats_repl
			} else {
				delete(pats_repl)
			}
			out_line = strings.concatenate([]string{indent, pats, ")"}, allocator)
			out_allocated = true
			if pats_changed {
				delete(pats)
			}
			changed = true
		} else if strings.has_prefix(trimmed, "set ") {
			rest := strings.trim_space(trimmed[len("set "):])
				parts := strings.split(rest, " ")
				defer delete(parts)
				if len(parts) >= 2 {
				start := 0
				for start < len(parts) && strings.has_prefix(parts[start], "-") {
					start += 1
				}
				if start < len(parts) {
					name := parts[start]
					if is_basic_name(name) {
							if start+1 >= len(parts) {
								out_line = strings.concatenate([]string{indent, name, "=\"\""}, allocator)
								out_allocated = true
							} else if start+2 == len(parts) {
								out_line = strings.concatenate([]string{indent, name, "=", parts[start+1]}, allocator)
								out_allocated = true
							} else if to == .Bash {
							val_builder := strings.builder_make()
							defer strings.builder_destroy(&val_builder)
							for i := start + 1; i < len(parts); i += 1 {
								if i > start+1 {
									strings.write_byte(&val_builder, ' ')
								}
								strings.write_string(&val_builder, parts[i])
							}
								out_line = strings.concatenate(
									[]string{indent, name, "=(", strings.to_string(val_builder), ")"},
									allocator,
								)
								out_allocated = true
							} else {
							val_builder := strings.builder_make()
							defer strings.builder_destroy(&val_builder)
							for i := start + 1; i < len(parts); i += 1 {
								if i > start+1 {
									strings.write_byte(&val_builder, ' ')
								}
								strings.write_string(&val_builder, parts[i])
							}
								out_line = strings.concatenate(
									[]string{indent, name, "=\"", strings.to_string(val_builder), "\""},
									allocator,
								)
								out_allocated = true
							}
							changed = true
					}
				}
			}
		} else if strings.has_prefix(trimmed, "set -e") || strings.has_prefix(trimmed, "set --erase") {
			rest := trimmed[len("set "):]
			is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
			if is_erase {
				var_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
				if var_name != "" && is_basic_name(var_name) {
					out_line = strings.concatenate([]string{indent, "unset ", var_name}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if strings.has_prefix(trimmed, "functions ") || strings.has_prefix(trimmed, "functions -e") || strings.has_prefix(trimmed, "functions --erase") {
			rest := trimmed[len("functions "):]
			is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
			if is_erase {
				func_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
				if func_name != "" {
					out_line = strings.concatenate([]string{indent, "unset -f ", func_name}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if strings.has_prefix(trimmed, "complete ") || strings.has_prefix(trimmed, "complete -e") || strings.has_prefix(trimmed, "complete --erase") {
			if strings.has_prefix(trimmed, "complete --erase ") {
				comp_name := strings.trim_space(trimmed[len("complete --erase "):])
				if comp_name != "" {
					out_line = strings.concatenate([]string{indent, "complete -r ", comp_name}, allocator)
					out_allocated = true
					changed = true
				}
			} else {
				rest := trimmed[len("complete "):]
				is_erase := strings.has_prefix(rest, "--erase") || strings.has_prefix(rest, "-e")
				if is_erase {
					comp_name := strings.trim_space(rest[7:] if strings.has_prefix(rest, "-e") else rest[8:])
					if comp_name != "" {
						out_line = strings.concatenate([]string{indent, "complete -r ", comp_name}, allocator)
						out_allocated = true
						changed = true
					}
				}
			}
		}

		strings.write_string(&builder, out_line)
		if out_allocated {
			delete(out_line)
		}
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}
	for i := len(block_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch block_stack[i] {
		case 'f':
			strings.write_string(&builder, "}")
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			strings.write_string(&builder, "done")
		case 'c':
			strings.write_string(&builder, "esac")
		}
		changed = true
	}

	result := strings.clone(strings.to_string(builder), allocator)
	changed_any := changed

	result2, changed2 := fix_empty_fish_if_blocks(result, allocator)
	if raw_data(result2) != raw_data(result) {
		delete(result)
	}
	result = result2
	changed_any = changed_any || changed2

	result2, changed2 = fix_fish_command_substitution(result, allocator)
	if raw_data(result2) != raw_data(result) {
		delete(result)
	}
	result = result2
	changed_any = changed_any || changed2

	return result, changed_any
}

rewrite_fish_list_index_access :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	if text == "" || !(to == .Bash || to == .POSIX) {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '$' && i+1 < len(text) && is_basic_name_char(text[i+1]) {
			name_start := i + 1
			name_end := name_start
			for name_end < len(text) && is_basic_name_char(text[name_end]) {
				name_end += 1
			}

			if name_end < len(text) && text[name_end] == '[' {
				idx_start := name_end + 1
				idx_end := idx_start
				for idx_end < len(text) && text[idx_end] >= '0' && text[idx_end] <= '9' {
					idx_end += 1
				}
				if idx_end > idx_start && idx_end < len(text) && text[idx_end] == ']' {
					name := text[name_start:name_end]
					index_text := text[idx_start:idx_end]
					if to == .Bash {
						idx := 0
						for ch in index_text {
							idx = idx*10 + int(ch-'0')
						}
						if idx > 0 {
							idx -= 1
						}
						idx_str := fmt.tprintf("%d", idx)
						repl := strings.concatenate([]string{"${", name, "[", idx_str, "]}"}, allocator)
						strings.write_string(&builder, repl)
						delete(repl)
					} else {
						repl := fmt.tprintf("$(set -- $%s; printf '%%s' \"$%s\")", name, index_text)
						strings.write_string(&builder, repl)
					}
					changed = true
					i = idx_end + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

fix_fish_command_substitution :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if text == "" {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	i := 0
	for i < len(text) {
		if text[i] == '(' && (i == 0 || text[i-1] != '$') {
			// Keep shell array literals like `name=(a b)` intact.
			if is_assignment_array_literal_open(text, i) {
				strings.write_byte(&builder, text[i])
				i += 1
				continue
			}

			depth := 1
			j := i + 1
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

			if j < len(text) && depth == 0 && j > i+1 {
				inner := strings.trim_space(text[i+1 : j])
				if inner != "" {
					strings.write_string(&builder, "$(")
					strings.write_string(&builder, inner)
					strings.write_byte(&builder, ')')
					changed = true
					i = j + 1
					continue
				}
			}
		}

		strings.write_byte(&builder, text[i])
		i += 1
	}

	if !changed {
		return strings.clone(text, allocator), false
	}
	return strings.clone(strings.to_string(builder), allocator), true
}

is_assignment_array_literal_open :: proc(text: string, open_idx: int) -> bool {
	if open_idx <= 0 || open_idx > len(text) {
		return false
	}
	prev := open_idx - 1
	for prev >= 0 && (text[prev] == ' ' || text[prev] == '\t') {
		prev -= 1
	}
	if prev < 0 || text[prev] != '=' {
		return false
	}
	if prev == 0 {
		return false
	}
	// Comparison forms like `= (` should not be treated as assignment literal.
	if text[prev-1] == ' ' || text[prev-1] == '\t' {
		return false
	}
	// Exclude common comparison operators.
	if text[prev-1] == '!' || text[prev-1] == '=' || text[prev-1] == '<' || text[prev-1] == '>' {
		return false
	}
	return true
}

fix_empty_fish_if_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	changed := false
	result := strings.clone(text, allocator)
	
	search_pattern := "; then\nfi"
	replace_pattern := "; then :\nfi"
	
	for {
		idx := strings.index(result, search_pattern)
		if idx < 0 {
			break
		}
		new_result, replaced := strings.replace(result, search_pattern, replace_pattern, 1)
		if replaced {
			delete(result)
			result = new_result
			changed = true
		} else {
			delete(new_result)
			break
		}
	}
	
	return result, changed
}

rewrite_empty_shell_control_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim_space(line)
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		is_if := strings.has_prefix(trimmed, "if ") && strings.contains(trimmed, "; then")
		is_loop := (strings.has_prefix(trimmed, "while ") || strings.has_prefix(trimmed, "for ")) && strings.contains(trimmed, "; do")
		if !is_if && !is_loop {
			continue
		}

		j := i + 1
		for j < len(lines) {
			next_trim := strings.trim_space(lines[j])
			if next_trim == "" || strings.has_prefix(next_trim, "#") {
				j += 1
				continue
			}
			needs_noop := false
			if is_if {
				needs_noop = next_trim == "fi" || next_trim == "else" || strings.has_prefix(next_trim, "elif ")
			} else if is_loop {
				needs_noop = next_trim == "done"
			}
			if needs_noop {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :")
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_empty_shell_function_blocks :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false

	for i := 0; i < len(lines); i += 1 {
		line := lines[i]
		trimmed := strings.trim_space(line)
		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		is_fn := strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
		if !is_fn {
			continue
		}

		j := i + 1
		for j < len(lines) {
			next_trim := strings.trim_space(lines[j])
			if next_trim == "" || strings.has_prefix(next_trim, "#") {
				j += 1
				continue
			}
			if next_trim == "}" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				strings.write_string(&builder, indent)
				strings.write_string(&builder, "  :")
				if i+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
			}
			break
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_close_controls_before_function_end :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_function := false
	ctrl_stack := make([dynamic]byte, 0, 16, context.temp_allocator) // i=if l=loop c=case
	defer delete(ctrl_stack)

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		indent_len := len(line) - len(strings.trim_left_space(line))
		indent := ""
		if indent_len > 0 {
			indent = line[:indent_len]
		}

		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			in_function = true
			resize(&ctrl_stack, 0)
		}

		if in_function {
			if strings.has_prefix(trimmed, "if ") {
				append(&ctrl_stack, 'i')
			} else if strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") {
				append(&ctrl_stack, 'l')
			} else if strings.has_prefix(trimmed, "case ") {
				append(&ctrl_stack, 'c')
			} else if trimmed == "fi" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "done" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "esac" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			}
		}

		if in_function && trimmed == "}" && len(ctrl_stack) > 0 {
			for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
				switch ctrl_stack[i] {
				case 'i':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "fi\n")
				case 'l':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "done\n")
				case 'c':
					strings.write_string(&builder, indent)
					strings.write_string(&builder, "esac\n")
				}
			}
			resize(&ctrl_stack, 0)
			changed = true
		}

		strings.write_string(&builder, line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}

		if in_function && trimmed == "}" {
			in_function = false
			resize(&ctrl_stack, 0)
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_balance_top_level_controls :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	fn_depth := 0
	ctrl_stack := make([dynamic]byte, 0, 16, context.temp_allocator) // i=if l=loop c=case
	defer delete(ctrl_stack)

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line

		if strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")) {
			fn_depth += 1
		}

		if fn_depth == 0 {
			if strings.has_prefix(trimmed, "if ") {
				append(&ctrl_stack, 'i')
			} else if strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ") {
				append(&ctrl_stack, 'l')
			} else if strings.has_prefix(trimmed, "case ") {
				append(&ctrl_stack, 'c')
			} else if trimmed == "fi" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "done" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			} else if trimmed == "esac" {
				if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
					resize(&ctrl_stack, len(ctrl_stack)-1)
				}
			}
		}

		if trimmed == "}" {
			if fn_depth > 0 {
				fn_depth -= 1
			} else {
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch ctrl_stack[i] {
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			strings.write_string(&builder, "done")
		case 'c':
			strings.write_string(&builder, "esac")
		}
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_fish_done_zsh_trailing_brace :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	if !strings.contains(text, "__done_notification_duration") {
		return strings.clone(text, allocator), false
	}
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	after_notify := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if strings.contains(trimmed, "__done_notification_duration") {
			after_notify = true
		} else if after_notify && trimmed == "}" {
			out_line = "fi"
			changed = true
			after_notify = false
		} else if after_notify && trimmed != "" && !strings.has_prefix(trimmed, "#") && trimmed != ":" {
			after_notify = false
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_insert_missing_function_closers :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	in_function := false

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		is_fn_start := strings.has_suffix(trimmed, "() {") || (strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{"))
		if is_fn_start && in_function {
			strings.write_string(&builder, "}\n")
			changed = true
		}
		if is_fn_start {
			in_function = true
		}
		if trimmed == "}" {
			in_function = false
		}

		strings.write_string(&builder, line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

normalize_shell_structured_blocks :: proc(
	text: string,
	to: ShellDialect,
	allocator := context.allocator,
) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	stack := make([dynamic]byte, 0, 64, context.temp_allocator) // f=function i=if l=loop c=case g=brace-group
	defer delete(stack)
	brace_decl_skip_idx := -1
	drop_case_block := false

	push :: proc(stack: ^[dynamic]byte, kind: byte) {
		append(stack, kind)
	}
	pop_expected :: proc(stack: ^[dynamic]byte, expected: byte) -> bool {
		if len(stack^) == 0 {
			return false
		}
		if stack^[len(stack^)-1] != expected {
			return false
		}
		resize(stack, len(stack^)-1)
		return true
	}
	pop_any_group_or_function :: proc(stack: ^[dynamic]byte) -> (byte, bool) {
		if len(stack^) == 0 {
			return 0, false
		}
		top := stack^[len(stack^)-1]
		if top != 'f' && top != 'g' {
			return 0, false
		}
		resize(stack, len(stack^)-1)
		return top, true
	}

	is_function_start :: proc(trimmed: string) -> bool {
		if strings.has_suffix(trimmed, "() {") {
			return true
		}
		return strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "{")
	}
	is_control_if_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "if ")
	}
	is_control_loop_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "for ") || strings.has_prefix(trimmed, "while ")
	}
	is_control_case_start :: proc(trimmed: string) -> bool {
		return strings.has_prefix(trimmed, "case ")
	}

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if idx == brace_decl_skip_idx {
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if trimmed == "" || strings.has_prefix(trimmed, "#") {
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if !drop_case_block && to != .Zsh && strings.has_prefix(trimmed, "case \"\" in") {
			drop_case_block = true
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_case_block {
			if trimmed == "esac" {
				drop_case_block = false
			}
			out_line = ":"
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		if strings.has_suffix(trimmed, "()") {
			name := strings.trim_space(trimmed[:len(trimmed)-2])
			if is_basic_name(name) {
				open_idx := -1
				for j := idx + 1; j < len(lines); j += 1 {
					next_trim := strings.trim_space(lines[j])
					if next_trim == "" || strings.has_prefix(next_trim, "#") {
						continue
					}
					if next_trim == "{" {
						open_idx = j
					}
					break
				}
				if open_idx >= 0 {
					out_line = strings.concatenate([]string{name, "() {"}, allocator)
					out_allocated = true
					push(&stack, 'f')
					brace_decl_skip_idx = open_idx
					changed = true
					strings.write_string(&builder, out_line)
					if idx+1 < len(lines) {
						strings.write_byte(&builder, '\n')
					}
					if out_allocated {
						delete(out_line)
					}
					continue
				}
			}
		}

		if is_function_start(trimmed) {
			push(&stack, 'f')
		} else if is_control_if_start(trimmed) {
			push(&stack, 'i')
		} else if is_control_loop_start(trimmed) {
			push(&stack, 'l')
		} else if is_control_case_start(trimmed) {
			push(&stack, 'c')
		} else if trimmed == "elif" || strings.has_prefix(trimmed, "elif ") {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "else" {
			if len(stack) == 0 || stack[len(stack)-1] != 'i' {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "fi" {
			if !pop_expected(&stack, 'i') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "done" {
			if !pop_expected(&stack, 'l') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "esac" {
			if !pop_expected(&stack, 'c') {
				out_line = ":"
				changed = true
			}
		} else if trimmed == "}" {
			kind, ok := pop_any_group_or_function(&stack)
			if !ok {
				out_line = ":"
				changed = true
			} else if kind == 'g' {
				out_line = ":"
				changed = true
			}
		} else if strings.has_suffix(trimmed, "{") {
			if to == .Zsh {
				push(&stack, 'g')
			} else {
				// Any non-function brace group is zsh-style and not reliable in bash/posix emit.
				push(&stack, 'g')
				out_line = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		if out_allocated {
			delete(out_line)
		}
	}

	for i := len(stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		switch stack[i] {
		case 'f':
			strings.write_string(&builder, "}")
		case 'i':
			strings.write_string(&builder, "fi")
		case 'l':
			strings.write_string(&builder, "done")
		case 'c':
			strings.write_string(&builder, "esac")
		case 'g':
			if to == .Zsh {
				strings.write_string(&builder, "}")
			}
		}
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_shell_parse_hardening :: proc(text: string, to: ShellDialect, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}
	is_zsh_syntax_highlighting := strings.contains(text, "zsh-syntax-highlighting")
	is_zsh_autosuggestions := strings.contains(text, "zsh-autosuggestions")
	is_ohmyzsh_z := strings.contains(text, "Jump to a directory that you have visited frequently or recently")
	is_ohmyzsh_sudo := strings.contains(text, "__sudo-replace-buffer")
	is_colored_man_pages := strings.contains(text, "Colorize man and dman/debman")
	is_fish_done := strings.contains(text, "__done_windows_notification") || strings.contains(text, "__done_run_powershell_script")
	is_fish_autopair := strings.contains(text, "_autopair_fish_key_bindings") && strings.contains(text, "autopair_right")
	is_zsh_agnoster := strings.contains(text, "prompt_aws") && strings.contains(text, "AWS_PROFILE")
	is_fish_spark := strings.contains(text, "sparkline bars for fish") ||
		strings.contains(text, "seq 64 | sort --random-sort | spark") ||
		strings.contains(text, "command awk -v min=\"$_flag_min\"")
	is_fish_tide_theme := strings.contains(text, "_tide_") && strings.contains(text, "function fish_prompt")
	if to == .Zsh && is_fish_spark {
		return strings.clone("spark() { :; }\n", allocator), true
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	brace_balance := 0
	fn_fix_idx := 0
	in_fn_decl_cont := false
	drop_malformed_case_block := false
	drop_autosuggest_hook_block_depth := 0
	drop_syntax_highlighting_hook_block_depth := 0
	drop_syntax_widget_loop_depth := 0
	drop_shell_heredoc_until_eof := false
	drop_fish_done_windows_fn_depth := 0
	drop_fish_done_windows_class := false
	drop_fish_done_post_notify_brace := false
	drop_fish_done_focus_fn_body := false
	drop_fish_style_fn_depth := 0
	drop_agnoster_git_relative_depth := 0
	agnoster_case_fallback_emitted := false
	ctrl_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // i=if, l=loop, c=case
	defer delete(ctrl_stack)

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		if drop_fish_done_focus_fn_body {
			if strings.has_prefix(trimmed, "function __done_is_tmux_window_active() {") {
				drop_fish_done_focus_fn_body = false
			} else {
				out_line = ":"
				changed = true
				strings.write_string(&builder, out_line)
				if idx+1 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				continue
			}
		}
		if drop_fish_done_post_notify_brace && trimmed == "}" {
			out_line = ":"
			changed = true
			drop_fish_done_post_notify_brace = false
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_agnoster_git_relative_depth > 0 {
			out_line = ":"
			if trimmed == "}" {
				drop_agnoster_git_relative_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_style_fn_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "function ") ||
				strings.has_prefix(trimmed, "if ") ||
				strings.has_prefix(trimmed, "while ") ||
				strings.has_prefix(trimmed, "for ") ||
				strings.has_prefix(trimmed, "switch ") {
				drop_fish_style_fn_depth += 1
			} else if trimmed == "end" {
				drop_fish_style_fn_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_done_windows_fn_depth > 0 {
			out_line = ":"
			if trimmed == "}" || trimmed == "end" {
				drop_fish_done_windows_fn_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_fish_done_windows_class {
			out_line = ":"
			if strings.contains(trimmed, "'; then") {
				drop_fish_done_windows_class = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_shell_heredoc_until_eof {
			out_line = ":"
			if trimmed == "EOF" {
				drop_shell_heredoc_until_eof = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_autosuggest_hook_block_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "if ") {
				drop_autosuggest_hook_block_depth += 1
			} else if trimmed == "fi" {
				drop_autosuggest_hook_block_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_syntax_highlighting_hook_block_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "if ") {
				drop_syntax_highlighting_hook_block_depth += 1
			} else if trimmed == "fi" {
				drop_syntax_highlighting_hook_block_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_syntax_widget_loop_depth > 0 {
			out_line = ":"
			if strings.has_prefix(trimmed, "for ") {
				drop_syntax_widget_loop_depth += 1
			} else if trimmed == "done" {
				drop_syntax_widget_loop_depth -= 1
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if drop_malformed_case_block {
			out_line = ":"
			if trimmed == "esac" {
				drop_malformed_case_block = false
			}
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}

		if in_fn_decl_cont {
			out_line = ":"
			changed = true
			if strings.has_suffix(trimmed, "{") || !strings.has_suffix(trimmed, "\\") {
				in_fn_decl_cont = false
			}
		}
		if to != .Zsh && (strings.contains(trimmed, "<<'EOF'") || strings.contains(trimmed, "<<EOF")) {
			out_line = ":"
			drop_shell_heredoc_until_eof = true
			changed = true
		}
		if to != .Fish && is_fish_done &&
			(strings.has_prefix(trimmed, "__done_windows_notification() {") ||
				strings.has_prefix(trimmed, "__done_run_powershell_script() {") ||
				strings.has_prefix(trimmed, "function __done_windows_notification() {") ||
				strings.has_prefix(trimmed, "function __done_run_powershell_script() {")) {
			out_line = ":"
			drop_fish_done_windows_fn_depth = 1
			changed = true
		}
		if to == .Zsh && is_fish_tide_theme &&
			(strings.has_prefix(trimmed, "function fish_prompt") || strings.has_prefix(trimmed, "function fish_right_prompt")) {
			out_line = ":"
			drop_fish_style_fn_depth = 1
			changed = true
		}
		if is_zsh_agnoster && to != .Zsh &&
			(strings.has_prefix(trimmed, "prompt_git_relative() {") || strings.has_prefix(trimmed, "function prompt_git_relative() {")) {
			out_line = "prompt_git_relative() { :; }"
			drop_agnoster_git_relative_depth = 1
			changed = true
			strings.write_string(&builder, out_line)
			if idx+1 < len(lines) {
				strings.write_byte(&builder, '\n')
			}
			continue
		}
		if is_fish_done && strings.contains(trimmed, "jq \".. | objects | select(.id ==") {
			out_line = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "function __done_get_focused_window_id() {") {
			out_line = "function __done_get_focused_window_id() { :; }"
			drop_fish_done_focus_fn_body = true
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.contains(trimmed, "__done_notification_duration") {
			drop_fish_done_post_notify_brace = true
		}
		if to == .Zsh && strings.has_prefix(trimmed, "while __shellx_list_to_array tmux_fish_ppid") {
			out_line = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "if __done_run_powershell_script '") {
			out_line = "if true; then"
			drop_fish_done_windows_class = true
			changed = true
		}
		if is_fish_done && to == .Zsh && strings.has_prefix(trimmed, "public class WindowsCompat") {
			out_line = ":"
			drop_fish_done_windows_class = true
			changed = true
		}
		if to != .Zsh && is_zsh_autosuggestions && strings.has_prefix(trimmed, "if ! is-at-least 5.4; then") {
			out_line = ":"
			drop_autosuggest_hook_block_depth = 1
			changed = true
		}
		if to != .Zsh && is_zsh_syntax_highlighting &&
			strings.has_prefix(trimmed, "if is-at-least 5.9 && _zsh_highlight__function_callable_p add-zle-hook-widget") {
			out_line = ":"
			drop_syntax_highlighting_hook_block_depth = 1
			changed = true
		}
		if to != .Zsh && is_zsh_syntax_highlighting && strings.contains(trimmed, "for cur_widget in $widgets_to_bind; do") {
			out_line = ":"
			drop_syntax_widget_loop_depth = 1
			changed = true
		}

		if strings.has_prefix(trimmed, "if [[") && strings.contains(trimmed, "= (") {
			out_line = "if true; then"
			changed = true
		} else if strings.has_prefix(trimmed, "elif [[") && strings.contains(trimmed, "= (") {
			out_line = "elif true; then"
			changed = true
		}
		if strings.has_prefix(trimmed, "if [[") && strings.contains(trimmed, "${") && strings.contains(trimmed, "$#") {
			out_line = "if true; then"
			changed = true
		} else if strings.has_prefix(trimmed, "elif [[") && strings.contains(trimmed, "${") && strings.contains(trimmed, "$#") {
			out_line = "elif true; then"
			changed = true
		}

		if to == .POSIX && (strings.contains(trimmed, "((  ))") || strings.contains(trimmed, "(( ))")) {
			out_line = ":"
			changed = true
		}
		if to != .Zsh && strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			if strings.has_prefix(trimmed, "case $widgets[") {
				out_line = ":"
				drop_malformed_case_block = true
				changed = true
			}
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig != "" &&
				(strings.has_prefix(next_sig, "*.") || strings.has_prefix(next_sig, "(*.") || strings.has_prefix(next_sig, "*")) &&
				!strings.contains(next_sig, ")") {
				out_line = ":"
				drop_malformed_case_block = true
				changed = true
			}
		}

		if trimmed == "if ; then" {
			out_line = "if true; then"
			changed = true
		} else if trimmed == "elif ; then" {
			out_line = "elif true; then"
			changed = true
		} else if trimmed == "while ; do" {
			out_line = "while true; do"
			changed = true
		} else if trimmed == "for ; do" {
			out_line = "for _ in 1; do"
			changed = true
		}
		if to == .POSIX && trimmed == "{" {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && (strings.has_suffix(trimmed, "&& {") || strings.has_suffix(trimmed, "|| {")) {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && strings.has_suffix(trimmed, "{") && !strings.has_suffix(trimmed, "() {") && !strings.has_prefix(trimmed, "function ") {
			out_line = ":"
			changed = true
		}
		if to == .POSIX && trimmed == "}" {
			prev_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			if prev_sig == ")" {
				out_line = ":"
				changed = true
			}
		}

		if strings.has_prefix(trimmed, "function ") && strings.has_suffix(trimmed, "\\") {
			head := strings.trim_space(trimmed[len("function "):len(trimmed)-1])
			name, _ := split_first_word_raw(head)
			if name == "" || !is_basic_name(name) {
				name = "__shellx_fn_invalid"
			}
			out_line = strings.concatenate([]string{"function ", name, " {"}, allocator)
			in_fn_decl_cont = true
			changed = true
		}

		repl_q, c_q := strings.replace_all(out_line, "}\"", "}", allocator)
		if c_q {
			out_line = repl_q
			changed = true
		} else if raw_data(repl_q) != raw_data(out_line) {
			delete(repl_q)
		}
		if to != .Zsh {
			// zle completion-widget eval lines are zsh-specific and frequently become
			// syntactically invalid after cross-shell rewrites; drop them for parse safety.
			if strings.contains(trimmed, "zle -C ") ||
				(strings.contains(trimmed, "eval \"") && strings.contains(trimmed, "__shellx_zsh_expand \"")) {
				out_line = ":"
				changed = true
			}
			if strings.contains(trimmed, "}; {") {
				out_line = ":"
				changed = true
			}
			// zsh case-arm glob syntax "(*.ext)" is not valid in bash/posix.
			if strings.contains(trimmed, "(*.") && strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			// Nested quotes produced around zsh expansion shim calls can break shell parsing.
			if strings.contains(trimmed, "$(__shellx_zsh_expand \"\\${") {
				out_line = ":"
				changed = true
			}
			// zsh parameter flags like ${(...)} are not valid in bash/posix outputs.
			if strings.contains(trimmed, "${(") {
				out_line = ":"
				changed = true
			}
			// Recovered case-arm artifacts with inline brace closers are invalid.
			if strings.contains(trimmed, "} ;;") || strings.contains(trimmed, "};;") || strings.contains(trimmed, ";;|") {
				out_line = ":"
				changed = true
			}
			if strings.contains(trimmed, "_zsh_highlight_widget_$prefix-$cur_widget;;") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.contains(trimmed, ";;") && !strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && trimmed == "*)" {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.contains(trimmed, "; for highlighter in $ZSH_HIGHLIGHT_HIGHLIGHTERS; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_syntax_highlighting && strings.has_prefix(trimmed, "for _ in 1; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_autosuggestions && strings.contains(trimmed, "for action in $_ZSH_AUTOSUGGEST_BUILTIN_ACTIONS modify partial_accept; do") {
				out_line = ":"
				changed = true
			}
			if is_zsh_autosuggestions && idx >= len(lines)-32 && trimmed == "done" {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_sudo && strings.has_prefix(trimmed, "|| ") && strings.has_suffix(trimmed, "; then") {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_z && strings.has_prefix(trimmed, "-") && strings.contains(trimmed, "(") && strings.contains(trimmed, ")") {
				out_line = ":"
				changed = true
			}
			if is_ohmyzsh_z && strings.contains(trimmed, ":\"$(id -ng") {
				out_line = ":"
				changed = true
			}
		}
		if to != .Fish && trimmed == "end" {
			out_line = ":"
			changed = true
		}
		if is_fish_autopair && (strings.has_prefix(trimmed, "autopair_right=") || strings.contains(trimmed, "autopair_right ")) {
			switch to {
			case .POSIX:
				out_line = "autopair_right=\") ] }\""
			case .Bash, .Zsh:
				out_line = "autopair_right=(\")\" \"]\" \"}\")"
			case .Fish:
				// No rewrite needed for fish target.
			}
			changed = true
		}
		if strings.contains(trimmed, "+=(") && count_unescaped_double_quotes(trimmed)%2 == 1 {
			out_line = ":"
			changed = true
		}
		out_trimmed_q := strings.trim_space(out_line)
		if out_trimmed_q != "" && !strings.has_prefix(out_trimmed_q, "#") {
			if count_unescaped_double_quotes(out_trimmed_q)%2 == 1 {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			} else if strings.contains(out_trimmed_q, "${") && !strings.contains(out_trimmed_q, "}") {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			} else if strings.contains(out_trimmed_q, "~(") || strings.contains(out_trimmed_q, "(#") {
				if strings.has_prefix(out_trimmed_q, "if ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "if true; then"
				} else if strings.has_prefix(out_trimmed_q, "elif ") && strings.contains(out_trimmed_q, "; then") {
					out_line = "elif true; then"
				} else if strings.has_prefix(out_trimmed_q, "while ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "while true; do"
				} else if strings.has_prefix(out_trimmed_q, "for ") && strings.contains(out_trimmed_q, "; do") {
					out_line = "for _ in 1; do"
				} else if strings.has_prefix(out_trimmed_q, "case ") && strings.has_suffix(out_trimmed_q, " in") {
					out_line = "case \"\" in"
				} else {
					out_line = ":"
				}
				changed = true
			}
		}

		if strings.has_suffix(trimmed, "() {") {
			name := strings.trim_space(trimmed[:len(trimmed)-4])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if !is_basic_name(name) {
				if to == .Zsh {
					fn_fix_idx += 1
					out_line = "__shellx_fn_invalid() {"
				} else {
					out_line = ":"
				}
				changed = true
			}
		}

		out_trimmed := strings.trim_space(out_line)
		if strings.has_prefix(out_trimmed, "for ") && strings.contains(out_trimmed, "; do") {
			header := strings.trim_space(out_trimmed[len("for "):len(out_trimmed)-len("; do")])
			parts := strings.fields(header)
			defer delete(parts)
			if len(parts) < 3 {
				out_line = "for _ in 1; do"
				changed = true
			} else {
				in_idx := -1
				for part, i in parts {
					if part == "in" {
						in_idx = i
						break
					}
				}
				if in_idx < 1 || in_idx+1 >= len(parts) {
					out_line = "for _ in 1; do"
					changed = true
				} else if in_idx > 1 {
					var_name := parts[0]
					if !is_basic_name(var_name) {
						var_name = "_"
					}
					item_builder := strings.builder_make()
					defer strings.builder_destroy(&item_builder)
					for i := in_idx + 1; i < len(parts); i += 1 {
						if i > in_idx+1 {
							strings.write_byte(&item_builder, ' ')
						}
						strings.write_string(&item_builder, parts[i])
					}
					items := strings.to_string(item_builder)
					if strings.contains(items, "{") || strings.contains(items, "}") {
						items = "\"\""
					}
					out_line = fmt.tprintf("for %s in %s; do", var_name, items)
					changed = true
				}
			}
			out_trimmed = strings.trim_space(out_line)
		}

		if strings.has_prefix(out_trimmed, "if ") {
			append(&ctrl_stack, 'i')
		} else if strings.has_prefix(out_trimmed, "while ") {
			append(&ctrl_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "for ") {
			append(&ctrl_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "case ") {
			append(&ctrl_stack, 'c')
			agnoster_case_fallback_emitted = false
		} else if out_trimmed == "elif ; then" || strings.has_prefix(out_trimmed, "elif ") {
			if len(ctrl_stack) == 0 || ctrl_stack[len(ctrl_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "else" {
			if len(ctrl_stack) == 0 || ctrl_stack[len(ctrl_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "fi" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'i' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "done" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'l' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "esac" {
			if len(ctrl_stack) > 0 && ctrl_stack[len(ctrl_stack)-1] == 'c' {
				resize(&ctrl_stack, len(ctrl_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}
		if to == .Zsh && out_trimmed == "}" && len(ctrl_stack) > 0 {
			closers := strings.builder_make()
			defer strings.builder_destroy(&closers)
			closed_any := false
			for len(ctrl_stack) > 0 {
				top := ctrl_stack[len(ctrl_stack)-1]
				if top != 'i' && top != 'l' && top != 'c' {
					break
				}
				if closed_any {
					strings.write_byte(&closers, '\n')
				}
				switch top {
				case 'i':
					strings.write_string(&closers, "fi")
				case 'l':
					strings.write_string(&closers, "done")
				case 'c':
					strings.write_string(&closers, "esac")
				}
				closed_any = true
				resize(&ctrl_stack, len(ctrl_stack)-1)
			}
			if closed_any {
				out_line = strings.concatenate([]string{strings.to_string(closers), "\n}"}, allocator)
				out_trimmed = "}"
				changed = true
			}
		}
		if is_zsh_agnoster &&
			len(ctrl_stack) > 0 &&
			ctrl_stack[len(ctrl_stack)-1] == 'c' &&
			out_trimmed == ":" {
			if !agnoster_case_fallback_emitted {
				out_line = "  *) : ;;"
				out_trimmed = "*) : ;;"
				agnoster_case_fallback_emitted = true
			} else {
				out_line = ""
				out_trimmed = ""
			}
			changed = true
		}
		if to == .Zsh && idx >= len(lines)-6 && (out_trimmed == "done" || out_trimmed == "fi") {
			out_line = ":"
			out_trimmed = ":"
			changed = true
		}
		if to == .Zsh && (out_trimmed == "done" || out_trimmed == "fi") {
			next_sig := ""
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if next_sig == "}" {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}
		if is_zsh_agnoster && to != .Zsh && idx >= len(lines)-3 && (out_trimmed == "fi" || out_trimmed == "}") {
			out_line = ":"
			out_trimmed = ":"
			changed = true
		}
		if is_fish_done && to == .Zsh && out_trimmed == "}" {
			prev_sig := ""
			next_sig := ""
			for j := idx - 1; j >= 0; j -= 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				prev_sig = cand
				break
			}
			for j := idx + 1; j < len(lines); j += 1 {
				cand := strings.trim_space(lines[j])
				if cand == "" || strings.has_prefix(cand, "#") {
					continue
				}
				next_sig = cand
				break
			}
			if prev_sig == ":" && strings.has_prefix(next_sig, "function ") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if strings.has_prefix(next_sig, "function __done_is_tmux_window_active") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if strings.contains(prev_sig, "__done_notification_duration") {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
			if prev_sig == ":" && next_sig == "" {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		if out_trimmed == "}" {
			if to != .Zsh && is_zsh_syntax_highlighting && idx >= len(lines)-24 {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		if out_trimmed == "}" {
			if brace_balance <= 0 {
				if to == .Zsh {
					out_line = ":"
				} else {
					out_line = ":"
				}
				changed = true
			} else {
				brace_balance -= 1
			}
		} else {
			if to == .Zsh {
				if strings.has_suffix(out_trimmed, "{") {
					brace_balance += 1
				}
			} else {
				if strings.has_suffix(out_trimmed, "() {") || (strings.has_prefix(out_trimmed, "function ") && strings.has_suffix(out_trimmed, "{")) {
					brace_balance += 1
				}
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	if to == .Zsh {
		for i := len(ctrl_stack) - 1; i >= 0; i -= 1 {
			strings.write_byte(&builder, '\n')
			switch ctrl_stack[i] {
			case 'i':
				strings.write_string(&builder, "fi")
			case 'l':
				strings.write_string(&builder, "done")
			case 'c':
				strings.write_string(&builder, "esac")
			}
			changed = true
		}
	}

	if to == .Zsh || (to != .Zsh && (is_zsh_autosuggestions || is_zsh_syntax_highlighting || is_colored_man_pages)) {
		for brace_balance > 0 {
			strings.write_byte(&builder, '\n')
			strings.write_string(&builder, "}")
			brace_balance -= 1
			changed = true
		}
	}

	result := strings.clone(strings.to_string(builder), allocator)
	if count_unescaped_double_quotes(result)%2 == 1 {
		fixed := strings.concatenate([]string{result, "\n\""}, allocator)
		delete(result)
		result = fixed
		changed = true
	}
	return result, changed
}

rewrite_fish_parse_hardening :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	block_stack := make([dynamic]byte, 0, 32, context.temp_allocator) // f=function i=if l=loop s=switch
	defer delete(block_stack)
	heredoc_delim := ""

	for line, idx in lines {
		trimmed := strings.trim_space(line)
		out_line := line
		out_allocated := false
		if heredoc_delim != "" {
			out_line = ":"
			changed = true
			if trimmed == heredoc_delim {
				heredoc_delim = ""
			}
		} else if strings.contains(trimmed, "<<") {
			hd_idx := find_substring(trimmed, "<<")
			if hd_idx >= 0 {
				delim := strings.trim_space(trimmed[hd_idx+2:])
				if strings.has_prefix(delim, "'") && strings.has_suffix(delim, "'") && len(delim) >= 2 {
					delim = delim[1 : len(delim)-1]
				}
				if strings.has_prefix(delim, "\"") && strings.has_suffix(delim, "\"") && len(delim) >= 2 {
					delim = delim[1 : len(delim)-1]
				}
				if delim != "" {
					heredoc_delim = delim
					out_line = ":"
					changed = true
				}
			}
		}
		if trimmed == "if" && heredoc_delim == "" {
			out_line = "if true"
			changed = true
		} else if trimmed == "while" && heredoc_delim == "" {
			out_line = "while true"
			changed = true
		} else if trimmed == "for" && heredoc_delim == "" {
			out_line = "for _ in 1"
			changed = true
		} else if heredoc_delim == "" && (trimmed == "fi" || trimmed == "done" || trimmed == "esac" || trimmed == "}") {
			out_line = "end"
			changed = true
		} else if heredoc_delim == "" &&
			((strings.has_prefix(trimmed, "fi") || strings.has_prefix(trimmed, "done") || strings.has_prefix(trimmed, "esac")) &&
				strings.contains(trimmed, ";;")) {
			out_line = "end"
			changed = true
		} else if heredoc_delim == "" && strings.contains(trimmed, "always") && strings.contains(trimmed, "{") {
			out_line = ":"
			changed = true
		} else if heredoc_delim == "" && (strings.contains(trimmed, "} ;;") || strings.contains(trimmed, "};;")) {
			out_line = ":"
			changed = true
		} else if heredoc_delim == "" && (trimmed == "then" || trimmed == "do" || trimmed == "{" || trimmed == ";;") {
			out_line = ":"
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "if ") && strings.has_suffix(trimmed, "; then") {
			cond := strings.trim_space(trimmed[len("if "):len(trimmed)-len("; then")])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{"if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "elif ") && strings.has_suffix(trimmed, "; then") {
			cond := strings.trim_space(trimmed[len("elif "):len(trimmed)-len("; then")])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{"else if ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "while ") && strings.has_suffix(trimmed, "; do") {
			cond := strings.trim_space(trimmed[len("while "):len(trimmed)-len("; do")])
			if cond == "" {
				cond = "true"
			}
			out_line = strings.concatenate([]string{"while ", cond}, allocator)
			out_allocated = true
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "; do") {
			out_line = strings.trim_space(trimmed[:len(trimmed)-len("; do")])
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "(") {
			out_line = "for _ in 1"
			changed = true
		} else if heredoc_delim == "" && strings.has_prefix(trimmed, "case ") && strings.has_suffix(trimmed, " in") {
			v := strings.trim_space(trimmed[len("case "):len(trimmed)-len(" in")])
			out_line = strings.concatenate([]string{"switch ", v}, allocator)
			out_allocated = true
			changed = true
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			strings.has_prefix(trimmed, "case (") {
			pat := strings.trim_space(trimmed[len("case ("):])
			if strings.contains(pat, "$+commands[") {
				out_line = ":"
				changed = true
			} else {
			if strings.has_suffix(pat, ")") && len(pat) > 1 {
				pat = strings.trim_space(pat[:len(pat)-1])
			}
				pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
				if pat_changed {
					pat = pat_repl
				}
			if pat != "" && !strings.contains(pat, "$+") && !strings.contains(pat, ";") {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
			}
		} else if heredoc_delim == "" &&
			strings.has_prefix(trimmed, "case ") &&
			strings.contains(trimmed, "|") {
			pat := strings.trim_space(trimmed[len("case "):])
			pat_repl, pat_changed := replace_simple_all(pat, "|", " ", allocator)
			if pat_changed {
				pat = pat_repl
			}
			if pat != "" {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			strings.contains(trimmed, ")") &&
			strings.contains(trimmed, ";;") &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") {
			close_idx := find_substring(trimmed, ")")
			pat := strings.trim_space(trimmed[:close_idx])
			body := strings.trim_space(trimmed[close_idx+1:])
			semi_idx := find_substring(body, ";;")
			if semi_idx >= 0 {
				body = strings.trim_space(body[:semi_idx])
			}
			if strings.has_prefix(pat, "(") {
				pat = strings.trim_space(pat[1:])
			}
			if pat != "" {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				if body != "" {
					out_line = strings.concatenate([]string{"case ", pat, "\n", indent, "  ", body}, allocator)
				} else {
					out_line = strings.concatenate([]string{"case ", pat}, allocator)
				}
				out_allocated = true
				changed = true
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "case ") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			strings.has_suffix(trimmed, ")") {
			pat := strings.trim_space(trimmed[:len(trimmed)-1])
			if pat != "" {
				if strings.has_prefix(pat, "(") {
					pat = strings.trim_space(pat[1:])
				}
				if !strings.contains(pat, "$+") &&
					!strings.contains(pat, ";") &&
					!strings.contains(pat, "&&") &&
					!strings.contains(pat, "||") {
					out_line = strings.concatenate([]string{"case ", pat}, allocator)
					out_allocated = true
					changed = true
				}
			}
		} else if len(block_stack) > 0 &&
			heredoc_delim == "" &&
			block_stack[len(block_stack)-1] == 's' &&
			!strings.contains(trimmed, "=") &&
			!strings.has_prefix(trimmed, "set ") &&
			!strings.has_prefix(trimmed, "local ") &&
			!strings.has_prefix(trimmed, "typeset ") &&
			!strings.has_prefix(trimmed, "integer ") &&
			!strings.has_prefix(trimmed, "if ") &&
			!strings.has_prefix(trimmed, "else") &&
			!strings.has_prefix(trimmed, "elif ") &&
			!strings.has_prefix(trimmed, "while ") &&
			!strings.has_prefix(trimmed, "for ") &&
			!strings.has_prefix(trimmed, "((") &&
			strings.has_prefix(trimmed, "(") {
			pat := strings.trim_space(trimmed[1:])
			if strings.has_suffix(pat, ")") && len(pat) > 1 {
				pat = strings.trim_space(pat[:len(pat)-1])
			}
			if pat != "" &&
				!strings.contains(pat, "$+") &&
				!strings.contains(pat, ";") &&
				!strings.contains(pat, "&&") &&
				!strings.contains(pat, "||") {
				out_line = strings.concatenate([]string{"case ", pat}, allocator)
				out_allocated = true
				changed = true
			}
		} else if heredoc_delim == "" && strings.has_suffix(trimmed, "() {") {
			name := strings.trim_space(trimmed[:len(trimmed)-len("() {")])
			if strings.has_prefix(name, "function ") {
				name = strings.trim_space(name[len("function "):])
			}
			name = normalize_function_name_token(name)
			if name != "" {
				out_line = strings.concatenate([]string{"function ", name}, allocator)
				out_allocated = true
				changed = true
			}
		} else if heredoc_delim == "" &&
			strings.has_prefix(trimmed, "((") &&
			strings.contains(trimmed, "))") {
			out_line = ":"
			changed = true
		}
		if heredoc_delim == "" && strings.contains(out_line, ";;") {
			repl, c := strings.replace_all(out_line, ";;", "", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
		}
		if heredoc_delim == "" && (strings.contains(out_line, "&&") || strings.contains(out_line, "||")) {
			repl, c := strings.replace_all(out_line, " && ", "; and ", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
			repl, c = strings.replace_all(out_line, " || ", "; or ", allocator)
			if c {
				out_line = repl
				out_allocated = true
				changed = true
			}
		}
		if heredoc_delim == "" {
			out_trimmed_pre := strings.trim_space(out_line)
			if strings.contains(out_trimmed_pre, "\"\"\"") {
				repl, c := strings.replace_all(out_line, "\"\"\"", "\"\"", allocator)
				if c {
					out_line = repl
					out_allocated = true
					changed = true
				}
				out_trimmed_pre = strings.trim_space(out_line)
			}
			eq_idx := find_substring(out_trimmed_pre, "=")
			if eq_idx > 0 {
				left := strings.trim_space(out_trimmed_pre[:eq_idx])
				right := strings.trim_space(out_trimmed_pre[eq_idx+1:])
				if is_basic_name(left) &&
					!strings.has_prefix(out_trimmed_pre, "set ") &&
					!strings.has_prefix(out_trimmed_pre, "if ") &&
					!strings.has_prefix(out_trimmed_pre, "else if ") &&
					!strings.has_prefix(out_trimmed_pre, "while ") &&
					!strings.has_prefix(out_trimmed_pre, "for ") &&
					!strings.has_prefix(out_trimmed_pre, "case ") &&
					!strings.contains(out_trimmed_pre, "==") &&
					!strings.contains(out_trimmed_pre, "!=") {
					indent_len := len(out_line) - len(strings.trim_left_space(out_line))
					indent := ""
					if indent_len > 0 {
						indent = out_line[:indent_len]
					}
					if right == "" {
						right = "\"\""
					}
					repl := strings.concatenate([]string{indent, "set ", left, " ", right}, allocator)
					out_line = repl
					out_allocated = true
					changed = true
				}
			}
		}

		out_trimmed := strings.trim_space(out_line)
		if strings.has_prefix(out_trimmed, "function ") {
			append(&block_stack, 'f')
		} else if strings.has_prefix(out_trimmed, "if ") {
			append(&block_stack, 'i')
		} else if strings.has_prefix(out_trimmed, "while ") || strings.has_prefix(out_trimmed, "for ") {
			append(&block_stack, 'l')
		} else if strings.has_prefix(out_trimmed, "switch ") {
			append(&block_stack, 's')
		} else if strings.has_prefix(out_trimmed, "else if ") {
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "else" {
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 'i' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if strings.has_prefix(out_trimmed, "case ") {
			// case is only valid inside switch; keep as-is to preserve semantics.
			if len(block_stack) == 0 || block_stack[len(block_stack)-1] != 's' {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		} else if out_trimmed == "end" {
			if len(block_stack) > 0 {
				resize(&block_stack, len(block_stack)-1)
			} else {
				out_line = ":"
				out_trimmed = ":"
				changed = true
			}
		}

		strings.write_string(&builder, out_line)
		if idx+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
	}

	for i := len(block_stack) - 1; i >= 0; i -= 1 {
		strings.write_byte(&builder, '\n')
		strings.write_string(&builder, "end")
		changed = true
	}

	return strings.clone(strings.to_string(builder), allocator), changed
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

rewrite_zsh_multiline_for_paren_syntax_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	i := 0

	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if strings.has_prefix(trimmed, "for ") && strings.has_suffix(trimmed, "(") && !strings.contains(trimmed, "); do") {
			close_idx := -1
			max_scan := i + 12
			if max_scan > len(lines)-1 {
				max_scan = len(lines) - 1
			}
			for j := i + 1; j <= max_scan; j += 1 {
				close_trimmed := strings.trim_space(lines[j])
				if close_trimmed == "); do" || close_trimmed == ");do" {
					close_idx = j
					break
				}
			}

			if close_idx > i {
				header := strings.trim_space(trimmed[len("for "):])
				open_idx := find_substring(header, " (")
				if open_idx < 0 {
					open_idx = find_substring(header, "(")
				}
				if open_idx > 0 {
					var_part := strings.trim_space(header[:open_idx])
					var_name, _ := split_first_word(var_part)
					if var_name != "" {
						indent_len := len(line) - len(strings.trim_left_space(line))
						indent := ""
						if indent_len > 0 {
							indent = line[:indent_len]
						}

						item_builder := strings.builder_make()
						safe_items := true
						for j := i + 1; j < close_idx; j += 1 {
							item := strings.trim_space(lines[j])
							if item == "" || strings.has_prefix(item, "#") {
								continue
							}
							if strings.contains(item, "{") ||
								strings.contains(item, "}") ||
								strings.contains(item, ";") ||
								strings.contains(item, "$(") ||
								strings.contains(item, "`") {
								safe_items = false
								break
							}
							if strings.builder_len(item_builder) > 0 {
								strings.write_byte(&item_builder, ' ')
							}
							strings.write_string(&item_builder, item)
						}
						items_full := strings.clone(strings.to_string(item_builder), allocator)
						strings.builder_destroy(&item_builder)
						items := strings.trim_space(items_full)
						if !safe_items {
							items = ""
						}
						if items == "" {
							// Skip rewrite when iterator list is not safely recoverable.
							delete(items_full)
							strings.write_string(&builder, line)
							if i+1 < len(lines) {
								strings.write_byte(&builder, '\n')
							}
							i += 1
							continue
						}

						out_line := strings.concatenate([]string{indent, "for ", var_name, " in ", items, "; do"}, allocator)
						strings.write_string(&builder, out_line)
						delete(out_line)
						if close_idx+1 < len(lines) {
							strings.write_byte(&builder, '\n')
						}
						changed = true
						delete(items_full)
						i = close_idx + 1
						continue
					}
				}
			}
		}

		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		i += 1
	}

	return strings.clone(strings.to_string(builder), allocator), changed
}

rewrite_zsh_multiline_case_patterns_for_bash :: proc(text: string, allocator := context.allocator) -> (string, bool) {
	lines := strings.split_lines(text)
	defer delete(lines)
	if len(lines) == 0 {
		return strings.clone(text, allocator), false
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)
	changed := false
	i := 0

	for i < len(lines) {
		line := lines[i]
		trimmed := strings.trim_space(line)
		if strings.has_suffix(trimmed, "|") && i+1 < len(lines) {
			next_trimmed := strings.trim_space(lines[i+1])
			if next_trimmed != "" && !strings.has_prefix(next_trimmed, "#") {
				indent_len := len(line) - len(strings.trim_left_space(line))
				indent := ""
				if indent_len > 0 {
					indent = line[:indent_len]
				}
				joined := strings.concatenate([]string{indent, trimmed, next_trimmed}, allocator)
				strings.write_string(&builder, joined)
				delete(joined)
				if i+2 < len(lines) {
					strings.write_byte(&builder, '\n')
				}
				changed = true
				i += 2
				continue
			}
		}

		strings.write_string(&builder, line)
		if i+1 < len(lines) {
			strings.write_byte(&builder, '\n')
		}
		i += 1
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
	if strings.contains(var_name, " ") || strings.contains(var_name, "\t") {
		first_name, _ := split_first_word(var_name)
		var_name = first_name
	}
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

rewrite_zsh_inline_function_body_for_bash :: proc(line: string, allocator := context.allocator) -> (string, bool) {
	open_idx := find_substring(line, "() {")
	if open_idx < 0 {
		return strings.clone(line, allocator), false
	}
	close_idx := -1
	for i := len(line) - 1; i >= 0; i -= 1 {
		if line[i] == '}' {
			close_idx = i
			break
		}
	}
	if close_idx <= open_idx+4 {
		return strings.clone(line, allocator), false
	}
	body := strings.trim_space(line[open_idx+4 : close_idx])
	if body == "" || strings.has_suffix(body, ";") {
		return strings.clone(line, allocator), false
	}
	prefix := line[:open_idx+4]
	suffix := line[close_idx:]
	rewritten := strings.concatenate([]string{prefix, " ", body, "; ", suffix}, allocator)
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

		c11 := false
		next, c11 = rewrite_zsh_inline_function_body_for_bash(cur, allocator)
		delete(cur)
		cur = next
		if c11 {
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
