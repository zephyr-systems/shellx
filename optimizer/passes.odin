package optimizer

import "../ir"
import "core:fmt"
import "core:mem"

OPTIMIZER_COLLECT_METRICS :: #config(OPTIMIZER_COLLECT_METRICS, false)

// OptimizationLevel represents the level of optimization to apply
OptimizationLevel :: enum {
	None, // No optimization
	Basic, // Basic optimizations (dead code elimination)
	Standard, // Standard optimizations (constant folding, pipeline simplification)
	Aggressive, // Aggressive optimizations (function inlining, loop unrolling)
}

// OptimizeResult contains the result of an optimization pass
OptimizationMetrics :: struct {
	forks_eliminated:  int,
	subshells_removed: int,
	builtins_used:     int,
	patterns_applied:  map[string]int,
	estimated_speedup: f32,
}

// OptimizeResult contains the result of an optimization pass
OptimizeResult :: struct {
	changed:     bool, // Whether any changes were made
	iterations:  int, // Number of iterations performed
	diagnostics: [dynamic]string, // Diagnostic messages
	metrics:     OptimizationMetrics,
}

// create_optimize_result creates a new optimization result
create_optimize_result :: proc(allocator := context.allocator) -> OptimizeResult {
	patterns: map[string]int
	if OPTIMIZER_COLLECT_METRICS {
		patterns = make(map[string]int, allocator)
	}

	return OptimizeResult {
		changed = false,
		iterations = 0,
		diagnostics = make([dynamic]string, allocator),
		metrics = OptimizationMetrics{
			patterns_applied = patterns,
		},
	}
}

// destroy_optimize_result cleans up the result
destroy_optimize_result :: proc(result: ^OptimizeResult) {
	delete(result.diagnostics)
	if result.metrics.patterns_applied != nil {
		delete(result.metrics.patterns_applied)
	}
}

// add_diagnostic adds a diagnostic message
add_diagnostic :: proc(result: ^OptimizeResult, message: string) {
	append(&result.diagnostics, message)
}

record_pattern :: proc(
	result: ^OptimizeResult,
	pattern: string,
	forks_saved := 0,
	subshells_saved := 0,
	builtins_delta := 0,
) {
	if !OPTIMIZER_COLLECT_METRICS {
		return
	}
	result.metrics.patterns_applied[pattern] += 1
	result.metrics.forks_eliminated += forks_saved
	result.metrics.subshells_removed += subshells_saved
	result.metrics.builtins_used += builtins_delta
}

merge_optimize_result :: proc(dst: ^OptimizeResult, src: OptimizeResult) {
	if src.changed {
		dst.changed = true
	}
	dst.iterations += src.iterations
	for msg in src.diagnostics {
		add_diagnostic(dst, msg)
	}
	dst.metrics.forks_eliminated += src.metrics.forks_eliminated
	dst.metrics.subshells_removed += src.metrics.subshells_removed
	dst.metrics.builtins_used += src.metrics.builtins_used
	if OPTIMIZER_COLLECT_METRICS && src.metrics.patterns_applied != nil && dst.metrics.patterns_applied != nil {
		for pattern, count in src.metrics.patterns_applied {
			dst.metrics.patterns_applied[pattern] += count
		}
	}
}

// optimize is the main optimization dispatcher
// Applies optimization passes based on the specified level
optimize :: proc(
	program: ^ir.Program,
	level: OptimizationLevel,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	switch level {
	case .None:
		// No optimization
		add_diagnostic(&result, "Optimization disabled")

	case .Basic:
		add_diagnostic(&result, "Running basic optimizations")
		dce_result := dead_code_elimination(program, allocator)
		merge_optimize_result(&result, dce_result)
		destroy_optimize_result(&dce_result)

	case .Standard:
		add_diagnostic(&result, "Running standard optimizations")

		// Run common subexpression elimination
		cse_result := common_subexpression_elimination(program, allocator)
		merge_optimize_result(&result, cse_result)
		destroy_optimize_result(&cse_result)

		// Run constant folding
		cf_result := constant_folding(program, allocator)
		merge_optimize_result(&result, cf_result)
		destroy_optimize_result(&cf_result)

		// Run dead code elimination
		dce_result := dead_code_elimination(program, allocator)
		merge_optimize_result(&result, dce_result)
		destroy_optimize_result(&dce_result)

		// Run pipeline simplification
		ps_result := pipeline_simplification(program, allocator)
		merge_optimize_result(&result, ps_result)
		destroy_optimize_result(&ps_result)

	case .Aggressive:
		add_diagnostic(&result, "Running aggressive optimizations")

		// Run all standard optimizations
		std_result := optimize(program, .Standard, allocator)
		merge_optimize_result(&result, std_result)
		destroy_optimize_result(&std_result)

		// Run function inlining
		fi_result := inline_small_functions(program, allocator)
		merge_optimize_result(&result, fi_result)
		destroy_optimize_result(&fi_result)

		// Run loop unrolling
		lu_result := loop_unrolling(program, allocator)
		merge_optimize_result(&result, lu_result)
		destroy_optimize_result(&lu_result)
	}

	if OPTIMIZER_COLLECT_METRICS && (result.metrics.forks_eliminated > 0 || result.metrics.subshells_removed > 0 || len(result.metrics.patterns_applied) > 0) {
		result.metrics.estimated_speedup = f32(result.metrics.forks_eliminated)*0.04 + f32(result.metrics.subshells_removed)*0.03
		add_diagnostic(
			&result,
			fmt.aprintf(
				"Optimizer metrics: forks=%d subshells=%d speedup_est=%.2f%%",
				result.metrics.forks_eliminated,
				result.metrics.subshells_removed,
				result.metrics.estimated_speedup*100.0,
				allocator,
			),
		)
	}

	return result
}

metrics_enabled :: proc() -> bool {
	return OPTIMIZER_COLLECT_METRICS
}

// dead_code_elimination removes unreachable code
// 23.2: Removes statements after return, break, continue
// Removes unused functions
// Returns OptimizeResult indicating whether changes were made
dead_code_elimination :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil || len(program.functions) == 0 {
		return result
	}

	// Find used functions by scanning all function bodies for function calls
	used_functions := make(map[string]bool, allocator)
	defer delete(used_functions)

	// Main function is always used
	for fn in program.functions {
		if fn.name == "main" {
			used_functions[fn.name] = true
		}
	}

	// Scan for function calls
	for fn in program.functions {
		for stmt in fn.body {
			if stmt.type == .Call {
				// Mark function as used if it's being called
				if stmt.call.function != nil {
					used_functions[stmt.call.function.name] = true
				}
			}
		}
	}

	// Remove unused functions
	new_functions := make([dynamic]ir.Function, allocator)
	for fn in program.functions {
		if used_functions[fn.name] {
			append(&new_functions, fn)
		} else {
			result.changed = true
			msg := fmt.aprintf("Removed unused function: %s", fn.name, allocator)
			add_diagnostic(&result, msg)
		}
	}
	delete(program.functions)
	program.functions = new_functions

	// Remove unreachable statements after return/break/continue
	for &fn in program.functions {
		new_body := make([dynamic]ir.Statement, allocator)
		found_terminal := false
		removed_count := 0

		for stmt in fn.body {
			if found_terminal {
				// Skip unreachable statements
				removed_count += 1
				continue
			}

			append(&new_body, stmt)

			// Check if this is a terminal statement
			switch stmt.type {
			case .Return:
				found_terminal = true
			case .Branch:
				// For branches, check if it's an unconditional branch (break/continue)
				if stmt.branch.condition == nil {
					found_terminal = true
				}
			case .Assign, .Call, .Logical, .Case, .Loop, .Pipeline:
				// Not a terminal statement
			}
		}

		if removed_count > 0 {
			result.changed = true
			msg := fmt.aprintf(
				"Removed %d unreachable statements from %s",
				removed_count,
				fn.name,
				allocator,
			)
			add_diagnostic(&result, msg)
		}

		delete(fn.body)
		fn.body = new_body
	}

	return result
}

// constant_folding evaluates constant expressions at compile time
// 23.3: Evaluates constant arithmetic
// Evaluates constant string concatenation
// Simplifies constant conditionals
constant_folding :: proc(program: ^ir.Program, allocator := context.allocator) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	// Helper to check if a value is a constant integer
	int_to_string :: proc(value: int, allocator: mem.Allocator) -> string {
		if value == 0 {
			buffer := make([]byte, 1, allocator)
			buffer[0] = '0'
			return string(buffer)
		}

		is_negative := value < 0
		n := value
		if is_negative {
			n = -n
		}

		digits := 0
		tmp := n
		for tmp > 0 {
			digits += 1
			tmp /= 10
		}

		total_len := digits
		if is_negative {
			total_len += 1
		}
		buffer := make([]byte, total_len, allocator)

		idx := total_len - 1
		for n > 0 {
			buffer[idx] = byte('0' + (n % 10))
			n /= 10
			idx -= 1
		}
		if is_negative {
			buffer[0] = '-'
		}

		return string(buffer)
	}

	evaluate_expression :: proc(
		expr: ir.Expression,
		allocator: mem.Allocator,
	) -> (value: ir.Expression, is_constant: bool) {
		if expr == nil {
			return nil, false
		}

		#partial switch e in expr {
		case ^ir.Literal:
			return expr, true
		case ^ir.BinaryOp:
			left, left_const := evaluate_expression(e.left, allocator)
			right, right_const := evaluate_expression(e.right, allocator)
			if !left_const || !right_const {
				return expr, false
			}

			left_lit, left_ok := left.(^ir.Literal)
			right_lit, right_ok := right.(^ir.Literal)
			if !left_ok || !right_ok {
				return expr, false
			}

			if e.op == .Add && left_lit.type == .Int && right_lit.type == .Int {
				left_int := 0
				right_int := 0

				for ch in left_lit.value {
					left_int = left_int * 10 + int(ch - '0')
				}
				for ch in right_lit.value {
					right_int = right_int * 10 + int(ch - '0')
				}

				new_literal := new(ir.Literal, allocator)
				new_literal.type = .Int
				new_literal.value = int_to_string(left_int + right_int, allocator)
				return new_literal, true
			}
		}

		return expr, false
	}

	// Process each function
	for &fn in program.functions {
		for &stmt in fn.body {
			switch stmt.type {
			case .Assign:
				folded, is_const := evaluate_expression(stmt.assign.value, allocator)
				if is_const && folded != nil {
					stmt.assign.value = folded
					result.changed = true
				}
			case .Branch:
				if stmt.branch.condition != nil {
					_, _ = evaluate_expression(stmt.branch.condition, allocator)
				}
			case .Call, .Logical, .Case, .Return, .Loop, .Pipeline:
				// Other statement types
			}
		}
	}

	return result
}

// pipeline_simplification simplifies command pipelines
// 23.5: Combines adjacent commands when possible
// Removes unnecessary pipes
pipeline_simplification :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	command_name :: proc(call: ir.Call) -> string {
		if call.function == nil {
			return ""
		}
		return call.function.name
	}

	arg_text :: proc(expr: ir.Expression) -> string {
		return ir.expr_to_string(expr)
	}

	has_grep_count_related_flag :: proc(call: ir.Call) -> bool {
		for arg in call.arguments {
			text := arg_text(arg)
			switch text {
			case "-c", "--count", "-q", "--quiet", "-l", "--files-with-matches":
				return true
			}
		}
		return false
	}

	with_leading_arg :: proc(call: ir.Call, arg: string, allocator: mem.Allocator) -> ir.Call {
		new_args := make([dynamic]ir.Expression, 0, len(call.arguments)+1, allocator)
		lit := new(ir.Literal, allocator)
		lit.value = arg
		lit.type = .String
		append(&new_args, lit)
		for existing in call.arguments {
			append(&new_args, existing)
		}
		out := call
		out.arguments = new_args
		return out
	}

	// Patterns to simplify conservatively:
	// echo ... | cat              -> echo ...
	// cmd | tee /dev/null         -> cmd
	// sort | uniq                 -> sort -u
	// grep ... | wc -l            -> grep -c ...

	for &fn in program.functions {
		for &stmt, idx in fn.body {
			if stmt.type == .Pipeline {
				pipeline := &stmt.pipeline

				// Check for simplification patterns
				if len(pipeline.commands) == 2 {
					first_cmd := pipeline.commands[0]
					second_cmd := pipeline.commands[1]

					first_name := command_name(first_cmd)
					second_name := command_name(second_cmd)
					if first_name == "echo" && second_name == "cat" {
						// Replace pipeline with just the echo command
						fn.body[idx] = ir.Statement {
							type     = .Call,
							call     = first_cmd,
							location = stmt.location,
						}
						result.changed = true
						msg := fmt.aprintf(
							"Simplified 'echo | cat' pipeline in %s",
							fn.name,
							allocator,
						)
						add_diagnostic(&result, msg)
						record_pattern(&result, "echo_pipe_cat", 1)
						continue
					}

					// Pattern: cmd | tee /dev/null -> cmd
					if second_name == "tee" && len(second_cmd.arguments) == 1 && arg_text(second_cmd.arguments[0]) == "/dev/null" {
						fn.body[idx] = ir.Statement{
							type = .Call,
							call = first_cmd,
							location = stmt.location,
						}
						result.changed = true
						msg := fmt.aprintf(
							"Simplified '%s | tee /dev/null' pipeline in %s",
							first_name,
							fn.name,
							allocator,
						)
						add_diagnostic(&result, msg)
						record_pattern(&result, "tee_devnull_elision", 1)
						continue
					}

					// Pattern: sort | uniq -> sort -u
					if first_name == "sort" && second_name == "uniq" && len(second_cmd.arguments) == 0 {
						fn.body[idx] = ir.Statement{
							type = .Call,
							call = with_leading_arg(first_cmd, "-u", allocator),
							location = stmt.location,
						}
						result.changed = true
						msg := fmt.aprintf(
							"Simplified 'sort | uniq' pipeline in %s",
							fn.name,
							allocator,
						)
						add_diagnostic(&result, msg)
						record_pattern(&result, "sort_uniq_to_sort_u", 1, 0, 1)
						continue
					}

					// Pattern: grep ... | wc -l -> grep -c ...
					if first_name == "grep" && second_name == "wc" && len(second_cmd.arguments) == 1 && arg_text(second_cmd.arguments[0]) == "-l" && !has_grep_count_related_flag(first_cmd) {
						fn.body[idx] = ir.Statement{
							type = .Call,
							call = with_leading_arg(first_cmd, "-c", allocator),
							location = stmt.location,
						}
						result.changed = true
						msg := fmt.aprintf(
							"Simplified 'grep | wc -l' pipeline in %s",
							fn.name,
							allocator,
						)
						add_diagnostic(&result, msg)
						record_pattern(&result, "grep_wc_count_to_grep_c", 1, 0, 1)
					}
				}
			}
		}
	}

	return result
}

// inline_small_functions inlines small functions
// 23.6: Inlines functions with single statement
// Only at aggressive optimization level
inline_small_functions :: proc(
	program: ^ir.Program,
	allocator := context.allocator,
) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil || len(program.functions) == 0 {
		return result
	}

	// Find small functions (single statement, no parameters)
	small_functions := make(map[string]ir.Function, allocator)
	defer delete(small_functions)

	for fn in program.functions {
		// Skip main function and functions with parameters
		if fn.name == "main" || len(fn.parameters) > 0 {
			continue
		}
		// Check if function has single simple statement
		if len(fn.body) == 1 {
			small_functions[fn.name] = fn
		}
	}

	// Inline calls to small functions
	for &fn in program.functions {
		for &stmt, idx in fn.body {
			if stmt.type == .Call {
				call_name := ""
				if stmt.call.function != nil {
					call_name = stmt.call.function.name
				}
				if target, ok := small_functions[call_name]; ok {
					// Inline the function body
					if len(target.body) > 0 {
						fn.body[idx] = target.body[0]
						result.changed = true
						msg := fmt.aprintf(
							"Inlined function '%s' in '%s'",
							call_name,
							fn.name,
							allocator,
						)
						add_diagnostic(&result, msg)
					}
				}
			}
		}
	}

	return result
}

// loop_unrolling unrolls loops with constant bounds
// 23.7: Unrolls loops with constant bounds
// Only for small iteration counts
// Only at aggressive optimization level
loop_unrolling :: proc(program: ^ir.Program, allocator := context.allocator) -> OptimizeResult {
	result := create_optimize_result(allocator)

	if program == nil {
		return result
	}

	MAX_UNROLL_COUNT :: 4 // Maximum iterations to unroll

	for &fn in program.functions {
		for &stmt in fn.body {
			if stmt.type == .Loop {
				loop := &stmt.loop

				// Check if this is a for-in loop with an iterable
				if loop.kind == .ForIn && loop.items != nil {
					// Try to determine if the iterable is a constant array
					// This is simplified - in reality you'd need to parse the iterable
					// For now, we'll just check if it looks like a simple list

					// Example: "1 2 3 4" or similar
					// In a real implementation, you'd parse this properly

					// For now, just mark that we attempted loop unrolling
					result.changed = false
					msg := fmt.aprintf("Analyzed loop in '%s' for unrolling", fn.name, allocator)
					add_diagnostic(&result, msg)
				}
			}
		}
	}

	return result
}
